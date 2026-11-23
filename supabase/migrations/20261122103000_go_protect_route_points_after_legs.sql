-- Prevent route point edits after route legs have been created.
-- This keeps route-leg geometry and the ordered point sequence consistent.
-- Nested foreign-key cascades (for example, deleting a quote) remain allowed.

CREATE OR REPLACE FUNCTION public.go_protect_route_points_after_legs()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_quote_ids uuid[];
BEGIN
    IF pg_trigger_depth() > 1 THEN
        IF TG_OP = 'DELETE' THEN
            RETURN OLD;
        END IF;
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        v_quote_ids := ARRAY[OLD.quote_id, NEW.quote_id];
        PERFORM q.id
        FROM public.ride_quotes q
        WHERE q.id = ANY(v_quote_ids)
        ORDER BY q.id
        FOR UPDATE;
    ELSIF TG_OP = 'DELETE' THEN
        v_quote_ids := ARRAY[OLD.quote_id];
        PERFORM q.id
        FROM public.ride_quotes q
        WHERE q.id = OLD.quote_id
        FOR UPDATE;
    ELSE
        v_quote_ids := ARRAY[NEW.quote_id];
        PERFORM q.id
        FROM public.ride_quotes q
        WHERE q.id = NEW.quote_id
        FOR UPDATE;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.ride_route_legs l
        WHERE l.quote_id = ANY(v_quote_ids)
    ) THEN
        RAISE EXCEPTION
            'Route points are immutable after route legs are created; create a new quote to change the route.'
            USING ERRCODE = '55000';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.go_protect_route_points_after_legs() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_go_protect_route_points_after_legs
ON public.ride_route_points;

CREATE TRIGGER trg_go_protect_route_points_after_legs
BEFORE INSERT OR UPDATE OR DELETE ON public.ride_route_points
FOR EACH ROW
EXECUTE FUNCTION public.go_protect_route_points_after_legs();
