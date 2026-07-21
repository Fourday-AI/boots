# Capability grounding (design note)

Status: problem defined 2026-07-16. First change landed in `boots-surface`
(proactive-craft backstop). Create-time gate (scope/build/clarify) is an open
follow-up, see "Where the gate lives" below.

## The instance that surfaced it

In the cv-grader dogfooding run (`boots-03` transcript `81fb18a6`), the whole
system was reframed to *"judge them on their actual work — the reels and
Instagram, not the CV,"* and the user confirmed it. Build then shipped a subagent
(`reel-editor-scout.md`) with tools `Read, Bash, Glob, Grep, WebFetch, WebSearch`,
and its brand-taste note asked the user to *"give me the brand's real Instagram
handle."*

That subagent cannot see Instagram (login wall, WebFetch returns HTML) and cannot
watch a reel at all (a reel is video; WebFetch returns text). The one signal the
entire system was built to judge on is the one thing it has no eyes for. It asked
the user for an Instagram handle it can't read, to sharpen a note against content
it can't watch. **The ask is hollow.**

## The problem (the class, not the one-off)

Boots reasons hard about *what a good judgment needs* (shared rule 4: "predict the
widest plausible input set" → CV + cover letter + portfolio + Instagram + reel +
site) and never checks *what the thing it's building can actually reach and
understand.* It conflates two different lists:

1. **Ideal information** — what a human expert would look at.
2. **Accessible information** — what the built system's tools can retrieve *and*
   parse.

Rule 4 optimises for list 1 with no counterweight. There is no step anywhere that
grounds a named input against list 2. So every input is treated as free.

Two questions must be answered per input and per reference source. Today neither is:

- **Reach** — is there a real access path? (a tool, an MCP server, browser-harness,
  a user paste, a file drop, a human step). Instagram behind a login = no reach
  with WebFetch.
- **Understand** — once it's in, can the system parse it into the thing it's
  judging? WebFetch gets HTML, not a watched reel. Reach without understand is
  still a gap, and the sneakier half, because the fetch "succeeds."

**The tell:** the machine asked the human for an input it can't consume. Any time
Boots asks "give me your Instagram / your site / your Notion," that request should
have been preceded by "…and something in this system can read it." The hollow ask
is the smoke; the missing grounding is the fire.

## Why it's the most dangerous failure mode for THIS product

The moat is "Alive = runs without you." A system that asks for an Instagram handle
it can't read is the anti-moat: it looks alive and is hollow. The user is
non-technical by design and cannot tell "watched the reel and judged it" from
"fetched a login wall and guessed from the cover letter." A silent capability gap
in a product built for people who can't read the code is the worst class of bug it
can ship — confident garbage without you, which is strictly worse than nothing.

## The resolution ladder — craft first, in this order

The default is NOT "drop it" or "ask the human." Default-to-human is the anti-moat
wearing a safety vest: it just moves the work back onto the founder. The product
already has real tools, so "we can't see Instagram" is usually a false limit.

1. **Craft a real machine path — the DEFAULT.** Be resourceful before giving up.
   For the reel/Instagram case, concretely: browser-harness with a logged-in
   profile to open and screenshot the feed; `yt-dlp` the reel then hand the video
   to a vision-capable model to actually watch it; a public oEmbed/embed endpoint.
   The instinct is *engineer a way in*, not "that's hard, ask the human."
2. **Human-in-the-loop** — only when no machine path is worth the build for the
   value it adds. The human is the eyes; the system judges the text they paste.
3. **Drop** — only when it's genuinely not worth it, said plainly.

## The guardrail that keeps craft from becoming the original bug

Craft is the failure mode's twin. A crafty machine that invents a second path that
also silently fails (WebFetch the oEmbed → still nothing) has just moved the hollow
ask one layer down. So craft is bounded by the same gate, not exempt from it:

- A crafted path still passes **reach + understand**. Craft means trying harder to
  find a path that actually passes, never lowering the bar to declare victory.
- The crafted path is **exercised at verify** on one real example. "I'll use
  browser-harness for Instagram" is a claim until verify opens one real feed and
  gets frames back. Crafty-but-checked.
- If the craft needs a new capability (a tool the system lacks, a login), that
  surfaces as a **capability-requirement decision** — how craft gets approved and
  wired in, not a synonym for giving up.

Net: **resourceful by default, honest under check.** The thing that stays
impossible is the hollow ask: claiming or requesting an input via a path never
verified to work.

## Where the gate lives (whole-pipeline, each stage owns a slice)

| Stage | What it must do | Status |
|---|---|---|
| **clarify** | When rule 4 predicts the wide input set, tag each item *reachable? understandable?* instead of listing all as free. | follow-up |
| **scope** | Only inputs that pass (or have a named human-step fallback) enter the `inputs:` contract and become fixtures. Ungrounded ones resolve to craft / human-step / drop, on the record. | follow-up |
| **build** | Match the *tool choice* to the grounded input. Never write a tool whose stated job its toolset can't do. **Never ask the user for an input not marked consumable.** | follow-up |
| **verify** | Proof-of-done must exercise each named input path on a real example. If it can't, that input was never really in scope. | follow-up |
| **surface** | Backstop: detect systems that claim an input/source they can't consume, and proactively drive the crafty fix as the next-step line. | **landed** |

## Acceptance test

Boots never asks the user for an input, and never writes a tool description
claiming to read a source, that the built system has no verified way to consume.
The hollow "give me your Instagram handle" ask becomes impossible.
