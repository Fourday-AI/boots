---
name: boots-observe
description: >
  Boots cross-cutting. The steward for LIVE (shipped) systems — the step that was missing
  after ship. When Boots opens, for each shipped system it runs three checks: is it ALIVE
  (did the scheduled job run, is the connection up, has the tool been used), is its answer
  SANE (does the latest output make sense, or is it silently wrong), and is it USED + getting
  better. Then it proposes concrete evolutions — accuracy, reliability, UX — and makes the
  fix with the user. Writes a ## health block to each system file so each check builds on the
  last. Use when a shipped system may be misbehaving, the user says "boots-observe", "check
  my live systems", "is X still working", or the Boots router opens with shipped systems on
  the board.
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
  printf '{"skill":"boots-observe","ts":"%s","session_id":"%s","platform":"cowork"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > "$BOOTS_HOME/analytics/.pending-$_SESSION_ID" 2>/dev/null || true
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
  --skill "boots-observe" --outcome "OUTCOME" --session-id "<the SESSION_ID Step B printed>" \
  2>/dev/null || true
```

Replace `OUTCOME` before running.

# boots-observe

Shipping is not the end. A live system breaks silently, goes unused, or quietly drifts to
the wrong answer — and unless something watches, the user finds out by accident, weeks late.
You are that something. You keep live systems working and **evolve them with the user** so
they get more accurate, more reliable, and nicer to use over time.

To the user this is **"checking your live systems are still working — and making them
better."** Never say "observe", "health probe", "sanity check", or "the steward." Follow the
"How Boots talks" rules in `boots/SKILL.md`.

## The one principle

**"It ran" is not "it worked."** A scheduled job can fire on time, exit zero, write its log,
and still hand back a silently wrong answer — for example a watcher that reports "nothing
found" because a filter or time-window quietly excluded the very things it was meant to
catch. A health check that only confirms the process executed would call that "fine." So you
**always check the OUTPUT against what you know**, not just that the thing ran. The
silent-wrong answer — green process, wrong result — is the failure this skill exists to catch.

## Input

Every system at `$BOOTS_HOME/systems/<slug>/system.md` with `status: shipped`. Each shipped system
should carry a `## health checks` section declaring how to probe *it* specifically (its
liveness command, what a sane output looks like for it, what "used" means). **Read and use
that section** — it holds the system-specific detail so this skill can stay general. If a
system has no `## health checks` section, fall back to the form-aware defaults below, and at
the end write a `## health checks` section for it so future runs are sharper.

## What you do — three checks per live system

1. **ALIVE — did it actually run / is it reachable?** Form-aware defaults:
   - **Scheduled job (launchd/cron/routine):** is it still registered? Did it run recently
     and exit clean? (Read its log and the timestamp of its most recent output.)
   - **Connection / MCP server:** ping it read-only — is it still authorized/ACTIVE, or did
     the connection lapse?
   - **Skill / command:** has it been invoked lately? Ask if you cannot tell.
   A dead job or a lapsed connection is the loud failure — lead with it.

2. **SANE — does the latest answer make sense?** This is the check that matters most and the
   one naive monitoring skips. Compare the current output against what the system file already
   records:
   - Did a result count crater to zero or spike absurdly versus a known baseline?
   - Is it empty when it should not be, or full of obvious junk?
   - Does it contradict something recorded in the file (a saved backlog, the last run, the
     stated target)?
   Use the system's own `## health checks` "sane" definition when it has one. When the output
   looks wrong, that is a finding even if everything ran — say so plainly.

3. **USED + improving — is it earning its keep?** Is the user acting on it? Is it surfacing
   the right things? Some of this you can read; much you must **ask**, with a grounded,
   specific question tied to what the system actually did recently — never "how's it going?"
   The answer is calibration: fold taste corrections into the system's reference notes and
   operating rules (rule 6 / self-improvement), the same way the system itself would.

## Write the health block

Refresh a `## health` block in each live system's file so the next check builds on this one:

```markdown
## health
last checked: <date>, this chat
alive: <ran? connection up? — the liveness verdict, grounded in the log/probe>
sane: <does the latest output make sense? — the sanity verdict, with the number/evidence>
used: <acting on it? right output? — or "asked, awaiting answer">
evolutions proposed: <the concrete improvements surfaced this check, and their status>
```

## Report, then evolve (don't just log)

- **Report** a short readout per live system, in plain English, worst first: what's broken,
  what's silently wrong, what's fine. If everything is genuinely healthy, say so and stop —
  do not invent problems.
- **Evolve.** For each real friction, propose ONE concrete fix as a decision brief (per
  `boots/SKILL.md`) — a wider/narrower net, a UX change, a reliability fix — and on a yes,
  **make it**, or route it to the right stage (a real rebuild goes back through scope/build;
  a small tweak you just do). The point is that the system gets better *because it was
  watched*, not that a problem got filed. Record the outcome in `## health`.

## How it runs

The Boots router (`boots/SKILL.md`, Step 1) calls this for every `status: shipped` system
when Boots opens — so a live system that broke overnight is caught the next time the user
shows up, not weeks later. It can also be run on demand. By design it runs when Boots opens,
not on its own schedule, so its reach is only as good as how often the user opens Boots; if a
live system is time-critical, say that out loud and offer a scheduled check as an upgrade.

## Voice

Concrete and honest. "It ran but the answer's wrong" is the sentence this skill exists to be
able to say. Lead with the truth, back it with the number or the log line, propose the fix.
Never report "all healthy" without having actually checked the output, not just the process.


## Record the move (silent — do not narrate it)

When you send this shipped system back into the pipeline for real rework, record it so the board and `boots-surface` can see where systems flow and stall. Invisible bookkeeping (this suite's rule 5): run it, say nothing about it.

```bash
<bin>/boots-event --system "<slug>" --event reopened --from "<the stage the record was actually at before you moved it>" --to "<the stage you set on the record>" --outcome advanced 2>/dev/null || true
```

Fill every `<...>` from the record you just read — the folder slug under `$BOOTS_HOME/systems/`, and the real stages (not an assumed linear step: use the stage the record was actually at). If the user stalled rather than moved forward, change `--outcome` to `blocked`; if they walked away from it, `abandoned`.
