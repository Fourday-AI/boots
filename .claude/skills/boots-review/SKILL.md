---
name: boots-review
description: >
  Boots closer, stage 1 of 3. Review a built AI system for what is wrong, missing,
  or half-done before it gets verified, using the lens that fits its form (a skill's
  triggers and steps, a subagent's role, an MCP server's tool schemas, a script's
  bugs). Writes the gaps back as concrete next steps. Use when a system is built and
  the user says "review it", "is this done", "boots-review", or a system reaches
  stage: review.
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
  printf '{"skill":"boots-review","ts":"%s","session_id":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > ~/.boots/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
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
  ~/.claude/skills/boots/bin/boots-telemetry-log --skill "boots-review" --duration "$_TEL_DUR" --outcome "OUTCOME" --session-id "$_SESSION_ID" 2>/dev/null &
fi
```

Replace `OUTCOME` before running.

# Boots review (closer 1 of 3)

Review is the first of the three closer stages. Its job is to find what is wrong
before anyone claims the thing works. You are a staff engineer reading a
teammate's not-quite-finished work: honest, specific, not flattering.

Review is not verify. Review reads and judges; verify runs and proves. Keep them
separate, that separation is deliberate.

To the user this is just **"checking it over for anything wrong before we test it"**
— never "review", "findings", or "the closer". Present what you find as a short,
ranked list of plain-English concerns ("it won't handle a Word doc", "the score can
never hit zero"), not as "findings" or "gaps".

Follow all the rules in `boots/SKILL.md` — "How Boots talks": the concerns land in
the chat, ranked, not just in the file.

## Input

A system at `~/.boots/systems/<slug>/system.md` with `stage: review`, a `form:`, and
an `## artifact` section pointing at what was made. Read the system file, then read
the artifact itself.

## What you do

1. **Read the artifact end to end.** Not the summary of it, the thing.
2. **Review through the lens that fits the form** (see the palette for this
   system's platform, `.claude/skills/boots/forms/<platform>.md`, default
   `claude-code.md`):
   - **skill** → is the trigger description right, are the steps followable, does
     the voice/output match intent, would it fire when meant to and not otherwise;
     does it actually read its reference notes at the point they matter (not ignore
     them), were the guided-run corrections encoded as rules, is the self-improvement
     rule present
   - **subagent** → is the role scoped, are the right tools granted, is the return
     shape clear
   - **slash command / hook** → does it do exactly one thing, is the event/trigger
     correct, any footgun
   - **MCP server** → are the tool schemas honest, inputs validated, errors handled
   - **Agent SDK app / script** → real bugs, skipped stages, unhandled edges, a
     claim not backed by code
   - **document** → is it true, will a fresh session actually behave differently
3. **Check it against its own foundation and scope.** Does the artifact do what was
   scoped, in the form scope chose? Did it grow past scope or fall short?
4. **Sweep for leaked secrets.** Grep the artifact and `~/.boots/systems/<slug>/` for
   anything that looks like a key or bearer credential: a `COMPOSIO_API_KEY`
   literal, a `connect.composio.dev` or session MCP URL written out in full, any
   long token sitting where a `${VAR}` expansion should be. The master key belongs
   in the OS keyring (`composio login`), never in a file, a shell-profile line, or
   the chat; the session URL belongs in the built system's `.env`, `${VAR}`-expanded
   from config and with that `.env` actually listed in `.gitignore` — confirm the
   `.gitignore` entry exists, not just that the `.env` does. Agents write a lot of
   files (system files, notes, READMEs, configs), and a secret in any of them is a
   leak into git. This is always a blocking gap, whatever else passes. To the user
   it is "I checked nothing private got baked into the files."
5. **For a self-running connection, check it fails loud, not silent.** If the system
   runs unattended (scheduled, headless) and relies on a connection, confirm two
   things: its runtime secret is read from a file the unattended process actually
   sees (local-scope MCP config, or a `.env` / launchd `EnvironmentFile`), not from
   `~/.zshrc`, which cron and launchd never source; and it surfaces a dead or expired
   connection ("your Gmail connection needs re-authorizing") instead of failing
   quietly. A self-running system that goes silent when its connection lapses is a
   blocking gap. Skip if the system has no connection or never runs unattended.
6. **Decide the verdict:**
   - clean enough to verify → advance the stage
   - has gaps that block → keep it at build, write the gaps as next steps

## Write back

Show the ranked findings in the chat. If clean:

```markdown
status: verifying
stage: verify
next_step: run boots-verify to prove the <form> works on a fixture

## now
last worked: <date>, this chat
reality: reviewed, clean — <one line on the state of the artifact>
you are here: read over and nothing blocking; not yet proven on real examples
next physical action: run it on your real examples and watch it work

## log
- <date> review, clean: <one line on why it passed>
```

Append a `sessions/<date>_<label>.md` synthesis before the chat ends; keep `## now`
current if this chat carries on into testing (continuity contract).

If it has blocking gaps, leave stage at build and make the next step the top gap:

```markdown
next_step: <the single most important thing to fix before this can ship>
## log
- <date> review, <N> gaps found, top one: <the gap>
```

## Hand off

When it is clean, don't go quiet. Say what verify does in plain English: **"Next
we actually run it on your real examples and watch it work. That's the 'verify'
step, the one that proves it instead of assuming it."** Drive it with a decision
brief: `Run boots-verify now? (recommended) / Not yet / Something else`. If the
examples aren't in the `inputs/` folder yet, remind them that's what verify needs.
If they pick yes, invoke `boots-verify`.

## The rule

Do not pass a system to verify to be nice. A false "looks done" here is exactly
the failure that killed the eleven history-capture threads: called done before
anyone confirmed it worked. If it is not ready, say so and name the fix.


## Record the move (silent — do not narrate it)

When you move this system to its next stage, record it so the board and `boots-surface` can see where systems flow and stall. Invisible bookkeeping (this suite's rule 5): run it, say nothing about it.

```bash
~/.claude/skills/boots/bin/boots-event --system "<slug>" --event transition --from "<the stage the record was actually at before you moved it>" --to review --outcome advanced 2>/dev/null || true
```

Fill every `<...>` from the record you just read — the folder slug under `~/.boots/systems/`, and the real stages (not an assumed linear step: use the stage the record was actually at). If the user stalled rather than moved forward, change `--outcome` to `blocked`; if they walked away from it, `abandoned`.
