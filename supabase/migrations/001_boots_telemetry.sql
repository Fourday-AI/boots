-- Boots telemetry schema.
-- Two event streams (funnel = systems moving through stages; runs = ops/crashes),
-- installations for retention, and a pulse cache. All identifying data is stripped
-- or hashed client-side before it ever reaches here (see boots-telemetry-sync).

create table funnel_events (
  id uuid default gen_random_uuid() primary key,
  received_at timestamptz default now(),
  v int not null default 1,
  event_timestamp timestamptz not null,
  event text not null,               -- created | transition | shipped | retired | reopened
  system text,                       -- HASHED client-side; opaque, not a real slug
  from_stage text,
  to_stage text,
  outcome text,                      -- advanced | blocked | abandoned
  form text,
  platform text,
  installation_id text               -- community tier only; random, not machine-derived
);

create table run_events (
  id uuid default gen_random_uuid() primary key,
  received_at timestamptz default now(),
  v int not null default 1,
  event_timestamp timestamptz not null,
  skill text,
  outcome text not null,             -- success | error | abort | unknown
  duration_s numeric,
  os text,
  installation_id text
);

create table installations (
  installation_id text primary key,
  first_seen timestamptz default now(),
  last_seen timestamptz default now(),
  os text
);

create table community_pulse_cache (
  id int primary key default 1,
  data jsonb,
  refreshed_at timestamptz default now()
);

create index idx_funnel_event_ts on funnel_events (event, event_timestamp);
create index idx_funnel_system on funnel_events (system, event_timestamp);
create index idx_run_error on run_events (skill, outcome) where outcome = 'error';

-- RLS: the anon key may INSERT only (that's all the ingest edge function needs —
-- least privilege, so a leaked public key can never READ anyone's data). Reads
-- happen exclusively via the community-pulse edge function using the service-role
-- key, which bypasses RLS. No anon SELECT anywhere.
alter table funnel_events enable row level security;
create policy anon_insert on funnel_events for insert with check (true);

alter table run_events enable row level security;
create policy anon_insert on run_events for insert with check (true);

-- installations is strictly insert-only for anon. A true upsert (ON CONFLICT) trips
-- RLS here (PostgREST routes it through a path the insert-only policy rejects with
-- 42501), so the ingest function does a plain INSERT and ignores the 23505 on repeat
-- installs. No UPDATE policy — a new install records first_seen; last_seen isn't
-- tracked (per-install recency is recoverable from the event streams).
alter table installations enable row level security;
create policy anon_insert on installations for insert with check (true);

alter table community_pulse_cache enable row level security;  -- no anon policy → anon denied

-- Read views (service-role only). The community funnel: where do systems flow and die.
-- security_invoker=on is load-bearing: without it a view runs as its (postgres) owner
-- and BYPASSES the base tables' insert-only RLS, letting anon read aggregates via
-- PostgREST. With it, a querying role hits the base-table RLS (no SELECT policy) and
-- is denied. The revoke is belt-and-braces so the anon key can't reach them at all.
create view funnel_by_stage with (security_invoker = on) as
  select to_stage as stage, count(*) as moves, count(distinct installation_id) as installs
  from funnel_events where to_stage is not null group by to_stage;

create view graveyard with (security_invoker = on) as
  select from_stage as stage, count(*) as abandonments
  from funnel_events where event = 'retired' and from_stage is not null
  group by from_stage order by abandonments desc;

create view crash_clusters with (security_invoker = on) as
  select skill, count(*) as crashes
  from run_events where outcome in ('error','unknown')
  group by skill order by crashes desc;

revoke all on funnel_by_stage, graveyard, crash_clusters from anon, authenticated;

-- weekly_active is DISTINCT installs in the window, not raw run_events rows (one
-- install with many runs counts once). PostgREST can't express count(distinct)
-- inline, so community-pulse calls this. SECURITY INVOKER + pinned empty search_path
-- (no definer escalation / injection); revoked from the public API — only the pulse
-- function's service-role client calls it. NULL installation_id (anonymous tier) is
-- excluded: an unidentified run isn't a distinct known install.
create or replace function public.weekly_active_installs(since timestamptz)
returns bigint
language sql
stable
security invoker
set search_path = ''
as $$
  select count(distinct installation_id)
  from public.run_events
  where event_timestamp >= since and installation_id is not null;
$$;

revoke all on function public.weekly_active_installs(timestamptz) from public, anon, authenticated;
grant execute on function public.weekly_active_installs(timestamptz) to service_role;
