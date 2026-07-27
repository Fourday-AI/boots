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

Run the block below silently. It is invisible plumbing — do NOT narrate it, echo it, or mention telemetry, branch, or sessions to the user (this suite's rule 5: never narrate your plumbing). Surface something ONLY if the update check prints `UPGRADE_AVAILABLE` or `JUST_UPGRADED` (see "Updates" below). Otherwise go straight to this skill's own opening as if the preamble were not here — it never replaces or precedes the skill's first move in the conversation.

```bash
_UPD=$(~/.claude/skills/boots/bin/boots-update-check 2>/dev/null || boots/bin/boots-update-check 2>/dev/null || true)
[ -n "$_UPD" ] && echo "$_UPD" || true
mkdir -p ~/.boots/sessions ~/.boots/analytics
touch ~/.boots/sessions/"$PPID" 2>/dev/null || true
find ~/.boots/sessions -mmin +120 -type f -exec rm {} + 2>/dev/null || true
_TEL=$(~/.claude/skills/boots/bin/boots-config get telemetry 2>/dev/null || echo "off")
_TEL_PROMPTED=$([ -f ~/.boots/.consent-prompted ] && echo "yes" || echo "no")
_PROACTIVE=$(~/.claude/skills/boots/bin/boots-config get proactive 2>/dev/null || echo "true")
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
# PID + time alone collide across machines — a container reliably hands out low PIDs,
# so a session in the cloud and one on the laptop starting the same second mint the
# SAME id, and each finalizes the other's pending marker as a crash. Hence the salt.
_SESSION_ID="$$-$(date +%s)-${RANDOM:-0}"
_TEL_START=$(date +%s)
# Flush anything the previous session left queued (backgrounded, rate-limited,
# tier-gated, silent without a backend). A session on a short-lived host can end
# before its last event ships; this is the catch-up.
[ "$_TEL" != "off" ] && [ -x ~/.claude/skills/boots/bin/boots-telemetry-sync ] && ~/.claude/skills/boots/bin/boots-telemetry-sync >/dev/null 2>&1 &
echo "TELEMETRY: ${_TEL:-off}"
echo "TEL_PROMPTED: $_TEL_PROMPTED"
echo "PROACTIVE: $_PROACTIVE"
echo "BRANCH: $_BRANCH"
# Ops run-start marker (Layer B). If this session dies before it logs an end event,
# the marker is left behind; the next boots-telemetry-log run finalizes any other
# session's stale marker as outcome:unknown, so a crash is recorded, not lost.
# It carries its own platform so the crash is attributed to the host it died on,
# not to whichever host later notices the corpse.
if [ "$_TEL" != "off" ]; then
  _PLATFORM=$(~/.claude/skills/boots/bin/boots-platform 2>/dev/null || echo "claude-code")
  printf '{"skill":"boots-retire","ts":"%s","session_id":"%s","platform":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" "$_PLATFORM" > ~/.boots/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
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
  ~/.claude/skills/boots/bin/boots-telemetry-log --skill "boots-retire" --duration "$_TEL_DUR" --outcome "OUTCOME" --session-id "$_SESSION_ID" 2>/dev/null &
fi
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
~/.claude/skills/boots/bin/boots-analytics --brief 2>/dev/null || true
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
   ls -lt ~/.boots/systems/*/system.md 2>/dev/null
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
~/.claude/skills/boots/bin/boots-event --system "<slug>" --event retired --from "<the stage the record was actually at before you moved it>" --to retired --outcome abandoned 2>/dev/null || true
```

Fill every `<...>` from the record you just read — the folder slug under `~/.boots/systems/`, and the real stages (not an assumed linear step: use the stage the record was actually at). If the user stalled rather than moved forward, change `--outcome` to `blocked`; if they walked away from it, `abandoned`.
