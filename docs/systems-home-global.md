# Boots: systems live in one global home (not per-repo)

Decision on record (2026-07-22): **a system's records live in the global Boots home —
`~/.boots/systems/<slug>/` — not per-repo.** Review happens *through the agent* (every
skill knows where systems are), so no separate review skill or dashboard is needed.

This reverses an earlier design that put system records in-repo at
`./state/systems/<slug>/`. Records created under the old layout are brought forward by
`boots-migrate-systems`.

---

## 0. The reframe (why the old placement was wrong for Boots)

Two things were tangled under "global vs local":

1. **The Boots *code*** (the skills) — install global, symlink into the host's skills
   dir. Settled, unchanged.
2. **The Boots *work state*** (each system's `system.md`, `sessions/`, `events.jsonl`,
   verify evidence) — this is the question.

And the built **artifact** is already decoupled from the repo: a shipped skill lives in
a skills dir to *function*, wherever that is. So the only undecided thing was **where a
system's records live.**

The old answer ("in-repo, state-as-code") was inherited from the developer-tooling
codebase parts of this engine were ported from. That tool augments a **developer already
living in a git repo**; Boots builds **standalone AI systems for people who are often not
in a repo at all**. For Boots the unit of "project" is *the system*, not *the repo*. The
inherited placement carries an assumption that does not hold for who Boots is for.

**The failure mode it creates:** a user builds a system in `~/Documents`, records land in
`~/Documents/state/systems/…`, then next session they open Claude Code in `~/Desktop` and
ask "how's my system doing?" — and Boots can't find records stranded in a directory the
user isn't standing in and doesn't think about. For a global tool used by people who
don't anchor to directories, **per-cwd state is a footgun.**

**Why "review through the agent" closes the loop:** the worry about a global store was
"reviewing outputs in a hidden `~/.boots` dir is harder." But a nontechnical Boots user
reviews their systems *by asking Boots*, not by browsing the filesystem. If every skill
always knows where systems live, the review surface exists for free — the agent opens and
renders the record and the artifact on request. Findability *is* the review surface.

---

## 1. The convention

```
~/.boots/systems/<slug>/
  system.md          # the record (header fields + ## now pickup + ## log)
  sessions/…         # per-session prose logs
  events.jsonl       # Layer-A funnel: one line per stage transition
  …                  # verify evidence, artifacts-in-progress, etc.
```

- **Home:** `~/.boots` (the Boots home — same dir that holds `config.yaml`, `analytics/`).
  Overridable with `BOOTS_HOME` (used by tests and power users).
- **One home, always found.** No cwd dependence, no per-repo `state/`, no cross-repo index
  needed to answer "where are my systems" — they are all in one place.

---

## 2. One source of truth for the path

The path is defined once and both representations stay in lockstep:

- **Skill prose** references `{{SYSTEMS_DIR}}/<slug>/…`. The token resolves via
  `HostPaths.systemsDir` (`scripts/resolvers/types.ts` → `scripts/resolvers/index.ts`):
  `~/.boots/systems` for Claude, `$BOOTS_HOME/systems` for env-var hosts (Codex). One
  edit, injected into every skill on `bun run gen:skill-docs` — never pasted into N files.
- **Bin scripts** read the same convention at runtime: `${BOOTS_HOME:-$HOME/.boots}/systems`.

Both agree on `~/.boots/systems/<slug>/`. This is the multi-host seam doing its job: a new
host gets the right path for free.

---

## 3. Build order

**Slice 1 — DONE (2026-07-22):**
- `HostPaths.systemsDir` + the `{{SYSTEMS_DIR}}` resolver token.
- `boots-event` writes to `$BOOTS_HOME/systems/<slug>/events.jsonl` (was cwd `state/systems/`).
- `boots-analytics` reads the global store and is reframed from "this repo" to "every
  system you have". Verified: from a non-repo cwd, records land in the global home and the
  board finds them; nothing is written to cwd.

**Slice 2 — DONE (2026-07-22):**
- Replaced `state/systems` → `{{SYSTEMS_DIR}}` across the 13 product skill `.tmpl` files +
  the `FUNNEL_EMIT` resolver + `boots-prospect/sources.md`; regenerated (freshness green,
  all tokens resolve to `~/.boots/systems`). Private skills left untouched.
- Fixed the nontechnical-user Finder handoff prose in `boots-build`/`boots-verify`/router:
  the input folder is now in the hidden `~/.boots` home, so the path resolves from the home
  (not `pwd`) and the skills lean toward "offer to open it for them".
- Added router talk-rule **10 (review through the agent)**: Boots reads the record + latest
  session + artifact and renders them in chat; proactively offers to show a shipped system
  rather than naming a hidden path. One rule every stage inherits — no new skill.
- Docs pass: `CLAUDE.md` (state location + open-source note), the `setup` install block
  ("your systems live in `~/.boots/systems/`, ask Boots to see one"). This repo's own
  `/state/` gitignore stays until slice 3 moves the author's legacy systems.

**Slice 3 — migration DONE (2026-07-22); developer opt-in still deferred:**
- **`bin/boots-migrate-systems`** — non-destructive (copies, never moves), idempotent
  (skips slugs already global), `--dry-run`, honors `BOOTS_HOME`. Verified: dry run →
  real copy → second run all-conflict; source intact.
- **Router Step 0** — lazy + repo-aware: the migration is per-repo because the old state
  was per-repo. When `boots` opens in a repo with a legacy `./state/systems/` holding
  slugs not yet global, it dry-runs, asks once (AskUserQuestion), migrates on yes, and
  drops `~/.boots/.migration-declined-<repo>` on no. Silent when there's nothing to move.
- **Verified against a real legacy repo:** 7 systems (282 files) copied into
  `~/.boots/systems/`; `boots-analytics` reads them from any cwd. Originals under `state/`
  left in place — delete once confirmed.
- **Option C affordance (still deferred):** a developer who *wants* records committed next
  to code can opt a system into a repo. Global is the default; in-repo is a deliberate
  choice. Build only when a real user asks.

---

## 4. Open items to resolve during slice 2/3

- **`~/.boots` collision.** The README installs the clone to `~/.boots` *and* the runtime
  writes state there. Systems now live at `~/.boots/systems/` alongside the clone. Coexists
  fine, but the "reclaim `~/.boots`" housekeeping (archive any earlier leftovers) is now
  a real prerequisite for a clean user install.
- **Funnel `_repo` field.** `boots-event`'s outbound buffer still tags a `_repo` slug from
  `git rev-parse`. With global systems this is less meaningful (local-only, harmless) — decide
  whether to keep, drop, or replace with the system slug context.
- **`.gitignore`.** The product repo's `/state/` ignore is about the maintainer's own dev sessions; a
  user's systems now live outside any repo, so the user-facing guidance is simply "your
  systems live in `~/.boots/systems/` and stay on your machine".
