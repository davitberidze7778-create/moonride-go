CREATE OR REPLACE FUNCTION public.go_create_ride_from_quote_with_discounts(p_quote_id uuid, p_category_code text, p_payment_method text DEFAULT 'cash'::text, p_voucher_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_quote public.ride_quotes%ROWTYPE;
  v_item record;
  v_ride_id uuid;
  v_offers int := 0;
  v_pickup text;
  v_dropoff text;
  v_voucher public.go_vouchers%ROWTYPE;
  v_voucher_id uuid;
  v_reward_id uuid;
  v_completed_count integer := 0;
  v_is_tenth_ride boolean := false;
  v_voucher_discount numeric(14,2) := 0;
  v_loyalty_discount numeric(14,2) := 0;
  v_discount_total numeric(14,2) := 0;
  v_final_fare numeric(14,2);
  v_wallet_before numeric(14,2);
  v_wallet_after numeric(14,2);
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  PERFORM 1 FROM public.profiles p
  WHERE p.id=v_uid AND p.role='passenger' AND p.account_status='active'
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active passenger account required' USING ERRCODE='42501'; END IF;
  IF NOT public.go_is_feature_enabled('ride.booking_dispatch') THEN
    RAISE EXCEPTION 'Ride booking is currently disabled by MASTER ADMIN';
  END IF;

  IF p_payment_method='cash' THEN
    IF NOT public.go_is_feature_enabled('payment.cash') THEN
      RAISE EXCEPTION 'Cash payment is currently disabled by MASTER ADMIN';
    END IF;
  ELSIF p_payment_method='wallet' THEN
    IF NOT public.go_is_feature_enabled('payment.wallet') THEN
      RAISE EXCEPTION 'MOONRIDE Wallet is currently disabled by MASTER ADMIN';
    END IF;
  ELSE
    RAISE EXCEPTION 'Card payments are unavailable until a TBC or Bank of Georgia PSP is securely configured';
  END IF;

  SELECT * INTO v_quote FROM public.ride_quotes q
  WHERE q.id=p_quote_id FOR UPDATE;
  IF NOT FOUND OR v_quote.passenger_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'Quote not found' USING ERRCODE='42501';
  END IF;
  IF v_quote.quote_source IS DISTINCT FROM 'GO' OR v_quote.status<>'priced' THEN
    RAISE EXCEPTION 'Only priced GO quotes can be booked';
  END IF;
  IF v_quote.expires_at IS NULL OR v_quote.expires_at<=now() THEN
    RAISE EXCEPTION 'Fare quote expired; calculate a new quote';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.go_quote_tariff_snapshots s WHERE s.quote_id=p_quote_id) THEN
    RAISE EXCEPTION 'Immutable fare snapshot is required';
  END IF;

  SELECT i.category_id,i.category_code,i.total_fare,i.currency_code
  INTO v_item
  FROM public.ride_quote_items i
  JOIN public.vehicle_categories c ON c.id=i.category_id AND c.is_active=true
  WHERE i.quote_id=p_quote_id AND i.category_code=p_category_code;
  IF NOT FOUND THEN RAISE EXCEPTION 'Selected vehicle category is unavailable'; END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.driver_live_locations ll
    JOIN public.driver_profiles dp ON dp.user_id=ll.driver_user_id
    JOIN public.profiles pr ON pr.id=dp.user_id AND pr.account_status='active'
    WHERE dp.approval_status='approved' AND dp.work_city_id=v_quote.city_id
      AND ll.is_online=true AND ll.location IS NOT NULL
      AND ll.updated_at>=now()-interval '90 seconds'
      AND public.ST_DWithin(
        ll.location,
        (SELECT public.ST_SetSRID(public.ST_MakePoint(rp.longitude::double precision,rp.latitude::double precision),4326)::public.geography
         FROM public.ride_route_points rp WHERE rp.quote_id=p_quote_id ORDER BY rp.sequence_number LIMIT 1),
        10000
      )
  ) THEN RAISE EXCEPTION 'No approved online drivers are currently available in this city'; END IF;

  IF nullif(upper(btrim(coalesce(p_voucher_code,''))),'') IS NOT NULL THEN
    IF NOT public.go_is_feature_enabled('promos.vouchers') THEN
      RAISE EXCEPTION 'Voucher redemption is currently disabled by MASTER ADMIN';
    END IF;
    SELECT * INTO v_voucher FROM public.go_vouchers v
    WHERE v.code=upper(btrim(p_voucher_code)) AND v.is_active
      AND v.valid_from<=now() AND (v.valid_until IS NULL OR v.valid_until>now())
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Voucher code is invalid or expired'; END IF;
    IF EXISTS (
      SELECT 1 FROM public.go_voucher_redemptions r
      WHERE r.voucher_id=v_voucher.id AND r.passenger_id=v_uid
    ) THEN RAISE EXCEPTION 'This voucher has already been used by this passenger'; END IF;
    IF v_voucher.currency_code IS NOT NULL AND v_voucher.currency_code<>v_item.currency_code THEN
      RAISE EXCEPTION 'Voucher currency does not match this ride';
    END IF;
    IF v_item.total_fare<v_voucher.minimum_fare THEN
      RAISE EXCEPTION 'Ride fare does not meet the voucher minimum';
    END IF;
    IF v_voucher.max_redemptions IS NOT NULL AND
       (SELECT count(*) FROM public.go_voucher_redemptions r WHERE r.voucher_id=v_voucher.id)>=v_voucher.max_redemptions THEN
      RAISE EXCEPTION 'Voucher redemption limit has been reached';
    END IF;
    IF v_voucher.discount_type='percentage' THEN
      v_voucher_discount:=round(v_item.total_fare*v_voucher.discount_value/100,2);
    ELSE
      v_voucher_discount:=least(v_item.total_fare,v_voucher.discount_value);
    END IF;
    IF v_voucher.max_discount_amount IS NOT NULL THEN
      v_voucher_discount:=least(v_voucher_discount,v_voucher.max_discount_amount);
    END IF;
    v_voucher_id:=v_voucher.id;
  END IF;

  IF public.go_is_feature_enabled('loyalty.10th_ride') THEN
    SELECT count(*)::integer INTO v_completed_count
    FROM public.go_rides r
    WHERE r.passenger_id=v_uid AND r.status='completed';
    v_is_tenth_ride := ((v_completed_count + 1) % 10 = 0)
      AND NOT EXISTS (
        SELECT 1 FROM public.go_rides r
        WHERE r.passenger_id=v_uid
          AND r.loyalty_reward_id IS NOT NULL
          AND r.status NOT IN ('completed','cancelled','no_driver')
      );
    IF v_is_tenth_ride THEN
      v_loyalty_discount:=round(v_item.total_fare * 0.25, 2);
    END IF;
  END IF;

  v_discount_total:=least(v_item.total_fare,v_voucher_discount+v_loyalty_discount);
  v_final_fare:=greatest(0,v_item.total_fare-v_discount_total);

  IF p_payment_method='wallet' THEN
    INSERT INTO public.go_wallet_accounts(user_id,currency_code)
    VALUES (v_uid,v_item.currency_code)
    ON CONFLICT (user_id,currency_code) DO NOTHING;
    SELECT balance INTO v_wallet_before
    FROM public.go_wallet_accounts
    WHERE user_id=v_uid AND currency_code=v_item.currency_code
    FOR UPDATE;
    IF NOT FOUND OR v_wallet_before<v_final_fare THEN
      RAISE EXCEPTION 'MOONRIDE Wallet balance is insufficient';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.go_wallet_accounts
      WHERE user_id=v_uid AND currency_code=v_item.currency_code AND status='active'
    ) THEN RAISE EXCEPTION 'MOONRIDE Wallet is frozen'; END IF;
  END IF;

  SELECT rp.address INTO v_pickup FROM public.ride_route_points rp
  WHERE rp.quote_id=p_quote_id ORDER BY rp.sequence_number LIMIT 1;
  SELECT rp.address INTO v_dropoff FROM public.ride_route_points rp
  WHERE rp.quote_id=p_quote_id ORDER BY rp.sequence_number DESC LIMIT 1;

  UPDATE public.ride_quotes
  SET selected_category_id=v_item.category_id,selected_fare=v_final_fare,status='confirmed',updated_at=now()
  WHERE id=p_quote_id;

  INSERT INTO public.go_rides(
    quote_id,passenger_id,city_id,category_code,pickup_address,dropoff_address,
    fare_amount,original_fare_amount,discount_amount,voucher_code,loyalty_reward_id,
    currency_code,payment_method,payment_status,status
  ) VALUES (
    p_quote_id,v_uid,v_quote.city_id,v_item.category_code,v_pickup,v_dropoff,
    v_final_fare,v_item.total_fare,v_discount_total,
    CASE WHEN v_voucher_id IS NULL THEN NULL ELSE v_voucher.code END,
    v_reward_id,v_item.currency_code,p_payment_method,
    CASE WHEN p_payment_method='wallet' THEN 'paid' ELSE 'cash_due' END,'dispatching'
  ) RETURNING id INTO v_ride_id;

  IF v_is_tenth_ride THEN
    INSERT INTO public.go_loyalty_rewards(
      passenger_id,earned_on_ride_id,redeemed_on_ride_id,
      completed_ride_number,discount_percent,status,redeemed_at
    ) VALUES (
      v_uid,v_ride_id,v_ride_id,v_completed_count+1,25,'redeemed',now()
    ) RETURNING id INTO v_reward_id;
    UPDATE public.go_rides SET loyalty_reward_id=v_reward_id WHERE id=v_ride_id;
  END IF;

  IF v_voucher_id IS NOT NULL THEN
    INSERT INTO public.go_voucher_redemptions(
      voucher_id,passenger_id,ride_id,original_fare,discount_amount,currency_code
    ) VALUES (v_voucher_id,v_uid,v_ride_id,v_item.total_fare,v_voucher_discount,v_item.currency_code);
  END IF;



  IF p_payment_method='wallet' AND v_final_fare>0 THEN
    UPDATE public.go_wallet_accounts
    SET balance=balance-v_final_fare,updated_at=now()
    WHERE user_id=v_uid AND currency_code=v_item.currency_code
    RETURNING balance INTO v_wallet_after;
    INSERT INTO public.go_wallet_transactions(
      user_id,currency_code,direction,transaction_type,amount,balance_before,balance_after,
      ride_id,source_type,source_id,note,created_by
    ) VALUES (
      v_uid,v_item.currency_code,'debit','ride_debit',v_final_fare,
      v_wallet_before,v_wallet_after,v_ride_id,'ride',v_ride_id,
      'MOONRIDE ride payment',v_uid
    );
  END IF;

  INSERT INTO public.go_ride_events(ride_id,actor_user_id,actor_role,event_type,new_status,note,metadata)
  VALUES (
    v_ride_id,v_uid,'passenger','ride.requested','dispatching',
    'Passenger confirmed a priced GO quote',
    jsonb_build_object('payment_method',p_payment_method,'original_fare',v_item.total_fare,
      'discount_amount',v_discount_total,'voucher_code',v_voucher.code,
      'loyalty_reward_id',v_reward_id)
  );

  INSERT INTO public.go_driver_offers(ride_id,driver_user_id,status,offered_at,expires_at)
  SELECT v_ride_id,dp.user_id,'sent',now(),now()+interval '45 seconds'
  FROM public.driver_live_locations ll
  JOIN public.driver_profiles dp ON dp.user_id=ll.driver_user_id
  JOIN public.profiles pr ON pr.id=dp.user_id AND pr.account_status='active'
  WHERE dp.approval_status='approved' AND dp.work_city_id=v_quote.city_id
    AND ll.is_online AND ll.location IS NOT NULL
    AND ll.updated_at>=now()-interval '90 seconds'
    AND public.ST_DWithin(
      ll.location,
      (SELECT public.ST_SetSRID(public.ST_MakePoint(rp.longitude::double precision,rp.latitude::double precision),4326)::public.geography
       FROM public.ride_route_points rp WHERE rp.quote_id=p_quote_id ORDER BY rp.sequence_number LIMIT 1),
      10000
    )
  ORDER BY public.ST_Distance(
    ll.location,
    (SELECT public.ST_SetSRID(public.ST_MakePoint(rp.longitude::double precision,rp.latitude::double precision),4326)::public.geography
     FROM public.ride_route_points rp WHERE rp.quote_id=p_quote_id ORDER BY rp.sequence_number LIMIT 1)
  ) ASC
  LIMIT 10
  ON CONFLICT (ride_id,driver_user_id) DO NOTHING;
  GET DIAGNOSTICS v_offers=ROW_COUNT;

  RETURN jsonb_build_object(
    'ride_id',v_ride_id,'status','dispatching','offers_sent',v_offers,
    'payment_method',p_payment_method,'fare_amount',v_final_fare,
    'original_fare_amount',v_item.total_fare,'discount_amount',v_discount_total,
    'wallet_balance',CASE WHEN p_payment_method='wallet' THEN v_wallet_after ELSE NULL END
  );
END;
$function$;

CREATE INDEX IF NOT EXISTS go_rides_active_loyalty_reservation_idx
ON public.go_rides(passenger_id, status)
WHERE loyalty_reward_id IS NOT NULL
  AND status NOT IN ('completed','cancelled','no_driver');
