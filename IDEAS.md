# Boots — ideas backlog

Things worth building into Boots that aren't built yet. One idea per section,
roughly ordered by how much we want it. This is the "someone should pick this up"
list, not a roadmap or a promise.

**How to read an entry.** Every idea has the same shape so you can skim it in
under a minute:

- **At a glance** — the one-line version and the current status.
- **The pain** — the real moment that makes us want it. If you can't feel the
  pain, the idea isn't ready.
- **The shape** — how it would work, roughly. Enough to picture it, not a spec.
- **The hard part** — the thing most likely to sink a naive build. Read this
  before you start.
- **Where it lives** — which form it takes (skill, command, hook, script) and
  where in the repo it would go. Boots builds any form Claude Code supports.
- **Open questions** — what's genuinely undecided. Good places to have an
  opinion.

**Want to build one?** Open an issue that says which idea you're taking and how
you'd cut the smallest useful version, or just open a PR. Boots values a small
thing that ships over a big thing that doesn't. If you scope it down, say what
you're leaving out and why. New ideas welcome too — copy the shape above.

**Status legend:** `proposed` (agreed it's worth it, nobody's building) ·
`shaping` (someone's actively designing it) · `building` · `parked` (good idea,
wrong time).

---

## 1. Replay-test — prove a skill change works by re-running a real chat point

**At a glance:** `proposed` · form: skill + a small headless runner · size: M

You improve a Boots skill by using it and catching where it goes wrong. Today,
the only way to check your fix is to revert the whole chat and manually retrace
your steps back to the exact moment the bug showed up. This makes that a one-line
command: mark the moment, change the skill, replay, get a PASS/FAIL.

### The pain

Concrete case this came from: while scoping a "read my Gmail for product
feedback" system, `boots-scope` suggested **Composio** to the user cold — a
provider name a non-technical person has never heard of, with zero context. The
fix was to make the skill gloss it in plain English the first time. But to *prove*
the fix worked, you'd have to rebuild the entire conversation up to that suggestion
by hand. Slow, unrepeatable, and you only ever see one run — so you can't tell a
month later whether some other edit silently broke it again.

### The shape

1. **Mark a checkpoint.** A checkpoint is a frozen prefix of a *real* Claude Code
   transcript — the messages and their tool results up to the point you picked.
   Claude Code already writes transcripts to `~/.claude/projects/<slug>/*.jsonl`,
   so this is capturing a path + a message index, not new plumbing. The expensive,
   non-deterministic work earlier in the chat (the actual Gmail read) is baked into
   the prefix and is *not* re-run.
2. **Change the skill**, like you would anyway.
3. **Replay.** Feed the frozen prefix into a fresh headless run (`claude -p`) with
   your changed skill loaded, and let it regenerate the next turn.
4. **Auto-author the check.** The runner reads what you changed (the skill diff +
   a one-line "what I was fixing" note) and generates a check unique to *this*
   change — e.g. "PASS if Composio is introduced with a plain-English gloss before
   first use, legible to a non-technical reader." The friction of hand-writing
   assertions is what kills every eval suite; auto-writing them from the change is
   the whole trick.
5. **Grade it.** An LLM-judge grades the regenerated turn PASS/FAIL against that
   criterion. Qualitative behaviour like "is this legible to a non-technical
   person" can't be a regex, so the judge is the default; deterministic
   string/structured checks are a bonus layer when a check happens to be mechanical.
6. **Diff on demand.** The raw baseline-vs-new output is always there to eyeball
   when you want to see the difference yourself — the grade is the automatic
   answer, the diff is the receipt.

### The hard part

**Non-determinism can make the test lie.** A Composio-style fix is exactly the
kind of behaviour an LLM produces *inconsistently*. If a replay passes once by
luck, you'll trust a fix that's actually flaky — which is worse than the manual
revert, because at least the manual revert shows you one real run you read with
your own eyes. So a credible PASS has to mean the check held across several
replays (e.g. 3-of-3, or 4-of-5), not one lucky shot. Build the runner around
repetition from day one; don't bolt it on later.

### Where it lives

A Boots skill (say `boots-replay`) plus a small runner script, under
`.claude/skills/`, invoked like the rest of the suite. No external service. Saved
checkpoints + their generated checks become **fixtures** that accumulate into a
regression suite — run them all before shipping any skill edit. That compounding
is the reason this belongs in the plugin and not a throwaway script.

### Open questions

- **Marking the checkpoint:** a mid-chat command (`/boots-checkpoint` snapshots
  "here") vs. picking a message out of a saved transcript after the fact. Mid-chat
  is lower friction; post-hoc needs no foresight. Possibly both.
- **Post-checkpoint tool calls:** if the regenerated turn itself calls a tool
  (not just the frozen prefix), does it run live or get stubbed? Fine to run live
  for v1; flag it.
- **How the "what I was fixing" note is captured** — typed by the user, inferred
  from the commit message, or read straight from the skill diff.
- **Flakiness reporting:** show a pass *rate* (4/5) rather than a binary when
  replays disagree, so a marginal fix reads as marginal.
