-- Enforce MASTER ADMIN feature gates on passenger ride creation.
-- Quotes remain available while dispatch/cash payment is disabled.
CREATE OR REPLACE FUNCTION public.go_create_ride_from_quote(
  p_quote_id uuid,
  p_category_code text,
  p_payment_method text DEFAULT 'cash'::text
)
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
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = v_uid AND p.account_status = 'active'
  ) THEN
    RAISE EXCEPTION 'Active passenger account required' USING ERRCODE='42501';
  END IF;

  IF NOT public.go_is_feature_enabled('ride.booking_dispatch') THEN
    RAISE EXCEPTION 'Ride booking is currently disabled by MASTER ADMIN';
  END IF;

  IF p_payment_method IS DISTINCT FROM 'cash' THEN
    RAISE EXCEPTION 'Only cash payment is available until a payment provider is connected';
  END IF;

  IF NOT public.go_is_feature_enabled('payment.cash') THEN
    RAISE EXCEPTION 'Cash payment is currently disabled by MASTER ADMIN';
  END IF;

  SELECT * INTO v_quote
  FROM public.ride_quotes q
  WHERE q.id = p_quote_id
  FOR UPDATE;

  IF NOT FOUND OR v_quote.passenger_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'Quote not found' USING ERRCODE='42501';
  END IF;

  IF v_quote.quote_source IS DISTINCT FROM 'GO' OR v_quote.status <> 'priced' THEN
    RAISE EXCEPTION 'Only priced GO quotes can be booked';
  END IF;

  IF v_quote.expires_at IS NULL OR v_quote.expires_at <= now() THEN
    RAISE EXCEPTION 'Fare quote expired; calculate a new quote';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.go_quote_tariff_snapshots s
    WHERE s.quote_id = p_quote_id
  ) THEN
    RAISE EXCEPTION 'Immutable fare snapshot is required';
  END IF;

  SELECT i.category_id, i.category_code, i.total_fare, i.currency_code
  INTO v_item
  FROM public.ride_quote_items i
  JOIN public.vehicle_categories c
    ON c.id = i.category_id AND c.is_active = true
  WHERE i.quote_id = p_quote_id AND i.category_code = p_category_code;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Selected vehicle category is unavailable';
  END IF;

  SELECT rp.address INTO v_pickup
  FROM public.ride_route_points rp
  WHERE rp.quote_id = p_quote_id
  ORDER BY rp.sequence_number
  LIMIT 1;

  SELECT rp.address INTO v_dropoff
  FROM public.ride_route_points rp
  WHERE rp.quote_id = p_quote_id
  ORDER BY rp.sequence_number DESC
  LIMIT 1;

  UPDATE public.ride_quotes
  SET selected_category_id = v_item.category_id,
      selected_fare = v_item.total_fare,
      status = 'confirmed',
      updated_at = now()
  WHERE id = p_quote_id;

  INSERT INTO public.go_rides (
    quote_id, passenger_id, city_id, category_code,
    pickup_address, dropoff_address, fare_amount, currency_code,
    payment_method, payment_status, status
  )
  VALUES (
    p_quote_id, v_uid, v_quote.city_id, v_item.category_code,
    v_pickup, v_dropoff, v_item.total_fare, v_item.currency_code,
    'cash', 'cash_due', 'dispatching'
  )
  RETURNING id INTO v_ride_id;

  INSERT INTO public.go_ride_events (
    ride_id, actor_user_id, actor_role, event_type, new_status, note
  )
  VALUES (
    v_ride_id, v_uid, 'passenger', 'ride.requested', 'dispatching',
    'Passenger confirmed a priced GO quote'
  );

  INSERT INTO public.go_driver_offers (
    ride_id, driver_user_id, status, offered_at, expires_at
  )
  SELECT
    v_ride_id, dp.user_id, 'sent', now(), now() + interval '45 seconds'
  FROM public.driver_live_locations ll
  JOIN public.driver_profiles dp ON dp.user_id = ll.driver_user_id
  JOIN public.profiles pr
    ON pr.id = dp.user_id AND pr.account_status = 'active'
  WHERE dp.approval_status = 'approved'
    AND dp.work_city_id = v_quote.city_id
    AND ll.is_online
    AND ll.location IS NOT NULL
    AND ll.updated_at >= now() - interval '90 seconds'
  ORDER BY public.ST_Distance(
    ll.location,
    (
      SELECT public.ST_SetSRID(
        public.ST_MakePoint(rp.longitude::double precision, rp.latitude::double precision),
        4326
      )::public.geography
      FROM public.ride_route_points rp
      WHERE rp.quote_id = p_quote_id
      ORDER BY rp.sequence_number
      LIMIT 1
    )
  ) ASC
  LIMIT 10
  ON CONFLICT (ride_id, driver_user_id) DO NOTHING;

  GET DIAGNOSTICS v_offers = ROW_COUNT;

  RETURN jsonb_build_object(
    'ride_id', v_ride_id,
    'status', 'dispatching',
    'offers_sent', v_offers,
    'payment_method', 'cash'
  );
END;
$function$;
