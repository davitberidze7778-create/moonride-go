-- Require each route leg to join adjacent route points and use the matching sequence.
-- This matches the invariants enforced by go_calculate_ride_quote.

CREATE OR REPLACE FUNCTION public.go_validate_route_leg_sequence()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_start_sequence integer;
    v_end_sequence integer;
BEGIN
    SELECT rp.sequence_number
    INTO v_start_sequence
    FROM public.ride_route_points rp
    WHERE rp.id = NEW.start_point_id
      AND rp.quote_id = NEW.quote_id;

    SELECT rp.sequence_number
    INTO v_end_sequence
    FROM public.ride_route_points rp
    WHERE rp.id = NEW.end_point_id
      AND rp.quote_id = NEW.quote_id;

    IF v_start_sequence IS NULL OR v_end_sequence IS NULL THEN
        RAISE EXCEPTION
            'Route leg points must belong to the same quote';
    END IF;

    IF NEW.sequence_number IS DISTINCT FROM v_start_sequence
       OR v_end_sequence <> v_start_sequence + 1 THEN
        RAISE EXCEPTION
            'Route leg must connect consecutive points at the matching sequence number';
    END IF;

    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_go_validate_route_leg_sequence
ON public.ride_route_legs;

CREATE TRIGGER trg_go_validate_route_leg_sequence
BEFORE INSERT OR UPDATE OF quote_id, start_point_id, end_point_id, sequence_number
ON public.ride_route_legs
FOR EACH ROW
EXECUTE FUNCTION public.go_validate_route_leg_sequence();
