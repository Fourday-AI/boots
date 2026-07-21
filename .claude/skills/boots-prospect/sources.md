# Boots prospect — source adapters

An **adapter** teaches prospect how to read one place latent work hides and turn
what it finds into a candidate opportunity. This file is the pluggable list: to
support a new backend you add an adapter here, you never edit `SKILL.md`. Every
adapter is **read-only**.

## The opportunity shape (what every adapter emits)

Each raw hit an adapter finds becomes one candidate in this common shape, so the
skill can merge and rank across sources:

```
what:   one plain line — the thing that could be built or finished
source: which adapter + a concrete pointer (a quote, a file path, a record id)
why:    the value if it were finished / why it keeps coming up
next:   boots-clarify (still fuzzy) | boots-track or boots-scope (already clear)
```

## The adapter contract (what each adapter specifies)

- **detect:** a path test or command that proves the source is present on this
  machine. Cheap, read-only, no auth. If it fails, the source is absent — skip it.
- **read:** how to pull candidate items once detected. Read-only.
- **shape:** how a raw item maps into the opportunity shape above.
- **notes:** cost, gotchas, or "reach limits" (e.g. server-side only).

---

## Shipped adapters (v1)

### state-systems — the dedupe filter (not a source of new work)
- **detect:** `ls state/systems/*/system.md 2>/dev/null`
- **read:** read each `system.md`'s slug + foundation.
- **shape:** not a source — this is the **exclusion set**. Any candidate that
  matches a tracked system is dropped. Prospect surfaces *untracked* work only.

### claude-memory — the user's own captured threads
- **detect:** `ls ~/.claude/projects/*/memory/MEMORY.md 2>/dev/null`
- **read:** read `MEMORY.md` (the index) and any `metadata: type: project` files;
  look for wants, half-done work, "meaning to build X" notes.
- **shape:** `what` = the ambition in the note; `source` = the memory file + line;
  `why` = why it was worth remembering; `next` = usually clarify.

### loose-ends toolkit — an optional graveyard backend
- **detect:** `PY=.venv/bin/python; [ -x "$PY" ] || PY=python3; $PY -m toolkit records summary 2>/dev/null`
- **read:** `$PY -m toolkit records summary`, then `$PY -m toolkit records show <id>`
  for any that look live. All guarded with `2>/dev/null || true` — absent = skip.
- **shape:** `what` = the record's intent; `source` = `toolkit` + record `id`
  (carry the id — it lets the closer reuse that backend's verify/status);
  `why` = why it was logged; `next` = track (it already has a home).

### repo-signals — unfinished intent sitting in the current repo
- **detect:** you're in a git repo (`git rev-parse --show-toplevel 2>/dev/null`).
- **read:** `TODO`/`FIXME`/`HACK` markers, stale branches (`git branch --sort=-committerdate`),
  `docs/` notes that name a follow-up, draft/`.wip` files.
- **shape:** `what` = the deferred work; `source` = file:line or branch name;
  `why` = what it blocks; `next` = scope if clear, clarify if vague.

### user-recall — just ask
- **detect:** always available.
- **read:** ask the user, in their words: "what's the thing you keep meaning to
  build and never do?" Use only when the other sources are thin, or to confirm.
- **shape:** `what` = what they say; `source` = "you said"; `next` = clarify.

---

## Detected-but-unadapted AI tools (offer to learn)

Prospect fingerprints these so it can report them honestly ("you also use X, I
can't read it yet") and offer the supervised **learn a backend** flow in
`SKILL.md`. None has a reader yet — presence detection only. Add a full adapter
above once one is learned.

| Tool | detect (present if this exists) | reach note |
| --- | --- | --- |
| Cursor | `~/Library/Application Support/Cursor/` | chats in a SQLite `state.vscdb` under leveldb-style keys — learnable, local |
| ChatGPT desktop | `~/Library/Application Support/com.openai.chat/` | local store largely opaque/encrypted — spike before trusting |
| GitHub Copilot | `~/.vscode/extensions/github.copilot*` | little durable history locally — low yield |
| Aider | `~/.aider.chat.history.md`, `~/.aider*` | plain markdown history — easy, high yield if used |
| Continue | `~/.continue/` | local session json — learnable |
| Windsurf | `~/Library/Application Support/Windsurf/` | VS Code fork, similar to Cursor |
| Zed | `~/Library/Application Support/Zed/` | assistant threads local — learnable |
| gbrain / gstack | a `.gbrain` / gstack learnings store in the repo | may already expose a CLI — check before scraping |
| ChatGPT / Claude web | (no local file) | **server-side only** — out of reach without the user's login; report, don't build |

Adding to this table (a new tool to detect) is cheap — one row. Turning a row into
a real reader is the supervised **learn a backend** flow, and it ends with a new
adapter in "Shipped adapters" above.
