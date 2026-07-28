---
name: boots-surface
description: >
  Boots cross-cutting. The proactive line: read the model of all systems and emit
  the single most useful next step, or a grounded "nothing's stuck" when there is
  none. This is the laptop-open moment. Use when the user says "boots-surface",
  "what's next", or when a session opens and Boots should lead.
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
  printf '{"skill":"boots-surface","ts":"%s","session_id":"%s","platform":"cowork"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > "$BOOTS_HOME/analytics/.pending-$_SESSION_ID" 2>/dev/null || true
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
  --skill "boots-surface" --outcome "OUTCOME" --session-id "<the SESSION_ID Step B printed>" \
  2>/dev/null || true
```

Replace `OUTCOME` before running.

# Boots surface (cross-cutting)

Surface is the proactive move, the thing you want when you open your laptop: Boots
tells you where you are with all your systems and always has one next step. It is
the difference between a tool you go to and a coach that comes to you.

Whatever you surface must be a single plain-English line the user understands with
zero context — what to do and which thing it's for ("Your CV grader is one step from
done, it just needs you to drop in 2-3 real CVs to test on"). Never report in the
stage vocabulary ("cv-grader is at verify"); see the translation table in
`boots/SKILL.md`.

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

1. **Read every system's state:**
   ```bash
   ls $BOOTS_HOME/systems/*/system.md 2>/dev/null
   ```
   For each system, read its `## now` block first, then `status:`, `stage:`, `form:`,
   and `next_step:`. **Reconcile before you trust it** — the same suspenders the
   router uses (see "The continuity contract" and Step 1 in `boots/SKILL.md`): if the
   claimed state can't be squared with what's on disk (an artifact that exists, a
   `run-state.json`, output files, a populated `sessions/`), reality wins — repair
   `## now` from the evidence and surface the repaired truth, not the stale claim. The
   proactive line is worthless if it points at a step the user finished hours ago. For
   any **untapped** opportunity to weigh against finishing a tracked system, invoke
   `boots-prospect` (or reuse the field it already surfaced this session) — it owns
   the feeder and mines every backend. Don't probe a store here yourself.
   **Also check each system for a capability hole** (see below): does it name an
   input or reference source it has no verified way to actually read?
2. **Pick the one thing.** Priority order:
   - **a system that is hollow** — it claims an input or source it can't consume
     (worst of all: it looks done and isn't; see "When a system is hollow")
   - a system stuck at review / verify / ship (near the finish, worth the most)
   - a system waiting on the user for a taste call
   - a fresh system with an obvious next build step
   - only if nothing tracked needs you: the top untapped opportunity from
     `boots-prospect` (finishing always beats starting)
3. **Emit one line, not a report.** The next step, named, with the system it
   belongs to. One line the user can act on immediately.

## When a system is hollow (be crafty)

A system is hollow when it was built to read something it can't actually read: a
subagent that "opens each Instagram and watches the reel" but only has `WebFetch`
(which returns a login wall, and can't watch video at all), an input in the scope
with no access path, a reference note that asks the user for a handle the system
has no way to consume. This is the worst state a system can be in, because it looks
finished. To the non-technical user there is no visible difference between "watched
the reel and judged it" and "guessed from the cover letter." Catch it here.

**The tell:** the system, or the build that made it, asked the user for an input
(an Instagram handle, a site, a Notion) with nothing on board that can read it.

When you find one, do not just report the block. **Be crafty — come with the fix,
and default to solving it in the machine, not handing it back to the user.** The
product already has real tools, so "it can't see Instagram" is usually a false
limit. The next-step line proposes the wired path:

> "Your reel scout can't actually see the reels yet — it only has plain web
> access, which hits a login wall on Instagram and can't watch video. Want me to
> give it browser-harness so it opens the feed for real, and have it download each
> reel so it can actually watch them?"

The order you reach for, before ever offloading to the user:
1. **Wire a real machine path** (the default) — browser-harness for a logged-in
   feed, `yt-dlp` the reel then a vision-capable model watches it, a public embed
   endpoint. Engineer a way in.
2. **A human step** — only if no machine path is worth it. The user is the eyes,
   the system judges what they paste.
3. **Drop it** — only if it's genuinely not worth it, said plainly.

**Stay honest.** A proposed path is a claim until it's proven on one real example.
Never promise it works; propose it, then let verify open one real feed and confirm
frames actually come back. Crafty by default, checked before it counts. Never
surface a fix that swaps one hollow path for another.

## When there is nothing

Say so. "Nothing's stuck. Two systems shipped this week, one waiting on your call
in scope. Want that one, or something new?" is the correct output when the model
is clean. Do not manufacture urgency. Silence with a model behind it beats noise.

## The rule

This is Move 10. A system that always has something to say has no model of you.
Boots earns the proactive line by being right that there is one, and by being
willing to say there is not.
