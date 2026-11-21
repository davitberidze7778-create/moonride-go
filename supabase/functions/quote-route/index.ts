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

type Point = { point_type: "pickup" | "stop" | "dropoff"; latitude: number; longitude: number; address?: string | null };

function validatePoints(input: unknown): Point[] {
  if (!Array.isArray(input) || input.length < 2 || input.length > 6) throw new Error("Route must contain pickup, destination and up to four stops.");
  return (input as Point[]).map((p, i, arr) => {
    const kind = i === 0 ? "pickup" : i === arr.length - 1 ? "dropoff" : "stop";
    if (!p || p.point_type !== kind) throw new Error("Invalid route point order.");
    if (!Number.isFinite(p.latitude) || p.latitude < -90 || p.latitude > 90 ||
        !Number.isFinite(p.longitude) || p.longitude < -180 || p.longitude > 180) throw new Error("Invalid route coordinates.");
    return { point_type: kind, latitude: p.latitude, longitude: p.longitude,
      address: typeof p.address === "string" ? p.address.trim().slice(0, 500) : null };
  });
}

async function tomtomLeg(a: Point, b: Point, key: string) {
  const coords = `${a.latitude},${a.longitude}:${b.latitude},${b.longitude}`;
  const url = new URL(`https://api.tomtom.com/routing/1/calculateRoute/${coords}/json`);
  url.searchParams.set("key", key);
  url.searchParams.set("routeType", "fastest");
  url.searchParams.set("traffic", "true");
  url.searchParams.set("travelMode", "car");
  url.searchParams.set("computeTravelTimeFor", "all");
  const response = await fetch(url);
  if (!response.ok) throw new Error(`TomTom route error ${response.status}`);
  const json = await response.json();
  const route = json?.routes?.[0];
  const leg = route?.legs?.[0];
  const summary = leg?.summary ?? route?.summary;
  const pts = leg?.points ?? [];
  if (!summary || !Number.isFinite(summary.lengthInMeters) || !Number.isFinite(summary.travelTimeInSeconds) || pts.length < 2) {
    throw new Error("TomTom returned an incomplete route.");
  }
  return {
    distance_km: Number((summary.lengthInMeters / 1000).toFixed(3)),
    duration_minutes: Number((summary.travelTimeInSeconds / 60).toFixed(2)),
    route_geometry: { type: "LineString", coordinates: pts.map((p: any) => [Number(p.longitude), Number(p.latitude)]) },
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return respond(405, { error: "Method not allowed." });
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) return respond(401, { error: "Authentication required." });

  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anon || !service) return respond(503, { error: "Supabase server environment is incomplete." });

  const token = auth.slice(7);
  const userClient = createClient(url, anon, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: auth } },
  });
  const adminClient = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });

  try {
    const { data: authData, error: authError } = await userClient.auth.getUser(token);
    if (authError || !authData.user) return respond(401, { error: "Session is invalid or expired." });
    const userId = authData.user.id;
    const { data: profile, error: profileError } = await userClient.from("profiles")
      .select("role,account_status").eq("id", userId).maybeSingle();
    if (profileError || profile?.role !== "passenger") return respond(403, { error: "Passenger account required." });
    if (profile.account_status !== "active") return respond(403, { error: "Passenger account is suspended." });

    const body = await req.json();

    if (body?.action === "select_category") {
      const quoteId = typeof body.quoteId === "string" ? body.quoteId : "";
      const code = typeof body.categoryCode === "string" ? body.categoryCode : "";
      if (!quoteId || !code) return respond(400, { error: "Quote ID and category are required." });
      const { data: quote, error: quoteErr } = await adminClient.from("ride_quotes")
        .select("id,passenger_id,quote_source,status,expires_at")
        .eq("id", quoteId).maybeSingle();
      if (quoteErr || !quote || quote.passenger_id !== userId) return respond(404, { error: "Quote not found." });
      if (quote.quote_source !== "GO" || quote.status !== "priced") return respond(409, { error: "Quote is not ready for category selection." });
      if (quote.expires_at && new Date(quote.expires_at).getTime() <= Date.now()) return respond(410, { error: "Fare quote expired. Calculate a new route." });
      const { data: item, error: itemErr } = await adminClient.from("ride_quote_items")
        .select("category_id,category_code,total_fare,currency_code,vehicle_categories!inner(is_active)")
        .eq("quote_id", quoteId).eq("category_code", code).eq("vehicle_categories.is_active", true).maybeSingle();
      if (itemErr || !item) return respond(409, { error: "This category is not available for the quote." });
      const { error: saveErr } = await adminClient.from("ride_quotes")
        .update({ selected_category_id: item.category_id, selected_fare: item.total_fare, updated_at: new Date().toISOString() })
        .eq("id", quoteId).eq("passenger_id", userId);
      if (saveErr) return respond(500, { error: "Could not save the selected category." });
      return respond(200, { quoteId, categoryCode: item.category_code, selectedFare: Number(item.total_fare), currencyCode: item.currency_code, expiresAt: quote.expires_at });
    }

    const tomtomKey = Deno.env.get("TOMTOM_API_KEY");
    if (!tomtomKey) return respond(503, { error: "TomTom server key missing. Add TOMTOM_API_KEY to Supabase Edge Function secrets." });
    const cityId = typeof body?.cityId === "string" ? body.cityId : "";
    if (!cityId) return respond(400, { error: "City ID is required." });
    const points = validatePoints(body.points);
    const { data: city, error: cityError } = await userClient.from("cities")
      .select("id,is_active,service_enabled").eq("id", cityId).maybeSingle();
    if (cityError || !city || !city.is_active || !city.service_enabled) return respond(409, { error: "GO service is not active in this city." });

    const segments = [];
    for (let i = 0; i < points.length - 1; i++) segments.push(await tomtomLeg(points[i], points[i + 1], tomtomKey));

    const { data: quoteId, error: createErr } = await userClient.rpc("go_create_ride_quote", { p_city_id: cityId, p_points: points });
    if (createErr || !quoteId) return respond(409, { error: createErr?.message || "Could not create GO quote." });

    const { data: stored, error: storedErr } = await adminClient.from("ride_route_points")
      .select("id,sequence_number").eq("quote_id", quoteId).order("sequence_number");
    if (storedErr || !stored || stored.length !== points.length) {
      await adminClient.from("ride_quotes").update({ status: "cancelled" }).eq("id", quoteId);
      return respond(500, { error: "Could not verify saved route points." });
    }

    const rows = segments.map((s, i) => ({
      quote_id: quoteId, start_point_id: stored[i].id, end_point_id: stored[i + 1].id,
      sequence_number: i, distance_km: s.distance_km, duration_minutes: s.duration_minutes, route_geometry: s.route_geometry,
    }));
    const { error: legErr } = await adminClient.from("ride_route_legs").insert(rows);
    if (legErr) {
      await adminClient.from("ride_quotes").update({ status: "cancelled" }).eq("id", quoteId);
      return respond(500, { error: "Could not save verified TomTom route." });
    }

    const { data: options, error: priceErr } = await userClient.rpc("go_calculate_ride_quote", { p_quote_id: quoteId, p_wait_minutes: 0 });
    if (priceErr || !options?.length) {
      await adminClient.from("ride_quotes").update({ status: "cancelled" }).eq("id", quoteId);
      return respond(409, { error: priceErr?.message || "GO tariff pricing is unavailable." });
    }

    return respond(200, {
      quoteId, cityId,
      distanceKm: Number(segments.reduce((sum, s) => sum + s.distance_km, 0).toFixed(3)),
      durationMinutes: Number(segments.reduce((sum, s) => sum + s.duration_minutes, 0).toFixed(2)),
      options,
    });
  } catch (error) {
    return respond(400, { error: error instanceof Error ? error.message : "Invalid GO request." });
  }
});
