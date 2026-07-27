---
name: boots-scope
description: >
  Boots pipeline, stage 2. Cut a clarified system to its smallest useful version,
  name what is out, and decide the form it takes (skill, subagent, hook, MCP
  server, Agent SDK app, script, doc). Use when a system has a foundation and the
  user says "boots-scope", "what's the smallest version", or a system reaches
  stage: scope.
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
# so a Cowork session and a local one starting the same second mint the SAME id, and
# each finalizes the other's pending marker as a crash. The random suffix separates them.
_SESSION_ID="$$-$(date +%s)-${RANDOM:-0}"
_TEL_START=$(date +%s)
# Flush anything the previous session left queued (backgrounded, rate-limited,
# tier-gated, silent without a backend). Sessions on short-lived hosts can end
# before their last event ships; this is the catch-up.
[ "$_TEL" != "off" ] && [ -x ~/.claude/skills/boots/bin/boots-telemetry-sync ] && ~/.claude/skills/boots/bin/boots-telemetry-sync >/dev/null 2>&1 &
echo "TELEMETRY: ${_TEL:-off}"
echo "TEL_PROMPTED: $_TEL_PROMPTED"
echo "PROACTIVE: $_PROACTIVE"
echo "BRANCH: $_BRANCH"
# Ops run-start marker (Layer B). If this session dies before it logs an end event,
# the marker is left behind; the next boots-telemetry-log run finalizes any other
# session's stale marker as outcome:unknown, so a crash is recorded, not lost.
if [ "$_TEL" != "off" ]; then
  printf '{"skill":"boots-scope","ts":"%s","session_id":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > ~/.boots/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
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
  ~/.claude/skills/boots/bin/boots-telemetry-log --skill "boots-scope" --duration "$_TEL_DUR" --outcome "OUTCOME" --session-id "$_SESSION_ID" 2>/dev/null &
fi
```

Replace `OUTCOME` before running.

# Boots scope (pipeline 2)

Scope is where ambition meets a week. It takes the write-up from the last step and
produces two decisions: the smallest version that is genuinely useful, and the shape
the thing takes. Most systems die because they were planned as the whole vision.
Many others get built in the wrong shape because nobody chose the shape, they
inherited whatever the repo already used. Scope kills both failures.

To the user, none of this is called "scope," and you never open it with a bare
abstraction. **"Let's pick the smallest version you'd actually use, and the shape it
takes"** is the exact sentence that lost the last user: someone new to this does not
yet know that their one idea contains several possible slices, or that a thing has a
"shape," so those words land as noise — "smallest version of *what*? shape of *what*?"
**Anchor every question to the concrete pieces they already named.** Read their
foundation back as a plain list of what it does, then propose starting with one of
them: "You said it needs to A, B, and C — I want to start with just A, the piece that
already earns its keep this week, and leave B and C for later. Sound right?" That *is*
the cut, put in their own nouns. Make the two decisions together, but never say
"scoping," "the slice," "the form," "the shape," or "the out-list" as a standalone
word; if an abstraction slips in, cash it out in the same breath in their concrete
things (see the translation table in `boots/SKILL.md`).

Follow all the rules in `boots/SKILL.md` — "How Boots talks": the cut lands in the
chat first and the file is the saved copy, and you drive the handoff at the end.
The two decisions are not the same kind, and treating them as the same is what lets
the wrong form slip through. **The cut is the user's call** — it's their week and
their appetite, so put it to them and take their answer. **The form is your call to
recommend** — it is a technical choice they have told you they cannot evaluate (they
do not know what a "skill" or a "subagent" is), so you own the recommendation and
they veto it *with a reason*, not by toggling. Never hand the form over as a free
choice, and keep the two as separate decisions — do not fold them into one toggle
where they read as equal preferences.

## Input

A system at `~/.boots/systems/<slug>/system.md` with `stage: scope` and a
`## foundation` section.

## What you do

1. **Read the foundation.** Find the one capability that, alone, would already be
   useful this week.

   **Then, before you cut anything, look at what the user already has.** This is the
   last cheap moment — after this, every mistake costs a build. Read `~/.boots/map.md`
   if it exists, then the `question:`, `target:`, `form:`, `status:` and `##
   scope` of every other `~/.boots/systems/*/system.md`. You are asking four things,
   in this order:

   - **Does this already exist?** Not "is it similar" — does a system already in the
     home do this job, or most of it? If one does, the honest recommendation is
     almost never "build a second one." It is **extend the one you shipped**, and you
     should say so out loud even though the user came here to start something new.
     This is the failure this check exists to prevent: a working system quietly
     duplicated by a weaker rebuild, because nobody compared. The tell is two systems
     whose `question:` lines mean the same thing, or that read the same source for the
     same purpose. Put it to the user as a real decision — `Extend <existing> instead
     (recommended) / Build it fresh anyway / They're actually different` — and if they
     build fresh, make them say what this one does that the other can't, and record
     that line in `## scope`. "I'd rather start clean" is a preference, not a reason;
     name the cost (two half-versions of one tool, both half-maintained) before you
     accept it.
   - **Does it serve a question already in play?** If it does, this system is another
     limb of something the user is already pushing on, not a fresh start. Say that in
     one plain line, and carry the same `question:` rather than inventing a new one.
   - **Does something it needs already exist?** Another system may already hold the
     connection, the reference note, or the exact data this one wants. Reuse beats
     rebuild, and it is invisible unless you look.
   - **Does something it produces get used by anything?** If its output would feed a
     system already in the home, note it in `## scope` now, so build knows where the
     output should land instead of dying in a folder.

   Keep this short in the chat — one or two lines unless you actually found
   something. **Finding nothing is the normal result and needs no ceremony.** But
   when you do find an overlap, it outranks everything else in this step: there is no
   point cutting the smallest version of a thing that should not be built at all.
2. **Force the cut.** If you could only ship five percent, what five percent? Not
   the MVP, the actual smallest thing that stands on its own. Show it in the chat as
   two plain lists — **"what's in the first version"** and **"what we're leaving out
   for now"** — spelled out in full, not as "the slice" and "the out-list." **Label
   each option by what it concretely does, never by a size word.** "Just the three
   accounts you watch" vs "every account in the sheet" lands; "the smallest version"
   vs "the next batch up" does not — a size word with no concrete referent is exactly
   what confused the last user. Put it to the user as a decision brief against that
   next-bigger option, named in full, so what goes in is a choice they made. Name what
   is left out, item by item.
3. **Decide the platform and the form. This is the step that was missing.** The
   platform is the runtime the system runs on, default `claude-code`; set it
   explicitly only if the user is targeting something else. Read the palette for
   that platform, `~/.claude/skills/boots/forms/<platform>.md` (default
   `claude-code.md`). Pick the form from the *nature of the work*, not from what
   the repo already contains:
   - synthesis / judgment / reading messy input / conversation → skill or subagent
   - deterministic transform with a clean pass/fail → script / CLI
   - must fire automatically on an event → hook
   - a new capability or live data → MCP server
   - runs unattended, outside a chat → Agent SDK app
   - makes every future session smarter → document / context

   **When the work needs an outside app, look for a ready-made connection before
   deciding to build one — and check your own host's marketplace first, a
   third-party provider only after.** The order is a ladder; the palette's "Connect
   before you build" section carries the concrete steps for this host:
   1. **Look at the integrations available in your own public marketplace** — the
      first-party and official connectors your tool ships. If one covers the app,
      that's the route: an official connector is more trustworthy than a third-party
      middleman, and it spares the user a second account to sign up for. Record the
      app as connecting **via marketplace**.
   2. **Only if the marketplace comes up empty** for that app, fall back to a hosted
      provider (the named default; see the palette). Record it **via hosted**.
   3. Build a **custom** connection only when the API is niche, internal, or
      self-hosted — the same reason you'd write any code a library already covers.

   To the user this is one plain-English decision either way, because rungs 1 and 2
   present identically: **"a ready-made connection that handles the login for you"**
   (recommended when the app is covered) vs **"we build our own connection"** (the
   wrong fit unless the API is niche, internal, or self-hosted). Which ready-made
   route you took — marketplace or hosted — you resolve silently; the user need not
   hear a provider name to tap the option. **Keep any provider name out of the option
   the user taps.** A name like "Composio" is one they never chose and have never
   heard of; dropping it bare into a question is exactly the bug that confused the
   last user — and on the marketplace route it need never appear at all. If a real
   product name does have to surface (only the hosted fallback forces it, at setup),
   gloss it in the same breath — what it is (the service behind that ready-made
   connection) and how it'll work for them (they connect their Gmail through it once,
   it handles the login, the system only reads); see the translation table in
   `boots/SKILL.md`. Then record exactly which apps and which
   specific actions the system needs (fetch emails yes, send emails no) — that
   list is what keeps the connection least-privilege at build. Default it to
   read-only actions; anything outward-acting (send an email, post a message,
   delete) goes in only as its own explicit decision with the user, because the
   system will read untrusted content through this connection and read-only is
   what limits the damage if that content tricks it.

   Put the form to the user as its own decision brief, **and explain the choice in
   plain English — the user does not know what a "skill" or a "subagent" is, and
   should not have to.** Do not present `skill` vs `subagent` as bare labels.
   Present what each *means in practice*, with a concrete example tied to their
   system, then your recommendation and why the nature of *their* work points there:

   > **Why this matters:** this decides how the thing is actually built and run.
   >
   > - **A tool your assistant runs as part of your session** (a "skill"): a set of
   >   instructions your AI follows itself — you say "grade these applicants" or point
   >   it at a folder, and it does the job right there, its working visible to you. ←
   >   recommended: grading a pile of CVs is one focused job you kick off and want to
   >   see, so there's nothing to gain from handing it off.
   > - **A separate worker the AI hands the job to** (a "subagent"): it goes off with
   >   its own fresh attention and its own tools, does the chunk of work out of sight,
   >   and comes back with just the result. Worth it when the job is big and messy and
   >   you don't want its rummaging filling up your main thread, or when you want
   >   several running at once — *not* because it "runs on its own" (a skill can be put
   >   on a schedule too), but because it keeps a heavy job in its own space.
   > - **An automatic trigger** (a "hook"): fires every time some event happens,
   >   without you asking.

   The real axis between the first two is **where the work happens** — inside your
   own session (skill) versus handed to a separate worker with its own context
   (subagent) — not foreground versus background. Both a skill and a subagent can be
   set to run unattended or on a schedule, so "it runs in the background" is never the
   reason to pick a subagent; isolation and running many at once are. Do not draw the
   choice as watch-it versus set-and-forget.

   **Do not let the repo choose.** If you catch yourself picking a form only because
   the repo you happen to be standing in is already full of that shape, that is the
   exact bug this step exists to stop. State your recommendation in their words, name the runner-up, and record
   the technical form name in the system file (chat stays plain, the file stays
   precise).

   **Put the recommendation *inside* the decision, not just above it.** When you
   render the form choice as an `AskUserQuestion`, the recommendation and the stakes
   have to live in the options the user actually taps — not only in the prose before
   it. The recommended form carries the `(recommended)` label, and its option text
   says why *their* work points there. The runner-up's option text says **why it is
   the wrong fit here** — do not describe it neutrally, and do not sell its upside,
   or the user taps it not knowing they are overriding you. A bare two-button toggle
   ("in-your-session tool" / "hand-off worker instead") is the failure this step
   exists to prevent: the walk-through lives in the prose, but the decision gets made
   on the buttons, so the buttons must carry the verdict.

   **If the user picks against your recommended form, do not just accept it.** Restate
   in one line the tradeoff they are taking on, ask what makes them lean the other
   way, and switch only if the reason holds up. Never reverse your own reasoning to
   agree with the tap — if you just called a form the wrong fit, you do not get to
   invent a fresh upside for it the moment they choose it. Hold the recommendation
   until you hear a real reason; a real reason is a fine reason to switch, and a
   silent override is not one.
4. **Name the real examples it'll be tested on.** A system is only done when it has
   run on real inputs, so decide *now* what those inputs are, so build can stage a
   place for them and verify can actually run. Predict the widest plausible input
   set from the foundation (rule 4 in `boots/SKILL.md`): for a CV grader that is not
   just "a CV" but CV + cover letter + portfolio link + Instagram + personal site.
   Write it into the scope as what feeds the system, and tell the user in the chat:
   **"To test this for real I'll need 2-3 actual examples. I'll make a folder for
   them at build."** This is the step that stops a system shipping unproven.
5. **Name the reference notes that make it good.** Separate from the inputs it
   processes, name the knowledge the system must *carry* to produce output worth
   having (see "Context the system needs to be good" in `boots/SKILL.md`). For a CV
   grader: a short page on what this founder values, a couple of past hires they
   rated. This is the single biggest lever on quality, so it is a scope decision, not
   a build afterthought. Do not assign it to the user as homework — record that build
   will *draft* each note and the user will correct it (rule 6). If the system needs
   none (a pure deterministic transform), say so explicitly.
6. **Set a form-appropriate target.** The `target:` is the proof of done for the
   chosen form, from forms.md, not always `exits 0`. A skill's target is "invoked
   on real examples, it does the thing." An MCP server's is "a tool call returns a
   real value." Only a script's target is an exit code. Getting this right here is
   what lets `boots-verify` check the real thing later.

## Write to the system file

```markdown
status: scoped
stage: build
platform: <platform, default claude-code>
form: <the chosen form>
next_step: run boots-build to make <the in-scope thing> as a <form>
target: <the form-appropriate proof of done, from forms/<platform>.md>

## now
last worked: <date>, this chat
reality: scoped — smallest slice and form chosen, nothing built yet
you are here: <the user's situation — "we've settled what to make and its shape">
next physical action: make <the in-scope thing> as a <form>

## scope
form: <chosen form> — <one-line why the work's nature points here>
relation to existing systems: <"none — nothing else touches this", or one of
  extends / overlaps / feeds / fed-by <slug>; and if built fresh despite an overlap,
  the reason it earns its own existence>
in:
- <the smallest useful thing>
out:
- <named thing not being built yet>
- <another>
inputs (what feeds it, for the test fixtures build will stage):
- <the widest plausible real inputs, e.g. CV + cover letter + portfolio link + Instagram>
integrations (outside apps it connects to; "none" if it stays local):
- <app> via <marketplace (host's own connector) | hosted (Composio) | custom> — tools: <the specific actions, e.g. GMAIL_FETCH_EMAILS>
reference notes (what it must know to be good; build drafts each, user corrects):
- <e.g. what this founder values in a hire; 2-3 past hires they rated — or "none" if a pure transform>

## log
- <date> scope, cut to <slice>; form: <form> (over <runner-up>)
```

## Hand off

Name the slice and the form in one sentence each, in plain English. Then say what
build does for them: **"Next I'll actually make it, and set up a folder for you to
drop your real examples in so we can test it. That's the 'build' step."** Drive
the next step with a decision brief: `Run boots-build now? (recommended) / Not yet
/ Something else`. If they pick yes, invoke `boots-build`.


## Record the move (silent — do not narrate it)

When you move this system to its next stage, record it so the board and `boots-surface` can see where systems flow and stall. Invisible bookkeeping (this suite's rule 5): run it, say nothing about it.

```bash
~/.claude/skills/boots/bin/boots-event --system "<slug>" --event transition --from "<the stage the record was actually at before you moved it>" --to scope --outcome advanced 2>/dev/null || true
```

Fill every `<...>` from the record you just read — the folder slug under `~/.boots/systems/`, and the real stages (not an assumed linear step: use the stage the record was actually at). If the user stalled rather than moved forward, change `--outcome` to `blocked`; if they walked away from it, `abandoned`.
