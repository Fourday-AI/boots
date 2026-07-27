# Boots forms — Cowork

**Platform: cowork.** This is one platform palette. It lists the forms an AI
system can take when **Cowork** is the runtime building and running it, plus how
to pick, build, verify, and ship each. Other platforms get their own file in this
directory with the same section shape (see `forms/README.md`). A system's
`platform:` field says which palette applies; the default is `cowork`.

Cowork is not a chat window with file access. It is a runtime: it runs work on a
schedule with nobody watching, connects to the apps the user already lives in,
produces real files, and keeps durable surfaces the user opens again next week. A
"system" is rarely a single skill. It is usually one of the forms below, or a
small composition of them.

**The composition is the norm, not the exception.** The most common shape of a
real Cowork system is three forms wired together: a **connector** brings the data
in, a **skill** does the judgment, and a **scheduled task** runs the whole thing
on a clock. Add an **artifact** when the user needs to look at the result without
opening a chat. If you find yourself scoping a system down to exactly one form,
check that you have not just dropped the part that makes it run without the user.

## The forms (Cowork)

| Form | It is | Lives at | Reach for it when |
| --- | --- | --- | --- |
| **Skill** | a reusable workflow Cowork loads on a trigger, invoked by name or matched from what the user asks | `skills/<name>/SKILL.md` inside a plugin, or a standalone `.skill` file the user saves | the work is judgment, synthesis, or a repeatable multi-step method a human kicks off |
| **Scheduled task** | a recurring job that starts a **fresh session** on a cron and runs unattended | created with `create_trigger` (Claude Code Remote MCP) | it must happen on a clock whether or not the user opens Cowork — a Monday digest, a nightly sweep, a 7am brief |
| **Connector** | a live connection to an app the user already uses, exposing its data and actions as tools | the connector registry — `SearchMcpRegistry` to find, `SuggestConnectors` to connect | the system needs live data or needs to act in Gmail, Slack, Drive, Asana, Linear, a CRM |
| **Deliverable** | a real file the user opens in their own software | `.docx` / `.xlsx` / `.pptx` / `.pdf` / `.md`, delivered with `SendUserFile` | the output **is** the document, the spreadsheet, or the deck — not a chat answer about it |
| **Artifact** | a persisted, self-contained HTML page in the user's desktop sidebar, updatable in place | `create_artifact` / `update_artifact` | the user will come back to it — a dashboard, tracker, status page, reference sheet, calculator |
| **Plugin** | a bundle of skills, connectors, and agents installed as one unit | a `.plugin` file (zip with `.claude-plugin/plugin.json`) | the system is a whole way of working rather than one job, or it has to be shared with a team |
| **Subagent** | a worker handed a scoped job with its own fresh context and tools | the `Agent` tool, or `agents/<name>.md` inside a plugin | the job is big, messy, or parallel — reading fifty files, a research sweep, an independent review |
| **Workflow** | deterministic multi-agent orchestration written as a script | a `Workflow` script (`agent()` / `pipeline()` / `parallel()`) | the same operation runs over a whole work-list — a migration, an audit, a broad sweep — and the control flow should be code, not vibes |
| **Memory / context** | durable knowledge every future session reads | `CLAUDE.md`, a `memory/` knowledge base, a skill's own `reference/` folder | the "system" is really context that makes every future session better |

## How to choose (the nature of the work picks the form)

Do not pick by what is easiest to demo. Pick by what the work *is*:

- **Synthesis, judgment, reading messy input, conversation** → skill (or subagent
  if it is big enough to want its own context).
- **Must happen on a clock, unattended** → scheduled task. This is the form Cowork
  has that a chat does not, and it is the most under-picked form in the palette.
- **New capability, or live data from an app the user already uses** → connector.
  Connect before you build (next section).
- **The output is a file the user opens elsewhere** → deliverable.
- **The user will look at it again next week** → artifact.
- **A whole way of working, or something a team installs** → plugin.
- **The same operation over a long work-list** → workflow.
- **Makes every future session smarter** → memory / context.

When two forms both fit, prefer the lighter one, and prefer the form whose "done"
you can actually verify (below). Two Cowork-specific traps:

- **Do not build a skill for something that should run on a schedule.** A skill the
  user has to remember to invoke is the same abandonment failure Boots exists to
  prevent, one level down. If the user's words were "every Monday" or "so I don't
  have to remember," the system is a scheduled task that calls a skill, not a skill.
- **Do not build a scraper for something a connector already exposes.** Search the
  registry first, every time.

## Connect before you build (integrations)

Before building any capability, check whether a connection already exposes it as
tools. In Cowork this is one step, not three:

**1. Search the connector registry.** Call `SearchMcpRegistry` with the app name
and a couple of category keywords ("gmail", "email"; "asana", "project
management"). Cowork's registry carries managed connections that handle OAuth in
the app — the user clicks through a normal sign-in flow, and no key is ever typed,
pasted, or stored in a file.

**2. If the registry has it, suggest it.** Call `SuggestConnectors` with the chosen
entry. The user completes auth in their own app. Record in the system file which
app the system connects to and which connector provides it. **Do this before scope
commits to a form** — whether a connection exists changes what the smallest useful
version is.

**3. Only if the registry comes up empty**, treat the capability as a build: a
skill that works from files the user drops in a connected folder, or a custom MCP
server if the user genuinely needs one. Say plainly that there is no ready-made
connection for that app, and what the manual path costs them.

These rules travel with every connection:

- **Least privilege, read-only by default.** Ask for the narrowest scope that does
  the job. Outward-acting permissions (send, post, delete) are a deliberate scope
  decision, never a default — the system will read untrusted content *through* this
  connection, and read-only is what contains an injected instruction.
- **Never handle the credential yourself.** Cowork connectors authenticate in the
  app. Never ask the user to paste a token, an API key, or a password into the
  chat, and never write one into a file, a system record, or an artifact. If a
  capability can only be reached with a pasted key, that is a reason to reconsider
  the form, not a step to walk the user through.
- **The connect click is the user's one job.** Boots finds the connector, explains
  in one line what it will read and what it will never do, and hands over the
  connect step. Everything else Boots does itself.
- **A scheduled task inherits the session's connections, not a chat's goodwill.**
  Before shipping a system that runs unattended against a connector, confirm the
  connection is live *from a fresh run*, not just from the chat you built it in.
  Interactively-authenticated connections can be absent in scheduled runs; a system
  that works in the build chat and silently fails at 7am every morning is the exact
  failure `boots-observe` exists to catch, and it is cheaper to catch it at verify.

To the user, the default name for this is never "connector," "MCP," or "an
integration." It is **"a ready-made connection to your Gmail that handles the
login for you."** See the translation table in `boots/SKILL.md` for the master rule.

## How to verify each form (Cowork)

`boots-verify` runs the check that matches the form. Exit-0 only applies to code.

- **Skill** → invoke it by name in a real session on a real example, observe it
  triggers, follows its own steps, and produces the result. Evidence is the actual
  output, quoted.
- **Scheduled task** → do not wait for the cron. Fire it once on demand
  (`fire_trigger`) and read what that run actually produced. A scheduled task that
  has never completed a real run is unverified, no matter how correct the cron
  string looks. Check the schedule separately: confirm the UTC cron matches the
  local time the user asked for.
- **Connector** → call one of its tools and check the response shape *and* a real
  value the user can recognise ("it pulled your last five emails, here are the
  subjects"). A connection that lists as authorised but returns nothing is not
  verified.
- **Deliverable** → open the produced file and read it back. Confirm it renders,
  the numbers are the researched numbers, and the formatting survived. Send it with
  `SendUserFile` and confirm the user can open it.
- **Artifact** → render it and look at it. Confirm it displays with real data, not
  placeholder data, and that it is self-contained (no external CSS/JS, no browser
  storage). Then confirm it persists — it appears in `list_artifacts`.
- **Plugin** → install it and invoke one skill from it end to end. "The zip exists"
  is not verification.
- **Subagent** → spawn it on a test task and check the returned result against the
  ask, not against how confident it sounded.
- **Workflow** → run it on a small real work-list and read the journal. Confirm
  each stage returned what the next stage expected, and that failures dropped items
  rather than silently returning nulls the script then treated as results.
- **Memory / context** → mostly a human judgment: does a fresh session reading it
  behave better. If it makes a checkable claim, check that claim.

If a form has no mechanical check, say so and route it to a human read. Do not
fake a pass. "I ran it and here is the real output" is the only pass.

## What "shipped" means per form (Cowork)

Present is not shipped. Live is shipped.

- **Skill** → saved where Cowork will load it (installed plugin, or a `.skill` file
  the user has saved to their account) and confirmed invocable by name. Not "the
  file exists," it responds.
- **Scheduled task** → registered, `enabled`, with a confirmed `next_run_at`, and at
  least one real run completed. The user has been told what it will do, when, and
  how to turn it off.
- **Connector** → connected, authorised, and answering — confirmed from a run, not
  from the settings screen.
- **Deliverable** → the finished file delivered to the user, and saved to their own
  folder if that is where it belongs.
- **Artifact** → persisted via `create_artifact` and confirmed present in the
  user's gallery, so it survives this session.
- **Plugin** → packaged as a `.plugin` file, delivered, and one skill from it
  invoked successfully after install.
- **Subagent** → defined where it can be spawned, and spawned once successfully.
- **Workflow** → the script runs start to finish on a real work-list, and the user
  knows the one command that runs it again.
- **Memory / context** → the final file in its resting place, and something reads it.

**Shipping is not the end.** Every form above except deliverable keeps running
after the user stops watching, which is why `boots-observe` exists. A shipped
system's record carries what "alive" looks like for its form — the last run
timestamp for a scheduled task, the connection state for a connector, the last
update for an artifact — so the next check has something to compare against.

## Where a Cowork system's files live

Cowork sessions run in a sandbox that is wiped when the session ends, so nothing a
system needs may live only there. Two rules:

- **The system's own record lives in the Boots home** — a folder in one of the
  user's connected folders. See "The Boots home" in `boots/SKILL.md`.
- **The built artifact lives where its form says it lives** — a saved skill, a
  registered scheduled task, a persisted artifact, a file written back to the
  user's own folder. A system whose only copy is in the session sandbox is not
  shipped, it is a draft that is about to be deleted.

## Plain English on this platform (what the user hears)

`boots/SKILL.md` carries the master translation table — the platform-independent
half, covering the words the pipeline itself uses (seed, foundation, scope, form,
review, verify, ship). **These rows are the Cowork half**: every form above has an
internal name the user has never heard, and this is what to say instead. The rule
from rule 5 applies unchanged — if a sentence would only make sense to someone who
has read these skills, rewrite it.

| Internal word (never say it) | Say to the user instead |
| --- | --- |
| skill | "something you ask for by name when you want it" — the thing they say, and it happens |
| scheduled task / trigger / cron | "something that just runs on its own every morning, whether or not you're at your desk" — and always say the actual time in *their* time, never a cron string |
| connector / MCP / integration / registry | "a ready-made connection to your Gmail (or Slack, or whatever) that handles the login for you" — and "connecting your Gmail" for the sign-in step |
| artifact (the persisted page) | "a page in your sidebar you can open any time to see where things are at" |
| deliverable | just name the file: "a spreadsheet" / "a Word doc" / "a PDF" |
| plugin | "a set of these bundled together, so you install it once and your team gets it too" |
| subagent | "a separate worker it hands a big or messy job to, that goes off on its own and comes back with just the result" |
| workflow / fan-out / orchestration | "running the same job across a whole list at once, instead of one at a time" |
| memory / context / reference doc | "the notes that teach it your taste" / "a short page about your brand it reads before it works" |
| the Boots home / BOOTS_HOME / the state folder / bridge mode | "the folder on your computer where I keep track of what you're building" — and never mention the mode at all |
| connected folder | "the folder you've given me access to" |
| the session / the sandbox | don't mention it. If you must explain why something has to be saved: "this chat's workspace gets cleared when we're done, so I'm putting it on your computer" |

**The one distinction worth labouring, because getting it wrong costs the most:**
a skill is something the user has to *remember to ask for*; a scheduled task
*happens to them*. When you offer the choice, put it in exactly those terms — "do
you want to run this when you think of it, or should it just land in your inbox
every Monday?" — and never as "skill or scheduled task".

## Exact syntax drifts, so don't hardcode it here

Skill frontmatter fields, plugin manifest keys, cron semantics, connector registry
shapes, and the artifact tool signatures change over time. This file teaches the
*decision and the shape*. When you need current exact syntax for a Cowork form,
read the tool descriptions available in the session, check the relevant bundled
skill (`cowork-plugin` for plugin structure), or search the docs at build time
rather than trusting a frozen snippet here.
