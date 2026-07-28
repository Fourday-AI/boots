# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Boots is an **open-source suite of skills** that helps people *finish* the AI systems they
start. If the AI tool is the builder, Boots is the finisher. The deliverable is the
`boots-*` skills at the top level of this repo, not any application code — there is no server, no
runtime, no build output. Users install by symlinking the skills into their tool's skills
dir (`./setup`) and pasting a `## Boots` block into their instructions file.

**Claude Code is the first host, not the only one.** Boots is built to run on more AI
coding tools over time — the two seams that make this possible are load-bearing and should
be respected in every change: (1) the multi-host template engine (`hosts/`), which
generates host-specific skill files from one source template, and (2) the platform-scoped
form palettes (`forms/`), which keep "what you can build" separate from "how the pipeline
thinks". Do not hardcode Claude-Code-only assumptions into skill judgment; put anything
host- or platform-specific behind those two seams.

Read `README.md` for the product framing and `boots/SKILL.md` for the full
behavioral contract (the router). Both are worth reading before changing skill prose.

## Project structure

The map. Two seams do the heavy lifting — `hosts/` (multi-host) and `forms/`
(multi-platform); everything else is skills, the engine that generates them, and the
runtime plumbing they call.

```
boots/
├── boots/                  # THE PRODUCT starts here — each skill is a TOP-LEVEL dir,
│   │                       #   so the repo's GitHub front page IS the list of skills.
│   ├── SKILL.md.tmpl       #   the router + all shared assets for the suite
│   ├── SKILL.md            #   generated (committed, AUTO-GENERATED header; don't edit)
│   ├── bin/                #   shell plumbing the preamble + stages call silently
│   ├── forms/              #   SEAM: platform palettes (claude-code.md today; one file per platform)
│   └── examples/           #   bundled resources skills read (e.g. finished-system.md)
├── boots-clarify/          # one dir per stage skill — .tmpl + generated .md each
├── boots-scope/            #   pipeline: clarify → scope → build → review → verify → ship
├── boots-build/
├── boots-review/
├── boots-verify/
├── boots-ship/
├── boots-prospect/         # cross-cutting skills (any time): prospect · track · surface ·
├── boots-track/            #   rethink · extract · retire · observe
├── boots-surface/
├── boots-rethink/          # the cross-SYSTEM step: reads every system + ~/.boots/map.md,
│                           #   names what they add up to, proposes merges/kills/missing
│                           #   pieces. Only step that goes backwards or disagrees.
├── boots-extract/
├── boots-retire/
├── boots-observe/
├── boots-upgrade/          # upgrade flow the preamble triggers on UPGRADE_AVAILABLE
├── hosts/                  # SEAM: one typed config per AI host — add a host = one file here
│   ├── claude.ts           #   primary/default host
│   ├── codex.ts            #   external host (frontmatter denylist + path rewrites)
│   └── index.ts            #   registry: import + append to ALL_HOST_CONFIGS
├── scripts/                # the template engine (ported from a larger internal tool)
│   ├── gen-skill-docs.ts   #   read .tmpl → resolve {{TOKENS}} → host transforms → write .md
│   ├── discover-skills.ts  #   finds every SKILL.md.tmpl in a top-level skill dir
│   ├── host-config.ts      #   HostConfig interface the hosts/ files implement
│   ├── test-e2e.sh         #   end-to-end tests: `bun run test` (offline, CI-safe) ·
│   │                       #   `bun run test:live` (+ GitHub upgrade + real ingest/pulse)
│   ├── test-install.sh     #   `test:install` — clean-room: cold HOME, clone, setup, uninstall
│   ├── test-lifecycle.sh   #   `test:lifecycle` — cold HOME + throwaway git upstream:
│   │                       #     install → funnel → upgrade → uninstall. Guards the
│   │                       #     repo-root walk in bin/, whose failure mode is SILENCE.
│   ├── test-session.sh     #   `test:session` — the only paid, manually-run check:
│   │                       #     real `claude -p` sessions prove Claude Code discovers
│   │                       #     and routes the skills. Needs a login; --dry-run is free.
│   └── resolvers/          #   each {{TOKEN}} → a generator function
│       ├── index.ts        #     RESOLVERS map (PREAMBLE, FUNNEL_*, BIN_DIR, SKILL_DIR, SYSTEMS_DIR)
│       ├── preamble.ts     #     {{PREAMBLE}} — the universal block injected into every skill
│       ├── funnel.ts       #     {{FUNNEL_EMIT}} / {{FUNNEL_ROLLUP}} — Layer A telemetry hooks
│       └── types.ts        #     TemplateContext + HOST_PATHS (path seam, defined once)
├── .claude-plugin/         # PUBLISH SEAM: marketplace.json — the catalog Claude Code
│                           #   reads for `/plugin marketplace add Fourday-AI/boots`.
│                           #   Points at ./dist/cowork. Validated by check:marketplace.
├── dist/cowork/            # COMMITTED build output — the plugin users actually install.
│                           #   Regenerate with `bun run build:cowork`; never hand-edit.
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

All 15 product skills currently have a `.tmpl`. Should one ever not, it is hand-authored
and you edit its `SKILL.md` directly — so check before editing.

Any top-level dir that is **not** on the `.gitignore` allow-list is
the author's own private work, not part of the Boots product. Leave those out of
product-facing changes, and never name them in anything published (README, changelog,
skill prose). The allow-list is the only list; don't keep a second copy here:

```bash
grep -oE '^!/boots[a-z-]*/' .gitignore | sed 's|^!/||;s|/$||'
```

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
  - `{{MAP_FILE}}` / `{{BOOTS_HOME}}` — the cross-system record (`~/.boots/map.md`) and its
    parent. Same path-seam discipline as `{{SYSTEMS_DIR}}`: defined once in `resolvers/types.ts`.
- `hosts/` — per-host config (`claude.ts` is default/primary, `codex.ts` for external).
  Host config drives frontmatter mode (allow/denylist), path rewrites, and metadata gen.
  **This is the seam for supporting more AI tools:** add a host by creating `hosts/<name>.ts`
  and appending it to `hosts/index.ts` — one source `.tmpl` then generates that host's skills.

This engine is a lean port of a larger internal system; it deliberately ships less than
its ancestor. Add resolvers/host features only when a real skill needs them.

## The pipeline and how skills relate

A system moves through stages, each a skill, each reading/writing one state file:

```
clarify → scope → build → review → verify → ship        (review→verify→ship = "the closer")
cross-cutting, any time: prospect · track · surface · rethink · extract · retire · observe
```

- `boots` is the **router** — reconciles every system's recorded state against what's
  actually on disk (reality wins over stale notes), then gives the single next step.
- **Every pipeline stage takes ONE system and moves it ONE step FORWARD.** That is
  deliberate, and it is also the suite's structural blind spot: a forward, single-system
  pipeline can never ask *"are these the right things, and what do they add up to?"* —
  so a user can assemble half a machine one system at a time and never be told what the
  machine is. `boots-rethink` is the answer to that, and the only skill that (a) takes
  every system as its subject, (b) may go backwards (merge, kill, re-open a settled
  decision), and (c) may disagree with the user's plan. If you add a skill, keep this
  property intact: don't teach a forward stage to restructure the set behind the user's
  back, and don't make rethink do the surgery itself — it decides, then hands to
  `boots-retire` / `boots-track` / `boots-scope`. **One written exception: the merge.**
  Rethink performs that one itself (step 7) — it creates the child system the parents add
  up to, with `born_from:` on the child and `evolved_into:` on each parent. The exception
  exists because deciding what the child IS *is* the surgery: the same judgment that says
  "these two are one thing" writes the child's question, and splitting that across two
  skills is what left the move unbuilt long enough for two accepted merge proposals to sit
  unexecuted on the map. Keep it narrow — rethink creates the child and writes the
  ancestry; retiring a parent is still `boots-retire`'s. Do not let a second exception in
  without the same standard of argument.
- **Three fields carry the cross-system view, and they are easy to conflate:**
  `target:` = what *done* looks like (proof this system works). `question:` = *why it
  exists* — what the user needs to find out, or the decision its output feeds. Only
  `question:` makes systems comparable by purpose; without it the only thing two systems
  share is plumbing ("both read Gmail"), which yields true-but-shallow findings. Above
  both sits `~/.boots/map.md` (**the map**): Boots' standing guess at what the user is
  actually building, the questions in play, which systems serve each, and a proposals
  list that *keeps declined items* so a rejected idea never returns as if it were new.
  The map lives above `systems/` because a question outlives the systems that serve it —
  shipping a system does not answer the question that caused it.
- State lives in the global Boots home at `~/.boots/systems/<slug>/system.md` (header
  fields + `## now` pickup block + `## log`), plus a `sessions/` folder — **not per-repo.**
  A system is the user's work and must be findable from any directory, so its records have
  one stable home regardless of where the user is standing. The path is defined once via
  the `{{SYSTEMS_DIR}}` resolver token (skills) and `${BOOTS_HOME:-$HOME/.boots}/systems`
  (bin scripts); see `docs/systems-home-global.md`. The user reviews systems *through the
  agent* (the router's talk rule 10), never by browsing the hidden home. (This dev repo's
  own `state/` still holds the author's legacy systems, gitignored, pending migration.)
- **Form palettes** live in `boots/forms/<platform>.md` (`claude-code.md` is
  the only one today; more platforms are drop-in — see `forms/README.md` for the section
  contract). A system's `platform:` field picks its palette; the palette defines the
  buildable forms, how to verify each, and what "shipped" means per form. Keep
  platform-specific mechanics in the palette; keep platform-independent judgment in skills.
  This split is the other half of multi-host support: a new platform is one new palette
  file, not a rewrite of the pipeline.

## Runtime plumbing (`boots/bin/`)

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
  Also finalizes a crashed session's stale `.pending-*` marker as `outcome:unknown`,
  then fires `boots-telemetry-sync` in the background.
- `boots-telemetry-sync` — the only script that talks to the network. Applies the
  privacy transform (strip `_repo`, salted-hash the system slug, drop the install id on
  the `anonymous` tier), then POSTs to the `telemetry-ingest` edge function — never the
  DB directly. Exits immediately when telemetry is `off` or no backend URL is set.
- `boots-migrate-systems` — brings legacy per-repo `state/systems/` records into the
  global `~/.boots/systems/` home. Copies (never moves), skips slugs already present,
  `--dry-run` available. Lazy and repo-aware: the router offers it per repo, because
  old state had no single location to migrate from.

`migrations/v<version>.sh` — idempotent, gated by `~/.boots/.last-setup-version`; run by
`setup` and `boots-upgrade` when upgrading across the version in `VERSION`. See
`migrations/README.md`. None exist yet (`schema_version` is 1) — the systems-home move
is handled by `boots-migrate-systems`, not a numbered migration.

## Publishing: this repo is its own plugin marketplace

Claude Code installs Boots by cloning (see below). **Cowork installs it as a plugin**, and
this repo is the marketplace it installs from — a user adds
`https://github.com/Fourday-AI/boots` and gets `boots@fourday`. Three facts make that work,
and each one inverts a normal convention, so none of them are safe to "clean up":

- **`dist/cowork/` is committed.** It is not incidental build output, it is the artifact
  users install — `.claude-plugin/marketplace.json` points at it, so **`git push` is the
  release**. Keeping it out of git is exactly what let a hand-made Cowork snapshot drift
  for weeks with nothing to diff it against. `.gitignore` allows `dist/cowork/` through
  and nothing else under `dist/`; the `!/dist/` line before `/dist/*` is load-bearing
  (git cannot re-include a file whose parent directory is excluded, and `/*/` excludes
  `dist/`).
- **Neither `plugin.json` nor the marketplace entry carries a `version`, on purpose.**
  Claude Code resolves a plugin's version from `plugin.json` → the marketplace entry →
  the **git commit SHA**, and skips the update when the resolved version matches what a
  user already has. A version string therefore *pins* the plugin: every fix pushed after
  a user's first install would be invisible until somebody remembered to bump `VERSION`.
  Omitting it makes every commit a new version, so users cannot silently fall behind.
  Both build-plugin.ts and check-marketplace.ts treat a *present* version as the error.
- **Freshness is gated, not trusted.** CI and `.githooks/pre-commit` both rebuild the
  bundle and fail if the committed one differs (`bun run build:cowork` then
  `git diff -- dist/`), plus `bun run check:marketplace` on the catalog. Editing a
  `.tmpl`, a `forms/` palette, a `bin/` script or `reference/` doc means rebuilding and
  committing `dist/` in the same commit — the same discipline as `.tmpl` → `SKILL.md`.

`VERSION` still ships inside the bundle so an install can say which release it came from.
It is informational; it is not the update key.

## Install / upgrade

The documented install clones the repo **into Claude Code's skills dir**, at
`~/.claude/skills/.boots`, so `git clone && ./setup` is the whole install:

```bash
git clone --depth 1 <url> ~/.claude/skills/.boots && ~/.claude/skills/.boots/setup
```

**The leading dot is load-bearing, not cosmetic.** Claude Code skips dot-directories
when discovering skills, so the repo is never mistaken for a skill. Without it two
things break, both verified against gstack (which clones to a visible
`~/.claude/skills/gstack`): (1) the clone dir would collide with the `boots/` skill's
own install path, and (2) Claude Code omits the repo-shaped dir from the skill list,
so the router would need an alias dir — and frontmatter `name:` does **not** override
a directory name, so the alias surfaces under its directory name (gstack's `/gstack`
shows up as `_gstack-command`). Boots cannot afford that: `boots` is the word users
type. Don't "simplify" the dot away.

- `./setup` symlinks each top-level `boots*` dir **whole** (so `bin/`, `forms/` and
  `examples/` come with it) into the skills dir. When the repo sits inside a dir named
  `skills`, it installs as siblings there; otherwise it falls back to `~/.claude/skills`,
  which is what keeps a dev checkout anywhere (e.g. `~/.boots`) working.
- `./setup --project` installs into `./.claude/skills` · `./setup --uninstall` removes
  only symlinks it created. Symlinks mean `git pull` upgrades every install at once.
  `setup` regenerates skills from templates if bun is present, else installs committed
  `.md` as-is.
- **`~/.boots/` is the runtime home, not the clone.** Systems, config and analytics live
  there and survive deleting or re-cloning the repo. Keep the two ideas distinct.

## Committing safely: the top-level allow-list

This is an **open-source repo you also iterate in**, so `.gitignore` is deny-by-default
where private data could leak:

- **Every top-level directory is an explicit allow-list.** `/*/` ignores all of them;
  each product skill and each repo directory is un-ignored with its own `!/<name>/`
  line. A newly created dir — private experiment, client work, half-baked idea — is
  **invisible to git until you add its `!` line**, so nothing private is committable by
  accident (verified: even `git add -A` cannot stage an unlisted dir). The friction is
  the point: tracking is opt-in, so the only failure mode is "forgot to publish a public
  skill" (harmless, obvious on the next `git status`), never the reverse. **When you
  ship a new product skill, add one `!` line for it.** This is deliberately an explicit
  list, not a `boots*/` glob — a glob would silently auto-commit a `boots-clientwork`
  dir; the list makes every publish a conscious act. `/*/` matches directories only, so
  top-level files (`README.md`, `VERSION`, `setup`) are unaffected.
- **`.claude/skills/` is now the author's own private work**, not the product. It is
  re-ignored after `!/.claude/` (which exists only to track `settings.json`).
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
