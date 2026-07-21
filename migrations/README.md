# Boots migrations

Idempotent bash scripts that fix up local state when Boots' shape changes between
versions — things `./setup` alone can't cover (a renamed config key, a moved file, a
system-record field). Run by `./setup` and by `boots-upgrade`, gated so each runs at
most once.

## Convention

- One file per version: `v<version>.sh` (e.g. `v0.2.0.0.sh`), matching the `VERSION` file's scheme.
- **Idempotent** — safe to run twice. Guard every change (`grep -q` before append, `[ -f ]` before move).
- Runs only when upgrading *from* an older version: setup compares `~/.boots/.last-setup-version`
  (the low-water mark) against the migration version and the current `VERSION`, in `sort -V` order.
  A fresh install skips migrations entirely and just stamps the marker.
- Print what you did. Never fail the upgrade — end non-fatal (`|| echo "..."`).

## Record migrations (the higher-stakes kind — deferred until needed)

System records live per-repo in `state/systems/<slug>/system.md` and carry a
`schema_version:` field. When that shape changes, a migration must back up the record
(`system.md.bak`), transform it, bump `schema_version`, and run **lazily** — when Boots
next touches that repo's state — because records are spread across every repo you've
built in, not in one global dir. No such migration exists yet (schema_version is 1);
this note is the contract for the first one.

## Nothing here yet

Boots is at v0.1.0.0. The first migration lands when the first breaking state change does.
