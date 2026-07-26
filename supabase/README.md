# Boots telemetry backend

The optional backend behind Boots' opt-in telemetry. It is **off by default** — a
default install never contacts it. See the *Privacy & telemetry* section of the root
[`README.md`](../README.md) for the user-facing summary; this file is the mechanics.

It's committed in full so the privacy claims are checkable rather than promised.

## What's here

| | |
|---|---|
| `config.sh` | the public project URL + anon key the client posts to. Safe to commit — see below. |
| `functions/telemetry-ingest/` | the **write** path. Validates a batch and inserts it. Uses the anon key. |
| `functions/community-pulse/` | the **read** path. Returns aggregate community stats, cached 1h. Uses the service-role key, server-side only. |
| `migrations/001_boots_telemetry.sql` | tables, row-level security policies, and the one aggregate function. |

## Why the anon key is safe to publish

The same reason a Firebase web config is: it grants nothing on its own. Row-level
security on every table is **insert-only** for `anon`, there is no select policy, the
reporting views are `security_invoker` with `anon` and `authenticated` revoked, and
`weekly_active_installs()` is granted to `service_role` alone. So the published key
can append events and nothing else — it cannot read a single row back, including the
rows it just wrote.

`telemetry-ingest` deliberately runs on the anon key rather than the service-role key,
for the same reason: a public write endpoint only needs INSERT, so that's all it gets.

## What a record contains

Everything identifying is stripped **on the client**, in
[`boots-telemetry-sync`](../.claude/skills/boots/bin/boots-telemetry-sync), before
anything is sent — not here. The server never sees the original values:

- the system slug is replaced by a SHA-256 hash, salted with a random per-install
  value, truncated to 16 hex characters
- the local `_repo` field is deleted outright
- on the `anonymous` tier the installation id is deleted too

What lands in the tables is a stage transition, an outcome, a form and platform, an OS
name, a skill name, a duration, and (on `community`) a random install id.

`scripts/test-e2e.sh` asserts this by inspecting the exact bytes the sync would send.

## Self-hosting

Point Boots at your own project instead:

```bash
supabase link --project-ref <your-ref>
supabase db push                              # apply migrations/
supabase functions deploy telemetry-ingest
supabase functions deploy community-pulse
```

Then set `BOOTS_SUPABASE_URL` and `BOOTS_SUPABASE_ANON_KEY` in `config.sh` (or export
them). Blanking the URL disables the remote layer entirely — the sync becomes a no-op.

## Known limitation

`telemetry-ingest` is unauthenticated by design (it accepts anonymous opt-in data) and
caps batch size and payload bytes, but it is **not rate-limited**. Anyone who reads
`config.sh` can append junk events. The blast radius is aggregate-stat noise, not data
exposure — the insert-only policy means no one can read anything back — but it is a
known, accepted trade-off rather than an oversight.
