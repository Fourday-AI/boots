---
name: boots-prospect
description: >
  Boots cross-cutting. The feeder: mine every AI backend the user actually has —
  Claude Code memory, past transcripts, a loose-ends backend, repo TODOs, other AI
  tools on the machine — and surface a ranked field of opportunities worth turning
  into systems. Detects which tools are present, reports the ones it can't read yet,
  and can learn a new one on request. Use when the user says "boots-prospect", "find
  opportunities", "what could I build", "what should I start", or "mine my loose ends".
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
  printf '{"skill":"boots-prospect","ts":"%s","session_id":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > ~/.boots/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
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
  ~/.claude/skills/boots/bin/boots-telemetry-log --skill "boots-prospect" --duration "$_TEL_DUR" --outcome "OUTCOME" --session-id "$_SESSION_ID" 2>/dev/null &
fi
```

Replace `OUTCOME` before running.

# Boots prospect (cross-cutting)

Prospect is the mouth of the funnel. Before anything enters the pipeline, someone
has to notice it is worth building. Prospect does that: it looks across every place
latent AI work hides — your Claude Code memory, past sessions, a loose-ends
backend, TODOs rotting in a repo, even other AI tools you use — and hands back a
**ranked field of opportunities**, each with the evidence it came from.

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

Read-only. Prospect **finds**; `boots-track` does the promoting and the writing.

## What you do

1. **Detect what's available.** For each source in `sources.md`, run its `detect:`
   check to see if it's present on this machine. Two outcomes matter:
   - sources you **have an adapter for** and that are present → you'll mine them.
   - AI tools you detect but have **no reader for** (Cursor, ChatGPT desktop, …) →
     you'll report these as untapped, and can offer to learn one (see below).
2. **Mine each present source** (read-only) using its adapter's `read:` step. Each
   raw hit becomes a candidate in the common shape from `sources.md`: *what it is,
   where it came from (a real quote / path / record id), why it might matter.*
3. **Dedupe against the pipeline.** Read `state/systems/*/system.md` and drop any
   candidate that is already a tracked system. Prospect surfaces **untracked** work;
   never re-surface something already in flight.
4. **Rank by value-if-finished** — the same instinct `boots-surface` uses. What
   would unlock the most, what the user keeps circling back to, what is closest to
   real. Cheap curiosities sink; recurring intent rises.
5. **Emit the ranked field.** Not one line — a short list. For each: what it is in
   plain words, the evidence it came from, why it's worth it, and the suggested next
   move (`boots-clarify` if fuzzy, `boots-track`/`boots-scope` if already clear).
6. **Report coverage honestly — no silent skips.** If you detected a tool you
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
surfaces ten shiny opportunities you'll never touch is noise; one that finds the
single thread you actually pick up is the whole job. Rank hard, dedupe against
what's already tracked, and be honest about what you couldn't read. Finding beats
hoarding.
