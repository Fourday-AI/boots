# Boots: the first-run experience

Design doc — 2026-07-22. Builds on `systems-home-global.md` (the global
`~/.boots/systems/` home + "review through the agent"). Status: **decisions locked,
architecture to pick.**

---

## The problem

The analytics work made the board the front door: `boots` opens, reads
`boots-analytics`, renders where every system stands. That works for a returning
user. It fails for a stranger.

On first run the board is empty. `boots-analytics` prints
`No systems yet (~/.boots/systems/ is empty).` and the router's only guidance for
that case is the "nothing's stuck" line — written for a *returning* user with
finished systems, not someone who just installed and has no idea what Boots is.

The deeper failure: **the finish line is invisible.** Boots' whole reason to exist
is "finishing beats starting." But a first-timer has never watched a Boots system
get finished, so "stay involved through review → verify → ship" asks them to grind
toward a payoff they can't picture. Motivation dies at the blank board.

This is not "add a welcome message." It is: *what must the first run make a stranger
believe, and how fast can it make them believe it.*

---

## Decisions locked

> **Reversal (2026-07-22, during eng review).** The first two decisions below were
> originally "finish line = a shipped thing held at the end of run #1" + "force a tiny
> wedge, always." Both were reversed: **run #1's job is orientation and being
> understood, not a same-session ship.** A user may have a bigger-bet system; distorting
> it into a tiny wedge to manufacture a fast ship is the worse failure. Rushing loses
> more than it gains. The originals are struck; the versions below govern.

1. **Finish line = made legible, not necessarily reached.** Run #1 must make the
   stranger *understand* what "done" looks like and where they are headed, so the
   review→verify→ship payoff is something they can picture and stay motivated toward.
   The single most important output is: **they feel understood, and they know the one
   next step.** Reaching a ship in session one is a bonus, never the bar.

2. **If they're blank, coach them to a system — two ways at once.** Foreground: a
   few forcing questions. Background: a **non-blocking subagent mines their chat
   history** (the `boots-prospect` mining contract, dispatched as an Agent — prospect
   is prose, not a callable engine, so this reuses its contract, not a function) for
   something they already started or clearly want. The mine folds in when it returns;
   because run #1 is unhurried, a late mine is surfaced on arrival, never waited on.

3. **Place, don't rush.** First-run ends by placing the user on the pipeline at the
   right stage and handing off to the **normal** stage skill — `boots-clarify` for a
   fresh idea, `boots-track` for something the mine surfaced. No compressed path, no
   `first_run` closer flag, no forked pipeline. A deliberately tiny wedge stays
   available as an *offer* for a blank user who wants a quick win — never forced onto
   a bigger-bet system.

4. **Boots announces itself through the skills, not a hook.** The front door can't
   depend on a stranger typing `boots`, but it also shouldn't depend on a global
   SessionStart hook — that would mean `./setup` writing `~/.claude/settings.json`, a
   high-blast-radius change (a bad merge breaks all of Claude Code) and the one thing
   that would break Boots' "it's all just skills" model. Instead the trigger is the
   **`## Boots` block already pasted into the user's CLAUDE.md** (global `~/.claude/
   CLAUDE.md` for a global install, or the project's). The block instructs Claude to
   lead with Boots' orientation when `~/.boots/.activated` is absent; the first-run
   flow lives **inside the `boots` router**, gated on that marker. Once activated, the
   block's first-run nudge no-ops and Boots behaves as the normal board.

   **Accepted tradeoff:** this trigger is *soft* — it depends on the model reading the
   CLAUDE.md block and acting on it, and on the block being present. Strictly less
   deterministic than a hook. Accepted, to keep Boots pure-skills and avoid the
   settings.json write. Because the block is host-appropriate by construction (each
   host's instructions file carries its own), no `hosts/` seam extension is needed —
   the earlier "hook behind the seam" plan is dropped.

---

## Premises (carried into the build)

- **First-run is a mode, detected once.** Trigger is a durable marker
  (`~/.boots/.activated`), not `systems == 0` — a user who retired everything is
  also at zero but is not new. First run = no marker yet.
- **Show the finish line before earning it.** The opener renders a real finished
  example ("this is what done looks like") in seconds, before asking for anything.
- **The pipeline is too heavy for a hello-world unmodified.** Six skill invocations
  with preambles is ceremony, not progress, for the first wedge. First-run needs a
  compressed path: collapse clarify+scope, go straight to build → ship.
- **Reuse `boots-prospect` as the miner, with a first-run lens.** Prospect ranks a
  whole field; first-run wants one tiny, ideally-already-started thing.

---

## The flow (shape, independent of architecture choice)

0. **Announce (via the CLAUDE.md `## Boots` block).** The block tells Claude to lead
   with Boots' orientation when `~/.boots/.activated` is absent, so the user never has
   to know the word `boots`. No hook, no settings.json write.
1. **Detect.** No `~/.boots/.activated` → first-run mode (a branch inside the `boots`
   router).
2. **Dispatch the mine (non-blocking).** Subagent runs the prospect engine with the
   first-run lens (small + already-started), returns a ranked shortlist.
3. **Orient (foreground, ~15s).** Three lines: what Boots does, the finish line, and
   "I'll help you finish one small thing right now." Render one real finished example
   so "done" is visible, not described.
4. **Coach (foreground).** 2-3 forcing questions to pull out what they want — running
   concurrently with the mine.
5. **Merge + understand.** Fold the mine's shortlist into the conversation. Reflect
   back what they want in their own words — the "you're understood" beat. Land on ONE
   thing to move on, whether a fresh idea or a mined thread.
6. **Place on the pipeline.** Decide the right entry stage and hand off to the normal
   stage skill: `boots-clarify` (fresh idea) or `boots-track` (mined thread). Give them
   the single next step in plain words. Offer a tiny wedge only if they're blank and
   want a quick win — never force it.
7. **Mark activated.** Write the marker. Every later run is the normal board.

---

## Alternatives (architecture)

> These are the options **as first considered**. Approach A was chosen but then modified
> by the eng-review reversal: the "compressed guided ship / force the wedge" parts are
> struck — see Decisions locked and Recommendation for what A actually became.

### APPROACH A — Router branch + compressed guided ship (minimal)
First-run is a new opening branch inside `boots/SKILL.md`, gated on
`~/.boots/.activated`. It dispatches the prospect subagent in the background,
runs the orient + coach beats in the foreground, forces the wedge, and drives a
**compressed** build → ship (clarify/scope folded into the coaching). A `first_run`
flag on the system tells the closer to keep scope minimal. No new skill file.

- Effort: **M** · Risk: **Low**
- Reuses: the router's existing opening, `boots-prospect`, `boots-build`, `boots-ship`.
- Pros: least new surface; ships fast; matches Boots' own "tiny wedge" ethos for its
  own feature; nothing new to generate through the template engine except router prose.
- Cons: orientation copy lives in the already-large router; the compressed path is a
  special case the closer has to honor.

### APPROACH B — New `boots-welcome` skill (clean seam)
A dedicated skill owns first-run end to end: intro copy, background mine, coaching,
wedge-forcing, hand-off to the pipeline with `first_run: true`. Router detects
first-run and routes to it.

- Effort: **L** · Risk: **Med**
- Reuses: `boots-prospect`, the pipeline.
- Pros: orientation isn't crammed into the router; clean separation; goes through the
  template engine like every other stage; the natural home if first-run grows.
- Cons: a whole new `SKILL.md.tmpl` + preamble + multi-host generation cost; more to
  maintain before the flow is validated on real users. Over-investment this early.

### APPROACH C — Worked-example seed + live intro (lateral)
Ship Boots with a canned example system frozen in a finished state. First-run's
opening move renders *the finished example* first — a real tiny skill someone built
with Boots — so the finish line is literally on screen in 5 seconds. Then coach their
own (grafts A's flow after the reveal).

- Effort: **S** (for the reveal piece) · Risk: **Low**
- Note: "force a tiny wedge" was chosen over "ship a throwaway demo *as their build*."
  C does not replace their build with a demo — it uses a finished example purely as
  **orientation**, then builds their real wedge. This piece grafts onto A cleanly.
- Pros: makes premise 2 concrete; cheapest possible "show don't tell."
- Cons: needs a bundled example that stays generic (open-source rule) and doesn't rot.

---

## Recommendation

**Chosen: Approach A** — a first-run branch inside `boots/SKILL.md`, gated on
`~/.boots/.activated`, with C's finished-example reveal grafted into the orient beat.
No compressed/forked ship (see the reversal): first-run orients, understands, and hands
off to the *normal* stage skills. B (a dedicated `boots-welcome` skill) is the end-state
if first-run grows, but over-invests before the flow has met a real stranger.

**Trigger (chosen): the CLAUDE.md `## Boots` block, no hook.** The block nudges Claude
into the router's first-run branch when `.activated` is absent. No `./setup`
settings.json write, no `hosts/` seam extension. Soft trigger accepted (see decision 4).

## Eng-review findings folded in

- **[Arch, resolved] Compressed-ship fork** — dissolved by the reversal; no `first_run`
  closer flag, no forked pipeline.
- **[Arch, resolved] Announce blast radius** — dropped the SessionStart hook; trigger is
  the CLAUDE.md block.
- **[Code quality] Don't re-describe mining.** First-run must **invoke `boots-prospect`'s
  contract**, not paste a second copy of "how to mine" into the router — two prose copies
  will drift. Per [[prospect-understand-and-invent]], the mine also **infers from who the
  user is** (profile), not only excavated notes. Fold that lens in, don't reinvent it.
- **[Code quality] `.activated` semantics.** Set the marker once orientation has been
  *shown* (not only on a completed ship), so a user who bails mid-first-run isn't
  re-onboarded forever. A separate `.first-run-declined` is optional if "no thanks"
  needs to differ from "did it".
- **[Ordering] First-run precedes the telemetry-consent ask.** The preamble's one-time
  consent prompt must not be a stranger's first impression. Orient first; earn the
  telemetry ask after they've engaged.
- **[Verification — the boomerang] The claim is "feels like progress + understood + a
  clear next step," not "ships in minutes."** Prove it: run first-run in a clean `$HOME`,
  confirm a stranger reaches *understood + one next step*, that the example reveal
  renders, and that `.activated` flips exactly once. This is the office-hours assignment
  turned into a verification gate. Re-run the developer-experience review against it
  once built.
- **[Performance] Cap the mine.** The only latency is the transcript scan; bound how many
  transcripts/how far back it reads so the background Agent returns in seconds, and keep
  the join unhurried so it never blocks the foreground.

## Open sub-decisions for the build

- What the bundled finished example is (must be generic per the open-source rule; must
  not rot).
- Exact miner lens — how prospect scores "small + already-started" *and* "inferred from
  profile" for a first-timer.
- Where the first-run branch sits relative to the router's existing migration + reconcile
  beats (it should run first when `.activated` is absent and there are zero systems).

## The assignment

Before writing any prose: run `boots` yourself in a throwaway `$HOME` with an empty
`~/.boots/` and screenshot the actual first-run output today. That blank board is the
thing a stranger sees. Build against the real artifact, not the imagined one.
