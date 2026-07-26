# Boots form palettes (per platform)

Boots builds AI systems, and the *forms* a system can take depend on the platform
it runs on. Claude Code offers skills, subagents, hooks, MCP servers, Agent SDK
apps. Another platform offers a different set. So the palette is platform-scoped:
one file per platform in this directory.

## Files

- `claude-code.md` — the palette Boots targets today. **Default.**
- (future) `cursor.md`, `cowork.md`, `<platform>.md` — drop-in, same shape.

## How a system picks its palette

Every system file carries a `platform:` field (default `claude-code`), set at
scope alongside the form. Each stage skill reads the palette for that platform:

```
~/.claude/skills/boots/forms/<platform>.md
```

If a system has no `platform:` line, use `claude-code.md`.

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
6. **A syntax-drift note** — where to get current exact syntax at build time.

Keep platform-specific mechanics (where a form lives, how to build/verify it) in
the platform file. Keep platform-independent judgment (the ten moves, the closer,
choosing by nature of work) in the skills. That split is what makes adding a
platform a matter of writing one file here, not touching the pipeline.
