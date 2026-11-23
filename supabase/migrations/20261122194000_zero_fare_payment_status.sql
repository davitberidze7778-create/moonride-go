-- A fully discounted or zero-fare ride is not a cash debt or payment.
CREATE OR REPLACE FUNCTION public.go_mark_zero_fare_payment_not_required()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NEW.fare_amount = 0 THEN
    NEW.payment_status := 'not_required';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.go_mark_zero_fare_payment_not_required() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_go_zero_fare_payment_status ON public.go_rides;
CREATE TRIGGER trg_go_zero_fare_payment_status
BEFORE INSERT OR UPDATE OF fare_amount, payment_method, payment_status
ON public.go_rides
FOR EACH ROW
EXECUTE FUNCTION public.go_mark_zero_fare_payment_not_required();
