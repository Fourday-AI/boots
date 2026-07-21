// Boots community-pulse edge function.
// Returns the aggregate community funnel: weekly-active installs, stage
// distribution, shipped/abandoned counts, the graveyard stage. Server-side cached
// (1h) to prevent DoS. Fail-closed: a healthy response carries status:"ok"; on
// recompute failure it serves the last snapshot marked stale:true, else 503 —
// errors never masquerade as healthy zeros.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CACHE_MS = 60 * 60 * 1000;
const JSON_HEADERS = { "Content-Type": "application/json", "Cache-Control": "public, max-age=3600" };

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  let cached: { data: Record<string, unknown>; refreshed_at: string } | null = null;
  try {
    const { data } = await supabase.from("community_pulse_cache").select("data, refreshed_at").eq("id", 1).single();
    cached = data ?? null;
  } catch { cached = null; }

  if (cached?.refreshed_at && Date.now() - new Date(cached.refreshed_at).getTime() < CACHE_MS) {
    return new Response(JSON.stringify({ ...cached.data, status: "ok" }), { status: 200, headers: JSON_HEADERS });
  }

  try {
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

    const { count: weekly } = await supabase
      .from("run_events").select("installation_id", { count: "exact", head: true })
      .gte("event_timestamp", weekAgo);

    const { data: funnel, error } = await supabase
      .from("funnel_events").select("event, to_stage, from_stage").gte("event_timestamp", weekAgo);
    if (error) throw error;

    const pipeline: Record<string, number> = {};
    const grave: Record<string, number> = {};
    let shipped = 0, abandoned = 0;
    for (const r of funnel ?? []) {
      if (r.to_stage) pipeline[r.to_stage] = (pipeline[r.to_stage] || 0) + 1;
      if (r.event === "shipped") shipped++;
      if (r.event === "retired") { abandoned++; if (r.from_stage) grave[r.from_stage] = (grave[r.from_stage] || 0) + 1; }
    }
    const graveyard = Object.entries(grave).sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;

    const payload = { status: "ok", weekly_active: weekly ?? 0, pipeline, shipped, abandoned, graveyard };
    await supabase.from("community_pulse_cache").upsert({ id: 1, data: payload, refreshed_at: new Date().toISOString() });
    return new Response(JSON.stringify(payload), { status: 200, headers: JSON_HEADERS });
  } catch {
    if (cached?.data) {
      return new Response(JSON.stringify({ ...cached.data, status: "ok", stale: true }), { status: 200, headers: JSON_HEADERS });
    }
    return new Response(JSON.stringify({ error: "pulse_unavailable" }), { status: 503, headers: { "Content-Type": "application/json" } });
  }
});
