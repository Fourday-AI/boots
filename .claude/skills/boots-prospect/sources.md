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
- **detect:** `ls ~/.boots/systems/*/system.md 2>/dev/null`
- **read:** read each `system.md`'s slug + foundation.
- **shape:** not a source — this is the **exclusion set**. Any candidate that
  matches a tracked system is dropped. Prospect surfaces *untracked* work only.

### claude-memory — the user's own captured threads
- **detect:** `ls ~/.claude/projects/*/memory/MEMORY.md 2>/dev/null`
- **read:** read `MEMORY.md` (the index) and any `metadata: type: project` files;
  look for wants, half-done work, "meaning to build X" notes.
- **shape:** `what` = the ambition in the note; `source` = the memory file + line;
  `why` = why it was worth remembering; `next` = usually clarify.

### user-profile — who the person is (feeds the picture, not a candidate)
- **detect:** `ls ~/.claude/projects/*/memory/*.md 2>/dev/null` (same store as
  claude-memory; always co-present with it).
- **read:** read the `metadata: type: user` notes (e.g. a `user_*founder*.md`) plus
  the roles/assets/behaviors that recur across projects — what they ship, what they
  do by hand, what data and connections they already have wired.
- **shape:** **not a candidate source** — this builds the *working picture* the skill
  reflects back in step 1 and reasons from in step 4 (`profile-derived`). It never
  emits an opportunity by itself; it's the lens the other sources are read through.

### loose-ends store — an external graveyard, if the user keeps one
Some people already have a place where abandoned work goes to sit: a homegrown CLI,
an issue tracker label, a `graveyard.md`. There is no single one to detect, so this
adapter is **user-configured, not auto-detected** — nothing runs until the user has
told Boots what their store is and how to read it (the "learn a backend" flow below).

- **detect:** the store recorded in the user's Boots config. No config entry → no
  store → skip silently. Never guess at a command that might not exist.
- **read:** whatever list-then-show pair the store offers, always read-only and
  guarded with `2>/dev/null || true` so an absent or changed backend can't fail a run.
- **shape:** `what` = the record's intent; `source` = the store's name + the record's
  own id; `why` = why it was logged; `next` = track (it already has a home).
- **notes:** **carry the id.** It is the one thing that makes the round trip work — a
  store that offers its own verify or status commands lets the closer check the work
  deterministically and hand the result back, instead of Boots judging it alone.

### repo-signals — unfinished intent sitting in the current repo
- **detect:** you're in a git repo (`git rev-parse --show-toplevel 2>/dev/null`).
- **read:** `TODO`/`FIXME`/`HACK` markers, stale branches (`git branch --sort=-committerdate`),
  `docs/` notes that name a follow-up, draft/`.wip` files.
- **shape:** `what` = the deferred work; `source` = file:line or branch name;
  `why` = what it blocks; `next` = scope if clear, clarify if vague.

### profile-derived — grounded ideation from who they are (invents, doesn't excavate)
- **detect:** always available once the `user-profile` picture exists (step 1).
- **read:** reason from the picture — for each recurring pattern in what they do (a
  manual chore they repeat, a dataset/corpus they keep leveraging, a connection
  already wired, a responsibility of their role), ask: *what would this specific
  person obviously benefit from building that they haven't written down?* These are
  net-new ideas, not mined notes.
- **shape:** `what` = the inferred build; `source` = the **named pattern** it traces
  to (not a quote — e.g. "you run feedback outreach by hand and your Gmail is already
  wired"); `why` = the leverage if it existed; `next` = usually clarify.
- **notes:** the anti-slop bar is the whole point. Every item **must** trace to an
  evidenced pattern in *this* person's work. Generic role advice ("a founder should
  build a CRM / a chatbot / a dashboard") is banned — if you can't name the specific
  pattern it falls out of, cut it. Grounded inference, never a blind brainstorm.

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
| ChatGPT / Claude web | (no local file) | **server-side only** — out of reach without the user's login; report, don't build |

Adding to this table (a new tool to detect) is cheap — one row. Turning a row into
a real reader is the supervised **learn a backend** flow, and it ends with a new
adapter in "Shipped adapters" above.
