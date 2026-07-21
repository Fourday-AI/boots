---
name: boots-verify
description: >
  Boots closer, stage 2 of 3. Prove a reviewed AI system actually works by running
  it end to end, using the check that fits its form (invoke a skill, spawn a
  subagent, fire a hook, call an MCP tool, run an app or script). Records real
  evidence and refuses to claim success on a check that did not pass. Use when a
  system passed review and the user says "verify it", "prove it works",
  "boots-verify", or a system reaches stage: verify.
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
  printf '{"skill":"boots-verify","ts":"%s","session_id":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > ~/.boots/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
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
  ~/.claude/skills/boots/bin/boots-telemetry-log --skill "boots-verify" --duration "$_TEL_DUR" --outcome "OUTCOME" --session-id "$_SESSION_ID" 2>/dev/null &
fi
```

Replace `OUTCOME` before running.

# Boots verify (closer 2 of 3)

Verify is the middle closer stage and the one that catches liars. Review reads;
verify runs. You do not decide whether it works by inspection. You execute the
thing and observe the result. This is the stage that was missing from every
abandoned thread, the plugin built four times and never once confirmed working.

The trap to avoid: verifying only the forms that have a clean exit code. A skill,
a subagent, an MCP server, and a hook all "work" or "don't work" in ways an exit
code never captures. Verify the form you actually have.

To the user this is just **"let's run it on your real examples and watch it
work"** — never "verify", "the check", or "fixtures". Show them the actual result
of the run, in plain terms, as the proof.

Follow all the rules in `boots/SKILL.md` — "How Boots talks": the evidence lands
in the chat, not just the file.

## Input

A system at `state/systems/<slug>/system.md` with `stage: verify`, a `form:`, and
a `target:` that scope wrote to fit that form.

## What you do — run the check that matches the form

**First, get the real examples in front of you.** Verify means running the thing on
actual inputs, not a toy the model invents. Look in the fixtures folder build staged
(`state/systems/<slug>/inputs/`). If it has real examples, use them. If it is empty
or only has the README, **stop and ask for them in plain English — describe how to
find the folder, don't just name the path** (rule 3 in `boots/SKILL.md`): resolve the
absolute path (`pwd`) and tell them how to reach it — "To prove this works I need 2-3
real examples. In Finder press ⌘⇧G, paste `<abs>/state/systems/<slug>/inputs`, and
drop them in there (or ask me to open it); the tool reads that folder when it runs.
Tell me when they're in." Do not verify on
made-up data and do not skip to a pass; a system with no real examples is not
verified, it is unproven. Only invent a minimal fixture if the user explicitly says
they have none and asks you to, and say so in the evidence.

**For a judgment system, test against criteria, not just once.** A skill or subagent
whose output is a taste call does not pass just because it ran without erroring. Turn
the `target:` and the reference notes into 3-4 plain success criteria before you run —
"grades match how the user actually ranked them", "voice sounds like the user, not a
generic recruiter", "summary stays under three lines". Then run it on more than one
real example (you can spawn parallel test agents to run the variations at once), and
read each result against each criterion. Report it as a short scorecard in the chat —
which criteria held, which slipped, on which example — not a bare "it worked". Where a
criterion slips, that is not a fail to hide; it is the next rule to add back in build.
For a deterministic form (script, hook), the mechanical check below is enough.

Read the palette for this system's platform,
`.claude/skills/boots/forms/<platform>.md` (default `claude-code.md`), section
"How to verify each form". Then:

- **skill** → invoke it in a real session on the user's real example inputs. Observe
  it triggers, follows its own steps, and produces the result. Evidence is the
  transcript.
- **subagent** → spawn it on a test task, check the returned result against the ask.
- **slash command** → type it, observe the expansion runs.
- **hook** → cause the event, confirm it fired and check its side effect (the file
  it writes, the block it applies).
- **MCP server** → call one of its tools, check the response shape and a real value.
- **Agent SDK app** → run it end to end on a fixture, check the output.
- **script / CLI** → run it, exit 0 plus expected output. If it is a loose-end-backed
  script in a feature-toolkit repo, use the deterministic check and do not judge it
  yourself:
  ```bash
  PY=.venv/bin/python; [ -x "$PY" ] || PY=python3
  $PY -m toolkit verify <id>
  ```
  exit 0 → verified with evidence; exit 1 → failed, stays unverified; exit 2 → no
  machine-checkable target, needs a human read.
- **document / context** → mostly Tier-2: have a fresh read confirm it changes
  behavior. If it makes a checkable claim, check that claim.

Never paraphrase the result. Paste what actually happened, the real output or the
real transcript.

## Notice what you had to do by hand (self-healing)

A pass tells you the *outcome* was right. It does not tell you the *artifact* produced
that outcome on its own. Those are different, and the gap between them is where
self-healing lives. As you run the check, watch yourself: every time you (the
operator) step in and do something the artifact should have done itself, that is an
artifact gap the run just surfaced — not a reason to fail, a reason to heal. A "pass"
that only happened because the human knew the tool's tricks is a tool that will fail
for anyone else.

Log every one. Watch for:
- **A workaround you performed that the artifact didn't tell you to** — you connected
  a browser, extracted links out of a PDF, grouped files by person, re-ran a step,
  found the input in a place the artifact didn't name.
- **A degraded substitute you reached for — or offered — when the real check was
  harder.** Grading from a description instead of the real thing; a proxy "good
  enough" pass; a `WebFetch` summary standing in for the actual artifact. If you were
  even *tempted* by the shortcut, the artifact needs a rule that forbids it, because
  the next operator will take it.
- **Something the user had to correct mid-run** that the artifact should have known.

Record each one in the system file as an `artifact_gaps:` list. A pass with an empty
list is a clean pass; a pass with gaps is a pass the *operator carried*, and ship is
required to heal each gap into the artifact before it closes. If you genuinely did
nothing by hand, write `none` — an honest empty list is fine, a dishonest one ships a
crippled tool.

## Write back

If it passed:

```markdown
status: shipping
stage: ship
next_step: run boots-ship to produce the finished artifact

## now
last worked: <date>, this chat
reality: <what the run actually produced — grounded in output, e.g. "ran on 12 real
  accounts, all 12 PDFs verified; 26 more flagged into 3 causes">
you are here: <the user's situation in their words — the decision or check mid-flight>
next physical action: <the concrete next move>

artifact_gaps:
- <each thing you had to do by hand that the artifact should do itself — or "none">
## log
- <date> verify, passed (<form>): <the actual evidence — output, transcript, or tool response>
- <date> verify, artifact gaps surfaced: <one line, or "none">
```

**Update `## now` the moment the run produces anything — mid-run, not just at the
end.** Verify is where a chat drives the real thing and can get cut off partway (the
run made 12 forms, then hit a wall). If that happens, `## now` and `run-state`/output
on disk must already say so, so the next chat picks up from "12 done, 26 flagged," not
"not run yet." Append a `sessions/<date>_<label>.md` synthesis before the chat ends.

If it failed, drop it back or hold it at verify with the failure named:

```markdown
next_step: fix <the specific failure> then re-verify
## log
- <date> verify, FAILED (<form>): <the actual error or wrong behavior>
```

If the form has no mechanical check, say so plainly, route it to a human read, and
leave it at verify. Do not fake a pass.

When it passes, don't go quiet. Show the real result in the chat, then say what
ship does in plain English: **"It works. Last step is 'ship'. I make it something
you can actually use whenever you want, and fold in anything review flagged, then
you're done carrying this."** Drive it with a decision brief: `Run boots-ship now?
(recommended) / Not yet / Something else`. If they pick yes, invoke `boots-ship`.

## The rule

There is exactly one way to pass this stage: the check that fits the form ran and
succeeded, and the evidence is real output or a real transcript, not your
assessment. "Should work" is a fail, for every form.


## Record the move (silent — do not narrate it)

When you move this system to its next stage, record it so the board and `boots-surface` can see where systems flow and stall. Invisible bookkeeping (this suite's rule 5): run it, say nothing about it.

```bash
~/.claude/skills/boots/bin/boots-event --system "<slug>" --event transition --from "<the stage the record was actually at before you moved it>" --to verify --outcome advanced 2>/dev/null || true
```

Fill every `<...>` from the record you just read — the folder slug under `state/systems/`, and the real stages (not an assumed linear step: use the stage the record was actually at). If the user stalled rather than moved forward, change `--outcome` to `blocked`; if they walked away from it, `abandoned`.
