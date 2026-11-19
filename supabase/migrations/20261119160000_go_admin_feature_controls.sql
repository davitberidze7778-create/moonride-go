-- MOONRIDE GO: Master Admin feature controls and final seven-category tariffs.
-- Additive GO-only configuration. Legacy fare tables are not modified.
BEGIN;
CREATE TABLE IF NOT EXISTS public.go_app_feature_flags (
 feature_key text PRIMARY KEY,
 label text NOT NULL,
 description text NOT NULL DEFAULT '',
 feature_group text NOT NULL,
 is_enabled boolean NOT NULL DEFAULT false,
 is_available boolean NOT NULL DEFAULT false,
 config jsonb NOT NULL DEFAULT '{}'::jsonb,
 updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT go_app_feature_flags_key_check CHECK (feature_key ~ '^[a-z0-9._-]+$')
);
ALTER TABLE public.go_app_feature_flags ENABLE ROW LEVEL SECURITY;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.go_app_feature_flags TO authenticated;
DROP POLICY IF EXISTS go_app_feature_flags_read_available ON public.go_app_feature_flags;
CREATE POLICY go_app_feature_flags_read_available ON public.go_app_feature_flags
 FOR SELECT TO authenticated USING (is_available=true OR public.is_master_admin());
DROP POLICY IF EXISTS go_app_feature_flags_admin_manage ON public.go_app_feature_flags;
CREATE POLICY go_app_feature_flags_admin_manage ON public.go_app_feature_flags
 FOR ALL TO authenticated USING (public.is_master_admin()) WITH CHECK (public.is_master_admin());

CREATE TABLE IF NOT EXISTS public.go_app_feature_flag_audit (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 feature_key text NOT NULL,
 old_state jsonb,
 new_state jsonb NOT NULL,
 actor_user_id uuid,
 changed_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.go_app_feature_flag_audit ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.go_app_feature_flag_audit TO authenticated;
DROP POLICY IF EXISTS go_app_feature_flag_audit_admin_read ON public.go_app_feature_flag_audit;
CREATE POLICY go_app_feature_flag_audit_admin_read ON public.go_app_feature_flag_audit
 FOR SELECT TO authenticated USING (public.is_master_admin());
CREATE OR REPLACE FUNCTION public.go_feature_flag_audit_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $audit$
BEGIN
 IF TG_OP='INSERT' THEN
  INSERT INTO public.go_app_feature_flag_audit(feature_key,old_state,new_state,actor_user_id)
  VALUES(NEW.feature_key,NULL,to_jsonb(NEW),auth.uid());
  RETURN NEW;
 END IF;
 IF OLD IS DISTINCT FROM NEW THEN
  INSERT INTO public.go_app_feature_flag_audit(feature_key,old_state,new_state,actor_user_id)
  VALUES(NEW.feature_key,to_jsonb(OLD),to_jsonb(NEW),auth.uid());
 END IF;
 RETURN NEW;
END;
$audit$;
REVOKE ALL ON FUNCTION public.go_feature_flag_audit_trigger() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS go_app_feature_flag_audit_trg ON public.go_app_feature_flags;
CREATE TRIGGER go_app_feature_flag_audit_trg AFTER INSERT OR UPDATE
 ON public.go_app_feature_flags FOR EACH ROW EXECUTE FUNCTION public.go_feature_flag_audit_trigger();

INSERT INTO public.go_app_feature_flags(feature_key,label,description,feature_group,is_enabled,is_available)
VALUES
('ride.quote','Ride quotes and tariff calculation','Allow passengers to request Supabase GO fare quotes','rides',true,true),
('ride.multiple_stops','Multiple stops','Allow pickup, up to four intermediate stops and destination','rides',true,true),
('pricing.dynamic','Dynamic pricing','Enable dynamic tariff multipliers','pricing',true,true),
('pricing.weather','Weather pricing','Allow weather multipliers to affect new quotes','pricing',true,true),
('pricing.demand','Demand pricing','Allow demand multipliers to affect new quotes','pricing',true,true),
('pricing.manual','Manual price override','Allow time-limited MASTER ADMIN price multipliers','pricing',true,true),
('safety.sos','SOS / 112','Show the emergency call action','safety',true,true),
('ride.booking_dispatch','Driver dispatch and booking','Send booking offers and assign the first accepting driver','rides',false,false),
('ride.scheduled','Scheduled rides','Allow passengers to book future rides','rides',false,false),
('tracking.live','Passenger live tracking','Show assigned driver position during an active ride','safety',false,false),
('payment.cash','Cash payments','Enable cash settlement for completed rides','payments',false,false),
('payment.wallet','MOONRIDE Wallet','Enable wallet charges and refunds','payments',false,false),
('payment.tbc','TBC card payments','Enable TBC hosted card payments','payments',false,false),
('payment.bog','Bank of Georgia card payments','Enable BOG hosted card payments','payments',false,false),
('promo.vouchers','Vouchers and promo codes','Redeem admin-issued fixed and percentage vouchers','promotions',false,false),
('loyalty.10ride25','10-ride loyalty reward','Apply 25% base-fare discount to next eligible ride','promotions',false,false),
('ride.staff_go','STAFF GO','Book a staff trip with up to four extra addresses','rides',false,false),
('safety.trip_share','Trip sharing','Share active ride details with trusted contacts','safety',false,false),
('addon.child_seat','Child seat','Request a child seat','add_ons',false,false),
('addon.pets','Pets','Request pet-friendly rides','add_ons',false,false),
('addon.luggage','Luggage','Request extra luggage space','add_ons',false,false),
('addon.airport_meet','Airport meet and greet','Request airport pickup assistance','add_ons',false,false),
('addon.air_conditioning','Air conditioning','Set air-conditioning preference','add_ons',false,false),
('addon.quiet_ride','Quiet ride','Request a quiet ride','add_ons',false,false),
('addon.temperature','Temperature preference','Choose cabin temperature preference','add_ons',false,false),
('ride.tips','Driver tips','Allow optional tips after a completed ride','payments',false,false),
('ai.assistant','MOONRIDE AI assistant','Enable in-app AI customer assistance','support',false,false)
ON CONFLICT(feature_key) DO UPDATE SET
 label=EXCLUDED.label,description=EXCLUDED.description,feature_group=EXCLUDED.feature_group;

CREATE OR REPLACE FUNCTION public.go_is_feature_enabled(p_feature_key text)
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER
SET search_path TO 'public','pg_temp'
AS $feature$
 SELECT COALESCE((SELECT f.is_enabled AND f.is_available
 FROM public.go_app_feature_flags f WHERE f.feature_key=p_feature_key),false);
$feature$;
REVOKE ALL ON FUNCTION public.go_is_feature_enabled(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.go_is_feature_enabled(text) TO authenticated,service_role;

DO $rates$
DECLARE v_plan_id uuid; v_plan_count integer;
BEGIN
 SELECT count(*),(array_agg(id))[1] INTO v_plan_count,v_plan_id
 FROM public.go_tariff_plans
 WHERE plan_name='BATUMI_TAXI_2026_V1' AND scope_type='city' AND is_active=true
 AND effective_from<=now() AND (effective_until IS NULL OR effective_until>now());
 IF v_plan_count<>1 THEN RAISE EXCEPTION 'Expected exactly one active Batumi GO plan, found %',v_plan_count; END IF;

 UPDATE public.vehicle_categories SET is_active=true
 WHERE code IN ('ECONOM_GO','ECONOM_PLUS_GO','COMFORT_GO','COMFORT_PLUS_GO','XL_GO','MINIVAN_GO','GROUP_RIDE_GO');
 UPDATE public.vehicle_categories SET is_active=false WHERE code='PREMIUM_GO';

 DELETE FROM public.go_tariff_category_rates r USING public.vehicle_categories c
 WHERE r.category_id=c.id AND r.tariff_plan_id=v_plan_id AND c.code='PREMIUM_GO';

 INSERT INTO public.go_tariff_category_rates(tariff_plan_id,category_id,rate_per_km)
 SELECT v_plan_id,c.id,CASE c.code
  WHEN 'ECONOM_GO' THEN 1.20 WHEN 'ECONOM_PLUS_GO' THEN 1.25
  WHEN 'COMFORT_GO' THEN 1.35 WHEN 'COMFORT_PLUS_GO' THEN 1.60
  WHEN 'XL_GO' THEN 1.71 WHEN 'MINIVAN_GO' THEN 1.85 WHEN 'GROUP_RIDE_GO' THEN 1.17 END
 FROM public.vehicle_categories c
 WHERE c.code IN ('ECONOM_GO','ECONOM_PLUS_GO','COMFORT_GO','COMFORT_PLUS_GO','XL_GO','MINIVAN_GO','GROUP_RIDE_GO')
 ON CONFLICT(tariff_plan_id,category_id) DO UPDATE SET rate_per_km=EXCLUDED.rate_per_km;
END;
$rates$;

CREATE OR REPLACE FUNCTION public.go_calculate_tariff_options(p_tariff_plan_id uuid, p_distance_km numeric, p_movement_minutes numeric, p_waiting_minutes numeric DEFAULT 0)
 RETURNS TABLE(category_code text, rate_per_km numeric, base_fare numeric, distance_fare numeric, time_fare numeric, waiting_fare numeric, dynamic_multiplier numeric, total_fare numeric, currency_code text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_plan public.go_tariff_plans%ROWTYPE;

    v_rate record;

    v_lower_minutes numeric;
    v_lower_fee numeric;
    v_upper_minutes numeric;
    v_upper_fee numeric;

    v_waiting_fare numeric := 0;
    v_dynamic_multiplier numeric := 1.0;
    v_raw_multiplier numeric := 1.0;

    v_base numeric;
    v_distance_fare numeric;
    v_time_fare numeric;
    v_total numeric;

    v_dynamic public.go_tariff_dynamic_rules%ROWTYPE;
BEGIN

    -- 1. INPUT VALIDATION

    IF p_tariff_plan_id IS NULL THEN
        RAISE EXCEPTION 'Tariff plan ID is required.';
    END IF;

    IF p_distance_km IS NULL OR p_distance_km < 0 THEN
        RAISE EXCEPTION 'Distance must be zero or greater.';
    END IF;

    IF p_movement_minutes IS NULL OR p_movement_minutes < 0 THEN
        RAISE EXCEPTION 'Movement time must be zero or greater.';
    END IF;

    IF p_waiting_minutes IS NULL OR p_waiting_minutes < 0 THEN
        RAISE EXCEPTION 'Waiting time must be zero or greater.';
    END IF;


    -- 2. LOAD ACTIVE TARIFF PLAN

    SELECT *
    INTO v_plan
    FROM public.go_tariff_plans
    WHERE id = p_tariff_plan_id
      AND is_active = true
      AND effective_from <= now()
      AND (
          effective_until IS NULL
          OR effective_until > now()
      );

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Tariff plan does not exist, is inactive, or is outside its effective dates.';
    END IF;


    -- 3. LOAD DYNAMIC PRICING CONFIGURATION
    -- Dynamic pricing remains 1.0 unless safely configured.

    SELECT *
    INTO v_dynamic
    FROM public.go_tariff_dynamic_rules
    WHERE tariff_plan_id = p_tariff_plan_id
      AND is_active = true
      AND public.go_is_feature_enabled('pricing.dynamic');

    IF FOUND THEN

        -- Manual override takes precedence.
        IF public.go_is_feature_enabled('pricing.manual')
           AND v_dynamic.manual_override_multiplier IS NOT NULL
           AND (
               v_dynamic.manual_override_until IS NULL
               OR v_dynamic.manual_override_until > now()
           )
        THEN
            v_raw_multiplier :=
                v_dynamic.manual_override_multiplier;

        ELSE

            v_raw_multiplier := 1.0;

            IF v_dynamic.weather_enabled
               AND public.go_is_feature_enabled('pricing.weather') THEN
                v_raw_multiplier :=
                    v_raw_multiplier
                    * v_dynamic.weather_multiplier;
            END IF;

            IF v_dynamic.demand_enabled
               AND public.go_is_feature_enabled('pricing.demand') THEN
                v_raw_multiplier :=
                    v_raw_multiplier
                    * v_dynamic.demand_multiplier;
            END IF;

        END IF;

        -- Safety: dynamic pricing is not applied
        -- until an administrator sets a maximum multiplier.
        IF v_dynamic.max_multiplier IS NOT NULL THEN
            v_dynamic_multiplier :=
                LEAST(
                    v_raw_multiplier,
                    v_dynamic.max_multiplier
                );
        ELSE
            v_dynamic_multiplier := 1.0;
        END IF;

    END IF;


    -- 4. CALCULATE WAITING FEE
    -- Uses linear interpolation between configured points.
    -- Above the last point, the last configured fee is retained.

    IF p_waiting_minutes <= v_plan.free_wait_minutes THEN

        v_waiting_fare := 0;

    ELSE

        SELECT
            wait_minutes,
            fee_amount
        INTO
            v_lower_minutes,
            v_lower_fee
        FROM public.go_tariff_waiting_rules
        WHERE tariff_plan_id = p_tariff_plan_id
          AND wait_minutes <= p_waiting_minutes
        ORDER BY wait_minutes DESC
        LIMIT 1;

        SELECT
            wait_minutes,
            fee_amount
        INTO
            v_upper_minutes,
            v_upper_fee
        FROM public.go_tariff_waiting_rules
        WHERE tariff_plan_id = p_tariff_plan_id
          AND wait_minutes > p_waiting_minutes
        ORDER BY wait_minutes ASC
        LIMIT 1;

        IF v_lower_minutes IS NULL THEN

            v_waiting_fare := 0;

        ELSIF v_upper_minutes IS NULL THEN

            v_waiting_fare := v_lower_fee;

        ELSE

            v_waiting_fare :=
                v_lower_fee
                +
                (
                    (p_waiting_minutes - v_lower_minutes)
                    /
                    NULLIF(
                        v_upper_minutes - v_lower_minutes,
                        0
                    )
                )
                *
                (v_upper_fee - v_lower_fee);

        END IF;

    END IF;


    -- 5. CALCULATE EACH ACTIVE VEHICLE CATEGORY

    FOR v_rate IN

        SELECT
            vc.code,
            tr.rate_per_km
        FROM public.go_tariff_category_rates tr
        JOIN public.vehicle_categories vc
          ON vc.id = tr.category_id
        WHERE tr.tariff_plan_id = p_tariff_plan_id
          AND vc.is_active = true
          AND vc.code IN (
              'ECONOM_GO','ECONOM_PLUS_GO','COMFORT_GO','COMFORT_PLUS_GO',
              'XL_GO','MINIVAN_GO','GROUP_RIDE_GO'
          )
        ORDER BY vc.code

    LOOP

        -- Minimum fare
        v_base := v_plan.minimum_fare;

        -- Distance after included distance
        v_distance_fare :=
            v_rate.rate_per_km
            *
            GREATEST(
                0,
                p_distance_km - v_plan.included_distance_km
            );

        -- Actual movement time after included time
        v_time_fare :=
            v_plan.extra_movement_minute_rate
            *
            GREATEST(
                0,
                p_movement_minutes
                - v_plan.included_movement_minutes
            );

        -- Total before dynamic pricing
        v_total :=
            v_base
            + v_distance_fare
            + v_time_fare
            + v_waiting_fare;

        -- Apply dynamic multiplier and round to 2 decimals
        v_total :=
            ROUND(
                v_total * v_dynamic_multiplier,
                2
            );

        RETURN QUERY
        SELECT
            v_rate.code::text,
            v_rate.rate_per_km::numeric,
            ROUND(v_base, 2),
            ROUND(v_distance_fare, 2),
            ROUND(v_time_fare, 2),
            ROUND(v_waiting_fare, 2),
            v_dynamic_multiplier,
            v_total,
            v_plan.currency_code::text;

    END LOOP;


    -- 6. ENSURE AT LEAST ONE CATEGORY WAS FOUND

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'No active vehicle categories or tariff rates found for this plan.';
    END IF;

END;
$function$;
CREATE OR REPLACE FUNCTION public.go_calculate_ride_quote(p_quote_id uuid, p_wait_minutes numeric DEFAULT 0)
 RETURNS TABLE(category_code text, rate_per_km numeric, base_fare numeric, distance_fare numeric, time_fare numeric, waiting_fare numeric, total_fare numeric, currency_code text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_quote public.ride_quotes%ROWTYPE;
    v_plan public.go_tariff_plans%ROWTYPE;
    v_option record;
    v_point_count integer;
    v_leg_count integer;
    v_rate_count integer;
    v_distance numeric;
    v_minutes numeric;
    v_wait numeric;
    v_applied_multiplier numeric := 1.0;
    v_weather_multiplier numeric := 1.0;
    v_demand_multiplier numeric := 1.0;
    v_category_prices jsonb := '{}'::jsonb;
    v_item_count integer := 0;
    v_category_id uuid;
BEGIN
    IF p_quote_id IS NULL THEN
        RAISE EXCEPTION 'Quote ID is required';
    END IF;

    IF p_wait_minutes IS NULL OR p_wait_minutes < 0 THEN
        RAISE EXCEPTION 'Waiting minutes must be non-negative';
    END IF;

    SELECT *
    INTO v_quote
    FROM public.ride_quotes q
    WHERE q.id = p_quote_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Quote not found';
    END IF;

    IF auth.uid() IS DISTINCT FROM v_quote.passenger_id
       AND coalesce(auth.role(), '') <> 'service_role' THEN
        RAISE EXCEPTION 'Not authorized to calculate this quote';
    END IF;

    IF NOT public.go_is_feature_enabled('ride.quote') THEN
        RAISE EXCEPTION 'MOONRIDE GO quote pricing is currently disabled by MASTER ADMIN';
    END IF;

    -- GO კალკულატორი მხოლოდ GO შეკვეთას ამუშავებს.
    IF v_quote.quote_source IS DISTINCT FROM 'GO' THEN
        RAISE EXCEPTION
            'This quote is not a GO quote';
    END IF;

    -- თუ Snapshot უკვე არსებობს, ძველი ფასი ბრუნდება.
    IF EXISTS (
        SELECT 1
        FROM public.go_quote_tariff_snapshots s
        WHERE s.quote_id = p_quote_id
    ) THEN
        RETURN QUERY
        SELECT
            i.category_code,
            i.rate_per_km,
            i.base_fare,
            i.distance_fare,
            i.time_fare,
            i.waiting_fare,
            i.total_fare,
            i.currency_code
        FROM public.ride_quote_items i
        WHERE i.quote_id = p_quote_id
        ORDER BY i.category_code;

        RETURN;
    END IF;

    IF v_quote.status <> 'pending' THEN
        RAISE EXCEPTION
            'Only pending quotes without a snapshot can be priced';
    END IF;

    v_wait := p_wait_minutes;

    SELECT *
    INTO v_plan
    FROM public.go_tariff_plans p
    WHERE p.city_id = v_quote.city_id
      AND p.scope_type = 'city'
      AND p.is_active = true
      AND p.effective_from <= now()
      AND (p.effective_until IS NULL OR p.effective_until > now());

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Active GO tariff plan not found';
    END IF;

    SELECT count(*)
    INTO v_point_count
    FROM public.ride_route_points rp
    WHERE rp.quote_id = p_quote_id;

    SELECT count(*)
    INTO v_leg_count
    FROM public.ride_route_legs rl
    WHERE rl.quote_id = p_quote_id;

    IF v_point_count < 2 OR v_leg_count <> v_point_count - 1 THEN
        RAISE EXCEPTION
            'Route is incomplete: expected one leg between each pair of points';
    END IF;

    -- თითოეული მონაკვეთი უნდა აკავშირებდეს მომდევნო ორ წერტილს.
    IF EXISTS (
        SELECT 1
        FROM public.ride_route_legs l
        LEFT JOIN public.ride_route_points s
          ON s.quote_id = l.quote_id
         AND s.sequence_number = l.sequence_number
        LEFT JOIN public.ride_route_points e
          ON e.quote_id = l.quote_id
         AND e.sequence_number = l.sequence_number + 1
        WHERE l.quote_id = p_quote_id
          AND (
              s.id IS NULL
              OR e.id IS NULL
              OR l.start_point_id <> s.id
              OR l.end_point_id <> e.id
          )
    ) THEN
        RAISE EXCEPTION 'Route leg point sequence is inconsistent';
    END IF;

    SELECT
        sum(l.distance_km),
        sum(l.duration_minutes)
    INTO v_distance, v_minutes
    FROM public.ride_route_legs l
    WHERE l.quote_id = p_quote_id;

    IF v_distance IS NULL OR v_minutes IS NULL THEN
        RAISE EXCEPTION 'Route distance or duration is missing';
    END IF;

    IF v_distance < 0 OR v_minutes < 0 THEN
        RAISE EXCEPTION 'Invalid route distance or duration';
    END IF;

    -- მინიმუმ ერთი აქტიური GO კატეგორიის ტარიფი აუცილებელია.
    SELECT count(DISTINCT c.id)
    INTO v_rate_count
    FROM public.go_tariff_category_rates r
    JOIN public.vehicle_categories c
      ON c.id = r.category_id
    WHERE r.tariff_plan_id = v_plan.id
      AND c.code IN (
          'ECONOM_GO',
          'ECONOM_PLUS_GO',
          'COMFORT_GO',
          'COMFORT_PLUS_GO',
          'XL_GO',
          'MINIVAN_GO',
'XL_GO',
          'GROUP_RIDE_GO'
      );

    IF v_rate_count < 1 THEN
        RAISE EXCEPTION
            'GO tariff plan must have at least one active approved category rate; found %',
            v_rate_count;
    END IF;

    -- დინამიკური წესების ფაქტორები Snapshot-ისთვის.
    SELECT
        CASE WHEN d.weather_enabled
             THEN greatest(1.0, coalesce(d.weather_multiplier, 1.0))
             ELSE 1.0 END,
        CASE WHEN d.demand_enabled
             THEN greatest(1.0, coalesce(d.demand_multiplier, 1.0))
             ELSE 1.0 END
    INTO v_weather_multiplier, v_demand_multiplier
    FROM public.go_tariff_dynamic_rules d
    WHERE d.tariff_plan_id = v_plan.id
      AND d.is_active = true
    LIMIT 1;

    v_weather_multiplier := coalesce(v_weather_multiplier, 1.0);
    v_demand_multiplier := coalesce(v_demand_multiplier, 1.0);

    -- GO კალკულატორი; ძველი ტარიფები არ გამოიყენება.
    FOR v_option IN
        SELECT *
        FROM public.go_calculate_tariff_options(
            v_plan.id,
            v_distance,
            v_minutes,
            v_wait
        ) AS o
        WHERE o.category_code IN (
            'ECONOM_GO',
            'ECONOM_PLUS_GO',
            'COMFORT_GO',
            'COMFORT_PLUS_GO',
            'XL_GO',
            'MINIVAN_GO',
'XL_GO',
            'GROUP_RIDE_GO'
        )
    LOOP
        SELECT c.id
        INTO v_category_id
        FROM public.vehicle_categories c
        WHERE c.code = v_option.category_code;

        IF v_category_id IS NULL THEN
            RAISE EXCEPTION
                'Vehicle category not found: %',
                v_option.category_code;
        END IF;

        INSERT INTO public.ride_quote_items (
            quote_id,
            category_id,
            category_code,
            rate_per_km,
            base_fare,
            distance_fare,
            time_fare,
            waiting_fare,
            total_fare,
            currency_code
        )
        VALUES (
            p_quote_id,
            v_category_id,
            v_option.category_code,
            v_option.rate_per_km,
            v_option.base_fare,
            v_option.distance_fare,
            v_option.time_fare,
            v_option.waiting_fare,
            v_option.total_fare,
            v_option.currency_code
        )
        ON CONFLICT (quote_id, category_id)
        DO UPDATE SET
            rate_per_km = EXCLUDED.rate_per_km,
            base_fare = EXCLUDED.base_fare,
            distance_fare = EXCLUDED.distance_fare,
            time_fare = EXCLUDED.time_fare,
            waiting_fare = EXCLUDED.waiting_fare,
            total_fare = EXCLUDED.total_fare,
            currency_code = EXCLUDED.currency_code;

        v_category_prices :=
            v_category_prices ||
            jsonb_build_object(
                v_option.category_code,
                jsonb_build_object(
                    'rate_per_km', v_option.rate_per_km,
                    'base_fare', v_option.base_fare,
                    'distance_fare', v_option.distance_fare,
                    'time_fare', v_option.time_fare,
                    'waiting_fare', v_option.waiting_fare,
                    'total_fare', v_option.total_fare,
                    'currency_code', v_option.currency_code
                )
            );

        v_applied_multiplier :=
            greatest(v_applied_multiplier, v_option.dynamic_multiplier);

        v_item_count := v_item_count + 1;
    END LOOP;

    IF v_item_count < 1 THEN
        RAISE EXCEPTION
            'Expected at least one GO category price, calculated %',
            v_item_count;
    END IF;

    -- ფასის პირობების უცვლელი Snapshot.
    INSERT INTO public.go_quote_tariff_snapshots (
        quote_id,
        tariff_plan_id,
        tariff_version,
        currency_code,
        minimum_fare,
        included_distance_km,
        included_movement_minutes,
        extra_movement_minute_rate,
        distance_km,
        movement_minutes,
        waiting_minutes,
        weather_multiplier,
        demand_multiplier,
        applied_multiplier,
        category_prices,
        calculation_details
    )
    VALUES (
        p_quote_id,
        v_plan.id,
        v_plan.rule_version,
        v_plan.currency_code,
        v_plan.minimum_fare,
        v_plan.included_distance_km,
        v_plan.included_movement_minutes,
        v_plan.extra_movement_minute_rate,
        v_distance,
        v_minutes,
        v_wait,
        v_weather_multiplier,
        v_demand_multiplier,
        greatest(1.0, v_applied_multiplier),
        v_category_prices,
        jsonb_build_object(
            'calculator', 'go_calculate_tariff_options',
            'tariff_plan_name', v_plan.plan_name,
            'tariff_scope', v_plan.scope_type,
            'waiting_fee_mode', v_plan.waiting_fee_mode,
            'free_wait_minutes', v_plan.free_wait_minutes,
            'calculated_at', now(),
            'dynamic_multiplier_is_combined',
                greatest(1.0, v_applied_multiplier)
        )
    );

    UPDATE public.ride_quotes
    SET
        total_distance_km = v_distance,
        total_duration_minutes = v_minutes,
        waiting_minutes = v_wait,
        currency_code = v_plan.currency_code,
        status = 'priced',
        updated_at = now()
    WHERE id = p_quote_id;

    RETURN QUERY
    SELECT
        i.category_code,
        i.rate_per_km,
        i.base_fare,
        i.distance_fare,
        i.time_fare,
        i.waiting_fare,
        i.total_fare,
        i.currency_code
    FROM public.ride_quote_items i
    WHERE i.quote_id = p_quote_id
    ORDER BY i.category_code;

END;
$function$;
CREATE OR REPLACE FUNCTION public.go_create_ride_quote(p_city_id uuid, p_points jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_user_id uuid;
    v_quote_id uuid;
    v_plan_id uuid;
    v_currency text;
    v_count integer;
    v_i integer := 0;
    v_point jsonb;
    v_point_type text;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;
    IF NOT public.go_is_feature_enabled('ride.quote') THEN
        RAISE EXCEPTION 'MOONRIDE GO quote service is currently disabled by MASTER ADMIN';
    END IF;

    IF p_points IS NULL
       OR jsonb_typeof(p_points) <> 'array' THEN
        RAISE EXCEPTION 'Route points must be a JSON array';
    END IF;

    v_count := jsonb_array_length(p_points);
    IF v_count > 2 AND NOT public.go_is_feature_enabled('ride.multiple_stops') THEN
        RAISE EXCEPTION 'Multiple stops are currently disabled by MASTER ADMIN';
    END IF;

    IF v_count < 2 OR v_count > 25 THEN
        RAISE EXCEPTION 'Route must contain 2 to 25 points';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.cities c
        WHERE c.id = p_city_id
          AND c.is_active = true
          AND c.service_enabled = true
    ) THEN
        RAISE EXCEPTION 'City is inactive or service is unavailable';
    END IF;

    -- მხოლოდ ერთი აქტიური, მოქმედი ქალაქის GO გეგმა.
    SELECT count(*)
    INTO v_i
    FROM public.go_tariff_plans p
    WHERE p.city_id = p_city_id
      AND p.scope_type = 'city'
      AND p.is_active = true
      AND p.effective_from <= now()
      AND (p.effective_until IS NULL OR p.effective_until > now());

    IF v_i <> 1 THEN
        RAISE EXCEPTION
            'Expected exactly one active GO city tariff plan; found %',
            v_i;
    END IF;

    SELECT p.id, p.currency_code
    INTO v_plan_id, v_currency
    FROM public.go_tariff_plans p
    WHERE p.city_id = p_city_id
      AND p.scope_type = 'city'
      AND p.is_active = true
      AND p.effective_from <= now()
      AND (p.effective_until IS NULL OR p.effective_until > now());

    IF v_currency IS NULL THEN
        RAISE EXCEPTION 'GO tariff plan has no currency';
    END IF;

    v_i := 0;

    -- წერტილების ფორმატისა და თანმიმდევრობის შემოწმება.
    FOR v_point IN
        SELECT value
        FROM jsonb_array_elements(p_points)
    LOOP
        v_i := v_i + 1;

        IF jsonb_typeof(v_point) <> 'object' THEN
            RAISE EXCEPTION 'Each route point must be an object';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM jsonb_object_keys(v_point) AS k(key)
            WHERE k.key NOT IN (
                'point_type',
                'latitude',
                'longitude',
                'address'
            )
        ) THEN
            RAISE EXCEPTION 'Unknown route point field';
        END IF;

        IF jsonb_typeof(v_point->'point_type')
             IS DISTINCT FROM 'string'
           OR jsonb_typeof(v_point->'latitude')
             IS DISTINCT FROM 'number'
           OR jsonb_typeof(v_point->'longitude')
             IS DISTINCT FROM 'number' THEN
            RAISE EXCEPTION 'Invalid route point fields';
        END IF;

        v_point_type := v_point->>'point_type';

        IF v_i = 1 AND v_point_type <> 'pickup' THEN
            RAISE EXCEPTION 'First point must be pickup';
        ELSIF v_i = v_count AND v_point_type <> 'dropoff' THEN
            RAISE EXCEPTION 'Last point must be dropoff';
        ELSIF v_i > 1 AND v_i < v_count
              AND v_point_type <> 'stop' THEN
            RAISE EXCEPTION 'Intermediate points must be stops';
        END IF;

        IF (v_point->>'latitude')::numeric NOT BETWEEN -90 AND 90
           OR (v_point->>'longitude')::numeric NOT BETWEEN -180 AND 180 THEN
            RAISE EXCEPTION 'Invalid geographic coordinates';
        END IF;

        IF v_point ? 'address'
           AND v_point->'address' <> 'null'::jsonb
           AND jsonb_typeof(v_point->'address') <> 'string' THEN
            RAISE EXCEPTION 'Address must be text or null';
        END IF;

        IF length(v_point->>'address') > 500 THEN
            RAISE EXCEPTION 'Address is too long';
        END IF;
    END LOOP;

    INSERT INTO public.ride_quotes (
        passenger_id,
        city_id,
        currency_code,
        route_preference,
        status,
        quote_source
    )
    VALUES (
        v_user_id,
        p_city_id,
        v_currency,
        'fastest',
        'pending',
        'GO'
    )
    RETURNING id INTO v_quote_id;

    v_i := 0;

    FOR v_point IN
        SELECT value
        FROM jsonb_array_elements(p_points)
    LOOP
        INSERT INTO public.ride_route_points (
            quote_id,
            point_type,
            sequence_number,
            latitude,
            longitude,
            address
        )
        VALUES (
            v_quote_id,
            v_point->>'point_type',
            v_i,
            (v_point->>'latitude')::numeric,
            (v_point->>'longitude')::numeric,
            v_point->>'address'
        );

        v_i := v_i + 1;
    END LOOP;

    RETURN v_quote_id;
END;
$function$;
CREATE OR REPLACE FUNCTION public.go_save_ride_route_legs(p_quote_id uuid,p_legs jsonb)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $route$
DECLARE
 v_user_id uuid:=auth.uid(); v_quote public.ride_quotes%ROWTYPE;
 v_point_count integer; v_existing integer; v_inserted integer:=0;
 v_segment record; v_seq integer; v_start uuid; v_end uuid;
 v_distance numeric; v_duration numeric; v_geometry jsonb;
BEGIN
 IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 IF p_quote_id IS NULL OR p_legs IS NULL OR jsonb_typeof(p_legs)<>'array' THEN
  RAISE EXCEPTION 'Quote ID and route leg array are required';
 END IF;
 SELECT * INTO v_quote FROM public.ride_quotes WHERE id=p_quote_id FOR UPDATE;
 IF NOT FOUND OR v_quote.passenger_id IS DISTINCT FROM v_user_id THEN
  RAISE EXCEPTION 'Not authorized for this ride quote' USING ERRCODE='42501';
 END IF;
 IF v_quote.quote_source IS DISTINCT FROM 'GO' OR v_quote.status<>'pending' THEN
  RAISE EXCEPTION 'Only pending GO quotes can receive route legs';
 END IF;
 IF EXISTS(SELECT 1 FROM public.go_quote_tariff_snapshots WHERE quote_id=p_quote_id) THEN
  RAISE EXCEPTION 'A quote with a tariff snapshot cannot be changed';
 END IF;
 SELECT count(*) INTO v_point_count FROM public.ride_route_points WHERE quote_id=p_quote_id;
 IF v_point_count<2 OR v_point_count>6 OR jsonb_array_length(p_legs)<>v_point_count-1 THEN
  RAISE EXCEPTION 'Route leg count must equal point count minus one (max: pickup + four stops + dropoff)';
 END IF;
 IF v_point_count>2 AND NOT public.go_is_feature_enabled('ride.multiple_stops') THEN
  RAISE EXCEPTION 'Multiple stops are currently disabled by MASTER ADMIN';
 END IF;
 SELECT count(*) INTO v_existing FROM public.ride_route_legs WHERE quote_id=p_quote_id;
 IF v_existing<>0 THEN RAISE EXCEPTION 'Route legs already exist for this quote'; END IF;
 FOR v_segment IN SELECT value,ordinality FROM jsonb_array_elements(p_legs) WITH ORDINALITY LOOP
  IF jsonb_typeof(v_segment.value)<>'object' OR EXISTS(
   SELECT 1 FROM jsonb_object_keys(v_segment.value) k(key)
   WHERE key NOT IN ('sequence_number','distance_km','duration_minutes','route_geometry')
  ) THEN RAISE EXCEPTION 'Invalid route leg object'; END IF;
  IF jsonb_typeof(v_segment.value->'sequence_number')<>'number'
   OR jsonb_typeof(v_segment.value->'distance_km')<>'number'
   OR jsonb_typeof(v_segment.value->'duration_minutes')<>'number'
   OR jsonb_typeof(v_segment.value->'route_geometry')<>'object' THEN
   RAISE EXCEPTION 'Invalid route leg fields';
  END IF;
  v_seq:=(v_segment.ordinality-1)::integer;
  IF (v_segment.value->>'sequence_number')::integer<>v_seq THEN RAISE EXCEPTION 'Route leg sequence must be contiguous'; END IF;
  v_distance:=(v_segment.value->>'distance_km')::numeric;
  v_duration:=(v_segment.value->>'duration_minutes')::numeric;
  v_geometry:=v_segment.value->'route_geometry';
  IF v_distance<=0 OR v_duration<0
   OR (v_geometry->>'type' IS DISTINCT FROM 'LineString'
       AND v_geometry->>'type' IS DISTINCT FROM 'MultiLineString')
   OR jsonb_typeof(v_geometry->'coordinates') IS DISTINCT FROM 'array' THEN
   RAISE EXCEPTION 'Invalid route geometry, distance or duration';
  END IF;
  SELECT id INTO v_start FROM public.ride_route_points WHERE quote_id=p_quote_id AND sequence_number=v_seq;
  SELECT id INTO v_end FROM public.ride_route_points WHERE quote_id=p_quote_id AND sequence_number=v_seq+1;
  IF v_start IS NULL OR v_end IS NULL THEN RAISE EXCEPTION 'Route point pair missing'; END IF;
  INSERT INTO public.ride_route_legs(quote_id,start_point_id,end_point_id,sequence_number,distance_km,duration_minutes,route_geometry)
  VALUES(p_quote_id,v_start,v_end,v_seq,v_distance,v_duration,v_geometry);
  v_inserted:=v_inserted+1;
 END LOOP;
 RETURN v_inserted;
END;
$route$;
REVOKE ALL ON FUNCTION public.go_save_ride_route_legs(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.go_save_ride_route_legs(uuid,jsonb) TO authenticated;
COMMIT;
