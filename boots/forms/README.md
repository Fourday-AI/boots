# Boots form palettes (per platform)

Boots builds AI systems, and the *forms* a system can take depend on the platform
it runs on. Claude Code offers skills, subagents, hooks, MCP servers, Agent SDK
apps. Another platform offers a different set. So the palette is platform-scoped:
one file per platform in this directory.

## Files

- `claude-code.md` — terminal agents with a shell and a disk. Default for Claude
  Code and Codex.
- `cowork.md` — Cowork. Adds the forms a terminal has no equivalent for: work that
  runs on a schedule with nobody watching, managed connections to the user's apps,
  persisted pages.
- (future) `cursor.md`, `<platform>.md` — drop-in, same shape.

Note that palettes are keyed by **platform**, not by host: Claude Code and Codex
are two hosts sharing one palette, because they are the same kind of machine. A
new palette is warranted only when the runtime can build *different things* — not
when it merely installs skills somewhere else.

## How a system picks its palette

Every system file carries a `platform:` field, set at scope alongside the form.
Each stage skill reads the palette for that platform, from the `forms/` folder
next to the `boots` skill's own `SKILL.md`. The skills are generated with that
path already filled in, so a stage never has to work it out.

If a system has no `platform:` line, use the running host's default — declared as
`platform.palette` in `hosts/<host>.ts`, and written into every generated skill.

## The section contract (what every platform file must have)

To add a platform, copy `claude-code.md`'s shape and fill it for that platform. A
palette file must contain these sections, so the stage skills can rely on them:

1. **A `Platform: <slug>` header line** naming the platform.
2. **The forms table** — columns: `Form | It is | Lives at | Reach for it when`.
   The forms themselves are platform-specific; only the table shape is fixed.
3. **How to choose** — mapping the *nature of the work* (synthesis, deterministic
   transform, event-triggered, new capability, unattended, durable context) to
   that platform's forms. The left side (nature of work) is constant across
   platforms; the right side (the form) is what changes.
4. **How to verify each form** — the real check per form. Never assume `exits 0`.
5. **What "shipped" means per form** — present and live, not just present.
6. **Plain English on this platform** — a translation table for THIS platform's
   form names: what each is called internally and what to say to the user
   instead. `boots/SKILL.md` carries only the platform-independent rows (the
   pipeline's own vocabulary); every form-specific row belongs here, because the
   forms are what differ. This section is what keeps Cowork words like "scheduled
   task" and "connector" out of the shared skill bodies.
7. **A syntax-drift note** — where to get current exact syntax at build time.

Keep platform-specific mechanics (where a form lives, how to build/verify it) in
the platform file. Keep platform-independent judgment (the ten moves, the closer,
choosing by nature of work) in the skills. That split is what makes adding a
platform a matter of writing one file here, not touching the pipeline.
