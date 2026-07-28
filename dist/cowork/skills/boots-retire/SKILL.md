---
name: boots-retire
description: >
  Boots cross-cutting. Propose dropping systems, rules, or artifacts that have gone
  cold, so the model stays honest and Boots can subtract, not only add. Use when
  the user says "boots-retire", "what can I drop", "clean this up", or when a system
  has sat untouched for weeks.
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
  printf '{"skill":"boots-retire","ts":"%s","session_id":"%s","platform":"cowork"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > "$BOOTS_HOME/analytics/.pending-$_SESSION_ID" 2>/dev/null || true
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
  --skill "boots-retire" --outcome "OUTCOME" --session-id "<the SESSION_ID Step B printed>" \
  2>/dev/null || true
```

Replace `OUTCOME` before running.

# Boots retire (cross-cutting)

Retire is the rarest move and the one that keeps Boots trustworthy. A system that
can only grow rots. Retire proposes subtraction: systems you stopped touching,
rules you keep overriding, artifacts nobody opens. It proposes, the user decides.

To the user this is just **"you've stopped using this, want to drop it?"** Never say
"retire", "cold", "the model", or a bare `<slug>` to them. Refer to the thing by
what it does and describe its state plainly ("that CV grader you haven't opened in
six weeks"), not by its stage.

## The funnel — read flow and staleness (run this, fold it in)

Before you report the board, run the rollup. It reads every system's event history
and gives you what `system.md` cannot: how long each system has sat untouched, where
systems pile up, and what has been abandoned.

```bash
<bin>/boots-analytics --brief 2>/dev/null || true
```

Read the output: `FUNNEL` (totals — shipped / active / stalled), `PIPELINE` (how
many systems at each stage), `GRAVEYARD` (the stage systems get abandoned from), and
one `SYS` line per system with its `cold=Nd` (days since it last moved). Lead with
what is **near-finished but stalled** — something one step from done that has gone cold
is worth more than a fresh idea. Name the graveyard stage only if it is real (not
`none yet`). Translate everything to plain words — never show the user the stage
vocabulary or the raw output.

## What you do

1. **Find the cold and the overridden:**
   ```bash
   ls -lt $BOOTS_HOME/systems/*/system.md 2>/dev/null
   ```
   Look for systems untouched for weeks, stuck at the same stage across many
   sessions, or long past their moment. If the user keeps a loose-ends store, read
   its list too — guarded, so an absent backend just means one less place to look.
2. **Propose, with the evidence, in plain words:** "You haven't touched that CV
   grader in six weeks and it never got past the planning stage. Want to drop it, or
   is it on hold on purpose?" Name the thing by what it does, not its slug, and say
   its state plainly, not "at scope." Say why you think it's gone cold. Do not delete
   anything yet.
3. **On a yes**, retire it cleanly:
   ```markdown
   status: retired
   next_step: none, retired <date>
   ## log
   - <date> retire, dropped because <reason>, user agreed
   ```
   Keep the file, mark it retired, so the history of the decision survives.

## The rule

This is Move 8. Earn the right to propose big deletions by being right about small
ones first. Never retire without the user's yes. A wrong deletion costs more trust
than a wrong addition, so bring evidence, not a hunch.


## Record the move (silent — do not narrate it)

When you retire this system, record it so the board and `boots-surface` can see where systems flow and stall. Invisible bookkeeping (this suite's rule 5): run it, say nothing about it.

```bash
<bin>/boots-event --system "<slug>" --event retired --from "<the stage the record was actually at before you moved it>" --to retired --outcome abandoned 2>/dev/null || true
```

Fill every `<...>` from the record you just read — the folder slug under `$BOOTS_HOME/systems/`, and the real stages (not an assumed linear step: use the stage the record was actually at). If the user stalled rather than moved forward, change `--outcome` to `blocked`; if they walked away from it, `abandoned`.
