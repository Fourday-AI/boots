-- Layer B learns which AI host it ran on.
--
-- run_events had `os` and nothing else, so the only way to tell a Cowork session
-- from a local one was the guess "linux means container" — which breaks the first
-- time a Linux user installs Boots normally, and silently. The funnel has carried
-- `platform` since day one; this brings the ops log level with it.
--
-- Nullable with no default and no backfill: rows written before this column
-- existed genuinely don't know their host, and inventing 'claude-code' for them
-- would turn missing data into confident wrong data. NULL means "not recorded".

alter table run_events add column if not exists platform text;

-- Crashes-by-host is the question this column exists to answer: a skill that only
-- ever dies in one environment is a host bug, not a skill bug.
create index if not exists idx_run_platform_outcome
  on run_events (platform, outcome)
  where outcome in ('error', 'unknown');
