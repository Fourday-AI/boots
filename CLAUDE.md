# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Boots is an **open-source suite of skills** that helps people *finish* the AI systems they
start. If the AI tool is the builder, Boots is the finisher. The deliverable is the
`boots-*` skills under `.claude/skills/`, not any application code — there is no server, no
runtime, no build output. Users install by symlinking the skills into their tool's skills
dir (`./setup`) and pasting a `## Boots` block into their instructions file.

**Claude Code is the first host, not the only one.** Boots is built to run on more AI
coding tools over time — the two seams that make this possible are load-bearing and should
be respected in every change: (1) the multi-host template engine (`hosts/`), which
generates host-specific skill files from one source template, and (2) the platform-scoped
form palettes (`forms/`), which keep "what you can build" separate from "how the pipeline
thinks". Do not hardcode Claude-Code-only assumptions into skill judgment; put anything
host- or platform-specific behind those two seams.

Read `README.md` for the product framing and `.claude/skills/boots/SKILL.md` for the full
behavioral contract (the router). Both are worth reading before changing skill prose.

**`vendor/paperclip/` is a vendored reference repo — ignore it entirely.** It is not part
of Boots and nothing there should be edited or reasoned about.

## Project structure

The map. Two seams do the heavy lifting — `hosts/` (multi-host) and `forms/`
(multi-platform); everything else is skills, the engine that generates them, and the
runtime plumbing they call.

```
boots/
├── .claude/skills/         # THE PRODUCT — the boots-* skills users install
│   ├── boots/              # the router + all shared assets for the suite
│   │   ├── SKILL.md.tmpl   #   source template (edit this)
│   │   ├── SKILL.md        #   generated (committed, AUTO-GENERATED header; don't edit)
│   │   ├── bin/            #   shell plumbing the preamble + stages call silently
│   │   ├── forms/          #   SEAM: platform palettes (claude-code.md today; one file per platform)
│   │   └── examples/       #   bundled resources skills read (e.g. finished-system.md)
│   ├── boots-clarify/      # one dir per stage skill — .tmpl + generated .md each
│   ├── boots-scope/        #   pipeline: clarify → scope → build → review → verify → ship
│   ├── boots-build/
│   ├── boots-review/
│   ├── boots-verify/
│   ├── boots-ship/
│   ├── boots-prospect/     # cross-cutting skills (any time): prospect · track · surface ·
│   ├── boots-track/        #   extract · retire · observe
│   ├── boots-surface/
│   ├── boots-extract/
│   ├── boots-retire/
│   ├── boots-observe/      # hand-authored (no .tmpl) — edit SKILL.md directly
│   └── boots-upgrade/      # upgrade flow the preamble triggers on UPGRADE_AVAILABLE
├── hosts/                  # SEAM: one typed config per AI host — add a host = one file here
│   ├── claude.ts           #   primary/default host
│   ├── codex.ts            #   external host (frontmatter denylist + path rewrites)
│   └── index.ts            #   registry: import + append to ALL_HOST_CONFIGS
├── scripts/                # the template engine (lean port of gstack's gen-skill-docs)
│   ├── gen-skill-docs.ts   #   read .tmpl → resolve {{TOKENS}} → host transforms → write .md
│   ├── discover-skills.ts  #   finds every SKILL.md.tmpl under .claude/skills
│   ├── host-config.ts      #   HostConfig interface the hosts/ files implement
│   └── resolvers/          #   each {{TOKEN}} → a generator function
│       ├── index.ts        #     RESOLVERS map (PREAMBLE, FUNNEL_*, BIN_DIR, SKILL_DIR, SYSTEMS_DIR)
│       ├── preamble.ts     #     {{PREAMBLE}} — the universal block injected into every skill
│       ├── funnel.ts       #     {{FUNNEL_EMIT}} / {{FUNNEL_ROLLUP}} — Layer A telemetry hooks
│       └── types.ts        #     TemplateContext + HOST_PATHS (path seam, defined once)
├── migrations/             # v<version>.sh — idempotent on-disk migrations (none yet; README only)
├── supabase/               # optional telemetry backend (functions + migrations); off by default
├── docs/                   # design docs (systems-home-global, first-run-experience, ...)
├── setup                   # symlink boots* skills into the host's skills dir; regen if bun present
├── README.md               # product framing (read before changing skill prose)
├── SKILLS-CHANGELOG.md     # generated from git history by the skills-changelog skill
└── VERSION                 # single monotonic version; gates migrations
```

Not in the repo (gitignored runtime state, created by running Boots): `~/.boots/`
holds every user's real state — `systems/<slug>/` records, `sessions/`, `analytics/`,
`config.yaml`. This dev clone may accumulate its own `analytics/`, `sessions/`,
`systems/`, `config.yaml`, `.activated` at the top level from being run in place;
those are local artifacts, never part of the product. See "The pipeline" below for
why systems live in a global home rather than per-repo.

## The critical workflow rule: edit templates, not generated files

Every stage skill has two files: `SKILL.md.tmpl` (source) and `SKILL.md` (generated,
committed, carries an `AUTO-GENERATED — do not edit directly` header). A small template
engine expands `{{PLACEHOLDER}}` tokens in the `.tmpl` into the `.md`.

- **Edit `SKILL.md.tmpl`, then regenerate.** Editing `SKILL.md` directly gets overwritten
  and fails the freshness gate.
- Regenerate: `bun run gen:skill-docs`  (requires [bun](https://bun.sh); TypeScript, no build step)
- Check freshness (CI/pre-commit gate, no writes): `bun run gen:skill-docs:check`
- **Commit both** the `.tmpl` and its regenerated `.md` together.
- Enable the pre-commit freshness gate once per clone: `git config core.hooksPath .githooks`

Skills without a `.tmpl` (e.g. `boots-observe`) are hand-authored `SKILL.md` files — those
you edit directly. The private/personal skills (`ad-repurposer`, `reply-guard`,
`oro-reel-scout`, `interview-*`, `pc-feedback-backlog`, `skills-changelog`) are the
author's own built systems, **not** part of the Boots product — leave them out of
product-facing changes.

## The template engine (`scripts/`)

- `scripts/gen-skill-docs.ts` — the pipeline: read `.tmpl` → resolve `{{PLACEHOLDERS}}` →
  apply host frontmatter/path transforms → write `SKILL.md` (+ metadata sidecar for
  external hosts). `--dry-run` is the freshness gate; `--host <claude|codex|all>` targets a host.
- `scripts/resolvers/` — each `{{TOKEN}}` maps to a generator in `resolvers/index.ts`:
  - `{{PREAMBLE}}` — the universal block injected into every skill (see below).
  - `{{FUNNEL_EMIT:to[:event]}}` — the "record the move" instruction a stage runs when it
    advances a system through the pipeline (Layer A telemetry).
  - `{{FUNNEL_ROLLUP}}` — the read-side instruction board skills run to fold flow/staleness in.
  - `{{BIN_DIR}}` — host-appropriate path to `boots/bin/`.
- `hosts/` — per-host config (`claude.ts` is default/primary, `codex.ts` for external).
  Host config drives frontmatter mode (allow/denylist), path rewrites, and metadata gen.
  **This is the seam for supporting more AI tools:** add a host by creating `hosts/<name>.ts`
  and appending it to `hosts/index.ts` — one source `.tmpl` then generates that host's skills.

This engine is a lean port of a larger system ("gstack") — comments reference gstack for
provenance; add resolvers/host features only when a real skill needs them.

## The pipeline and how skills relate

A system moves through stages, each a skill, each reading/writing one state file:

```
clarify → scope → build → review → verify → ship        (review→verify→ship = "the closer")
cross-cutting, any time: prospect · track · surface · extract · retire · observe
```

- `boots` is the **router** — reconciles every system's recorded state against what's
  actually on disk (reality wins over stale notes), then gives the single next step.
- State lives in the global Boots home at `~/.boots/systems/<slug>/system.md` (header
  fields + `## now` pickup block + `## log`), plus a `sessions/` folder — **not per-repo.**
  A system is the user's work and must be findable from any directory, so its records have
  one stable home regardless of where the user is standing. The path is defined once via
  the `{{SYSTEMS_DIR}}` resolver token (skills) and `${BOOTS_HOME:-$HOME/.boots}/systems`
  (bin scripts); see `docs/systems-home-global.md`. The user reviews systems *through the
  agent* (the router's talk rule 10), never by browsing the hidden home. (This dev repo's
  own `state/` still holds the author's legacy systems, gitignored, pending migration.)
- **Form palettes** live in `.claude/skills/boots/forms/<platform>.md` (`claude-code.md` is
  the only one today; more platforms are drop-in — see `forms/README.md` for the section
  contract). A system's `platform:` field picks its palette; the palette defines the
  buildable forms, how to verify each, and what "shipped" means per form. Keep
  platform-specific mechanics in the palette; keep platform-independent judgment in skills.
  This split is the other half of multi-host support: a new platform is one new palette
  file, not a rewrite of the pipeline.

## Runtime plumbing (`.claude/skills/boots/bin/`)

Shell scripts the preamble and stages call silently. Global state lives under `~/.boots/`
(never in-repo). Telemetry is **off by default** and reads only local files.

- `boots-update-check` — silent version check via each preamble; prints `UPGRADE_AVAILABLE`
  / `JUST_UPGRADED` or nothing. Derives the upstream from the clone's own `origin` (Boots
  has no single canonical repo), so it is dormant until pushed to a remote. Failure mode is
  silence — a bad network never wedges a skill.
- `boots-config` — get/set config (telemetry tier, proactive, update_check kill switch).
- `boots-event` — appends a funnel transition (Layer A: systems moving through stages).
- `boots-analytics` — rolls funnel history into a board (`--brief`); counts per stage,
  shipped/stalled/abandoned, days-cold per system.
- `boots-telemetry-log` — ops run event (Layer B: which skill ran, duration, outcome).

`migrations/v<version>.sh` — idempotent, gated by `~/.boots/.last-setup-version`; run by
`setup` and `boots-upgrade` when upgrading across the version in `VERSION`. See
`migrations/README.md`. None exist yet (`schema_version` is 1).

## Install / upgrade

- `./setup` (global, symlinks `boots*` skills into `~/.claude/skills`) · `./setup --project`
  (into `./.claude/skills`) · `./setup --uninstall`. Symlinks mean `git pull` upgrades every
  install at once. `setup` regenerates skills from templates if bun is present, else installs
  committed `.md` as-is.

## Committing safely: the skills allow-list

This is an **open-source repo you also iterate in**, so `.gitignore` is deny-by-default
where private data could leak:

- **`.claude/skills/` is an explicit allow-list.** `/.claude/skills/*` ignores every
  skill dir; each product skill is un-ignored with its own `!/.claude/skills/<name>/`
  line. A newly created skill dir — private experiment, client work, half-baked idea —
  is **invisible to git until you add its `!` line**, so nothing private is committable
  by accident (verified: even `git add -A` cannot stage an unlisted skill). The friction
  is the point: tracking is opt-in, so the only failure mode is "forgot to publish a
  public skill" (harmless, obvious on the next `git status`), never the reverse. **When
  you ship a new product skill, add one `!` line for it.** This is deliberately an
  explicit list, not a `boots*/` glob — a glob would silently auto-commit a
  `boots-clientwork` dir; the list makes every publish a conscious act.
- **Local-clone runtime state is ignored.** Running Boots in this repo in place creates
  top-level `.activated`, `.consent-prompted`, `.last-setup-version`, `analytics/`,
  `config.yaml`, `installation-id`, `sessions/`, and `systems/` — the same artifacts
  `~/.boots/` holds per-user. They are NOT part of the product (`systems/` in particular
  holds private work) and are all gitignored. `CLAUDE.md` and `IDEAS.md` are the tracked
  contributor docs.
- The same deny-by-default pattern is the tool to reach for if you add any other
  top-level dir that mixes public and private.

## Conventions

- **Boots is open source: keep the `boots-*` skills generic.** Never bake private data
  (real names, the author's own systems, addresses, brand specifics) into skill prose or
  templates — a user's systems live in their own `~/.boots/systems/` home, never in the
  product. See the two-layer separation: product = `boots-*` skills; the author's own
  systems = other skill dirs + this repo's gitignored `state/` (legacy, pre-migration).
- Voice/talk rules for anything a user reads are defined in `boots/SKILL.md` ("How Boots
  talks", the translation table). Internal stage vocabulary is banned from user-facing chat;
  match that register when writing skill prose.
- `SKILLS-CHANGELOG.md` is generated from git history by the `skills-changelog` skill, not
  hand-written.
