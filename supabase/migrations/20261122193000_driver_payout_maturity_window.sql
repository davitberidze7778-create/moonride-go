-- Apply the agreed payout maturity and local-time withdrawal window on the server.
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
  v_recent_credits numeric(14,2);
  v_mature_balance numeric(14,2);
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
  IF timezone('Asia/Tbilisi',now())::time < time '11:00' THEN
    RAISE EXCEPTION 'Payout requests are accepted after 11:00 Asia/Tbilisi';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 OR p_currency_code !~ '^[A-Z]{3}$'
     OR p_bank_code NOT IN ('tbc','bog')
     OR length(btrim(coalesce(p_account_holder,''))) < 3
     OR v_iban !~ '^[A-Z]{2}[0-9A-Z]{13,32}$' THEN
    RAISE EXCEPTION 'Valid payout details are required';
  END IF;

  SELECT balance INTO v_balance
  FROM public.go_driver_wallet_accounts
  WHERE driver_user_id=v_uid AND currency_code=p_currency_code AND status='active'
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'No available active driver balance'; END IF;

  SELECT coalesce(sum(amount),0) INTO v_recent_credits
  FROM public.go_driver_wallet_transactions
  WHERE driver_user_id=v_uid AND currency_code=p_currency_code
    AND direction='credit' AND created_at>now()-interval '24 hours';
  v_mature_balance := greatest(0,v_balance-v_recent_credits);

  SELECT coalesce(sum(amount),0) INTO v_reserved
  FROM public.go_driver_payout_requests
  WHERE driver_user_id=v_uid AND currency_code=p_currency_code
    AND status IN ('pending','approved');
  IF p_amount > v_mature_balance-v_reserved THEN
    RAISE EXCEPTION 'Payout amount exceeds the balance matured after the 24-hour hold';
  END IF;

  INSERT INTO public.go_driver_payout_requests(driver_user_id,amount,currency_code,bank_code)
  VALUES (v_uid,p_amount,p_currency_code,p_bank_code)
  RETURNING id INTO v_payout_id;

  INSERT INTO private.go_driver_payout_details(payout_request_id,account_holder,iban)
  VALUES (v_payout_id,btrim(p_account_holder),v_iban);

  RETURN jsonb_build_object(
    'payout_request_id',v_payout_id,
    'status','pending',
    'amount',p_amount,
    'currency_code',p_currency_code,
    'available_after_hold',v_mature_balance-v_reserved
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.go_request_driver_payout(numeric,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.go_request_driver_payout(numeric,text,text,text,text) TO authenticated;
