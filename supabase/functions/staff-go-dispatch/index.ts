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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return respond(405, { error: "Method not allowed." });
  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return respond(401, { error: "Authentication required." });

  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anon || !service) return respond(503, { error: "Supabase server environment is incomplete." });

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
    const body = await req.json();
    const requestId = typeof body?.requestId === "string" ? body.requestId : "";
    if (!requestId) return respond(400, { error: "STAFF GO request ID is required." });

    const { data: profile, error: profileError } = await userClient.from("profiles")
      .select("role,account_status").eq("id", userId).maybeSingle();
    if (profileError || profile?.role !== "passenger" || profile.account_status !== "active") {
      return respond(403, { error: "An active passenger account is required." });
    }

    const { data: request, error: requestError } = await adminClient.from("staff_go_requests")
      .select("id,passenger_id,status").eq("id", requestId).maybeSingle();
    if (requestError || !request || request.passenger_id !== userId) {
      return respond(404, { error: "STAFF GO request not found for this passenger." });
    }

    const { data: flag, error: flagError } = await adminClient.from("go_app_feature_flags")
      .select("is_enabled,is_available").eq("feature_key", "ride.staff_go").maybeSingle();
    if (flagError || !flag?.is_enabled || !flag?.is_available) {
      return respond(409, { error: "STAFF GO is currently unavailable." });
    }

    const { data: orders, error: ordersError } = await adminClient.from("staff_go_orders")
      .select("id,order_sequence,status").eq("request_id", requestId)
      .in("status", ["requested", "dispatching"]).order("order_sequence");
    if (ordersError) return respond(500, { error: "Could not load STAFF GO orders for dispatch." });
    if (!orders?.length) {
      const { data: current } = await adminClient.from("staff_go_requests").select("status").eq("id",requestId).single();
      return respond(200, { success: true, requestId, status: current?.status ?? request.status, results: [] });
    }

    const results: Record<string, unknown>[] = [];
    for (const order of orders) {
      const { data, error } = await adminClient.rpc("go_staff_go_dispatch_order", { p_order_id: order.id });
      results.push({
        orderId: order.id,
        orderSequence: order.order_sequence,
        ...(data && typeof data === "object" ? data : {}),
        ...(error ? { error: error.message } : {}),
      });
    }

    const { data: finalRequest, error: finalError } = await adminClient.from("staff_go_requests")
      .select("status").eq("id", requestId).single();
    if (finalError) return respond(500, { error: "Dispatch was attempted but request status could not be refreshed.", results });

    return respond(200, {
      success: results.every((r) => !r.error),
      requestId,
      status: finalRequest.status,
      results,
    });
  } catch (error) {
    return respond(400, { error: error instanceof Error ? error.message : "Invalid STAFF GO dispatch request." });
  }
});
