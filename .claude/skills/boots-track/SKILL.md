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
  printf '{"skill":"boots-track","ts":"%s","session_id":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > ~/.boots/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
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
  ~/.claude/skills/boots/bin/boots-telemetry-log --skill "boots-track" --duration "$_TEL_DUR" --outcome "OUTCOME" --session-id "$_SESSION_ID" 2>/dev/null &
fi
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
   mkdir -p ~/.boots/systems/<slug>
   ```

   ```markdown
   # System: <slug>

   status: clarifying
   stage: clarify
   form: (decided at scope)
   next_step: run boots-clarify to sharpen this, or boots-scope if it's already clear
   target: n/a
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
~/.claude/skills/boots/bin/boots-event --system "<slug>" --event created --to "<the stage you set on the record>" --outcome advanced 2>/dev/null || true
```

Fill every `<...>` from the record you just read — the folder slug under `~/.boots/systems/`, and the real stages (not an assumed linear step: use the stage the record was actually at). If the user stalled rather than moved forward, change `--outcome` to `blocked`; if they walked away from it, `abandoned`.
