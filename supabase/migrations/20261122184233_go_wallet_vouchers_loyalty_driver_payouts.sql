-- MOONRIDE finance, rewards and driver payout foundation.
-- Additive migration: existing rides, quotes and tariff snapshots are preserved.

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.go_wallet_accounts (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  currency_code text NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
  balance numeric(14,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','frozen')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, currency_code)
);

CREATE TABLE IF NOT EXISTS public.go_wallet_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  currency_code text NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
  direction text NOT NULL CHECK (direction IN ('credit','debit')),
  transaction_type text NOT NULL CHECK (transaction_type IN ('admin_credit','ride_debit','ride_refund','adjustment')),
  amount numeric(14,2) NOT NULL CHECK (amount > 0),
  balance_before numeric(14,2) NOT NULL CHECK (balance_before >= 0),
  balance_after numeric(14,2) NOT NULL CHECK (balance_after >= 0),
  ride_id uuid REFERENCES public.go_rides(id) ON DELETE RESTRICT,
  source_type text,
  source_id uuid,
  note text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT go_wallet_transaction_idempotency UNIQUE (transaction_type, source_id)
);

CREATE TABLE IF NOT EXISTS public.go_payment_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES public.go_rides(id) ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  provider text NOT NULL CHECK (provider IN ('tbc','bog')),
  amount numeric(14,2) NOT NULL CHECK (amount > 0),
  currency_code text NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
  status text NOT NULL DEFAULT 'created' CHECK (status IN ('created','pending','succeeded','failed','cancelled','refunded')),
  provider_payment_id text,
  checkout_url text,
  idempotency_key text NOT NULL UNIQUE,
  provider_response jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.go_vouchers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE CHECK (code = upper(btrim(code)) AND length(code) BETWEEN 3 AND 40),
  discount_type text NOT NULL CHECK (discount_type IN ('percentage','fixed')),
  discount_value numeric(12,2) NOT NULL CHECK (discount_value > 0),
  currency_code text CHECK (currency_code IS NULL OR currency_code ~ '^[A-Z]{3}$'),
  max_discount_amount numeric(12,2) CHECK (max_discount_amount IS NULL OR max_discount_amount > 0),
  minimum_fare numeric(12,2) NOT NULL DEFAULT 0 CHECK (minimum_fare >= 0),
  max_redemptions integer CHECK (max_redemptions IS NULL OR max_redemptions > 0),
  is_active boolean NOT NULL DEFAULT true,
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_until timestamptz,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT go_voucher_validity_check CHECK (valid_until IS NULL OR valid_until > valid_from),
  CONSTRAINT go_voucher_percentage_check CHECK (discount_type <> 'percentage' OR discount_value <= 100),
  CONSTRAINT go_voucher_fixed_currency_check CHECK (discount_type <> 'fixed' OR currency_code IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS public.go_voucher_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  voucher_id uuid NOT NULL REFERENCES public.go_vouchers(id) ON DELETE RESTRICT,
  passenger_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  ride_id uuid NOT NULL UNIQUE REFERENCES public.go_rides(id) ON DELETE RESTRICT,
  original_fare numeric(12,2) NOT NULL CHECK (original_fare >= 0),
  discount_amount numeric(12,2) NOT NULL CHECK (discount_amount >= 0),
  currency_code text NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
  redeemed_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT go_voucher_one_use_per_passenger UNIQUE (voucher_id, passenger_id)
);

CREATE TABLE IF NOT EXISTS public.go_loyalty_rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  earned_on_ride_id uuid NOT NULL UNIQUE REFERENCES public.go_rides(id) ON DELETE RESTRICT,
  redeemed_on_ride_id uuid UNIQUE REFERENCES public.go_rides(id) ON DELETE RESTRICT,
  completed_ride_number integer NOT NULL CHECK (completed_ride_number > 0 AND completed_ride_number % 10 = 0),
  discount_percent numeric(5,2) NOT NULL DEFAULT 25 CHECK (discount_percent = 25),
  status text NOT NULL DEFAULT 'available' CHECK (status IN ('available','redeemed','expired')),
  created_at timestamptz NOT NULL DEFAULT now(),
  redeemed_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.go_driver_wallet_accounts (
  driver_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  currency_code text NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
  balance numeric(14,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','frozen')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (driver_user_id, currency_code)
);

CREATE TABLE IF NOT EXISTS public.go_driver_wallet_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  currency_code text NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
  direction text NOT NULL CHECK (direction IN ('credit','debit')),
  transaction_type text NOT NULL CHECK (transaction_type IN ('admin_earning_credit','payout_debit','adjustment')),
  amount numeric(14,2) NOT NULL CHECK (amount > 0),
  balance_before numeric(14,2) NOT NULL CHECK (balance_before >= 0),
  balance_after numeric(14,2) NOT NULL CHECK (balance_after >= 0),
  source_type text,
  source_id uuid,
  note text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT go_driver_wallet_transaction_idempotency UNIQUE (transaction_type, source_id)
);

CREATE TABLE IF NOT EXISTS public.go_driver_payout_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  amount numeric(14,2) NOT NULL CHECK (amount > 0),
  currency_code text NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
  bank_code text NOT NULL CHECK (bank_code IN ('tbc','bog')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','paid')),
  admin_note text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  paid_at timestamptz
);

CREATE TABLE IF NOT EXISTS private.go_driver_payout_details (
  payout_request_id uuid PRIMARY KEY REFERENCES public.go_driver_payout_requests(id) ON DELETE CASCADE,
  account_holder text NOT NULL,
  iban text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON private.go_driver_payout_details FROM PUBLIC, anon, authenticated;
ALTER TABLE private.go_driver_payout_details ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.go_rides
  ADD COLUMN IF NOT EXISTS original_fare_amount numeric(14,2),
  ADD COLUMN IF NOT EXISTS discount_amount numeric(14,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS voucher_code text,
  ADD COLUMN IF NOT EXISTS loyalty_reward_id uuid REFERENCES public.go_loyalty_rewards(id) ON DELETE RESTRICT;

UPDATE public.go_rides
SET original_fare_amount = fare_amount
WHERE original_fare_amount IS NULL;

ALTER TABLE public.go_rides
  ALTER COLUMN original_fare_amount SET NOT NULL,
  DROP CONSTRAINT IF EXISTS go_rides_payment_method_check,
  ADD CONSTRAINT go_rides_payment_method_check
    CHECK (payment_method IN ('cash','wallet','tbc_card','bog_card'));

CREATE INDEX IF NOT EXISTS go_wallet_transactions_user_created_idx
  ON public.go_wallet_transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS go_payment_attempts_user_created_idx
  ON public.go_payment_attempts(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS go_voucher_redemptions_passenger_idx
  ON public.go_voucher_redemptions(passenger_id, redeemed_at DESC);
CREATE INDEX IF NOT EXISTS go_loyalty_rewards_available_idx
  ON public.go_loyalty_rewards(passenger_id, created_at)
  WHERE status = 'available';
CREATE INDEX IF NOT EXISTS go_driver_wallet_transactions_driver_created_idx
  ON public.go_driver_wallet_transactions(driver_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS go_driver_payout_requests_driver_status_idx
  ON public.go_driver_payout_requests(driver_user_id, status, requested_at DESC);

ALTER TABLE public.go_wallet_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.go_wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.go_payment_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.go_vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.go_voucher_redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.go_loyalty_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.go_driver_wallet_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.go_driver_wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.go_driver_payout_requests ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.go_wallet_accounts, public.go_wallet_transactions,
  public.go_payment_attempts, public.go_vouchers, public.go_voucher_redemptions,
  public.go_loyalty_rewards, public.go_driver_wallet_accounts,
  public.go_driver_wallet_transactions, public.go_driver_payout_requests
FROM PUBLIC, anon, authenticated;

GRANT SELECT ON public.go_wallet_accounts, public.go_wallet_transactions,
  public.go_payment_attempts, public.go_voucher_redemptions, public.go_loyalty_rewards,
  public.go_driver_wallet_accounts, public.go_driver_wallet_transactions,
  public.go_driver_payout_requests
TO authenticated;

GRANT SELECT, INSERT, UPDATE ON public.go_vouchers TO authenticated;

CREATE POLICY go_wallet_accounts_read_owner_or_admin ON public.go_wallet_accounts
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) OR (SELECT public.is_master_admin()));
CREATE POLICY go_wallet_transactions_read_owner_or_admin ON public.go_wallet_transactions
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) OR (SELECT public.is_master_admin()));
CREATE POLICY go_payment_attempts_read_owner_or_admin ON public.go_payment_attempts
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) OR (SELECT public.is_master_admin()));
CREATE POLICY go_vouchers_admin_manage ON public.go_vouchers
  FOR ALL TO authenticated
  USING ((SELECT public.is_master_admin()))
  WITH CHECK ((SELECT public.is_master_admin()));
CREATE POLICY go_voucher_redemptions_read_owner_or_admin ON public.go_voucher_redemptions
  FOR SELECT TO authenticated
  USING (passenger_id = (SELECT auth.uid()) OR (SELECT public.is_master_admin()));
CREATE POLICY go_loyalty_rewards_read_owner_or_admin ON public.go_loyalty_rewards
  FOR SELECT TO authenticated
  USING (passenger_id = (SELECT auth.uid()) OR (SELECT public.is_master_admin()));
CREATE POLICY go_driver_wallet_accounts_read_owner_or_admin ON public.go_driver_wallet_accounts
  FOR SELECT TO authenticated
  USING (driver_user_id = (SELECT auth.uid()) OR (SELECT public.is_master_admin()));
CREATE POLICY go_driver_wallet_transactions_read_owner_or_admin ON public.go_driver_wallet_transactions
  FOR SELECT TO authenticated
  USING (driver_user_id = (SELECT auth.uid()) OR (SELECT public.is_master_admin()));
CREATE POLICY go_driver_payout_requests_read_owner_or_admin ON public.go_driver_payout_requests
  FOR SELECT TO authenticated
  USING (driver_user_id = (SELECT auth.uid()) OR (SELECT public.is_master_admin()));

CREATE OR REPLACE FUNCTION public.go_admin_credit_wallet(
  p_user_id uuid,
  p_amount numeric,
  p_currency_code text,
  p_note text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_balance_before numeric(14,2);
  v_balance_after numeric(14,2);
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_master_admin() THEN
    RAISE EXCEPTION 'MASTER ADMIN required' USING ERRCODE = '42501';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 OR p_amount > 1000000
     OR p_currency_code !~ '^[A-Z]{3}$' THEN
    RAISE EXCEPTION 'Invalid wallet credit amount or currency';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = p_user_id AND role = 'passenger'
  ) THEN
    RAISE EXCEPTION 'Passenger account not found';
  END IF;

  INSERT INTO public.go_wallet_accounts(user_id, currency_code)
  VALUES (p_user_id, p_currency_code)
  ON CONFLICT (user_id, currency_code) DO NOTHING;

  SELECT balance INTO v_balance_before
  FROM public.go_wallet_accounts
  WHERE user_id = p_user_id AND currency_code = p_currency_code
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Wallet account could not be locked'; END IF;
  UPDATE public.go_wallet_accounts
  SET balance = balance + p_amount, updated_at = now()
  WHERE user_id = p_user_id AND currency_code = p_currency_code
  RETURNING balance INTO v_balance_after;

  INSERT INTO public.go_wallet_transactions(
    user_id,currency_code,direction,transaction_type,amount,
    balance_before,balance_after,source_type,note,created_by
  ) VALUES (
    p_user_id,p_currency_code,'credit','admin_credit',p_amount,
    v_balance_before,v_balance_after,'master_admin',nullif(btrim(coalesce(p_note,'')),''),auth.uid()
  );

  RETURN jsonb_build_object('user_id',p_user_id,'currency_code',p_currency_code,'balance',v_balance_after);
END;
$function$;

CREATE OR REPLACE FUNCTION public.go_admin_credit_driver_wallet(
  p_driver_user_id uuid,
  p_amount numeric,
  p_currency_code text,
  p_note text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_before numeric(14,2);
  v_after numeric(14,2);
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_master_admin() THEN
    RAISE EXCEPTION 'MASTER ADMIN required' USING ERRCODE='42501';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 OR p_amount > 1000000
     OR p_currency_code !~ '^[A-Z]{3}$'
     OR nullif(btrim(coalesce(p_note,'')),'') IS NULL THEN
    RAISE EXCEPTION 'Valid amount, currency and earning note are required';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    JOIN public.driver_profiles d ON d.user_id=p.id
    WHERE p.id=p_driver_user_id AND p.role='driver' AND p.account_status='active'
      AND d.approval_status='approved'
  ) THEN
    RAISE EXCEPTION 'Approved active driver not found';
  END IF;
  INSERT INTO public.go_driver_wallet_accounts(driver_user_id,currency_code)
  VALUES (p_driver_user_id,p_currency_code)
  ON CONFLICT (driver_user_id,currency_code) DO NOTHING;
  SELECT balance INTO v_before FROM public.go_driver_wallet_accounts
  WHERE driver_user_id=p_driver_user_id AND currency_code=p_currency_code FOR UPDATE;
  UPDATE public.go_driver_wallet_accounts
  SET balance=balance+p_amount,updated_at=now()
  WHERE driver_user_id=p_driver_user_id AND currency_code=p_currency_code
  RETURNING balance INTO v_after;
  INSERT INTO public.go_driver_wallet_transactions(
    driver_user_id,currency_code,direction,transaction_type,amount,
    balance_before,balance_after,source_type,note,created_by
  ) VALUES (
    p_driver_user_id,p_currency_code,'credit','admin_earning_credit',p_amount,
    v_before,v_after,'master_admin',btrim(p_note),auth.uid()
  );
  RETURN jsonb_build_object('driver_user_id',p_driver_user_id,'currency_code',p_currency_code,'balance',v_after);
END;
$function$;

CREATE OR REPLACE FUNCTION public.go_request_driver_payout(
  p_amount numeric,
  p_currency_code text,
  p_bank_code text,
  p_account_holder text,
  p_iban text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_balance numeric(14,2);
  v_reserved numeric(14,2);
  v_payout_id uuid;
  v_iban text := upper(regexp_replace(coalesce(p_iban,''),'[^A-Za-z0-9]','','g'));
BEGIN
  IF v_uid IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.profiles p
    JOIN public.driver_profiles d ON d.user_id=p.id
    WHERE p.id=v_uid AND p.role='driver' AND p.account_status='active'
      AND d.approval_status='approved'
  ) THEN
    RAISE EXCEPTION 'Approved active driver account required' USING ERRCODE='42501';
  END IF;
  IF NOT public.go_is_feature_enabled('driver.payouts') THEN
    RAISE EXCEPTION 'Driver payouts are disabled by MASTER ADMIN';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 OR p_currency_code !~ '^[A-Z]{3}$'
     OR p_bank_code NOT IN ('tbc','bog')
     OR length(btrim(coalesce(p_account_holder,''))) < 3
     OR v_iban !~ '^[A-Z]{2}[0-9A-Z]{13,32}$' THEN
    RAISE EXCEPTION 'Valid payout details are required';
  END IF;

  SELECT balance INTO v_balance
  FROM public.go_driver_wallet_accounts
  WHERE driver_user_id=v_uid AND currency_code=p_currency_code
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'No available driver balance'; END IF;

  SELECT coalesce(sum(amount),0) INTO v_reserved
  FROM public.go_driver_payout_requests
  WHERE driver_user_id=v_uid AND currency_code=p_currency_code
    AND status IN ('pending','approved');
  IF p_amount > v_balance - v_reserved THEN
    RAISE EXCEPTION 'Payout amount exceeds available balance';
  END IF;

  INSERT INTO public.go_driver_payout_requests(driver_user_id,amount,currency_code,bank_code)
  VALUES (v_uid,p_amount,p_currency_code,p_bank_code)
  RETURNING id INTO v_payout_id;

  INSERT INTO private.go_driver_payout_details(payout_request_id,account_holder,iban)
  VALUES (v_payout_id,btrim(p_account_holder),v_iban);

  RETURN jsonb_build_object('payout_request_id',v_payout_id,'status','pending','amount',p_amount,'currency_code',p_currency_code);
END;
$function$;

CREATE OR REPLACE FUNCTION public.go_admin_set_driver_payout_status(
  p_payout_request_id uuid,
  p_status text,
  p_note text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_row public.go_driver_payout_requests%ROWTYPE;
  v_before numeric(14,2);
  v_after numeric(14,2);
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_master_admin() THEN
    RAISE EXCEPTION 'MASTER ADMIN required' USING ERRCODE='42501';
  END IF;
  IF p_status NOT IN ('approved','rejected','paid') THEN
    RAISE EXCEPTION 'Invalid payout status';
  END IF;
  SELECT * INTO v_row FROM public.go_driver_payout_requests
  WHERE id=p_payout_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Payout request not found'; END IF;
  IF v_row.status IN ('paid','rejected') THEN
    RAISE EXCEPTION 'Payout request is already finalized';
  END IF;

  IF p_status='paid' THEN
    SELECT balance INTO v_before FROM public.go_driver_wallet_accounts
    WHERE driver_user_id=v_row.driver_user_id AND currency_code=v_row.currency_code
    FOR UPDATE;
    IF NOT FOUND OR v_before < v_row.amount THEN
      RAISE EXCEPTION 'Driver wallet balance is insufficient for payout';
    END IF;
    UPDATE public.go_driver_wallet_accounts
    SET balance=balance-v_row.amount,updated_at=now()
    WHERE driver_user_id=v_row.driver_user_id AND currency_code=v_row.currency_code
    RETURNING balance INTO v_after;
    INSERT INTO public.go_driver_wallet_transactions(
      driver_user_id,currency_code,direction,transaction_type,amount,
      balance_before,balance_after,source_type,source_id,note,created_by
    ) VALUES (
      v_row.driver_user_id,v_row.currency_code,'debit','payout_debit',v_row.amount,
      v_before,v_after,'payout',v_row.id,nullif(btrim(coalesce(p_note,'')),''),auth.uid()
    );
  END IF;

  UPDATE public.go_driver_payout_requests
  SET status=p_status,admin_note=nullif(btrim(coalesce(p_note,'')),''),
      reviewed_by=auth.uid(),reviewed_at=now(),
      paid_at=CASE WHEN p_status='paid' THEN now() ELSE paid_at END
  WHERE id=p_payout_request_id;

  RETURN jsonb_build_object('payout_request_id',payout_request_id,'status',p_status);
END;
$function$;

CREATE OR REPLACE FUNCTION public.go_create_ride_from_quote_with_discounts(
  p_quote_id uuid,
  p_category_code text,
  p_payment_method text DEFAULT 'cash',
  p_voucher_code text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
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
  v_reward public.go_loyalty_rewards%ROWTYPE;
  v_reward_id uuid;
  v_voucher_discount numeric(14,2) := 0;
  v_loyalty_discount numeric(14,2) := 0;
  v_discount_total numeric(14,2) := 0;
  v_final_fare numeric(14,2);
  v_wallet_before numeric(14,2);
  v_wallet_after numeric(14,2);
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id=v_uid AND p.role='passenger' AND p.account_status='active'
  ) THEN RAISE EXCEPTION 'Active passenger account required' USING ERRCODE='42501'; END IF;
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
    SELECT * INTO v_reward FROM public.go_loyalty_rewards r
    WHERE r.passenger_id=v_uid AND r.status='available'
    ORDER BY r.created_at,r.id
    LIMIT 1 FOR UPDATE SKIP LOCKED;
    IF FOUND THEN
      v_reward_id:=v_reward.id;
      v_loyalty_discount:=round(v_item.total_fare*v_reward.discount_percent/100,2);
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

  IF v_voucher_id IS NOT NULL THEN
    INSERT INTO public.go_voucher_redemptions(
      voucher_id,passenger_id,ride_id,original_fare,discount_amount,currency_code
    ) VALUES (v_voucher_id,v_uid,v_ride_id,v_item.total_fare,v_voucher_discount,v_item.currency_code);
  END IF;

  IF v_reward_id IS NOT NULL THEN
    UPDATE public.go_loyalty_rewards
    SET status='redeemed',redeemed_on_ride_id=v_ride_id,redeemed_at=now()
    WHERE id=v_reward_id AND status='available';
    IF NOT FOUND THEN RAISE EXCEPTION 'Loyalty reward was already used'; END IF;
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

CREATE OR REPLACE FUNCTION public.go_refund_wallet_on_ride_cancel()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_before numeric(14,2);
  v_after numeric(14,2);
BEGIN
  IF OLD.status IS DISTINCT FROM 'cancelled'
     AND NEW.status='cancelled'
     AND NEW.payment_method='wallet'
     AND NEW.payment_status='paid'
     AND NEW.fare_amount>0
     AND NOT EXISTS (
       SELECT 1 FROM public.go_wallet_transactions t
       WHERE t.transaction_type='ride_refund' AND t.source_id=NEW.id
     ) THEN
    SELECT balance INTO v_before
    FROM public.go_wallet_accounts
    WHERE user_id=NEW.passenger_id AND currency_code=NEW.currency_code
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Wallet account missing during ride refund'; END IF;
    UPDATE public.go_wallet_accounts
    SET balance=balance+NEW.fare_amount,updated_at=now()
    WHERE user_id=NEW.passenger_id AND currency_code=NEW.currency_code
    RETURNING balance INTO v_after;
    INSERT INTO public.go_wallet_transactions(
      user_id,currency_code,direction,transaction_type,amount,balance_before,balance_after,
      ride_id,source_type,source_id,note,created_by
    ) VALUES (
      NEW.passenger_id,NEW.currency_code,'credit','ride_refund',NEW.fare_amount,
      v_before,v_after,NEW.id,'ride',NEW.id,'Automatic refund for cancelled wallet ride',NEW.cancelled_by
    );
    UPDATE public.go_rides SET payment_status='refunded' WHERE id=NEW.id;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_go_refund_wallet_on_ride_cancel ON public.go_rides;
CREATE TRIGGER trg_go_refund_wallet_on_ride_cancel
AFTER UPDATE OF status ON public.go_rides
FOR EACH ROW EXECUTE FUNCTION public.go_refund_wallet_on_ride_cancel();

CREATE OR REPLACE FUNCTION public.go_issue_10th_ride_loyalty_reward()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_completed_count integer;
BEGIN
  IF OLD.status IS DISTINCT FROM 'completed' AND NEW.status='completed'
     AND public.go_is_feature_enabled('loyalty.10th_ride') THEN
    SELECT count(*)::integer INTO v_completed_count
    FROM public.go_rides
    WHERE passenger_id=NEW.passenger_id AND status='completed';
    IF v_completed_count>0 AND v_completed_count%10=0 THEN
      INSERT INTO public.go_loyalty_rewards(
        passenger_id,earned_on_ride_id,completed_ride_number,discount_percent,status
      ) VALUES (
        NEW.passenger_id,NEW.id,v_completed_count,25,'available'
      )
      ON CONFLICT (earned_on_ride_id) DO NOTHING;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_go_issue_10th_ride_loyalty_reward ON public.go_rides;
CREATE TRIGGER trg_go_issue_10th_ride_loyalty_reward
AFTER UPDATE OF status ON public.go_rides
FOR EACH ROW EXECUTE FUNCTION public.go_issue_10th_ride_loyalty_reward();

REVOKE ALL ON FUNCTION public.go_admin_credit_wallet(uuid,numeric,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.go_admin_credit_driver_wallet(uuid,numeric,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.go_request_driver_payout(numeric,text,text,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.go_admin_set_driver_payout_status(uuid,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.go_create_ride_from_quote_with_discounts(uuid,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.go_admin_credit_wallet(uuid,numeric,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.go_admin_credit_driver_wallet(uuid,numeric,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.go_request_driver_payout(numeric,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.go_admin_set_driver_payout_status(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.go_create_ride_from_quote_with_discounts(uuid,text,text,text) TO authenticated;

INSERT INTO public.go_app_feature_flags(feature_key,label,description,feature_group,is_enabled,is_available,config)
VALUES
  ('payment.wallet','MOONRIDE Wallet','Wallet payments funded only by MASTER ADMIN credit.','payments',true,true,'{"funding":"admin_only","refund":"automatic_on_ride_cancellation"}'::jsonb),
  ('payment.tbc','TBC Card','TBC PSP payment flow; unavailable until merchant credentials and webhook verification are configured.','payments',false,true,'{"provider":"tbc","configured":false}'::jsonb),
  ('payment.bog','Bank of Georgia Card','BOG PSP payment flow; unavailable until merchant credentials and webhook verification are configured.','payments',false,true,'{"provider":"bog","configured":false}'::jsonb),
  ('promos.vouchers','Promo Codes','MASTER ADMIN vouchers with one redemption per passenger.','promotions',true,true,'{"per_passenger_limit":1,"all_categories":true}'::jsonb),
  ('loyalty.10th_ride','10th Ride Reward','Each tenth completed ride earns 25 percent off the next ride.','loyalty',true,true,'{"completed_rides_required":10,"discount_percent":25}'::jsonb),
  ('driver.payouts','Driver Payout Requests','Drivers can request payout from settled driver wallet balance.','finance',true,true,'{"banks":["tbc","bog"],"admin_marks_paid":true}'::jsonb)
ON CONFLICT (feature_key) DO NOTHING;
