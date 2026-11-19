-- GO quote validity (5 minutes) and server-checked category selection.
BEGIN;
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
        expires_at,
        quote_source
    )
    VALUES (
        v_user_id,
        p_city_id,
        v_currency,
        'fastest',
        'pending',
        now() + interval '5 minutes',
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
$function$
;
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

    IF v_quote.expires_at IS NOT NULL AND v_quote.expires_at <= now() THEN
        RAISE EXCEPTION 'This GO fare quote has expired. Please request a new quote.';
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
$function$
;
CREATE OR REPLACE FUNCTION public.go_select_ride_quote_category(
 p_quote_id uuid,
 p_category_code text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $select$
DECLARE
 v_user_id uuid := auth.uid();
 v_quote public.ride_quotes%ROWTYPE;
 v_item record;
BEGIN
 IF v_user_id IS NULL THEN
  RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
 END IF;
 IF p_quote_id IS NULL OR NULLIF(btrim(p_category_code),'') IS NULL THEN
  RAISE EXCEPTION 'Quote and category are required';
 END IF;
 IF NOT public.go_is_feature_enabled('ride.quote') THEN
  RAISE EXCEPTION 'MOONRIDE GO quote service is currently disabled by MASTER ADMIN';
 END IF;

 SELECT * INTO v_quote
 FROM public.ride_quotes
 WHERE id=p_quote_id
 FOR UPDATE;

 IF NOT FOUND OR v_quote.passenger_id IS DISTINCT FROM v_user_id THEN
  RAISE EXCEPTION 'Not authorized for this quote' USING ERRCODE='42501';
 END IF;
 IF v_quote.quote_source IS DISTINCT FROM 'GO' OR v_quote.status<>'priced' THEN
  RAISE EXCEPTION 'Only priced GO quotes can select a category';
 END IF;
 IF v_quote.expires_at IS NOT NULL AND v_quote.expires_at<=now() THEN
  RAISE EXCEPTION 'This GO fare quote has expired. Please request a new quote.';
 END IF;

 SELECT i.category_id,i.category_code,i.total_fare,i.currency_code
 INTO v_item
 FROM public.ride_quote_items i
 JOIN public.vehicle_categories c ON c.id=i.category_id
 WHERE i.quote_id=p_quote_id
   AND i.category_code=p_category_code
   AND c.is_active=true;

 IF NOT FOUND THEN
  RAISE EXCEPTION 'This ride category is unavailable for this quote';
 END IF;

 UPDATE public.ride_quotes
 SET selected_category_id=v_item.category_id,
     selected_fare=v_item.total_fare,
     updated_at=now()
 WHERE id=p_quote_id;

 RETURN jsonb_build_object(
  'quote_id',p_quote_id,
  'category_code',v_item.category_code,
  'selected_fare',v_item.total_fare,
  'currency_code',v_item.currency_code,
  'expires_at',v_quote.expires_at
 );
END;
$select$;
REVOKE ALL ON FUNCTION public.go_select_ride_quote_category(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.go_select_ride_quote_category(uuid,text) TO authenticated;

COMMIT;
