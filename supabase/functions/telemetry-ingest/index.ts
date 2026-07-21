// Boots telemetry-ingest edge function.
// Validates + inserts a batch of already-anonymized events. Routes each record by
// its `event` field: skill_run -> run_events, everything else -> funnel_events.
// Uses the ANON key (least privilege — a public telemetry endpoint only needs
// INSERT), not the service-role key. Called by boots-telemetry-sync.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MAX_BATCH = 100;
const MAX_BYTES = 60_000;
const FUNNEL_EVENTS = ["created", "transition", "shipped", "retired", "reopened"];

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("POST required", { status: 405 });
  if (parseInt(req.headers.get("content-length") || "0") > MAX_BYTES) {
    return new Response("Payload too large", { status: 413 });
  }
  try {
    const body = await req.json();
    const records = Array.isArray(body) ? body : [body];
    if (records.length > MAX_BATCH) return new Response(`Batch too large (max ${MAX_BATCH})`, { status: 400 });

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    );

    const funnel: Record<string, unknown>[] = [];
    const runs: Record<string, unknown>[] = [];
    const installs = new Map<string, string | null>();
    const s = (x: unknown, n: number) => (x == null ? null : String(x).slice(0, n));

    for (const e of records) {
      if (e?.v !== 1 || !e?.ts) continue;
      const iid = e.installation_id ? String(e.installation_id).slice(0, 64) : null;
      const os = e.os ? String(e.os).slice(0, 20) : null;

      if (e.event === "skill_run") {
        if (!e.outcome) continue;
        runs.push({
          v: 1, event_timestamp: e.ts, skill: s(e.skill, 50),
          outcome: String(e.outcome).slice(0, 20),
          duration_s: typeof e.duration_s === "number" ? e.duration_s : null,
          os, installation_id: iid,
        });
      } else if (FUNNEL_EVENTS.includes(e.event)) {
        funnel.push({
          v: 1, event_timestamp: e.ts, event: String(e.event).slice(0, 20),
          system: s(e.system, 64), from_stage: s(e.from_stage, 20), to_stage: s(e.to_stage, 20),
          outcome: s(e.outcome, 20), form: s(e.form, 64), platform: s(e.platform, 32),
          installation_id: iid,
        });
      } else continue;

      if (iid) installs.set(iid, os);
    }

    let inserted = 0;
    if (funnel.length) {
      const { error } = await supabase.from("funnel_events").insert(funnel);
      if (!error) inserted += funnel.length;
    }
    if (runs.length) {
      const { error } = await supabase.from("run_events").insert(runs);
      if (!error) inserted += runs.length;
    }
    for (const [id, os] of installs) {
      await supabase.from("installations").upsert(
        { installation_id: id, last_seen: new Date().toISOString(), os },
        { onConflict: "installation_id" },
      );
    }

    return new Response(JSON.stringify({ inserted }), {
      status: 200, headers: { "Content-Type": "application/json" },
    });
  } catch {
    return new Response("Invalid request", { status: 400 });
  }
});
