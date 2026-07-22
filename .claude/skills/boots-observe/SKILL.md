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

Run the block below silently. It is invisible plumbing — do NOT narrate it, echo it, or mention telemetry, branch, or sessions to the user (this suite's rule 5: never narrate your plumbing). Surface something ONLY if the update check prints `UPGRADE_AVAILABLE` or `JUST_UPGRADED` (see "Updates" below). Otherwise go straight to this skill's own opening as if the preamble were not here — it never replaces or precedes the skill's first move in the conversation.

```bash
_UPD=$(~/.claude/skills/boots/bin/boots-update-check 2>/dev/null || .claude/skills/boots/bin/boots-update-check 2>/dev/null || true)
[ -n "$_UPD" ] && echo "$_UPD" || true
mkdir -p ~/.boots/sessions ~/.boots/analytics
touch ~/.boots/sessions/"$PPID" 2>/dev/null || true
find ~/.boots/sessions -mmin +120 -type f -exec rm {} + 2>/dev/null || true
_TEL=$(~/.claude/skills/boots/bin/boots-config get telemetry 2>/dev/null || echo "off")
_TEL_PROMPTED=$([ -f ~/.boots/.consent-prompted ] && echo "yes" || echo "no")
_PROACTIVE=$(~/.claude/skills/boots/bin/boots-config get proactive 2>/dev/null || echo "true")
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
_SESSION_ID="$$-$(date +%s)"
_TEL_START=$(date +%s)
echo "TELEMETRY: ${_TEL:-off}"
echo "TEL_PROMPTED: $_TEL_PROMPTED"
echo "PROACTIVE: $_PROACTIVE"
echo "BRANCH: $_BRANCH"
# Ops run-start marker (Layer B). NOTE: gstack finalizes another session's stale
# .pending-* markers as outcome:unknown (crash detection) inside its telemetry-log
# script — boots-telemetry-log MUST port that finalize loop when it lands (Phase
# 3), or crashed sessions leak markers that never become 'unknown' events.
if [ "$_TEL" != "off" ]; then
  printf '{"skill":"boots-observe","ts":"%s","session_id":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > ~/.boots/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
fi
```

## Updates (act on the preamble output)

If the preamble printed `UPGRADE_AVAILABLE <old> <new>`: read `~/.claude/skills/boots-upgrade/SKILL.md` and follow its inline upgrade flow (auto-upgrade if configured, else a 4-option AskUserQuestion: Yes / Always / Not now / Never). If it printed `JUST_UPGRADED <old> <new>`: say "Running Boots v{new} (just updated!)" and continue.

If `PROACTIVE` is `false`: don't proactively suggest other Boots skills this session.

## Telemetry consent (ask once — the one thing here you may surface)

Everything else in this preamble is silent plumbing. This is the exception: a single, one-time question. If `TEL_PROMPTED` is `yes`, skip it entirely. If `no`, ask once via AskUserQuestion, then always `touch ~/.boots/.consent-prompted` regardless of the answer.

> Help Boots get better? It can share which stages your systems pass through and where they stall — so the project can see where people get stuck. **No code, no file contents, and no repo or system names** (those stay on your machine). A stable, random ID only on the "community" tier.

- **A) Help Boots get better (community)** → `~/.claude/skills/boots/bin/boots-config set telemetry community`
- **B) No thanks** → ask once more: "Anonymous instead — aggregate counts only, no ID?" → yes: `~/.claude/skills/boots/bin/boots-config set telemetry anonymous` · no: `~/.claude/skills/boots/bin/boots-config set telemetry off`

Always, whatever they choose:
```bash
touch ~/.boots/.consent-prompted 2>/dev/null || true
```

Default is **off**. Nothing is sent anywhere unless the user actively picks community or anonymous here.

## Telemetry (run last)

After the workflow completes, log the ops run event (Layer B). OUTCOME is success/error/abort. This writes only to `~/.boots/`; run it even in plan mode.

```bash
_TEL_END=$(date +%s); _TEL_DUR=$(( _TEL_END - _TEL_START ))
rm -f ~/.boots/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
if [ "$_TEL" != "off" ] && [ -x ~/.claude/skills/boots/bin/boots-telemetry-log ]; then
  ~/.claude/skills/boots/bin/boots-telemetry-log --skill "boots-observe" --duration "$_TEL_DUR" --outcome "OUTCOME" --session-id "$_SESSION_ID" 2>/dev/null &
fi
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

Every system at `~/.boots/systems/<slug>/system.md` with `status: shipped`. Each shipped system
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
~/.claude/skills/boots/bin/boots-event --system "<slug>" --event reopened --from "<the stage the record was actually at before you moved it>" --to "<the stage you set on the record>" --outcome advanced 2>/dev/null || true
```

Fill every `<...>` from the record you just read — the folder slug under `~/.boots/systems/`, and the real stages (not an assumed linear step: use the stage the record was actually at). If the user stalled rather than moved forward, change `--outcome` to `blocked`; if they walked away from it, `abandoned`.
