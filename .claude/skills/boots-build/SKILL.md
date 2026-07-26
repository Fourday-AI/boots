---
name: boots-build
description: >
  Boots pipeline, stage 3. Make the scoped slice in the form scope chose — a skill,
  subagent, slash command, hook, MCP server, Agent SDK app, script, or document —
  in its native Claude Code location. Produces the artifact the closer then reviews,
  verifies, and ships. Use when a system is scoped and the user says "boots-build",
  "make it", or a system reaches stage: build.
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
  printf '{"skill":"boots-build","ts":"%s","session_id":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > ~/.boots/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
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
  ~/.claude/skills/boots/bin/boots-telemetry-log --skill "boots-build" --duration "$_TEL_DUR" --outcome "OUTCOME" --session-id "$_SESSION_ID" 2>/dev/null &
fi
```

Replace `OUTCOME` before running.

# Boots build (pipeline 3)

Build is where the thing gets made. It takes the scoped slice and the form scope
chose and produces a real artifact, a file that exists, not a description of one.
Build is deliberately followed by three closer stages, so build's job is not to be
perfect, it is to make something concrete enough to review.

To the user this step is just **"making it"** — never "build", "the artifact", or
"the form". Follow all the rules in `boots/SKILL.md` — "How Boots talks", especially
rule 5 (don't narrate your plumbing) and the translation table. Build does its work
mostly in files, but still say in the chat, in plain words, what you made and where,
do not end with only a path.

## Input

A system at `~/.boots/systems/<slug>/system.md` with `stage: build`, a `## scope`
section naming the in-scope slice, a `form:` line, and a `target:`.

## What you do

1. **Read the scope and the form, then say back what you're making, in plain
   English.** Open with one line the user understands: "I'm making a tool you call
   by name that reads a folder of applicants and scores them for taste. That's the
   'skill' shape we picked, because grading is something you kick off yourself each
   round." Build only the in-scope slice. If you find yourself building something on
   the out-list, stop, that is scope creep for a later pass.
2. **Don't build cold if a starting point already exists.** Before writing from
   scratch, check whether the user already has a bootstrap you can seed from — an
   export from Claude's console skill builder, a scaffold from a local agent
   builder on their machine, an earlier version of this system. Ask in one line if
   it is plausible ("Do you already have a draft of this from the skill builder or
   anywhere on your computer? I can start from that instead of cold"). If they point
   at one, read it and build from it. Starting from their material beats a blank
   file.
3. **Draft the reference notes it needs — you write them, the user corrects them.**
   Scope named the reference knowledge this system must carry to be any good (what
   the user values, examples of "good", their brand, their voice). Do not ask the
   user to write these. This is rule 6 in `boots/SKILL.md`: read whatever you can
   reach — their site, their posts, past work they point at, what they've told you in
   this session — and *draft each note yourself*, then show it in the chat for
   correction. "I read your last ten posts and wrote up how your voice works, tell
   me what's off" beats "send me your brand guidelines." Store each note **bundled
   inside the artifact itself** — in the form's own directory (for a skill,
   `.claude/skills/<name>/reference/`), **not** in the boots state tree — so the
   finished system is self-contained: it reads the note every run, and someone handed
   just the skill folder gets the taste with it, not a dangling path into scaffolding
   they don't have. (The artifact is named and placed in step 5; put the note in its
   directory there, or draft it now and move it when you place the artifact.) If you
   genuinely can't reach the source (a private account, a file only they have), say
   exactly that and stage the spot for it. Skip this only if scope recorded "none".
4. **For a judgment system, do it once by hand first (the guided run).** If the form
   is a skill or subagent — anything whose quality is a taste call — do the task once,
   live, on one real example *before* you write the reusable version. Ask for a
   single real example (or use one already shared), work through it in stages, and at
   the taste-points offer options rather than one-shotting (rule 7): "here are three
   ways I could rank these, which matches how you think?" **Every correction the user
   makes here is gold** — "no, a career gap isn't a negative", "keep the summary to
   three lines" — because these become the permanent rules in step 5. Tell the user
   plainly why you're doing this: **"Let's grade one for real together first, so I can
   see how you actually think — then I'll bake that into the tool so it does it your
   way every time."** For non-judgment forms (a hook, a script, a doc) skip this;
   there is no taste to capture.
5. **Build it in its native location, and bake in what the guided run taught.** Read
   the palette for this system's platform, `.claude/skills/boots/forms/<platform>.md`
   (default `claude-code.md`), for where the chosen form lives and how it is shaped.
   If you need the current exact syntax (skill frontmatter, hook events, MCP config,
   Agent SDK packages), check the `/claude-code-guide` skill or the Claude Code docs
   now — do not trust a frozen snippet.

   **First, name the artifact for what it does — do not silently reuse the folder
   slug.** `<name>` below is what the user *types to invoke it* (`/reel-editor-scout`),
   so it is user-facing and permanent. The folder slug from clarify is usually right,
   but check it still fits what you actually built, and if the seed leaked through
   earlier (a folder called `cv-grader` for a taste screener), fix it here rather than
   shipping the wrong name. Because it's a name the user lives with, treat it as a
   taste-point (rule 7): offer them the name you'd pick and one alternative in one line,
   don't just slugify. A system called `/cv-grader` that actually scouts for taste is
   the exact failure this catches.

   - **skill** → `.claude/skills/<name>/SKILL.md` with frontmatter + a clear body
   - **subagent** → `.claude/agents/<name>.md` with its role, tools, and model
   - **slash command** → `.claude/commands/<name>.md`
   - **hook** → the command plus its wiring in `settings.json` under `hooks`
   - **MCP server** → the server process and the config that registers it
   - **Agent SDK app** → a Python/TS project using the Claude Agent SDK, with one
     documented run command
   - **script / CLI** → the script. If the repo has an established recipe for adding
     a unit of work (a `features/` or plugin dir with its own conventions), following
     it is one valid shape of this form — never the default for every system
   - **document / context** → the file in its resting place (a `CLAUDE.md`
     section, a reference doc, a memory)

   Three things make the artifact good, not just present:
   - **Encode every guided-run correction as an explicit rule** in the artifact, in
     the user's own words. The corrections *are* the spec.
   - **Point it at the reference notes and tell it to read them at the moment they
     matter**, not all up front — and point by the note's **full path inside the
     artifact**, e.g. "Before you score the portfolio, read
     `.claude/skills/<name>/reference/taste.md`." The notes live *inside* the artifact
     (step 3), so they travel with it; never point across into `state/`. A bare
     `reference/…` won't resolve at run time (the cwd isn't the skill dir), and a
     `~/.boots/systems/<slug>/…` path silently breaks the moment someone copies the skill
     without the scaffolding — that split is the exact failure this avoids.
   - **Bake in self-improvement, and cover both kinds of lesson.** For a skill or
     subagent, add a standing rule so it keeps getting better as it's used. It must
     capture two different things, routed to two different places:
     - **Taste corrections** ("that grade's too generous", "stop weighting follower
       count") → append to the reference notes, where the taste lives.
     - **Behavioral / operational rules** ("always open the real work in a browser,
       never grade from a description", "group files by person") → add to the artifact's
       own body, where its steps live — *not* the reference notes, and *not* only a
       memory outside the tool.
     Word it so the artifact knows the difference: *"If a run needed a workaround you
     weren't told to do, or the user corrected how you work (not just what you scored),
     write that as a new rule in the right place here — taste calls into the notes,
     how-you-operate rules into these steps — so the tool itself does it next time, not
     the person running it."* This is what turns one build into something that compounds
     **on its own**, instead of compounding only in the head of whoever runs it.
6. **Wire any outside connections scope named — you do the setup, the user only
   clicks the login link.** Follow the connection ladder from the palette's
   "Connect before you build" section, in order — marketplace first, hosted only
   after.

   **First, the marketplace route.** If scope recorded the app as **via marketplace**
   (or the app is a mainstream one and scope left the route open), look at the
   integrations available in your own public marketplace and, if the connector is
   there, wire the system through it — a first-party connector, no extra account for
   the user to create. Log that the system uses the marketplace connection (which
   connector, which account) in the system file. Prefer this whenever the marketplace
   covers the app; only when it comes up empty do you drop to the hosted route below.

   **Fall back to a hosted connection only when the marketplace has nothing.** If the
   scope's integrations list names a hosted connection (Composio), set it up now, by
   the route that fits the form (see "Connect before you build" in the palette):
   register the MCP endpoint in the Claude Code config for a skill, subagent, command,
   or hook; create a scoped SDK session and pass its MCP URL into the app for an Agent
   SDK app or script. Enable only the specific tools scope listed, never the whole
   toolkit. The login and secrets steps that follow are the hosted route's:

   **For the hosted route, first get the user logged in — a browser, not a key.** If they are not already
   logged into Composio, run `composio login`: a browser opens, they sign in, and the
   key is stored in the OS keyring (macOS Keychain). They never type or paste a key,
   and it never enters the chat. Say it in plain words — "a browser will open, sign
   in to connect your account, then come back."

   **Secrets discipline (the palette's rules apply here).** Mint the scoped session
   reading the key from the keyring — prefer the `composio` CLI (it reads the keyring
   directly), or if you mint through the SDK, resolve the key from the keyring for
   that one command only; never re-materialize it as a persisted export, a file, or a
   shell-profile line, and never print it into the chat. The master key stays in the
   keyring and never reaches the running artifact. The session URL is the *runtime*
   secret: write it into the built system's own `.env`, `${VAR}`-expanded from any
   config that needs it, and add the `.env` line to `.gitignore` yourself before you
   put anything in it — you write those files, the user does not. And remember the
   runtime home depends on how the system runs: a scheduled or headless system reads
   its secret from a file on disk (local-scope MCP config, or a dotenv `.env` /
   launchd `EnvironmentFile`), never from `~/.zshrc`, which an unattended process
   does not source.

   Then drive the login handoff, which is genuinely the user's job (rule 3):
   generate the connect link and say in plain words **"I've set up the connection
   to your Gmail. Click this link to log in, then tell me when you're done."**
   Confirm the account shows connected before relying on it. Default to plain words —
   "a ready-made connection that handles the login for you," not "Composio" or "MCP."
   But the one place the real name is unavoidable is the `composio login` you just
   walked them through: there, do not drop "Composio" cold — introduce it once, what
   it is (the service behind that ready-made connection) and how it works for them
   (they sign in through their browser once, then connect their Gmail the same way,
   and the system only reads), then the name is fine. Skip this step if scope
   recorded no integrations.
7. **Stage the place for the test examples — proactively, before the user asks.**
   This is rule 3 in `boots/SKILL.md` ("do the prep, don't ask permission to prep")
   and it is the thing that got missed last time: the user said "I'll give you
   examples" and had to figure out where to put them. Do not repeat that. Create the
   fixtures folder now and drop a short README naming exactly what goes there, using
   the open-ended input set scope predicted:
   ```bash
   mkdir -p ~/.boots/systems/<slug>/inputs
   echo ~/.boots/systems/<slug>/inputs   # the ABSOLUTE path (~ expands) to tell the user how to find the folder
   ```
   Write `~/.boots/systems/<slug>/inputs/README.md` — this is the one surface the user
   actually sees once they're standing in the folder, so it says both **what to drop
   in** and **what the tool does with it** (mirror the flow sentence from the chat, so
   it's reinforced right where they are). E.g. "Drop each applicant's CV, cover letter,
   and any portfolio/Instagram/website link here. One file or one folder per person is
   fine; links can go in a `.txt`. — The tool reads everything in this folder when it
   runs and writes the finished results to the `output` folder next to it, so that's
   where to look afterward." Then tell the user in the chat — **describe how to find the folder AND explain what the tool
   does with the files** (rule 3 in `boots/SKILL.md`, "make the landing spot findable,
   explain the flow"). Don't dump the raw repo path; give them the absolute path plus
   the way to reach it, and one plain sentence on the flow so they know these files
   matter and where the results land:

   > "I made a folder on your computer for the examples. To find it: in Finder press
   > **⌘⇧G**, paste `~/.boots/systems/<slug>/inputs`, and hit enter (or just ask me
   > to open it). Drop 2-3 real examples in there — your spreadsheet, a couple of CVs,
   > whatever this tool reads. **Here's how it works:** the tool reads whatever's in
   > that folder each time it runs, so that's where it gets your real data; when it
   > runs it'll [drop the finished files in the `output` folder next to it / show you
   > the results here in the chat]. Tell me when your files are in and I'll test it for
   > real."

   Do NOT just hand them the `~/.boots/systems/<slug>/inputs/` path with no way to find it
   and no picture of what the drop does — that bare path is exactly the instruction a
   nontechnical user can't act on; they'll drop the file somewhere random and stall.
   The user should leave knowing where the folder is, what the tool does with what they
   put there, and where the results will show up.
8. **Point the system's `## artifact` section at what you made**, and note the
   reference notes, the fixtures folder, and any wired connections so review and
   verify know where the real examples, the knowledge, and the live tools live.
9. **Do not self-certify it as done.** That is what review, verify, and ship are
   for. Build hands off unproven on purpose.

## Write to the system file

```markdown
status: reviewing
stage: review
next_step: run boots-review to find what's wrong before verify

## now
last worked: <date>, this chat
reality: <what actually exists now — "runner written at <path>, not yet run">
you are here: <the user's situation in their words — "it's made but unproven">
next physical action: <the concrete next move — "read it over, then test on 3 real examples">

## artifact
<path to what was built, one line on what it is and its form>

## log
- <date> build, made <artifact> as a <form>, covering the in-scope slice
```

Keep `## now` honest as the work moves: if you go past "made it" in this same chat —
you ran it, it produced output, it hit an error, you fixed something — update `##
now` and the header fields to match *that*, not the tidy "just built it" state. An
interrupted build that already ran the thing must not read as "not run yet." Append a
`sessions/<date>_<label>.md` synthesis before the chat ends (continuity contract).

## Hand off

Say in the chat what you built and where, and remind the user you're waiting on
their real examples in the `inputs` folder (refer to it the way you described it to
them — "the examples folder" — not the raw path). Then say what review does in plain
English: **"Next I'll read back over what I made and catch anything wrong or
half-done before we test it. That's the 'review' step."** Drive it with a decision
brief: `Run boots-review now? (recommended) / Not yet / Something else`. Do not
claim it works, you have not checked. If they pick yes, invoke `boots-review`.


## Record the move (silent — do not narrate it)

When you move this system to its next stage, record it so the board and `boots-surface` can see where systems flow and stall. Invisible bookkeeping (this suite's rule 5): run it, say nothing about it.

```bash
~/.claude/skills/boots/bin/boots-event --system "<slug>" --event transition --from "<the stage the record was actually at before you moved it>" --to build --outcome advanced 2>/dev/null || true
```

Fill every `<...>` from the record you just read — the folder slug under `~/.boots/systems/`, and the real stages (not an assumed linear step: use the stage the record was actually at). If the user stalled rather than moved forward, change `--outcome` to `blocked`; if they walked away from it, `abandoned`.
