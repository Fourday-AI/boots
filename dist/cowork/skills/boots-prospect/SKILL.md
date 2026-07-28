---
name: boots-prospect
description: >
  Boots cross-cutting. The feeder: mine every backend the user actually has — their
  standing context and task list, past sessions, the tools and folders they've
  connected — and surface a ranked field of opportunities worth turning
  into systems. Detects which tools are present, reports the ones it can't read yet,
  and can learn a new one on request. Use when the user says "boots-prospect", "find
  opportunities", "what could I build", "what should I start", or "mine my loose ends".
preamble-tier: 1
---
<!-- AUTO-GENERATED from SKILL.md.tmpl — do not edit directly -->
<!-- Regenerate: bun run gen:skill-docs -->

## Preamble (run first, then say nothing about it)

Run the block below silently. It is invisible plumbing — do NOT narrate it, echo it, or mention telemetry, folders, or sessions to the user (this suite's rule 5: never narrate your plumbing). Surface something ONLY if the update check prints `UPGRADE_AVAILABLE` or `JUST_UPGRADED` (see "Updates" below), or if the home comes back `absent`. Otherwise go straight to this skill's own opening as if the preamble were not here — it never replaces or precedes the skill's first move in the conversation.

**Step A — resolve the Boots home.** Everything else depends on it. Read `${CLAUDE_PLUGIN_ROOT}/skills/boots/reference/boots-home.md` for the full protocol. The short version is four steps. Take them in order and stop at the first hit.

1. Run this with the **Bash** tool:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/boots/bin/boots-home"
   ```

   If it prints `BOOTS_MODE local` with a path, that is the home. Run every Boots command in this skill with **Bash**.

2. If it printed `absent`, **do not believe it yet** — and above all do not create a home. That script can only see this session's own sandbox, which is not the user's computer. Get the connected folder roots (`get_device_info`, or the session's own notice of which folders are connected) and call `device_list_dir` on each. If one holds a `Boots/` folder, that is the home, `<bin>` is `<home>/.bin`, and every Boots command runs with **device_bash**.

3. **Still nothing? Ask before you build.** `get_device_info` also returns `homeDirectories` — a names-only listing of the user's home folder that needs no permission to read. Look through it for `.boots` and for any folder holding a `Boots`. If one is there, the user has a Boots home you simply have not been given access to yet: call `device_request_folder_access` on it (this works for hidden folders, and is one tap for them). **Skipping this step is the failure that matters** — it tells a user with years of work that they have none, and then offers to start them a second, empty one.

4. Only if the bridge is unavailable, and no connected folder holds a `Boots/`, and nothing in `homeDirectories` looks like one, is the mode really `absent`.

`BOOTS_MODE absent` → do not run Step B. Read `${CLAUDE_PLUGIN_ROOT}/skills/boots/reference/boots-home.md` and follow "First run".

**Step B — the rest of the preamble.** Substitute the resolved `<home>` and `<bin>`, and run it with the tool Step A selected. **Every bash block in this skill is its own invocation and nothing carries between them** — no exported variable, no working directory. So substitute `<home>` and `<bin>` into every block that follows, and treat each one as if it were the first.

```bash
export BOOTS_HOME="<home>"
_UPD=$(bash "<bin>/boots-update-check" 2>/dev/null || true)
[ -n "$_UPD" ] && echo "$_UPD" || true
mkdir -p "$BOOTS_HOME/analytics"
_TEL=$(bash "<bin>/boots-config" get telemetry 2>/dev/null || echo "off")
_TEL_PROMPTED=$([ -f "$BOOTS_HOME/.consent-prompted" ] && echo "yes" || echo "no")
_PROACTIVE=$(bash "<bin>/boots-config" get proactive 2>/dev/null || echo "true")
# A container hands out low PIDs, so PID + second collides with a session on the
# user's own machine — and each would then finalize the other's marker as a crash.
_SESSION_ID="$$-$(date +%s)-${RANDOM:-0}"
echo "TELEMETRY: ${_TEL:-off}"
echo "TEL_PROMPTED: $_TEL_PROMPTED"
echo "PROACTIVE: $_PROACTIVE"
echo "SESSION_ID: $_SESSION_ID"
# Ops run-start marker (Layer B). A Cowork session can be reclaimed mid-run with
# no chance to write an end event, so this marker is what lets the NEXT run
# finalize a dead session as outcome:unknown instead of losing it. The platform is
# stamped in because THIS host is the one that gets reclaimed — a later session on
# the user's laptop must not report the crash as having happened there.
if [ "$_TEL" != "off" ]; then
  printf '{"skill":"boots-prospect","ts":"%s","session_id":"%s","platform":"cowork"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > "$BOOTS_HOME/analytics/.pending-$_SESSION_ID" 2>/dev/null || true
fi
# Ship anything a previous, reclaimed session left queued. On a host that is wiped
# between sessions this is the only chance those events ever get: nothing else here
# will notice them, and the sandbox that wrote them is already gone.
[ "$_TEL" != "off" ] && bash "<bin>/boots-telemetry-sync" >/dev/null 2>&1 &
```

## Updates (act on the preamble output)

If the preamble printed `UPGRADE_AVAILABLE <old> <new>`: mention it once, in one plain line — a newer Boots is available and they can install it the way they installed this one. Do not derail the session into an upgrade; they came here for their systems. If they are not interested, snooze it:

```bash
BOOTS_HOME="<home>"
printf '%s 1 %s\n' "<new>" "$(date +%s)" > "$BOOTS_HOME/update-snoozed"
```

If it printed `JUST_UPGRADED <old> <new>`: say "Running Boots v{new} (just updated)" and continue.

If `PROACTIVE` is `false`: don't proactively suggest other Boots skills this session.

## Telemetry consent (ask once — the one thing here you may surface)

Everything else in this preamble is silent plumbing. This is the exception: a single, one-time question. If `TEL_PROMPTED` is `yes`, skip it entirely. If `no`, ask once via AskUserQuestion, then always mark it prompted regardless of the answer.

Ask it in one breath, in your own plain voice — not as a policy notice. It must say three things, or the person cannot answer it honestly: **what Boots does with them** (walks a system from idea to finished, one stage at a time), **what gets sent** (only the stage a system reached and when — "scoped", "built", "stalled at verify"), and **who sees it** (the people who build Boots, privately — it is not posted anywhere, and no other user ever sees your data). Say plainly that your code, your files, and the names of what you're building never leave your computer. Never use the word "community" as a label — to a new user it reads as *other users can see this*, which is false.

Ask with AskUserQuestion, header `Share usage`, using these three options **verbatim** — the words are the point:

- **"Share my progress" — the full picture; recommended.** Description: sends the stage each of your systems reaches, tied to one random ID so the maintainers can see a whole journey and where it broke. → `bash "<bin>/boots-config" set telemetry community`
- **"Counts only"** — no ID, so they see totals but can't tell one person's run from another. → `bash "<bin>/boots-config" set telemetry anonymous`
- **"Nothing"** — Boots sends nothing at all. → `bash "<bin>/boots-config" set telemetry off`

Ask once and take the answer. Do not re-ask, re-frame, or push a second time if they decline — one question, then straight into their work. They can change it later with `boots-config set telemetry <tier>`; mention that only if they hesitate.

Always, whatever they choose:
```bash
BOOTS_HOME="<home>"
touch "$BOOTS_HOME/.consent-prompted" 2>/dev/null || true
```

Default is **off**, and nothing has anywhere to go until a `telemetry_url` is configured. Nothing is sent anywhere unless the user actively picks community or anonymous here.

## Telemetry (run last)

After the workflow completes, log the ops run event (Layer B). OUTCOME is success/error/abort. This writes only inside the Boots home; run it even in plan mode.

```bash
BOOTS_HOME="<home>" bash "<bin>/boots-telemetry-log" \
  --skill "boots-prospect" --outcome "OUTCOME" --session-id "<the SESSION_ID Step B printed>" \
  2>/dev/null || true
```

Replace `OUTCOME` before running.

# Boots prospect (cross-cutting)

Prospect is the mouth of the funnel. Before anything enters the pipeline, someone
has to notice it is worth building. Prospect does that in two moves: it **reads who
you are** — the role you're in, what you keep doing by hand, the assets and
connections you already have wired — and then it hands back a **ranked field of
opportunities** aimed at that person. The field is two kinds of thing woven
together: **loose threads you've already started** (mined from your standing
context, past sessions, a loose-ends backend, TODOs rotting somewhere, the other
tools you use) and **builds your profile obviously implies** but that you haven't written
down anywhere yet. Every item carries its evidence — a quote/path for a found
thread, the named pattern in what you do for a profile-derived one.

The half that makes prospect feel like it *gets* you is the first move. A run that
skips straight to mining hands back a competent list that could belong to anyone; a
run that first reflects back *"here's who I think you are and what you keep doing"*
makes the same list land as **yours**. Do the understanding first, out loud, always.

This is not `boots-surface`. Surface emits the single most useful next step on work
already **tracked**. Prospect emits the **field** of work that is **not yet
tracked** — the raw material surface and track feed on. Surface answers "what's my
one next move"; prospect answers "what's out there worth starting."

To the user this is just **"let me look through everything you've been meaning to
do and find the handful actually worth building."** Never say "prospect", "feeder",
"backend", or "adapter" to them. Name the sources plainly ("your notes", "your past
chats", "the stuff you use Cursor for").

Follow all the rules in `boots/SKILL.md` — "How Boots talks", including the
plain-English translation table.

Read-only. Prospect **understands, finds, and infers**; `boots-track` does the
promoting and the writing.

## What you do

1. **Read who you are — first, before hunting for threads.** Build a short working
   picture of the person: the role they're in, what they keep doing by hand, the
   assets, data, and connections they already have wired, the shape of what they
   ship. Pull it from the `type: user` profile notes in the host's standing memory
   (the `user-profile` read in `sources.md`) and from the patterns that repeat across
   projects — a founder of a 161K-user paying product reads very differently from a
   freelance designer, and the field you surface should too. You'll open the emit by
   reflecting this back, so hold it as a few concrete lines, not a vibe.
2. **Detect what's available.** For each source in `sources.md`, run its `detect:`
   check to see if it's present on this machine. Two outcomes matter:
   - sources you **have an adapter for** and that are present → you'll mine them.
   - AI tools you detect but have **no reader for** (Cursor, ChatGPT desktop, …) →
     you'll report these as untapped, and can offer to learn one (see below).
3. **Mine each present source for threads already started** (read-only) using its
   adapter's `read:` step. Each raw hit becomes a candidate in the common shape from
   `sources.md`: *what it is, where it came from (a real quote / path / record id),
   why it might matter.* This is the found work — the archaeology half.
4. **Reason from the picture to what they haven't written down.** The profile move,
   and the half that answers "all the things I could build." Given who they are and
   what they visibly do over and over, what would a person in *exactly their
   position* obviously benefit from building — that is not sitting in a note yet?
   These are **profile-derived** candidates (the `profile-derived` entry in
   `sources.md`), and they are held to a hard bar: **each must trace to a real,
   evidenced pattern** in what they do — a recurring manual chore, a dataset or
   connection they keep leveraging, a responsibility of their role. Grounded
   inference, never a generic brainstorm. "You're a founder, so build a CRM / a
   chatbot / an analytics dashboard" is slop and is banned — if you can't point at
   the specific pattern in *this* person's work that the idea falls out of, cut it.
5. **Dedupe against the pipeline.** Read `$BOOTS_HOME/systems/*/system.md` and drop any
   candidate that is already a tracked system. Prospect surfaces **untracked** work;
   never re-surface something already in flight.
6. **Rank by value-if-finished** — the same instinct `boots-surface` uses. Found
   threads and profile-derived ideas compete in one list. What would unlock the
   most, what the user keeps circling back to, what is closest to real. Cheap
   curiosities sink; recurring intent and clean leverage rise.
7. **Emit — lead with the picture, then the field.** Open with two or three plain
   lines reflecting what you understood about them and what they do, so the list
   reads as personal and they can correct you if you're off. Then the ranked field —
   not one line, a short list. For each: what it is in plain words, the evidence it
   came from (a quote/path for found work, the named pattern for a profile-derived
   idea — and say which kind it is), why it's worth it, and the suggested next move
   (`boots-clarify` if fuzzy, `boots-track`/`boots-scope` if already clear).
8. **Report coverage honestly — no silent skips.** If you detected a tool you
   couldn't read, say so: *"I mined your memory and this repo's TODOs; I also see
   you use Cursor and ChatGPT desktop but can't read those yet — want me to learn
   one?"* Implying you scanned everything when you skipped a detected source is the
   same lie as a hollow system. Name what you didn't reach.

## Called by, not only invoked

Prospect is a user-facing move **and** the shared feeder the other skills delegate
to instead of probing a backend themselves:

- `boots-surface` calls it for any untapped opportunity to weigh against finishing a
  tracked system.
- `boots-track` calls it to get the ranked candidates, then promotes one.
- `boots-clarify` calls it for grounding evidence when reframing a fresh ambition.

Prospect is **lightweight by default** — detection plus a few cheap reads. Callers
may reuse the field prospect already surfaced this session rather than re-mining.
The one expensive thing prospect does — learning a new tool — never happens on its
own; it is always a separate, asked-for step.

## Learning a new backend (steps 2→3 of the ask, supervised)

When detection finds a tool with no adapter and the user says "yes, learn it":

1. **Spike its store once, with the user watching.** Open the tool's local data
   (e.g. Cursor's `state.vscdb`), find where conversations/history live, and read a
   couple of real entries. This is a one-time reverse-engineering pass, not
   something a normal prospect run does.
2. **Confirm the read actually works** on one real example before believing it —
   the same honesty `boots-verify` demands. If the history is server-side only
   (ChatGPT web, Claude.ai) or encrypted with no key you hold, say so plainly and
   **stop** — do not build a reader that can't actually read (a hollow adapter).
3. **Crystallize it into `sources.md`** — append a new adapter with its `detect:`,
   `read:`, and `shape:` filled in. The expensive part happened once; every future
   run just reads the adapter.

**Rails, non-negotiable:**
- **Read-only, local files only.** Never trigger a login/OAuth flow, never touch a
  credential store or keychain, never send history off the machine. If reading a
  tool would need auth or scraping, that's a decision to put to the user, not
  something prospect does itself.
- **Map, not diary.** An adapter records the *stable* read path (the file, the
  table, the query), never one-off values or secrets.
- **Server-side-only tools are out of scope** until there's a sanctioned API path —
  name them as "can't reach without your login" and leave them.

## The rule

This is Move 0 — it runs *before* the pipeline, feeding it. A prospector that
surfaces ten shiny opportunities you'll never touch is noise; one that hands you the
single thing you actually pick up is the whole job. It earns that by **knowing who
you are first**, then drawing on both what you've already started and what your
profile plainly implies.

Grounded invention is in scope — but only grounded. Prospect does not just excavate
notes; it reasons from the real shape of your work to builds you haven't named. The
guardrail is the same anti-slop spine either way: every profile-derived idea must
fall out of an evidenced pattern in *this* person's work, or it's cut. Generic
founder advice is noise wearing a suit. Rank hard, dedupe against what's already
tracked, be honest about what you couldn't read. **Understanding you, then finding
and inferring what's worth building for you — that beats hoarding.**
