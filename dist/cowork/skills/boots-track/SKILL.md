---
name: boots-track
description: >
  Boots cross-cutting. Promote a loose, abandoned thread into a tracked system with
  state, a form, and a next step, so it stops rotting and enters the pipeline. The
  bridge from wherever your unfinished AI work lives (a loose-ends scanner, a notes
  file, a memory, your own recall) into a boots system. Use when the user says
  "boots-track", "pick this back up", "make this a system", or points at an
  abandoned thread worth reviving.
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
  printf '{"skill":"boots-track","ts":"%s","session_id":"%s","platform":"cowork"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > "$BOOTS_HOME/analytics/.pending-$_SESSION_ID" 2>/dev/null || true
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
  --skill "boots-track" --outcome "OUTCOME" --session-id "<the SESSION_ID Step B printed>" \
  2>/dev/null || true
```

Replace `OUTCOME` before running.

# Boots track (cross-cutting)

Track is the bridge. Unfinished AI work piles up somewhere, an abandoned chat, a
half-built plugin, a note that says "should automate this." Track takes one of
those and promotes it into a real boots system so the pipeline can finish it. This
is how dead threads come back to life: one at a time, each becoming a tracked
system with a stage and a next step.

To the user this is just **"picking something you started and dropped back up, and
giving it a real plan so it gets finished this time."** Never say "track", "promote",
"thread", or "the pipeline" to them. Refer to the thing in their own words for it.

Follow all the rules in `boots/SKILL.md` — "How Boots talks", including the
plain-English translation table.

## Where the thread comes from

The candidates come from `boots-prospect`, the feeder — it mines every backend the
user has (a loose-ends store, memory, past transcripts, repo TODOs, other AI tools)
and hands back a ranked field, each with the evidence and, if it came from a
backend, its record `id`. Invoke it, or reuse the field it already surfaced this
session. If the user points you straight at one thread ("pick up the plugin thing"),
you don't need the full scan — take that one.

## What you do

1. **Surface the candidates** — take the ranked field from `boots-prospect` (or the
   one thread the user pointed at) and quote them back.
2. **Pick the thread** the user named, or the one whose finishing would unlock the
   most, as a decision brief.
3. **Create the system** from it. Carry a loose-end `id` only if the thread came
   from a backend that has one, it lets the closer reuse that backend's verify.
   **Name the slug from what the thread was *really* trying to do** (the foundation
   paragraph below), not from its original title. An abandoned thread called "plugin
   attempt 4" is not the system's name; what it was reaching for is:

   ```bash
   mkdir -p $BOOTS_HOME/systems/<slug>
   ```

   ```markdown
   # System: <slug>

   status: clarifying
   stage: clarify
   form: (decided at scope)
   next_step: run boots-clarify to sharpen this, or boots-scope if it's already clear
   target: n/a
   question: <why it exists: what it needs to find out, or the decision it feeds —
     your best read of the abandoned thread's real point; "unclear, ask at clarify"
     is an honest value and better than a guess dressed up as fact>
   id: <loose-end id, or omit>

   ## now
   last worked: <date>, this chat
   reality: just picked up from an abandoned thread — nothing built
   you are here: revived <source ref>; not yet sharpened or scoped
   next physical action: sharpen what it's really for, or scope it if already clear

   ## foundation
   <one paragraph on what this thread was really trying to do>

   ## log
   - <date> track, promoted <source ref> into a system
   ```

   If the thread is already well understood, you may send it straight to
   `boots-scope`; if it is still fuzzy, route through `boots-clarify` first.

## The rule

Promote deliberately, not in bulk. A tracked system you will actually finish beats
ten promoted threads that re-rot. This is Move 4, lightweight by default: only
promote when there is real intent to work it.


## Record the move (silent — do not narrate it)

When you create this system's record, record it so the board and `boots-surface` can see where systems flow and stall. Invisible bookkeeping (this suite's rule 5): run it, say nothing about it.

```bash
<bin>/boots-event --system "<slug>" --event created --to "<the stage you set on the record>" --outcome advanced 2>/dev/null || true
```

Fill every `<...>` from the record you just read — the folder slug under `$BOOTS_HOME/systems/`, and the real stages (not an assumed linear step: use the stage the record was actually at). If the user stalled rather than moved forward, change `--outcome` to `blocked`; if they walked away from it, `abandoned`.
