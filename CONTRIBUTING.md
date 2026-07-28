# Contributing to Boots

Thanks for being here. Boots is a suite of **skills** — prose that tells an agent how to
behave — running today on Claude Code and Claude Cowork. There's no server and no runtime.
That makes it unusually easy to contribute to and unusually easy to break in subtle ways,
so this guide is mostly about the few rules that aren't obvious.

## Get set up

```bash
git clone https://github.com/Fourday-AI/boots.git ~/.claude/skills/.boots
cd ~/.claude/skills/.boots
git config core.hooksPath .githooks      # do this once — see "the freshness gate"
./setup                                  # symlink the skills alongside the clone
```

You'll want [bun](https://bun.sh) — it runs the generator and the tests. There is no
compile step and no dependencies to install beyond bun itself.

```bash
bun run gen:skill-docs        # regenerate every SKILL.md from its template
bun run gen:skill-docs:check  # freshness check, writes nothing
bun run test                  # end-to-end suite, offline and CI-safe
bun run test:live             # the above, plus real network checks
```

## The one rule that will bite you: edit templates, not skills

Every skill is **two files**:

```
boots-scope/SKILL.md.tmpl   ← the source. Edit this.
boots-scope/SKILL.md        ← generated, committed, DO NOT EDIT.
```

The generated file carries an `AUTO-GENERATED — do not edit directly` header. If you
edit it, your change is silently erased the next time anyone regenerates, and the
pre-commit gate will reject the commit anyway.

So: **edit the `.tmpl`, run `bun run gen:skill-docs`, and commit both files together.**

Every skill in the suite currently has a `.tmpl`. If one ever doesn't, it's
hand-authored and you edit its `SKILL.md` directly — so check before you start typing.

### The freshness gate

`.githooks/pre-commit` refuses any commit where a generated `SKILL.md` doesn't match
its template. Enable it once per clone with `git config core.hooksPath .githooks`. CI
runs the same check, so a stale file fails the PR either way — the hook just tells you
sooner. (It no-ops if you don't have bun, so a bun-less contributor can still commit;
they just can't regenerate.)

### The second rule: rebuild the published bundle

`dist/cowork/` is **committed build output**, which is unusual and deliberate: it is the
plugin Cowork users actually install. `.claude-plugin/marketplace.json` points at it, so
**pushing to `main` is the release** — there is no separate publish step to catch a
mistake later.

So if you change anything the bundle carries — a `.tmpl`, a `boots/forms/` palette, a
`boots/bin/` script, a `boots/reference/` doc — rebuild and commit `dist/` in the same
commit:

```bash
bun run build:cowork        # regenerate the plugin bundle
bun run check:marketplace   # validate the catalog users install from
```

The pre-commit hook and CI both rebuild and fail if what's committed differs, so you
can't ship a stale bundle by accident — but knowing why saves you a confusing rejection.

One thing that looks like an oversight and isn't: **the bundle carries no `version`, on
purpose.** Claude Code falls back to the git commit SHA, which makes every push a new
version that reaches installed copies automatically. Adding a version string would *pin*
the plugin and silently stop users receiving updates, so both build scripts treat a
present version as an error.

## How the repo is laid out

```
boots/              the router, plus shared assets for the whole suite
  bin/              shell scripts the skills call silently
  forms/            platform palettes (see below)
boots-clarify/      one top-level directory per skill — the product IS the
boots-scope/        front page of the repo
boots-build/  …
hosts/              per-AI-tool config (see below)
scripts/            the template engine + the test suite
supabase/           optional telemetry backend, off by default
docs/               design notes
.claude-plugin/     marketplace.json — the catalog users install Boots from
dist/cowork/        the built plugin, committed because it IS what users install
```

`CLAUDE.md` has the fuller map and is worth reading before a substantial change.

### Two seams to respect

Boots is built to run on more than one AI tool, and to build more than one kind of
thing. Two seams carry that, and both are load-bearing:

- **`hosts/`** — one typed config per AI host. Adding support for a new tool should be
  *one new file* plus a line in `hosts/index.ts`, never a rewrite of the skills.
- **`boots/forms/`** — one palette per platform, defining what you can
  build there, how to verify it, and what "shipped" means. Adding a platform should be
  *one new palette file*.

So: keep host- and platform-specific mechanics behind those seams, and keep the skills
themselves about judgment. If you find yourself writing "if Claude Code..." inside a
stage skill, that logic belongs in a host config or a form palette.

### One more structural rule

Every **pipeline** stage takes one system and moves it one step **forward**. That's
deliberate. `boots-rethink` is the single exception — the only skill that looks at
every system at once, that may go backwards (merge, kill, reopen), and that may
disagree with the user. Please keep that property intact: don't teach a forward stage
to restructure things behind the user's back, and don't make rethink perform the
surgery itself — it decides, then hands off.

## Writing skill prose

This is most of what contributing to Boots actually is.

- **Read `boots/SKILL.md` first**, especially "How Boots talks". It defines the voice
  and a translation table from internal stage vocabulary to what a user should
  actually read. Internal words (`artifact`, `funnel`, `transition`) are banned from
  user-facing chat. Match that register.
- **Keep it generic.** This is open source. Never bake in real names, companies,
  addresses, or your own systems. A user's work lives in their `~/.boots/`, never in
  the product.
- **Be concrete about behavior, not verbose about principle.** A skill is instructions
  to an agent. "Ask for the one example that would prove it wrong" beats a paragraph
  about the importance of falsifiability.

## Committing safely

`.gitignore` is **deny-by-default** for directories. `/*/` ignores every top-level
directory and each product skill (plus the handful of repo directories) is un-ignored
with its own `!` line. A new directory is invisible to git until you add that line —
not even `git add -A` can stage it.

This is intentional: it means a private experiment or client work can never be
committed by accident. The cost is that **when you add a new product skill you must add
its `!` line**, or it silently won't ship. That failure is harmless and obvious on the
next `git status`; the reverse would not be.

Please also don't commit anything from `~/.boots/` runtime state — `systems/`,
`sessions/`, `analytics/`, `config.yaml`. They're all gitignored already; just don't
fight it.

## Opening a pull request

1. Branch off `main`.
2. Make the change in the `.tmpl`, regenerate, commit both.
3. Run `bun run test`.
4. Describe **what a user will notice**, not what you refactored. If a skill's behavior
   changed, say what it does now that it didn't before.

Small PRs are much easier to accept than large ones. If you're planning something big —
a new stage, a new host, a new platform palette — open an issue first so we can talk
about where it fits.

## Reporting a security issue

Please don't open a public issue. Email <henry@fourday.ai> instead.

## License

By contributing you agree that your contributions are licensed under the
[MIT License](LICENSE).
