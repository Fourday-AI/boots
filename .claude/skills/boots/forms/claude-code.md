# Boots forms — Claude Code

**Platform: claude-code.** This is one platform palette. It lists the forms an AI
system can take when **Claude Code** is the runtime building and running it, plus
how to pick, build, verify, and ship each. Other platforms get their own file in
this directory with the same section shape (see `forms/README.md`). A system's
`platform:` field says which palette applies; the default is `claude-code`.

Boots builds **AI systems**, and Claude Code is not only a coding assistant, it is
a runtime you build agentic systems on. A "system" is rarely a single script. It
is usually one of the forms below, or a small composition of them.

## The forms (Claude Code)

| Form | It is | Lives at | Reach for it when |
| --- | --- | --- | --- |
| **Skill** | a reusable prompt-workflow Claude Code loads on a trigger | `.claude/skills/<name>/SKILL.md` | the work is judgment, synthesis, or a repeatable multi-step method a human invokes |
| **Subagent** | a specialized agent spawned for a scoped task, own context + tools | `.claude/agents/<name>.md` | you want work done in a fresh context, in parallel, or by a narrow specialist (reviewer, researcher) |
| **Slash command** | a user-typed `/name` that expands to a prompt | `.claude/commands/<name>.md` (or a skill) | a short, frequently-typed instruction, lighter than a full skill |
| **Hook** | a shell command the harness runs on an event | `settings.json` `hooks` (PreToolUse, PostToolUse, Stop, …) | something must happen automatically every time X, without the model choosing to |
| **MCP server** | a tool/data provider Claude connects to — hosted (connect to a provider like Composio) or custom (you build it) | MCP config (`.mcp.json` / settings), plus its own process only if custom | the system needs a new capability or live data source exposed as callable tools |
| **Agent SDK app** | a standalone agentic program | a Python/TS project using the Claude Agent SDK | the system runs outside an interactive Claude Code session (a service, a scheduled job, a product surface) |
| **Script / CLI** | deterministic automation, no or thin LLM | a script, or `toolkit/features/<name>.py` in a feature-toolkit repo | the work is a mechanical transform with a clean pass/fail, LLM optional |
| **Document / context** | durable knowledge the agent reads | `CLAUDE.md`, a reference file, a memory | the "system" is really context that makes every future session better |

Compositions are normal: an MCP server plus a skill that drives it; a subagent
plus a hook that triggers it; a script wrapped by a slash command.

## How to choose (the nature of the work picks the form)

Do not pick by what the repo already contains. Pick by what the work *is*:

- **Synthesis, judgment, reading messy input, conversation** → skill or subagent.
- **Deterministic transform with a real pass/fail** → script / CLI.
- **Must fire automatically on an event** → hook.
- **New capability or live data** → MCP server. Connect before you build (next section).
- **Runs unattended, outside a chat** → Agent SDK app.
- **Makes every future session smarter** → document / context.

When two forms both fit, prefer the lighter one, and prefer the form whose "done"
you can actually verify (below). If the work is genuinely agentic (the thing
itself reasons), do not bury it in a deterministic script just because a script is
easier to check. Fix the verification instead.

## Connect before you build (integrations)

Before building any capability, check whether a connection already exposes it as
MCP tools — and check in this order. Don't reach for a third-party provider first.

**1. Look at the integrations available in your own public marketplace.** Claude
Code ships a marketplace of first-party and official connectors — the same set you'd
browse to add any integration (the `/mcp` menu, the connector/plugin marketplace,
`claude mcp` listings). Ask the question of yourself — "look at the integrations I
have available in my public marketplace" — and run that check with whatever your host
gives you; there's no separate program and no list Boots maintains. If an official
connector covers the app the system needs, connect through that: it's first-party
(more trusted than a middleman) and it needs no second account from the user. Record
the app in the system file as connecting **via marketplace**, and log which connector
you used and to which account. This is the default whenever the marketplace has the app.

**2. Only if the marketplace comes up empty for that app, fall back to a hosted
provider.** The named default is **Composio** (composio.dev): 800+ SaaS toolkits
(Gmail, Slack, Notion, GitHub, HubSpot, calendars, CRMs) with managed OAuth, so
"read the user's inbox" is a connection, not a build. Everything below in this
section — scoped sessions, `composio login`, the secret discipline — is the hosted
route.

**3. Write a custom MCP server** only when the API is niche, internal, or
self-hosted — the same reason you'd write any code a library already covers.

Both routes start from a **scoped session**, never the broad endpoint, because
everything running inside a Claude Code session inherits every MCP server that
session has:

- **Skill / subagent / command / hook** (runs inside a Claude Code session) →
  mint a scoped session for this system and register its MCP URL for this project
  at local scope (project-specific but outside git), or env-expanded in
  `.mcp.json`. Do not register the broad `connect.composio.dev` endpoint at user
  scope for convenience: every session-borne system would see all of it,
  regardless of its own scoped tool list. If the user wants the broad endpoint
  for their own interactive use, that is a conscious choice they make, not a
  default Boots sets.
- **Agent SDK app / script** (runs outside a session) → the Composio SDK creates a
  scoped session (`composio.create(user_id, toolkits=[...], tools={...}, mcp=True)`)
  whose MCP URL you pass into `ClaudeAgentOptions.mcp_servers`.

These rules travel with every connection:

- **Least privilege, read-only by default.** Enable only the specific tools scope
  named (`GMAIL_FETCH_EMAILS`, not all of gmail) — the scoped-session route
  enforces this by construction. Outward-acting tools (send, post, delete) are a
  deliberate scope decision, never a default: the system will read untrusted
  content *through* this connection, and a read-only session is what contains an
  injected instruction.
- **The master key is a browser login, never a typed key.** The user runs
  `composio login` once — a browser opens, they log into their Composio account,
  and the key is stored in the OS keyring (macOS Keychain), never typed into the
  terminal, a file, or the chat. Boots checks whether they are already logged in
  and only runs `composio login` if not. The key stays in the keyring: never copy
  it into a file, a shell profile, a committed config, or the chat, and never ask
  the user to paste it anywhere. It is used once at build time to mint the session
  and never reaches the running artifact. If the mint tool needs the key in its
  env (the SDK reads `COMPOSIO_API_KEY`; the CLI reads the keyring directly),
  prefer the CLI, or read the key from the keyring for that one mint command only
  — a visible, one-shot action, never a persisted export or a file.
- **The session URL is the runtime secret, and it lives in the built system's
  `.env`.** A session URL is a bearer credential with a small blast radius (one
  account, the named tools, read-only), and it is what the *running* artifact uses,
  every run. Boots writes it into the built system's own gitignored `.env` (and
  writes the `.gitignore` entry itself — you write these files, the user does not),
  `${VAR}`-expanded from any config that needs it. Never print the URL into the
  chat, never write it into a committed file, an artifact, a system file, or a
  note, and never into boots-03 itself.
- **A self-running system reads its secret from a file, not a login shell.**
  `~/.zshrc` is sourced only by interactive login shells, so a cron job, launchd
  agent, scheduled cloud agent, or headless `claude -p` never sees a var set there
  — it would run with no credential and fail silently. So the runtime secret must
  live where an unattended process actually reads it: for a skill / subagent / hook,
  the session URL in local-scope MCP config (`.mcp.json` / `.claude/settings.local.json`,
  read from disk); for an Agent SDK app or script on launchd/cron, the `.env`
  loaded by the app (dotenv) or a launchd `EnvironmentFile` — and if a dotfile is
  unavoidable, `~/.zshenv` (all shells), never `~/.zshrc`. Mint once at build,
  persist only the scoped session URL; the self-running artifact never holds the
  master key.
- **The login handoff is the user's one job.** Boots generates the connect link
  (`session.authorize("gmail")` → redirect URL), hands over that single link, and
  confirms the connected account shows `ACTIVE` before moving on. Everything else
  — config, registration, tool selection — Boots does itself.

To the user, the default name for this is never "Composio," "MCP," or "an integration."
It is **"a ready-made connection to your Gmail/Slack that handles the login for you."**
The one place the real name is unavoidable is setup — the `composio login` they run
once (a browser opens, they sign in), the connect link they click. There, do not drop
"Composio" bare: introduce it once — what it is (the service behind that ready-made
connection) and how it works for them (they sign in through their browser once, then
connect their Gmail the same way, and the system only reads) — then the name is fine. See the translation table in `boots/SKILL.md` for the
master rule.

### Field-tested setup notes (Composio)

- **The API key needs WRITE scope.** A read-only Composio key can list accounts but
  **cannot create connections or MCP servers** — `initiate` returns 403
  "connected_accounts write access". If connect fails this way, the user's key is
  restricted; have them issue a full/write key. Check this before anything else.
- **MCP servers register at session start.** A mid-session `claude mcp add ... --scope
  local` (which correctly keeps the URL out of git) does **not** appear in the running
  session — its tools load next session. So build/verify can't call the in-session MCP
  tools the same turn you register them. **Fallback: drive the connection via the
  Composio Python SDK** (`c.tools.execute("GMAIL_FETCH_EMAILS", user_id=..., arguments=...,
  dangerously_skip_version_check=True)`) — same connection, same read-only tools, proves
  the pipe now. Tell the user a fresh session is needed for the in-chat path.
- **Install the SDK in a venv** — system Python is often PEP-668 "externally managed";
  `python3 -m venv` then `pip install composio`.
- **Get the key in by browser login, not by editing a shell file.** Handing a
  nontechnical user a shell `export ... >> ~/.zshrc` command repeatedly failed on
  quote-escaping (a stuck `quote>` prompt) — and even done right it leaves a plaintext
  master key in their profile forever. Use `composio login` instead: a browser opens,
  they sign in, the key lands in the OS keyring (Keychain), encrypted, never typed into
  the chat or a file. The gotcha that replaces the old one: the keyring is a CLI store,
  so the Python/TS SDK (which reads `COMPOSIO_API_KEY` from env) won't pick it up on its
  own — mint through the `composio` CLI, or resolve the key from the keyring for that one
  command; don't fall back to writing it into a file or a shell profile.

### Reading a provider inbox — gotchas any Gmail/mail system hits

- A subject/label search **also returns the user's own outbound mail** — exclude their
  own addresses (all of them; watch for a separate outreach subdomain) and SENT-labelled
  messages; keep only inbound.
- `GMAIL_FETCH_EMAILS` list results **truncate the body to ~200 chars** — fetch the full
  body per message with `GMAIL_FETCH_MESSAGE_BY_MESSAGE_ID` before extracting anything.
- Bodies carry the **quoted-reply tail and sometimes raw HTML** — strip before quoting.
- **`resultSizeEstimate` is unreliable** (saw 201 vs 600+) — always paginate `nextPageToken`
  and report counts as a floor if you cap the sweep.

## How to verify each form (Claude Code)

`boots-verify` runs the check that matches the form. Exit-0 only applies to code.

- **Skill** → invoke it in a real session on a fixture input, observe it triggers,
  follows its own steps, produces the result. Evidence is the transcript.
- **Subagent** → spawn it on a test task, check the returned result against the ask.
- **Slash command** → type it, observe the expansion runs.
- **Hook** → cause the event, confirm the hook fired and did its job (its side
  effect, e.g. a file it writes).
- **MCP server** → call one of its tools, check the response shape and a real value.
  For a hosted connection (Composio), first confirm the connected account is
  `ACTIVE`, so an auth failure is not blamed on the artifact.
- **Agent SDK app** → run it end-to-end on a fixture, check the output.
- **Script / CLI** → run it, exit 0 plus expected output. In a feature-toolkit repo
  this can use the repo's own verify (`python -m toolkit verify <id>`).
- **Document / context** → mostly a human judgment: does a fresh session reading it
  behave better. If it makes a checkable claim, check that.

If a form has no mechanical check, say so and route it to a human read. Do not fake
a pass. "I ran it and here is the real output" is the only pass.

## What "shipped" means per form (Claude Code)

- **Skill / subagent / command** → the file is in place and it is invocable (shows
  up, triggers, runs). Not "the file exists," it responds.
- **Hook** → wired in settings and confirmed firing.
- **MCP server** → connectable, its tools appear and answer. For a hosted
  connection: registered at a scope that keeps the credential out of git, the
  connected account `ACTIVE`, and the one-time prerequisite (the user logged in via
  `composio login`, key in the keyring) documented.
- **Agent SDK app** → runnable with one documented command.
- **Script / CLI** → invocable from its entry point (a toolkit feature shows in
  `python -m toolkit`).
- **Document** → the final file in its resting place, and something reads it.

## Exact syntax drifts, so don't hardcode it here

Frontmatter fields, hook event names, MCP config shape, and Agent SDK package
names change over time. This file teaches the *decision and the shape*. When you
need the current exact syntax for a Claude Code form, check the `/claude-code-guide`
skill or the Claude Code docs at build time rather than trusting a frozen snippet.
