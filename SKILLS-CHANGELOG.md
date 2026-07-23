# Skills changelog

What changed in the boots skill suite, one entry per improvement session, newest
first. Entries are generated from git history by the `skills-changelog` skill —
inferred from the diff, not written by hand. Each entry ends with a
`Tracked up to:` marker that tells the next run where to start.

<!-- New entries go directly below this line. -->

## [2026-07-23] Community funnel goes live
**Boots can now show the aggregate community funnel — where systems across all
opted-in installs flow and stall — and opted-in installs can contribute to it.**

The telemetry backend was fully built but dormant (no project provisioned). It's now
live and wired end to end: an opted-in install ships its funnel (systems moving
through stages) and ops runs to a hosted endpoint, and `boots-analytics --community`
reads back the aggregate — weekly-active installs, shipped/abandoned counts, and the
stage systems most often die at. Privacy is enforced on your machine before anything
leaves it: system names are hashed, repo names are stripped, and it's **off by default**
— nothing is sent unless you explicitly opt in.

### Added
- **boots (community funnel):** `boots-analytics --community` now returns real
  aggregate stats from the hosted backend instead of "not available yet". Opted-in
  installs contribute via `boots-telemetry-sync`. Still off by default; the anon key
  in the public config is read-blocked by row-level security (it can only append
  events, never read anyone's data).

### Fixed
- **boots (telemetry ingest):** per-install records now actually persist. The
  insert-only privacy model made the previous upsert silently fail, so the
  installations stream was dropping every record.

_Tracked up to: ee7071e5f7b5c8c9c19962d6eda0b5207ec09450_

## [2026-07-23] Update notices work on private installs
**Boots now reliably tells you when a newer version is available — even when your
install points at a private repo.**

The update check used to fetch its version marker from a public CDN, which silently
returns "not found" for private repositories. On those installs the check quietly
assumed you were up to date and never surfaced an upgrade. It now falls back to an
authenticated fetch, so the "a new Boots is available" nudge actually fires.

### Fixed
- **boots (update check):** detects available upgrades on private-repo installs
  instead of silently reporting up-to-date. The public fast path is unchanged; the
  authenticated fallback only kicks in when the public fetch returns nothing. Verified
  end to end across every branch — upgrade-available, up-to-date, snooze, force,
  dev-running-ahead, kill switch, and the just-upgraded notice.

### Internal
- Repo-hygiene: `.claude/skills/` is now a deny-by-default allow-list (a new private
  or client skill is invisible to git until its dir is explicitly listed), the update
  check's runtime artifacts are gitignored, and `CLAUDE.md`/`IDEAS.md` are tracked
  contributor docs. No change to any shipped skill's behavior.

_Tracked up to: 7899ff96953cd5a35d927bf19a31204244585f97_

## [2026-07-22] A real first run for new users, every system in one home, and prospect that understands you
**The first time you run Boots it now introduces itself and shows what "finished"
looks like, your systems live in one place you can reach from any folder, and Boots
checks its own connector marketplace before reaching for a third-party login.**

The suite's biggest gap — a blank, silent board for someone who just installed it —
is closed. Systems also stop getting stranded in whatever repo you happened to be
standing in when you started them.

### Added
- **boots (first run):** the first time Boots opens for you (no systems yet), it
  introduces itself and renders a worked example of a *finished* system, so you can
  picture the finish line before building anything. It mines your history in the
  background while it listens, reflects back what you actually want, and hands you one
  next step — no rush to ship, and a bigger idea is never shrunk into a throwaway demo.
  An existing user is recognised and never re-onboarded.
- **boots (global home):** every system's records now live in one place
  (`~/.boots/systems/`), so Boots finds your work from any directory instead of losing
  it in the repo you started it in. Old per-repo state is pulled in automatically the
  first time Boots opens in that repo.

### Changed
- **boots-scope / boots-build:** when a system needs an outside app, Boots now checks
  your tool's own connector marketplace first (a first-party connection, no second
  account to create) and only falls back to a hosted provider when the marketplace
  doesn't cover it.
- **boots-prospect:** now reads *who you are* and infers what you could build from your
  profile, not only digging up abandoned threads — so its suggestions fit you, not just
  your leftovers.
- **boots (router):** on open, checks your shipped systems for silent breakage or drift
  and surfaces a broken live system above fresh ideas.

_Tracked up to: 0090ab029d18e1920941a52f88ff3ba534827aef_

## [2026-07-21] Boots can share anonymous usage to help the project (off by default), and the router watches your live systems
**If you opt in, Boots can send anonymous usage — which steps your systems pass
through and where they stall — so the project can see where people get stuck and
smooth the rough spots. It is **off by default**, asks once, and never sends your
code, file contents, repo names, or system names: a system's name is hashed to an
opaque token before anything leaves your machine, and nothing leaves at all unless
you say yes. Separately, the router now sends every shipped system to the "observe"
steward automatically.**

The telemetry is the one thing Boots' background setup ever surfaces to you — a
single question, once. Say yes and you help the project see the shape of how people
actually build (where systems pile up, which step gets abandoned most); say no and
Boots stays fully local, exactly as before. Everything is written locally first and
you can read it plainly; only if you opted in does a rate-limited sync ship a
stripped, hashed copy. The community view rides on the same data, aggregated.

### Added
- **opt-in telemetry (off by default):** a one-time question — help the project with
  anonymous usage, or stay fully local. Three levels: community (a random,
  non-identifying id), anonymous (aggregate counts only), or off. Nothing is sent
  unless you actively pick one of the first two.
- **community funnel:** `boots-analytics --community` shows the aggregate across
  everyone who opted in — where systems pile up and the step people abandon at most.
  Lights up once the project's shared backend is turned on; until then it says so.
- **boots (router):** now automatically routes any shipped system to `boots-observe`,
  so live systems get watched every time you open Boots.

### Internal
- Remote layer ported faithfully from gstack: local-first buffers, cursor sync
  rate-limited to 5 min, a random (never machine-derived) installation id on the
  community tier only, repo names stripped and system names hashed client-side before
  upload, and Supabase edge functions + schema whose public key can only INSERT (a
  leaked key can't read anyone's data). Dormant until a backend is provisioned.

_Tracked up to: 4c66a8439045f90b200f392e06c42ee4c69eca7b_

## [2026-07-21] Boots can update itself now, and the live-system steward joined the fold
**Boots learned to keep itself current: when a newer version exists, it offers to update
— pull the latest, re-run its setup, apply any fixups, and tell you in plain words what
changed — or does it silently if you asked it to. And boots-observe, the step that
watches your already-shipped systems, is now wired in like every other step.**

The update check rides along on every step (quietly, off by default to interrupt), backs
off politely if you say "not now", and never blocks you on a bad connection. It switches
on the day Boots is published to a shared home; until then there's nothing to check
against and it stays silent. boots-observe — which checks each live system is still
alive, still giving sane answers, and still used — now runs the same shared setup as the
rest of the suite, and when it sends a broken live system back for a real rebuild, that
move now shows up on the board alongside everything else.

### Added
- **boots-upgrade:** new step — checks for a newer Boots and, on your say-so, updates
  everything at once (one pull updates every project), runs any version fixups, and
  summarises what's new. Four answers to the prompt: update now, always auto-update, not
  now (it backs off and re-asks later), or never.
- **every step:** now quietly checks for a newer Boots and offers the update if there is
  one. Off-switchable, polite about "not now", never blocks on a flaky connection.
- **boots-observe:** the shipped-system steward now runs the shared step setup (so it
  gets the update check and quiet usage logging like the others), and a broken live
  system it routes back for rebuild now registers on the board as reopened.

### Fixed
- **the board:** the usage line no longer miscounts when there are zero errors.

### Internal
- A VERSION stamp, a `migrations/` folder (empty until the first shape change needs one),
  and setup now runs pending fixups and records the version it set up. The update check
  derives its upstream from the repo's own git remote, so it's dormant until Boots has
  one. Also gitignored a stray CLAUDE.md.

_Tracked up to: e9aa3c6f4ddef906f693878fe409a01b0b8353a9_

## [2026-07-21] Boots now sees where your systems pile up, stall, and get abandoned
**Boots quietly records each system as it moves through the steps, and can now show
you the shape of your whole workshop: how many systems sit at each step, which are
near-finished but have gone cold, and which step is your graveyard where things get
dropped. The "here's your next step" board is backed by real flow data now, not just
a re-read of each file — and it all stays on your machine.**

Every step now records its move into a small per-system history that lives in the repo
with the work (clarify starts one, scope/build/review/verify/ship advance it, "pick it
back up" revives one, "drop it" retires one). A new `boots-analytics` rolls all of that
into a board — counts at each step, what shipped, what got abandoned and from where, and
how long each system has sat untouched. The router, the "what's next" line, and the
"what can I drop" step all read it, so a system one move from done that went cold surfaces
above a fresh idea, and "gone cold" is a real number of days now, not a guess. Nothing
is sent anywhere: the board reads your own files, and usage tracking is off by default.

### Added
- **boots-analytics:** new local dashboard — rolls every system into a board (how many
  at each step, shipped vs abandoned vs active vs stalled, the step things get abandoned
  from, and days-cold per system). Runs on demand, reads only local files.
- **boots (router), boots-surface, boots-retire:** now fold that board into what they
  tell you — surface leads its next-step with it, retire uses real days-cold instead of
  eyeballing timestamps, the router shows it before the board.
- **every step + "pick it back up" / "drop it":** each records its move into the
  system's own history, truthfully (the stage it was actually at, even if you jumped in
  out of order), and silently (you never see the bookkeeping).

### Internal
- The plumbing under the funnel: `boots-config` (settings), an ops run-log with
  crash-detection, and a version stamp on each system record for safe future migrations.
  All telemetry is **off by default and local** — opting in (a later step) is what adds
  a shared device id and sending anything out.

_Tracked up to: 3645273ff96b7fc4ecfb2654c84b6e8b1782db21_

## [2026-07-21] Skills build themselves from templates now, and the scope choice stops calling a subagent "background"
**Two things. Every Boots skill is now generated from a template that injects one
shared header into all of them at once — the groundwork for Boots keeping itself up
to date and learning which steps you actually use (both still dormant; nothing is
sent anywhere yet). And the scope step no longer frames the skill-vs-subagent choice
as "runs in the chat" versus "runs in the background," which was just wrong.**

The template engine is plumbing you won't see yet: each skill's `SKILL.md` is now
rendered from a matching `SKILL.md.tmpl`, so one shared preamble lands in every skill
instead of being copied by hand. Today that preamble runs silently and does nothing
(telemetry is off by default and the update check isn't built), but it's the seam the
update system and usage tracking plug into next. The scope change is real and
immediate: choosing a skill versus a subagent now turns on *where the work happens* —
inside your session versus handed to a separate worker with its own fresh context —
because a skill can be scheduled too, so "it runs on its own" was never the real
difference.

### Changed
- **boots-scope, boots (router):** the skill-vs-subagent decision brief and the
  plain-English table now turn on where the work happens (your session vs a handed-off
  worker), not foreground vs background. Isolation and running many at once are the
  reasons to reach for a subagent; "runs unattended" is not, since a skill can be
  scheduled too.

### Added
- **all boots skills:** each now has a `SKILL.md.tmpl`, and its `SKILL.md` is
  generated from it (`bun run gen:skill-docs`), so a shared preamble injects into
  every skill from one place. A pre-commit hook refuses to commit a `SKILL.md` that's
  out of sync with its template. Codex host support is wired but off by default —
  adding it later is regenerate, not rework.

### Internal
- The injected preamble is deliberately inert for now: telemetry defaults to off, the
  `boots-update-check` / `boots-config` / `boots-telemetry-log` scripts it calls don't
  exist yet, and every call is guarded — so nothing an end user sees changed this
  session. It is the foundation for the update + telemetry phases that follow.

_Tracked up to: 15414f83b86832fc6b81f17eaf2f7ab88cde8afd_

## [2026-07-20] Connecting an app is a browser login now, and the skill you build travels with you
**When Boots wires up an outside app (Gmail, Slack), it logs you in through your
browser instead of asking you to paste a secret key into your shell — and the skill
it builds now carries its own connection and its own taste-notes inside its folder,
so if you hand that folder to someone else it just works. Boots also won't sign off on
a system that runs on a schedule if that system would go dead-silent the day its
connection expires.**

Built from actually shipping real Gmail-reading systems and hitting every sharp edge.
The connection setup used to tell you to put a long `COMPOSIO_API_KEY` into your shell
profile — which broke on quote-escaping for non-technical users and left a plaintext
master key sitting in your profile forever. Now Boots runs one `composio login`: a
browser opens, you sign in, and the key lands encrypted in your OS keyring, never typed
into the chat or a file. The per-app connection secret gets written into the finished
system's own gitignored `.env` (Boots writes the `.gitignore` line itself), so the
secret lives with the thing that uses it and never leaks into git. Reference notes — the
short pages that teach a skill your taste — now live inside the skill's own folder
instead of Boots' scratch tree, so a finished skill is genuinely self-contained.

### Changed
- **boots-build:** the connect step now drives a `composio login` browser sign-in
  instead of telling you to set a shell key; the built system's connection secret is
  written into its own `.env` and pointed at by `${VAR}`, with the `.gitignore` entry
  written for you. Taste-notes are drafted into the artifact's own `reference/` folder
  and pointed at by full path, so they travel with the skill.
- **boots (router):** the translation table and the notes-handling text updated to
  match — notes are "bundled inside the artifact," and the unavoidable real-name moment
  is now the browser `composio login`, glossed once in plain English.
- **boots/forms/claude-code.md:** the per-connection rules rewritten around the
  browser-login-plus-keyring model and the session URL as the runtime secret, plus a
  new rule that a self-running system must read its secret from a file (not `~/.zshrc`,
  which cron and launchd never source). Adds a field-tested notes section from building
  a real Gmail system: write-scoped keys, MCP-registers-next-session, venv install, and
  the Gmail-inbox gotchas (own-mail filtering, body truncation, unreliable counts).

### Fixed
- **boots-review:** the secret sweep now also confirms the `.gitignore` entry actually
  exists (not just the `.env`), and adds a blocking check that a self-running system
  fails loud on a lapsed connection and reads its secret from a place an unattended
  process can see — so a scheduled system can't ship destined to go quietly dead.

### Added
- **IDEAS.md:** a contributor-facing backlog of things worth building into Boots but
  not built yet, each with a fixed skim-in-a-minute shape (the pain, the shape, the
  hard part, where it lives, open questions) and a status legend — the "someone should
  pick this up" list for open-sourcing.

_Tracked up to: cafc4388bea309e9c7188d33fc613c9eba30e8e9_

## [2026-07-19] Boots stops dropping "Composio" on you with no idea what it is
**When Boots needs an outside app connected it no longer drops the bare product name
"Composio" into a question or setup step — the one place the real name is unavoidable
now comes with a plain-English gloss of what it is and how it'll work for you, so a
nontechnical user can actually read it.**

Real feedback: while scoping the Gmail-feedback system, the question tool suggested
"Composio" cold — a provider name the user never chose and had never heard of. The
skills already said "never say Composio, call it a ready-made connection," but a
provider name unavoidably surfaces at least once (you set `COMPOSIO_API_KEY`, you
click a connect link), so that blanket ban was both getting violated and impossible
to keep. The fix swept the whole family: plain-English stays the default everywhere,
but the first time the real name has to reach you it's introduced in one sentence —
what it is (the service behind that ready-made connection) and how it works for you
(you connect your Gmail through it once, it handles the login, the system only reads)
— never a cold drop.

### Fixed
- **boots (router):** the master translation table now carries the root rule — a real
  product name bends the "never say it" rule instead of breaking it: gloss it once,
  then the bare name is fine; a cold drop is the bug.
- **boots-scope:** the connection decision-brief now keeps "Composio" out of the
  option you tap, and glosses it in the same breath if it has to appear — this is the
  exact spot the reported leak happened.
- **boots-build:** the connect/`COMPOSIO_API_KEY` step no longer says "never say
  Composio" while forcing you to set a key by that name — it now introduces the name
  once, in plain terms, at the point it's unavoidable.
- **boots/forms/claude-code.md:** the "Connect before you build" palette rule reworked
  the same way — default plain-English, glossed real name at the setup step.

### Added
- **repo:** README, an installer (`setup`), and a banner — the suite is now set up to
  be open-sourced.

_Tracked up to: c4c79b1955dbdc9e7241eddf6b8009138757a0c5_

## [2026-07-18] The "drop your files here" handoff finally makes sense to a nontechnical user
**When Boots asks for your real examples it now tells you how to actually find the
folder on your computer and what the tool does with what you put there — instead of
handing you a raw path like `state/systems/<slug>/inputs/` and leaving you to guess.**

Real feedback: during the fee-form build the ask to "put it in the /inputs folder"
didn't land — the user just dropped the spreadsheet somewhere and stalled, with no
picture of where that folder lived or how a dropped file becomes a working system.
The fix makes every place that hands off the folder do two things: describe how to
reach it (absolute path + Finder's Go-to-Folder, ⌘⇧G — not the raw repo path), and
explain the flow in one plain sentence (your files go in → the tool reads them each
run → the results show up in the `output` folder or the chat, so you know where to
look).

### Changed
- **boots (router):** rule 3 ("do the prep") now demands the landing spot be
  *findable* and the *flow explained* — not just a folder with a path, but a
  described location plus one sentence on what the tool does with the files and where
  results land.
- **boots-build:** the handoff message and the staged `inputs/README.md` both now
  describe how to find the folder and mirror the flow sentence, so it's reinforced
  right where the user is standing.
- **boots-verify:** the "no examples yet" re-prompt describes how to reach the folder
  instead of naming the bare path.

_Tracked up to: 3b75153230000c61a0e7ffdb834365baddd26851_

## [2026-07-18] Scope stops asking questions in words a first-timer can't parse
**When Boots scopes a new system it now frames the cut and the form in your own
concrete nouns — "start with just the three accounts you watch" — instead of the
bare abstractions "smallest version," "shape," and "next batch" that a newcomer
can't cash out.**

Real feedback: during the fee-form build, the scope questions landed as noise —
"smallest version of *what*? shape of *what*?" The pipeline already swapped the
internal jargon for plain words, but the replacements were themselves abstractions
a first-timer doesn't yet hold (they don't know their idea has versions or a
"shape"). The fix adds a governing rule — a translation isn't done until it's
anchored to the concrete thing the user named — and applies it at the two scope
sites that surfaced the bare words.

### Changed
- **boots (router):** new principle above the translation table — swapping one
  abstract word for another isn't a translation; anchor to the user's nouns. The
  `scope` and `form` table rows now read "anchor to their pieces," not a phrase to
  say verbatim.
- **boots-scope:** the opening no longer leads with "let's pick the smallest
  version and the shape it takes"; it reads the foundation back as a plain list and
  proposes starting with one named piece. The cut question labels each option by
  what it concretely does ("every account in the sheet"), never by a size word.

_Tracked up to: f01f32d56dcaa7d1b91f7bab5ff94a8137f08c45_

## [2026-07-18] Extract's lesson-routing reads for anyone, not just Henry
**boots-extract's guidance no longer hardcodes your name — the routing advice now
speaks generically, so the skill reads the same whoever is running it.**

Two spots in the "route the lesson" step named *Henry* directly ("something true
about Henry", "a durable fact about how Henry works"). Both now say *the user*, so
the skill's instructions are portable instead of tied to one person.

### Changed
- **boots-extract:** replaced the two hardcoded "Henry" references in the
  lesson-routing step with "the user."

_Tracked up to: 5d3a94eba5479ff48ad4efa41cf84a36182f59da_

## [2026-07-18] Opening a new chat feels like continuing the last one
**Every boots system now records where you actually are right now — not where the
last clean handoff left it — and the router self-heals a chat that did the work but
never wrote it down, so a pickup lands you back in your own situation instead of a
step you finished hours ago.**

The suite gained a continuity contract. Each system's state file carries a new `##
now` block — reality on disk, your situation in your own words, and the one physical
next move — that every stage keeps current as work lands, backed by a `sessions/`
folder that holds one short synthesis per chat. That's the belt. The suspenders:
when you run `boots`, the router no longer trusts the file blind — it reconciles the
claim against ground truth (does the artifact exist? is there a run-state or output
the file never mentions?), and when disk disagrees, reality wins: it repairs the
record and reports the caught-up truth, telling you in one line that it did. The
first thing you read now is where you are, then the one next move, then the board.

### Added
- **boots (router):** a "continuity contract" section and a 9th "How Boots talks"
  rule. Step 1 now reconciles each state file against disk (and, only on evidence of
  drift, the last transcript) before reporting; Step 2 leads with your reconciled
  situation in your own words, not a stage. State files gained a `## now` block and
  each system a `sessions/<date>_<label>.md` history.

### Changed
- **boots-surface:** reads `## now` first and reconciles before it trusts the file,
  so the proactive next-step line can't point at a step you already finished.
- **boots-clarify / scope / build / review / verify / ship / track:** each stage's
  state-file template now writes a `## now` block on handoff and reminds the chat to
  keep it current and drop a `sessions/` synthesis before ending. Build and verify
  additionally call out mid-run updates — a chat cut off after producing real output
  must read as "did it," not "not run yet."

_Tracked up to: b191a5dd4c35ae416df1e7497c15a1cdf7b564e0_

## [2026-07-17] A feeder at the front, a self-healing closer at the back
**Boots can now go find work worth building instead of waiting to be handed it, and
a shipped tool has to absorb the tricks its operator used rather than leaving them
in your head.**

Two ends of the pipeline got built out. At the front, `boots-prospect` sweeps every
place your unfinished AI work hides and hands back a ranked field of opportunities
with the evidence for each — so "what should I build" has a grounded answer. At the
back, verify now writes down everything you had to do by hand to make a run pass,
and ship can't close until each of those is either encoded into the artifact or
deferred on the record. The effect is that a tool stops needing you to know its
tricks. This session also cut back most of the hardening layer added on 2026-07-16.

### Added
- **boots-prospect:** new. Mines Claude Code memory, past transcripts, a loose-ends
  store, repo TODOs, and other AI tools on the machine for latent work, then ranks
  what it finds. Read-only, reports the sources it can't read yet, and learns a new
  one on request. Backends plug in as adapters in `sources.md`, so supporting a new
  source never means editing the skill.
- **oro-reel-scout:** new. Ranks freelance content editors applying to ORO on a
  taste-first rubric — design eye and fashion-forward instinct decide it, editing
  competence is only a floor. Opens each applicant's actual work rather than
  grading from a description, and returns a shortlist with a one-line reason each.

### Changed
- **boots-verify:** records an `artifact_gaps:` list — every workaround you
  performed that the tool didn't tell you to, every degraded substitute you reached
  for (or were merely tempted by), everything the user had to correct mid-run. A
  pass with gaps is a pass the operator carried, not a finished tool.
- **boots-ship:** must now heal each gap verify surfaced into the artifact itself,
  or defer it in one line with a reason. No system closes with an un-triaged gap.
- **boots-extract:** a lesson now routes to every destination that fits, and asks
  out loud whether it's also a rule the artifact must obey — if it is, editing the
  artifact is mandatory even after the memory is written. A lesson that teaches you
  and not the tool didn't land.
- **boots-build:** the self-improvement rule it bakes into new tools now splits by
  kind — taste corrections go to the reference notes, operational rules go into the
  artifact's own steps — so tools compound on their own, not in the operator's head.
- **boots, boots-surface, boots-track, boots-clarify:** all four now call
  `boots-prospect` for new opportunities instead of probing a backend themselves.
  Surface weighs the top untapped opportunity only when nothing tracked needs you;
  finishing still beats starting. The one remaining direct backend touch is ship's
  status write-back.

### Removed
- **boots, boots-verify, boots-ship, boots-retire:** most of the 2026-07-16
  hardening layer, deliberately. Gone: verify's three integrity rules; ship's
  self-contained and fire-the-advertised-trigger steps and its `## gaps` section
  (superseded by the artifact-gaps loop); retire's grep for live readers before
  archiving; the router's serve-the-brought-ask step and stale-stage reconciliation
  in both `boots` and `boots-surface`; flow mode and the `invoke:`/`mode:` system
  file lines; the file-drop and `inputs/` guidance; ask-against-real-material; and
  the clean-slate honesty section.

_Tracked up to: a69d63e5f66bb9d0814a1cfa858e56ae1327eb39_

## [2026-07-16] Ready-made app connections, and hardening from real sessions
**Boots-built systems can now reach Gmail, Slack, and 800+ other apps through
ready-made connections with managed login — scoped so tightly that the master
key never reaches the agents that run them.**

Two threads. First, integrations: instead of building a custom live-data
connection every time, Boots now checks whether a hosted provider (Composio)
already covers the app, and wires it as a per-system scoped session — read-only
by default, minted once at build time, with the user's only job being one login
link. Second, a batch of fixes drawn from watching real sessions fail: stale
stage lines, verify runs that never recorded a verdict, shipped tools that broke
when their notes got archived, and briefs nobody engaged with.

### Added
- **boots/forms (palette):** new "Connect before you build" section — check
  Composio's 800+ toolkits before writing a custom MCP server, with four
  standing security rules: least privilege and read-only by default, the master
  key stays in the user's env and never reaches a running artifact, session
  URLs are secrets too and stay out of git, and the login handoff is the user's
  one job.
- **boots-scope:** when a system needs an outside app, a plain-English
  "ready-made connection vs build our own" decision, and an `integrations:`
  list recording exactly which actions it may take — outward-acting ones (send,
  post, delete) only as an explicit decision.
- **boots-build:** a wiring step — Boots sets up the connection, enables only
  the scoped tools, hands over one login link, and never writes a key or
  session URL into anything it produces.
- **boots-review / boots-ship:** secret sweeps — review greps the artifact and
  system folder for leaked keys or session URLs (always a blocking gap), and
  ship re-runs the sweep over everything being committed.
- **boots-verify:** three integrity rules from real failures — never end the
  turn as the thing you're testing (run it via a subagent), pass only what
  actually executed, and name the fresh-artifact trap instead of faking a run.
- **boots-ship:** shipped artifacts must be self-contained (notes move to a
  permanent home so archiving can't silently break them), the advertised
  trigger gets fired once for real before it's promised, and known gaps land in
  a `## gaps` section instead of dying as chat asides.
- **boots (router):** serve a brought ask directly instead of opening with the
  board; flow mode ("carry it through, only stop when you genuinely need me")
  with `invoke:`/`mode:` fields in the system file; copy-ready input paths and
  the drag-from-Finder trick, treating any pasted path as the inputs arriving;
  decision briefs asked off real material and kept scarce; an honest one-line
  caveat when someone asks for a clean slate.

### Changed
- **boots / boots-surface:** stage lines are reconciled against reality before
  being reported — if the artifact already exists or already ran, fix the file
  first instead of telling the user to build a thing that ran yesterday.
- **boots-retire:** before archiving a system folder, check nothing live still
  reads from it, and move what it reads to a permanent home first.
- **.gitignore:** `.env` / `.env.*` ignored as the repo-level backstop for
  integration keys and session URLs.

### Removed
- **reel-editor-scout (agent):** retired.

_Internal: the range also contains the previous session's own changelog commit
(9dddb56)._

_Tracked up to: d566fe937aa509d75dc0ff467e325611b6b370d4_

## [2026-07-16] Name and create late — stop freezing an opening guess
**Boots no longer locks in a name from the first thing you say. It waits until
it actually knows what the system is, then names the folder and the command
for that — so you don't end up with `/cv-grader` for what's really a taste scout.**

The failure this fixes: minting a permanent identity (the folder, the slug, the
invocation name a user types) at the first moment it's *possible* instead of the
moment it's *right*. A vague "grade their CVs" would `mkdir cv-grader/` in step 1,
and that stale name survived the reframe into a talent scout that screens for
taste. Now clarify holds the seed verbatim and creates the folder only after the
reframe, named from what the system became; build names the built artifact for
what it does (as a taste-point, offering you the name it'd pick plus one
alternative) rather than reusing the folder slug; track slugs a revived thread
from what it was reaching for, not its stale title.

### Added
- **boots:** new rule 8, "Name and create late" — do naming, folder-making, and
  committing at the moment you know the answer, not the first moment you could;
  ask "do I actually know what this is yet?" before creating anything.

### Changed
- **boots-clarify:** stops `mkdir`-ing in step 1; holds the seed verbatim and
  creates `state/systems/<slug>` at step 5, slugged from the reframed problem.
- **boots-build:** names the artifact for what it does before writing it, treating
  the invocation name as a taste-point instead of silently reusing the folder slug.
- **boots-track:** slugs the promoted system from what the abandoned thread was
  really trying to do, not its original title ("plugin attempt 4").

_Tracked up to: e23e887e24407e6cd8c93b430fa8d7821ad72937_

## [2026-07-16] Capability grounding — surface catches hollow systems
**Boots now notices when a system was built to read something it can't
actually read, and comes to you with the fix instead of shipping it broken.**

A "hollow" system is one built to judge on an input it has no way to consume.
The case that triggered this: a reel-scout meant to watch candidates' reels and
Instagram, built with only plain web access — which hits a login wall and can't
watch video at all, so it asked for an Instagram handle it could never read.
`boots-surface` now scans for that gap across every system, ranks a hollow
system above a merely-stuck one, and its next-step line proposes the wired fix
(open the feed with browser-harness, download each reel so it can actually watch
it) — defaulting to solving it in the machine rather than handing you homework,
while staying honest that a proposed path isn't proven until verify runs it for real.

### Changed
- **boots-surface:** reads each system for a capability hole, prioritises hollow
  systems over stuck ones, and emits a crafty come-with-the-fix next step (new
  "When a system is hollow (be crafty)" section).

### Added
- **docs/capability-grounding.md:** design note defining the problem across the
  whole pipeline — reach + understand per input, the craft-first resolution
  ladder, per-stage ownership. Surface is the backstop that landed; the
  create-time gate in clarify/scope/build/verify is a named follow-up.
- **skills-changelog:** first generated entry — the git-driven changelog tool is
  now in use for this repo.

_Tracked up to: ac508adce07c69fec3b8314bae80cb5b8b2e2066_

## [2026-07-16] Genesis — version control + changelog set up
**The boots skills now have a git history and an auto-generated changelog.**

`boots-03` was put under version control (baseline `8bd097b`) and the
`skills-changelog` skill was added, reverse-engineered from gstack's git-driven
changelog generator. From the next session on, wrapping up with "skills-changelog"
writes the entry for you.

### Added
- **skills-changelog:** new skill — reads git history since the last entry, groups
  changes by theme, appends a dated entry here. No semver, no CI, no interview.

_Tracked up to: 8bd097be7b8bc66bc38e2e4c77b263c6ac2b450d_
