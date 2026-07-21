# Changelog

What changed in the Boots skill suite, one entry per release, newest first.
Written in plain language: what you can now do that you couldn't before.

<!-- New entries go directly below this line. -->

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
