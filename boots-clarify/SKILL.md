---
name: boots-clarify
description: >
  Boots pipeline, stage 1. Turn a vague AI ambition into a foundation: a reframed
  problem, the capabilities it implies, and a paragraph in the user's own words.
  Creates the system file. Use when the user says "boots-clarify", "clarify what I
  want", or brings a fuzzy "I want AI to do X" with no concrete deliverable.
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
# so a session in the cloud and one on the laptop starting the same second mint the
# SAME id, and each finalizes the other's pending marker as a crash. Hence the salt.
_SESSION_ID="$$-$(date +%s)-${RANDOM:-0}"
_TEL_START=$(date +%s)
# Flush anything the previous session left queued (backgrounded, rate-limited,
# tier-gated, silent without a backend). A session on a short-lived host can end
# before its last event ships; this is the catch-up.
[ "$_TEL" != "off" ] && [ -x ~/.claude/skills/boots/bin/boots-telemetry-sync ] && ~/.claude/skills/boots/bin/boots-telemetry-sync >/dev/null 2>&1 &
echo "TELEMETRY: ${_TEL:-off}"
echo "TEL_PROMPTED: $_TEL_PROMPTED"
echo "PROACTIVE: $_PROACTIVE"
echo "BRANCH: $_BRANCH"
# Ops run-start marker (Layer B). If this session dies before it logs an end event,
# the marker is left behind; the next boots-telemetry-log run finalizes any other
# session's stale marker as outcome:unknown, so a crash is recorded, not lost.
# It carries its own platform so the crash is attributed to the host it died on,
# not to whichever host later notices the corpse.
if [ "$_TEL" != "off" ]; then
  _PLATFORM=$(~/.claude/skills/boots/bin/boots-platform 2>/dev/null || echo "claude-code")
  printf '{"skill":"boots-clarify","ts":"%s","session_id":"%s","platform":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" "$_PLATFORM" > ~/.boots/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
fi
```

## Updates (act on the preamble output)

If the preamble printed `UPGRADE_AVAILABLE <old> <new>`: read `~/.claude/skills/boots-upgrade/SKILL.md` and follow its inline upgrade flow (auto-upgrade if configured, else a 4-option AskUserQuestion: Yes / Always / Not now / Never). If it printed `JUST_UPGRADED <old> <new>`: say "Running Boots v{new} (just updated!)" and continue.

If `PROACTIVE` is `false`: don't proactively suggest other Boots skills this session.

## Telemetry consent (ask once — the one thing here you may surface)

Everything else in this preamble is silent plumbing. This is the exception: a single, one-time question. If `TEL_PROMPTED` is `yes`, skip it entirely. If `no`, ask once via AskUserQuestion, then always `touch ~/.boots/.consent-prompted` regardless of the answer.

Ask it in one breath, in your own plain voice — not as a policy notice. It must say three things, or the person cannot answer it honestly: **what Boots does with them** (walks a system from idea to finished, one stage at a time), **what gets sent** (only the stage a system reached and when — "scoped", "built", "stalled at verify"), and **who sees it** (the people who build Boots, privately — it is not posted anywhere, and no other user ever sees your data). Say plainly that your code, your files, and the names of what you're building never leave your machine. Never use the word "community" as a label — to a new user it reads as *other users can see this*, which is false.

Ask with AskUserQuestion, header `Share usage`, using these three options **verbatim** — the words are the point:

- **"Share my progress" — the full picture; recommended.** Description: sends the stage each of your systems reaches, tied to one random ID so the maintainers can see a whole journey and where it broke. → `~/.claude/skills/boots/bin/boots-config set telemetry community`
- **"Counts only"** — no ID, so they see totals but can't tell one person's run from another. → `~/.claude/skills/boots/bin/boots-config set telemetry anonymous`
- **"Nothing"** — Boots sends nothing at all. → `~/.claude/skills/boots/bin/boots-config set telemetry off`

Ask once and take the answer. Do not re-ask, re-frame, or push a second time if they decline — one question, then straight into their work. They can change it later with `~/.claude/skills/boots/bin/boots-config set telemetry <tier>`; mention that only if they hesitate.

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
  ~/.claude/skills/boots/bin/boots-telemetry-log --skill "boots-clarify" --duration "$_TEL_DUR" --outcome "OUTCOME" --session-id "$_SESSION_ID" 2>/dev/null &
fi
```

Replace `OUTCOME` before running.

# Boots clarify (pipeline 1)

Clarify is the front door, and for most users the very first time they meet Boots.
It takes a one-sentence ambition and produces the short write-up the rest of the
steps read. Internally that one sentence is the "seed" and the write-up is the
"foundation", but **the user never hears either word** — to them this step is just
"working out what you actually want." Keep their exact sentence verbatim in the
file, do not clean it up. The job is to thicken that sentence until something can be
built on it, not to answer the request.

Because this is the first contact, open plainly. Something like: **"Let's work out
what you actually want to build before making anything. I'll ask a few questions,
push back where your idea is fuzzy, then write it back to you as one short
paragraph you can react to."** Do not say "logging your seed" or "let's build your
foundation" — that means nothing to a newcomer and makes them feel lost.

Follow all the rules in `boots/SKILL.md` — "How Boots talks", especially rule 5
(don't narrate your plumbing) and the plain-English translation table: the write-up
lands in the chat first and the file is the saved copy, and you drive the handoff at
the end instead of going quiet. Every choice you put to the user is a decision brief
in the AskUserQuestion format from `boots/SKILL.md`.

## What you do

1. **Hold the seed verbatim — but do not create the folder yet.** Note their exact
   sentence, unchanged; you'll save it when you create the file at the end. **Do not
   `mkdir` anything now.** The folder's name is the system's permanent identity, and
   right now all you have is what the user *said*, not what you're actually building —
   those are different things, and you won't know the second until after the reframe
   (step 4). Naming it from the raw ambition is exactly how you end up with a folder
   called `cv-grader/` for what the reframe reveals is a taste-based talent scout. Wait.
   You create the folder once, at step 5, named from the settled understanding.

2. **Pull evidence** from the user's AI history so the reframe is grounded, not
   guessed. Invoke `boots-prospect` (or reuse the field it already surfaced) — it
   mines every backend the user has, from a loose-ends store to their memory to past
   transcripts, and hands back the real threads with their source. Fall back to
   whatever history the user points at, or their own words in this session. Quote
   the real threads back to them in the chat. The ambition they keep circling is the
   strongest evidence you have.

   **Also read `~/.boots/map.md` if it exists** (Boots' standing answer to what this
   person is building overall, and the questions they already have in play). If this
   new ambition serves a question that is already on the map, say so in one plain
   line — "this sounds like part of the same push as X" — and note the connection;
   you will record it as the system's `question:`. That is the cheapest moment there
   is to notice you are starting a second limb of something you already have.

3. **Draft the forcing answers from the evidence, then confirm them — don't ask
   cold.** The forcing questions are: who uses the output (a real name), what
   they do today instead, the one thing they would miss most if it broke, the
   smallest useful five percent, what they noticed that others missed, and what
   should be true in twelve months. For each one the evidence can answer, draft the
   likely answer and put it to the user as a decision brief —
   `Confirm / Adjust / It's actually something else` — so they are correcting a
   grounded guess, not filling a blank. Ask the genuinely open ones (usually the
   twelve-month one) as a short prose block. This is what "well-informed questions"
   means: your history does the drafting, the user does the correcting.

   **Two more you must not skip — they are the ones that got missed last time:**

   - **What can it learn from / pull on?** Two different things hide here, and you
     want both:
     - **What feeds it each time it runs** — the material it processes. A brand's
       Instagram, a website, past examples, a folder of files, a link the user would
       paste. The seed "grade their CVs" hid that the real inputs are CV *and* cover
       letter *and* a portfolio reel *and* an Instagram *and* a personal site. Name
       the widest plausible set of inputs out loud (rule 4 in `boots/SKILL.md`) and
       let the user confirm or cut it. Missing this is how a system ends up too
       narrow to be useful on day one.
     - **What it needs to *know* to be any good** — the reference knowledge it
       carries (see "Context the system needs to be good" in `boots/SKILL.md`). For a
       CV grader: what *this* founder values in a hire, examples of people they rated
       highly before, the kind of role they hire for. Output quality is mostly this,
       not the prompt. Crucially, do not ask the user to write these — tell them you
       can draft them: **"To grade like you and not like a generic recruiter, it'll
       help if it knows what you actually look for. I can take a first pass at writing
       that up from what you tell me, and you fix it."** That is rule 6; naming it
       here is what lets scope and build carry it through.
   - **What is this FOR — what do you need to find out, or what decision does it
     feed?** This is the one question about *why the system exists* rather than what
     it does, and it is the field the rest of Boots reads to see how your systems fit
     together. Everything else in this step describes the machinery; this describes
     the point. Ask it plainly — **"Say this one gets built and works perfectly. What
     does that let you find out, or decide, that you can't today?"** — and keep
     pushing until the answer names a real thing, not a restatement of the build.
     "It gives me a ranked shortlist of testers" is the *output*, not the answer. The
     answer is "I need to know whether this works for people I've never met." Test it
     the same way every time: **if the system worked perfectly and you learned or
     decided nothing new, the answer is wrong — dig again.**

     Then record it in one line as `question:`. Keep it short and in their words.
     Two systems that share a question are two limbs of one job, and that is
     invisible to Boots unless this line exists — it is what later lets Boots say
     "these four are all the same push" or "you already built this." Without it the
     only thing Boots can compare across systems is plumbing.
   - **What does it do for you vs hand back?** Draw the autonomy line explicitly.
     What should the AI do on its own in the background (read the brand, fetch the
     material, draft the first pass) versus stop and hand to the user for a taste
     call? Founders assume the AI can either do everything or nothing; your job is to
     name the real boundary, because it shapes what gets built. Put it as a decision
     brief: what runs on its own, what waits for you.

4. **Reframe, one premise at a time.** Push back on the seed at the noun level. The
   reframe must differ from the seed. Name the three load-bearing premises and put
   EACH through its own decision brief (`Agree / Disagree / Adjust`), with a
   recommendation and the evidence behind it. This is the sharpest moment in
   clarify — a real decision with a grounded recommendation, made in the chat, not
   a paragraph the user skims.

5. **Write the foundation, then create the system named from it.** Six sentences
   max, second person, the user's vocabulary, one bolded punch line. Render the full
   paragraph in the chat as your output. **Now — and only now — create the folder**,
   with a slug that names what the reframe settled on, not the seed:
   ```bash
   mkdir -p ~/.boots/systems/<slug>
   ```
   Derive `<slug>` from the reframed problem in the foundation. If the seed was "grade
   their CVs" but the foundation says "a talent scout that screens for taste," the slug
   is `reel-editor-scout` or `taste-screener`, never `cv-grader`. Then save the same
   foundation text to the file, keeping the user's verbatim seed sentence inside it (the
   file records both what they first said and what it became). The chat is where the
   user reads it; the file is the copy.

## Write to the system file

```markdown
# System: <slug>

status: clarifying
stage: scope
platform: claude-code
form: (decided at scope)
next_step: run boots-scope to cut this to its smallest useful version and pick a form
target: n/a
question: <what this needs to find out, or the decision its output feeds — one line, their words>


## now
last worked: <date>, this chat
reality: just clarified — a foundation paragraph exists, nothing built
you are here: <the user's situation — "we've named what you're really after">
next physical action: cut it to the smallest version worth building, and pick its shape

## foundation
<the paragraph — the same text you showed in the chat>

## log
- <date> clarify, foundation written from <N> threads of evidence; question: <the one line>
```

**Then add it to the map.** Append the system under its question in `~/.boots/map.md`
(create the file from the shape in `boots/SKILL.md` if it does not exist yet). If the
question is new, add it as a new question with this system as its only limb. This is
two lines of upkeep and it is what makes the whole set legible later — a system whose
question never reaches the map is a system nothing can reason about.

Append a `sessions/<date>_<label>.md` synthesis before the chat ends, and keep `##
now` current if this chat goes further than clarify (continuity contract).

## Hand off

Do not go quiet. Name the reframed problem in one sentence. Then say in plain
English what happens next: **"Next I'll cut this down to the smallest version you'd
actually use this week and pick what shape it takes. That's the 'scope' step."**
Drive it with a decision brief: `Run boots-scope now? (recommended) / Not yet /
Something else`. If they pick yes, invoke `boots-scope`.


## Record the move (silent — do not narrate it)

When you create this system's record, record it so the board and `boots-surface` can see where systems flow and stall. Invisible bookkeeping (this suite's rule 5): run it, say nothing about it.

```bash
~/.claude/skills/boots/bin/boots-event --system "<slug>" --event created --to clarify --outcome advanced 2>/dev/null || true
```

Fill every `<...>` from the record you just read — the folder slug under `~/.boots/systems/`, and the real stages (not an assumed linear step: use the stage the record was actually at). If the user stalled rather than moved forward, change `--outcome` to `blocked`; if they walked away from it, `abandoned`.
