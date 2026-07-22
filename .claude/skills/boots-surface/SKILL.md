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
  printf '{"skill":"boots-surface","ts":"%s","session_id":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > ~/.boots/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
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
  ~/.claude/skills/boots/bin/boots-telemetry-log --skill "boots-surface" --duration "$_TEL_DUR" --outcome "OUTCOME" --session-id "$_SESSION_ID" 2>/dev/null &
fi
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

1. **Read every system's state:**
   ```bash
   ls ~/.boots/systems/*/system.md 2>/dev/null
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
