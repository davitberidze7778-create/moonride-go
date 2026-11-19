-- Ensure every pricing/category change creates a new GO tariff plan version.
CREATE OR REPLACE FUNCTION public.go_increment_tariff_plan_version()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $version$
DECLARE
  v_plan_id uuid;
BEGIN
  IF TG_TABLE_NAME='vehicle_categories' THEN
    IF TG_OP='UPDATE' AND OLD.is_active IS DISTINCT FROM NEW.is_active THEN
      UPDATE public.go_tariff_plans p
      SET rule_version=rule_version+1, updated_at=now()
      WHERE EXISTS (
        SELECT 1 FROM public.go_tariff_category_rates r
        WHERE r.tariff_plan_id=p.id AND r.category_id=NEW.id
      );
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP='DELETE' THEN
    v_plan_id := OLD.tariff_plan_id;
    UPDATE public.go_tariff_plans
    SET rule_version=rule_version+1, updated_at=now()
    WHERE id=v_plan_id;
    RETURN OLD;
  END IF;

  v_plan_id := NEW.tariff_plan_id;
  UPDATE public.go_tariff_plans
  SET rule_version=rule_version+1, updated_at=now()
  WHERE id=v_plan_id;
  RETURN NEW;
END;
$version$;
REVOKE ALL ON FUNCTION public.go_increment_tariff_plan_version() FROM PUBLIC,anon,authenticated;

DROP TRIGGER IF EXISTS go_tariff_category_rates_version_trg ON public.go_tariff_category_rates;
CREATE TRIGGER go_tariff_category_rates_version_trg
AFTER INSERT OR UPDATE OR DELETE ON public.go_tariff_category_rates
FOR EACH ROW EXECUTE FUNCTION public.go_increment_tariff_plan_version();

DROP TRIGGER IF EXISTS go_tariff_waiting_rules_version_trg ON public.go_tariff_waiting_rules;
CREATE TRIGGER go_tariff_waiting_rules_version_trg
AFTER INSERT OR UPDATE OR DELETE ON public.go_tariff_waiting_rules
FOR EACH ROW EXECUTE FUNCTION public.go_increment_tariff_plan_version();

DROP TRIGGER IF EXISTS go_tariff_dynamic_rules_version_trg ON public.go_tariff_dynamic_rules;
CREATE TRIGGER go_tariff_dynamic_rules_version_trg
AFTER INSERT OR UPDATE OR DELETE ON public.go_tariff_dynamic_rules
FOR EACH ROW EXECUTE FUNCTION public.go_increment_tariff_plan_version();

DROP TRIGGER IF EXISTS vehicle_categories_go_version_trg ON public.vehicle_categories;
CREATE TRIGGER vehicle_categories_go_version_trg
AFTER UPDATE OF is_active ON public.vehicle_categories
FOR EACH ROW EXECUTE FUNCTION public.go_increment_tariff_plan_version();
