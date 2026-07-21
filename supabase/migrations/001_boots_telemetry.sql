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

alter table installations enable row level security;
create policy anon_insert on installations for insert with check (true);
create policy anon_update on installations for update using (true) with check (true);

alter table community_pulse_cache enable row level security;  -- no anon policy → anon denied

-- Read views (service-role only). The community funnel: where do systems flow and die.
create view funnel_by_stage as
  select to_stage as stage, count(*) as moves, count(distinct installation_id) as installs
  from funnel_events where to_stage is not null group by to_stage;

create view graveyard as
  select from_stage as stage, count(*) as abandonments
  from funnel_events where event = 'retired' and from_stage is not null
  group by from_stage order by abandonments desc;

create view crash_clusters as
  select skill, count(*) as crashes
  from run_events where outcome in ('error','unknown')
  group by skill order by crashes desc;
