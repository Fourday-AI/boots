---
name: boots-extract
description: >
  Boots cross-cutting. Run a feedback-extraction pass when a system ships or real
  feedback arrives: what did this teach, what pattern does it confirm or break,
  what should change. The loop that makes work compound instead of being a one-off.
  Use when a system is shipped and the user says "boots-extract", "what did we
  learn", or after external feedback lands.
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
# Ops run-start marker (Layer B). If this session dies before it logs an end event,
# the marker is left behind; the next boots-telemetry-log run finalizes any other
# session's stale marker as outcome:unknown, so a crash is recorded, not lost.
if [ "$_TEL" != "off" ]; then
  printf '{"skill":"boots-extract","ts":"%s","session_id":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > ~/.boots/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
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
  ~/.claude/skills/boots/bin/boots-telemetry-log --skill "boots-extract" --duration "$_TEL_DUR" --outcome "OUTCOME" --session-id "$_SESSION_ID" 2>/dev/null &
fi
```

Replace `OUTCOME` before running.

# Boots extract (cross-cutting)

Extract is the compounding loop. Without it, every shipped system is a one-time
event and the coach never gets smarter. When a system ships, or feedback comes
back, extract asks what it taught and writes that lesson somewhere it will be
read again.

To the user this is just **"jotting down what we learned so the next one goes
smoother."** Never say "extract", "the lesson", or "the loop" to them. Most of this
step is backstage; if you say anything, say plainly what you noticed and where it
now lives ("I'll remember you care more about taste than a polished CV").

## Input

A shipped system at `~/.boots/systems/<slug>/system.md`, or a piece of external
feedback the user pastes.

## What you do

1. Read the system's `## log` and `## foundation`. What actually happened versus
   what was predicted?
2. Pull the lesson. Be concrete: a pattern confirmed ("the closer split into
   three did catch a gap review missed"), a pattern broken ("scope was still too
   big, the slice took three sessions"), or a rule to change.
3. **Route the lesson — and it can go to more than one place.** A lesson usually has
   more than one face: something true about *the user* and, at the same time, a rule the
   *artifact* must now follow. Send it to every destination that fits, not just the
   first one you think of:
   - **A behavioral rule the shipped artifact must follow → edit the artifact itself**
     (its `SKILL.md`, subagent file, hook config, MCP setup). This is the destination
     that gets missed. If the lesson is "the tool should always do X" or "never do Y,"
     it belongs in *the thing that runs*, not only in a memory about how you'd handle
     it. A lesson that changes how the *tool* should behave but leaves the tool's own
     instructions unchanged did not land — it evaporated into a note.
   - **A durable fact about how the user works → a memory** (the persistent user model).
   - **A pattern about the Boots pipeline itself → a `boots-*` skill edit**, or a note
     for `boots-retire`.
   - **A system-specific note → the system's own log.**

   **The dual-nature check, out loud, every time:** "Is this also a rule the artifact
   must obey?" If yes, the artifact edit is *mandatory* even after you've written the
   memory. Writing only the memory for a lesson that is also about the tool is the
   exact miss this step exists to prevent: it teaches *you*, not the tool, and the tool
   repeats the mistake for the next person who runs it.
4. Update the system model so it reflects the lesson **and names where each part of it
   went** (artifact / memory / pipeline / log), not just that the ship happened.

## Write back

```markdown
## log
- <date> extract, lesson: <the one thing this taught, and where it went>
```

## The rule

This is Move 7. The test is whether the **artifact**, the user model, and the pipeline
are meaningfully different a month from now than today. A lesson that changes how the
*tool* should behave but never touches the tool did not flow back — it evaporated into
a note that teaches you and not the thing that runs. If nothing ever changes the
artifact, the memory, or a skill, extract is not running. One real lesson that lands in
the thing that runs beats a tidy summary.
