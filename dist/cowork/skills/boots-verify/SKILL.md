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
  printf '{"skill":"boots-verify","ts":"%s","session_id":"%s","platform":"cowork"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > "$BOOTS_HOME/analytics/.pending-$_SESSION_ID" 2>/dev/null || true
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
  --skill "boots-verify" --outcome "OUTCOME" --session-id "<the SESSION_ID Step B printed>" \
  2>/dev/null || true
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

A system at `$BOOTS_HOME/systems/<slug>/system.md` with `stage: verify`, a `form:`, and
a `target:` that scope wrote to fit that form.

## What you do — run the check that matches the form

**First, get the real examples in front of you.** Verify means running the thing on
actual inputs, not a toy the model invents. Look in the fixtures folder build staged
(`$BOOTS_HOME/systems/<slug>/inputs/`). If it has real examples, use them. If it is empty
or only has the README, **stop and ask for them in plain English — describe how to
find the folder, don't just name the path** (rule 3 in `boots/SKILL.md`): resolve the
absolute path (expand `$BOOTS_HOME/systems/<slug>/inputs` — it's in the Boots home, a
folder they have no reason to browse) and tell them how to reach it — "To prove this
works I need 2-3 real examples. In Finder press ⌘⇧G, paste
`$BOOTS_HOME/systems/<slug>/inputs`, and
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
`${CLAUDE_PLUGIN_ROOT}/skills/boots/forms/<platform>.md` (default `cowork.md`), section
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
- **script / CLI** → run it, exit 0 plus expected output. If the system came from a
  loose-ends store that offers its own verify command for the record, **run that
  instead of judging the output yourself** — a deterministic check the repo already
  trusts beats your reading of the result. Treat a non-zero exit as a real failure
  that leaves the system unverified, and a "nothing machine-checkable here" result as
  a route to a human read, not as a pass.
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
<bin>/boots-event --system "<slug>" --event transition --from "<the stage the record was actually at before you moved it>" --to verify --outcome advanced 2>/dev/null || true
```

Fill every `<...>` from the record you just read — the folder slug under `$BOOTS_HOME/systems/`, and the real stages (not an assumed linear step: use the stage the record was actually at). If the user stalled rather than moved forward, change `--outcome` to `blocked`; if they walked away from it, `abandoned`.
