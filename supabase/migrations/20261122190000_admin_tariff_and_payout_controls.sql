-- Admin-only atomic tariff editing and private payout review access.

CREATE OR REPLACE FUNCTION public.go_admin_update_tariff_plan(
  p_plan_id uuid,
  p_values jsonb,
  p_rates jsonb DEFAULT '[]'::jsonb,
  p_waiting_rules jsonb DEFAULT '[]'::jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_row_count integer := 0;
  v_item jsonb;
  v_id uuid;
  v_amount numeric;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_master_admin() THEN
    RAISE EXCEPTION 'MASTER ADMIN required' USING ERRCODE='42501';
  END IF;
  IF jsonb_typeof(coalesce(p_values,'{}'::jsonb)) <> 'object'
     OR jsonb_typeof(coalesce(p_rates,'[]'::jsonb)) <> 'array'
     OR jsonb_typeof(coalesce(p_waiting_rules,'[]'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'Invalid tariff editor payload';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.go_tariff_plans WHERE id=p_plan_id) THEN
    RAISE EXCEPTION 'Tariff plan not found';
  END IF;

  UPDATE public.go_tariff_plans
  SET plan_name=coalesce(nullif(btrim(p_values->>'plan_name'),''),plan_name),
      minimum_fare=coalesce((p_values->>'minimum_fare')::numeric,minimum_fare),
      included_distance_km=coalesce((p_values->>'included_distance_km')::numeric,included_distance_km),
      included_movement_minutes=coalesce((p_values->>'included_movement_minutes')::numeric,included_movement_minutes),
      extra_movement_minute_rate=coalesce((p_values->>'extra_movement_minute_rate')::numeric,extra_movement_minute_rate),
      free_wait_minutes=coalesce((p_values->>'free_wait_minutes')::numeric,free_wait_minutes),
      waiting_fee_mode=coalesce(nullif(p_values->>'waiting_fee_mode',''),waiting_fee_mode),
      updated_at=now()
  WHERE id=p_plan_id
    AND coalesce((p_values->>'minimum_fare')::numeric,minimum_fare)>=0
    AND coalesce((p_values->>'included_distance_km')::numeric,included_distance_km)>=0
    AND coalesce((p_values->>'included_movement_minutes')::numeric,included_movement_minutes)>=0
    AND coalesce((p_values->>'extra_movement_minute_rate')::numeric,extra_movement_minute_rate)>=0
    AND coalesce((p_values->>'free_wait_minutes')::numeric,free_wait_minutes)>=0
    AND coalesce(nullif(p_values->>'waiting_fee_mode',''),waiting_fee_mode) IN ('manual_points','fixed','disabled');
  IF NOT FOUND THEN RAISE EXCEPTION 'Tariff plan values are invalid'; END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(coalesce(p_rates,'[]'::jsonb))
  LOOP
    v_id := (v_item->>'id')::uuid;
    v_amount := (v_item->>'rate_per_km')::numeric;
    IF v_amount IS NULL OR v_amount < 0 THEN RAISE EXCEPTION 'Invalid category rate'; END IF;
    UPDATE public.go_tariff_category_rates
    SET rate_per_km=v_amount
    WHERE id=v_id AND tariff_plan_id=p_plan_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Category rate does not belong to this plan'; END IF;
    v_row_count := v_row_count + 1;
  END LOOP;

  FOR v_item IN SELECT value FROM jsonb_array_elements(coalesce(p_waiting_rules,'[]'::jsonb))
  LOOP
    v_id := (v_item->>'id')::uuid;
    v_amount := (v_item->>'fee_amount')::numeric;
    IF v_amount IS NULL OR v_amount < 0 THEN RAISE EXCEPTION 'Invalid waiting fee'; END IF;
    UPDATE public.go_tariff_waiting_rules
    SET fee_amount=v_amount
    WHERE id=v_id AND tariff_plan_id=p_plan_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Waiting rule does not belong to this plan'; END IF;
    v_row_count := v_row_count + 1;
  END LOOP;

  RETURN jsonb_build_object('plan_id',p_plan_id,'updated_rows',v_row_count);
END;
$function$;

CREATE OR REPLACE FUNCTION public.go_admin_get_driver_payout_queue()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_master_admin() THEN
    RAISE EXCEPTION 'MASTER ADMIN required' USING ERRCODE='42501';
  END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id',r.id,
    'driver_user_id',r.driver_user_id,
    'driver_name',p.full_name,
    'amount',r.amount,
    'currency_code',r.currency_code,
    'bank_code',r.bank_code,
    'status',r.status,
    'admin_note',r.admin_note,
    'requested_at',r.requested_at,
    'account_holder',d.account_holder,
    'iban',d.iban
  ) ORDER BY r.requested_at DESC),'[]'::jsonb)
  INTO v_result
  FROM public.go_driver_payout_requests r
  JOIN private.go_driver_payout_details d ON d.payout_request_id=r.id
  JOIN public.profiles p ON p.id=r.driver_user_id;
  RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.go_admin_update_tariff_plan(uuid,jsonb,jsonb,jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.go_admin_get_driver_payout_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.go_admin_update_tariff_plan(uuid,jsonb,jsonb,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.go_admin_get_driver_payout_queue() TO authenticated;
