---
name: boots-ship
description: >
  Boots closer, stage 3 of 3. Produce the finished, usable form for a verified AI
  system — invocable skill, registered subagent, connectable MCP server, runnable
  app, wired hook — and mark it done, so the system stops being a thread you carry
  and becomes a thing you have. Use when a system passed verify and the user says
  "ship it", "finish it", "boots-ship", or a system reaches stage: ship.
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
  printf '{"skill":"boots-ship","ts":"%s","session_id":"%s","platform":"cowork"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > "$BOOTS_HOME/analytics/.pending-$_SESSION_ID" 2>/dev/null || true
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
  --skill "boots-ship" --outcome "OUTCOME" --session-id "<the SESSION_ID Step B printed>" \
  2>/dev/null || true
```

Replace `OUTCOME` before running.

# Boots ship (closer 3 of 3)

Ship is the last closer stage. Review found the gaps, verify proved it runs, ship
turns it into the finished thing and closes the system. After ship, the system is
no longer in flight. That transition, from carrying it to having it, is the whole
point of Boots.

To the user this is just **"turning it into something you can use whenever, and
calling it done"** — never "ship", "the closer", or "the artifact". The one thing
they need from you here is dead simple: what it is now, and exactly how to use it
next time ("just say 'grade these applicants' and point me at the folder").

Follow all the rules in `boots/SKILL.md` — "How Boots talks": tell the user in the
chat, in plain words, where the finished thing lives and how they use it.

## Input

A system at `$BOOTS_HOME/systems/<slug>/system.md` with `stage: ship` and a `form:`,
meaning it already passed verify with real evidence. If it has not passed verify,
stop and send it back. Ship assumes verify succeeded, it does not re-run it.

## What you do

1. **Produce the usable form.** Verify proved the machinery works; ship makes it
   something someone actually uses. Read the palette for this system's platform,
   `${CLAUDE_PLUGIN_ROOT}/skills/boots/forms/<platform>.md` (default `cowork.md`), section
   "What shipped means per form". Confirm the form is not just present but live:
   - **skill / subagent / command** → in place and invocable, it triggers and runs
   - **hook** → wired in settings and confirmed firing
   - **MCP server** → connectable, its tools appear and answer
   - **Agent SDK app** → runnable with one documented command
   - **script / CLI** → invocable from its entry point, and listed wherever that
     entry point advertises its commands
   - **document** → the final file in its resting place, and something reads it
2. **Heal the artifact against the gaps verify surfaced (self-healing). Do this
   before you close anything.** Verify recorded an `artifact_gaps:` list — everything
   the operator had to do by hand that the artifact should do itself. This step is the
   difference between shipping *a tool* and shipping *a tool plus a human who knows its
   tricks*; only the first is real. Go through the list and for each gap, do one of two
   things, out loud:
   - **Encode it into the artifact** so the tool does it unaided next time — a new rule
     in the skill body, an added step, a forbidden-shortcut line ("never grade from a
     description; if the browser isn't connected, stop and get it connected"), a check.
     It goes into *the thing that runs* — not the system log, not a memory, not your
     chat summary. If the fix is "the tool should always X" or "never Y," and X/Y isn't
     written in the artifact, you have not healed it.
   - **Or defer it explicitly**, in one line, with the reason (genuinely out of scope,
     needs a capability that doesn't exist yet). A deferred gap is a decision on the
     record, not a thing you dropped.
   You may not close the system with an un-triaged gap. If verify's list was `none`,
   say so and move on. **A lesson that lands only in a memory or the chat, when it was
   a rule the tool must obey, is the failure this step exists to stop.**
3. **Check nothing shipping carries a secret.** Ship is the moment files become
   permanent in git history, so run the same sweep review ran, one last time,
   over everything being committed: no key or token literals, configs hold
   `${VAR}` expansions, session URLs live outside git. If the system uses a
   hosted connection, confirm it is registered at a scope that keeps the
   credential out of git and the connected account is still `ACTIVE`. A secret
   found here blocks the ship until it is moved out and rotated.
4. **Close the loop with wherever this came from.** Optional, and only if it applies:
   if the system was promoted out of a loose-ends store, set that record's status so
   the graveyard stops showing finished work as abandoned. Use the store's own
   command, guarded so a missing or changed backend can never block a ship. No
   store, or no id carried through → skip this silently.
5. **Close the system file:**
   ```markdown
   status: shipped
   stage: ship
   next_step: none, shipped <date>

   ## now
   last worked: <date>, this chat
   reality: shipped — <where the finished artifact lives and how it's invoked>
   you are here: done; usable whenever you want
   next physical action: none — use it, or run boots-extract for what it taught

   ## log
   - <date> ship, shipped <form>: <where the finished artifact lives and how it's used>
   ```

## Offer what it could grow into (don't push)

A shipped system that gets used is the seed of something bigger, and the user rarely
sees the next rung on their own. Once it's working, name the natural extensions in
plain English as an *offer*, not homework — pick only the ones that actually fit this
system, and only if it earned it by working:

- **Run it on a schedule** — "want this to run itself every morning and have a draft
  waiting?" (a scheduled job / cron, so it stops needing you to kick it off).
- **Chain it with a related one** — if the user has other shipped systems that share
  an input, offer to wire them into one command ("one link in → the post, the
  newsletter, and the summary out, in one go").
- **Stop it repeating work** — if it runs on a stream of similar things, offer a
  little tracking list so it skips what it already did.
- **Hand it to someone else** — if a teammate could use it, offer to package it so
  they get the user's taste and process without the user in the loop.

Keep this to one or two that genuinely fit, as a decision brief. Do not list all four
at every ship. The point is that finishing one system opens the door to a bigger one,
and Boots is the thing that notices.

**A ship is also the moment the whole picture changed, so mark the map stale.** A
newly finished thing is the strongest reason to re-read what all the user's systems
add up to: it may now answer a question outright, make another system redundant, or
supply the piece something else was waiting on. Note in `$BOOTS_HOME/map.md` that a system
shipped since its `last read` (or, if the file doesn't exist yet and there are three
or more systems, just say so) — the router picks that up and runs `boots-rethink` on
the next open. **Shipping a system does not answer the question that caused it**, and
this is the hook that stops a finished system quietly ending a line of enquiry that is
still open.

## Then hand to extract

A shipped system is the trigger for `boots-extract`. Tell the user plainly that it's
done and usable, then offer the next step in their words: **"Want me to jot down what
we learned building this, so the next one goes smoother?"** as a decision brief
(`Yes (recommended) / Not now / Something else`). Do not say "run extract" or "pull
the lesson". Do not auto-run it. On a yes, invoke `boots-extract`.

## The rule

Ship means done and used, not done and filed. If the artifact exists but nobody
can invoke, connect to, or read it, it is not shipped, it is another abandoned
thread with a nicer folder.


## Record the move (silent — do not narrate it)

When you mark this system shipped, record it so the board and `boots-surface` can see where systems flow and stall. Invisible bookkeeping (this suite's rule 5): run it, say nothing about it.

```bash
<bin>/boots-event --system "<slug>" --event shipped --from "<the stage the record was actually at before you moved it>" --to ship --outcome advanced 2>/dev/null || true
```

Fill every `<...>` from the record you just read — the folder slug under `$BOOTS_HOME/systems/`, and the real stages (not an assumed linear step: use the stage the record was actually at). If the user stalled rather than moved forward, change `--outcome` to `blocked`; if they walked away from it, `abandoned`.
