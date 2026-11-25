import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.57.0";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};
const respond = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: cors });

type Point = { latitude: number; longitude: number; address: string };

async function tomtomLeg(a: Point, b: Point, key: string) {
  const url = new URL("https://api.tomtom.com/maps/orbis/routing/routes/calculate");
  url.searchParams.set("apiVersion", "3");
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "TomTom-Api-Version": "3",
      "TomTom-Api-Key": key,
      "Attributes": "routes",
    },
    body: JSON.stringify({
      routePlanningLocations: {
        origin: { type: "Point", coordinates: [a.longitude, a.latitude] },
        destination: { type: "Point", coordinates: [b.longitude, b.latitude] },
      },
      routeType: "fast",
      traffic: "live",
    }),
    signal: AbortSignal.timeout(20000),
  });
  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`TomTom Orbis Routing v3 error ${response.status}: ${detail.slice(0, 220)}`);
  }
  const json = await response.json();
  const route = json?.routes?.[0];
  const summary = route?.summary;
  const legs = Array.isArray(route?.legs) ? route.legs : [];
  const legCoordinates = legs.flatMap((item: any) =>
    Array.isArray(item?.path?.coordinates) ? item.path.coordinates : []
  );
  const coordinates = legCoordinates.length >= 2
    ? legCoordinates
    : (Array.isArray(route?.path?.coordinates) ? route.path.coordinates : []);
  if (!summary || !Number.isFinite(summary.lengthInMeters) ||
      !Number.isFinite(summary.travelDurationInSeconds) || coordinates.length < 2) {
    throw new Error("TomTom returned an incomplete route.");
  }
  return {
    distance_km: Number((summary.lengthInMeters / 1000).toFixed(3)),
    duration_minutes: Number((summary.travelDurationInSeconds / 60).toFixed(2)),
    route_geometry: {
      type: "LineString",
      coordinates: coordinates.map((pair: number[]) => [Number(pair[0]), Number(pair[1])]),
    },
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return respond(405, { error: "Method not allowed." });
  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return respond(401, { error: "Authentication required." });

  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const tomtomKey = Deno.env.get("TOMTOM_API_KEY") ?? Deno.env.get("VUE_APP_TOMTOM_API_KEY");
  if (!url || !anon || !service) return respond(503, { error: "Supabase server environment is incomplete." });
  if (!tomtomKey) return respond(503, { error: "TomTom server key missing. Add TOMTOM_API_KEY to Supabase Edge Function secrets." });

  const userClient = createClient(url, anon, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: authorization } },
  });
  const adminClient = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });

  try {
    const token = authorization.slice(7);
    const { data: authData, error: authError } = await userClient.auth.getUser(token);
    if (authError || !authData.user) return respond(401, { error: "Session is invalid or expired." });
    const userId = authData.user.id;

    const { data: profile, error: profileError } = await userClient.from("profiles")
      .select("role,account_status").eq("id", userId).maybeSingle();
    if (profileError || profile?.role !== "passenger" || profile.account_status !== "active") {
      return respond(403, { error: "An active passenger account is required." });
    }

    const body = await req.json();
    const requestId = typeof body?.requestId === "string" ? body.requestId : "";
    const categoryId = typeof body?.categoryId === "string" ? body.categoryId : "";
    if (!requestId || !categoryId) return respond(400, { error: "Request ID and vehicle category are required." });

    const { data: flag, error: flagError } = await adminClient.from("go_app_feature_flags")
      .select("is_enabled,is_available").eq("feature_key", "ride.staff_go").maybeSingle();
    if (flagError || !flag?.is_enabled || !flag?.is_available) {
      return respond(409, { error: "STAFF GO is currently unavailable." });
    }

    const { data: request, error: requestError } = await userClient.from("staff_go_requests")
      .select("id,passenger_id,request_mode,pickup_address,pickup_latitude,pickup_longitude,city_id,currency_code,status")
      .eq("id", requestId).eq("passenger_id", userId).maybeSingle();
    if (requestError || !request) return respond(404, { error: "STAFF GO request not found." });
    if (!["draft", "quoting"].includes(request.status)) return respond(409, { error: "STAFF GO request is no longer quoteable." });

    const { data: category, error: categoryError } = await userClient.from("vehicle_categories")
      .select("id,code,is_active").eq("id", categoryId).maybeSingle();
    if (categoryError || !category?.is_active || ["GROUP_RIDE_GO", "MINIVAN_GO"].includes(category.code)) {
      return respond(409, { error: "Select one of the six active ride categories." });
    }

    const { data: city, error: cityError } = await userClient.from("cities")
      .select("id,is_active,service_enabled").eq("id", request.city_id).maybeSingle();
    if (cityError || !city?.is_active || !city?.service_enabled) return respond(409, { error: "STAFF GO is not active in this city." });

    const { data: addresses, error: addressError } = await userClient.from("staff_go_addresses")
      .select("id,sequence_no,address_label,address_text,latitude,longitude")
      .eq("request_id", requestId).order("sequence_no");
    if (addressError || !addresses || addresses.length < 1 || addresses.length > 5) {
      return respond(409, { error: "STAFF GO request must contain one to five destination addresses." });
    }

    const pickup: Point = {
      latitude: Number(request.pickup_latitude),
      longitude: Number(request.pickup_longitude),
      address: request.pickup_address,
    };
    const destinations: Point[] = addresses.map((a: any) => ({
      latitude: Number(a.latitude),
      longitude: Number(a.longitude),
      address: a.address_text,
    }));
    const items: Record<string, unknown>[] = [];
    const routeSnapshot: Record<string, unknown>[] = [];
    let totalDistance = 0;
    let totalDuration = 0;

    if (request.request_mode === "single_vehicle_route") {
      const routePoints = [pickup, ...destinations];
      const legs = [];
      for (let i = 0; i < routePoints.length - 1; i++) {
        legs.push(await tomtomLeg(routePoints[i], routePoints[i + 1], tomtomKey));
      }
      const distance = Number(legs.reduce((sum, leg) => sum + leg.distance_km, 0).toFixed(3));
      const duration = Number(legs.reduce((sum, leg) => sum + leg.duration_minutes, 0).toFixed(2));
      totalDistance = distance;
      totalDuration = duration;
      items.push({ order_sequence: 1, category_id: categoryId, distance_km: distance, duration_minutes: duration });
      routeSnapshot.push({
        order_sequence: 1,
        route_points: routePoints,
        legs: legs.map((leg) => leg.route_geometry),
      });
    } else if (request.request_mode === "separate_vehicle_per_address") {
      for (let i = 0; i < addresses.length; i++) {
        const leg = await tomtomLeg(pickup, destinations[i], tomtomKey);
        totalDistance += leg.distance_km;
        totalDuration += leg.duration_minutes;
        items.push({
          order_sequence: addresses[i].sequence_no,
          destination_address_id: addresses[i].id,
          category_id: categoryId,
          distance_km: leg.distance_km,
          duration_minutes: leg.duration_minutes,
        });
        routeSnapshot.push({
          order_sequence: addresses[i].sequence_no,
          destination_address_id: addresses[i].id,
          route_geometry: leg.route_geometry,
        });
      }
      totalDistance = Number(totalDistance.toFixed(3));
      totalDuration = Number(totalDuration.toFixed(2));
    } else {
      return respond(400, { error: "Unsupported STAFF GO request mode." });
    }

    const { data: quoteResult, error: quoteError } = await adminClient.rpc("go_staff_go_create_quote", {
      p_request_id: requestId,
      p_items: items,
      p_route_snapshot: { provider: "tomtom_orbis_v3", mode: request.request_mode, routes: routeSnapshot },
      p_route_provider: "tomtom",
    });
    if (quoteError || !quoteResult?.quote_id) {
      return respond(409, { error: quoteError?.message ?? "Could not create STAFF GO price quote." });
    }

    const { data: quoteItems, error: itemError } = await adminClient.from("staff_go_quote_items")
      .select("id,order_sequence,destination_address_id,category_code,distance_km,duration_minutes,fare_amount,currency_code,pricing_method_snapshot")
      .eq("quote_id", quoteResult.quote_id).order("order_sequence");
    if (itemError) return respond(500, { error: "Quote was created but quote items could not be read." });

    const { data: quote, error: quoteReadError } = await adminClient.from("staff_go_quotes")
      .select("id,total_distance_km,total_duration_minutes,total_fare,currency_code,expires_at,status")
      .eq("id", quoteResult.quote_id).single();
    if (quoteReadError) return respond(500, { error: "Quote was created but quote details could not be read." });

    return respond(200, {
      success: true,
      requestId,
      quoteId: quote.id,
      requestMode: request.request_mode,
      categoryCode: category.code,
      totalDistanceKm: quote.total_distance_km,
      totalDurationMinutes: quote.total_duration_minutes,
      totalFare: quote.total_fare,
      currencyCode: quote.currency_code,
      expiresAt: quote.expires_at,
      items: quoteItems ?? [],
      routeSnapshot,
    });
  } catch (error) {
    return respond(400, { error: error instanceof Error ? error.message : "Invalid STAFF GO quote request." });
  }
});
