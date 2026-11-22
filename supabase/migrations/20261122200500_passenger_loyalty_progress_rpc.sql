CREATE OR REPLACE FUNCTION public.go_get_my_loyalty_progress()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_completed integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;
  SELECT count(*)::integer INTO v_completed
  FROM public.go_rides
  WHERE passenger_id=v_uid AND status='completed';

  RETURN jsonb_build_object(
    'completed_rides',v_completed,
    'next_discount_on_upcoming_ride',((v_completed+1)%10=0),
    'rides_until_discount',10-(v_completed%10),
    'discount_percent',25
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.go_get_my_loyalty_progress() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.go_get_my_loyalty_progress() TO authenticated;
