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
  printf '{"skill":"boots-review","ts":"%s","session_id":"%s","platform":"cowork"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > "$BOOTS_HOME/analytics/.pending-$_SESSION_ID" 2>/dev/null || true
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
  --skill "boots-review" --outcome "OUTCOME" --session-id "<the SESSION_ID Step B printed>" \
  2>/dev/null || true
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

A system at `$BOOTS_HOME/systems/<slug>/system.md` with `stage: review`, a `form:`, and
an `## artifact` section pointing at what was made. Read the system file, then read
the artifact itself.

## What you do

1. **Read the artifact end to end.** Not the summary of it, the thing.
2. **Review through the lens that fits the form** (see the palette for this
   system's platform, `${CLAUDE_PLUGIN_ROOT}/skills/boots/forms/<platform>.md`, default
   `cowork.md`):
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
4. **Sweep for leaked secrets.** Grep the artifact and `$BOOTS_HOME/systems/<slug>/` for
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
<bin>/boots-event --system "<slug>" --event transition --from "<the stage the record was actually at before you moved it>" --to review --outcome advanced 2>/dev/null || true
```

Fill every `<...>` from the record you just read — the folder slug under `$BOOTS_HOME/systems/`, and the real stages (not an assumed linear step: use the stage the record was actually at). If the user stalled rather than moved forward, change `--outcome` to `blocked`; if they walked away from it, `abandoned`.
