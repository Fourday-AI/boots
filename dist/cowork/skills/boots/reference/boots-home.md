# The Boots home (where the record lives, and how to reach it)

Every Boots skill reads and writes one place: the **Boots home**. This file is the
shared protocol. Every skill's preamble points here rather than restating it.

It applies to any platform whose `homeModel` is `resolved` — a runtime whose
filesystem is not the user's and does not survive the session. On a platform where
the agent's disk *is* the user's disk, none of this is needed: the home is simply
`~/.boots` and there is nothing to resolve.

## Why it is not in the session

A session here runs in a sandbox that is **wiped when it ends**. Anything Boots
writes to the sandbox is gone by the next chat. Boots' entire promise is that
opening a new chat feels like continuing the last one, so the record cannot live
there. It lives in a folder on the user's own computer:

```
<a connected folder>/Boots/
├── map.md                     the standing guess at what they're building
├── config.yaml
├── systems/
│   └── <slug>/
│       ├── system.md          the record
│       ├── events.jsonl       the funnel
│       └── sessions/          one file per chat
├── analytics/
└── .bin/                      the Boots scripts, installed here so every tool can run them
```

## Resolving it (do this once per session, before anything else)

```bash
bash "{{SKILL_DIR}}/bin/boots-home"
```

It prints three lines. Parse them, do not guess:

```
BOOTS_MODE local|bridge|absent
BOOTS_HOME <path, or empty>
BOOTS_BIN  <path, or empty>
```

**`local`** — the folder is directly visible to this session. True when the runtime
is on the user's computer, and when a connected folder is mounted in. Run every
Boots script with the **`Bash`** tool. You are done resolving.

**`absent` from this script does not mean absent.** The script runs in the session
sandbox. In a cloud session the user's folders are not there — they are on the
other side of the device bridge, which no shell command can see into. So an
`absent` here is the first of four steps, not a verdict:

1. `boots-home` says `local` → done, use **`Bash`**.

2. **Probe the bridge.** Get the connected folder roots from `get_device_info`
   (or from the session's own notice of which folders are connected) and call
   `device_list_dir` on each. A root containing a `Boots/` folder is the home;
   `<bin>` is `<home>/.bin`; the mode is **`bridge`** and every Boots script runs
   with **`device_bash`**. Use `device_stage_files` to pull a file into the
   session when you need to read it closely, and `device_commit_files` to write
   one back.

3. **Nothing connected? Look before you build, then ask.** `get_device_info` also
   returns **`homeDirectories`** — a names-only listing of the user's home folder,
   readable with no permission at all. Scan it for `.boots` and for any folder
   that would hold a `Boots` (the user may have named it anything; `Boots Co-work`
   is one real example). If you find a candidate, the user has a home and you have
   simply not been given access to it yet — call `device_request_folder_access` on
   it. This works for hidden directories, and it is one tap for the user. If they
   decline, take that as an answer and continue without a home rather than
   creating one.

4. Only when the bridge is unavailable, **and** no connected folder holds a
   `Boots/`, **and** nothing in `homeDirectories` looks like one, is the mode
   really `absent`. See "First run" below.

**Skipping step 2 or step 3 is the failure this protocol exists to prevent**, and
it is not hypothetical — it happened three times in two days to Boots' own author.
Each time the sequence was identical: no folder connected at session start, the
probe correctly reported `absent` about the sandbox, and the session then created a
second, empty Boots home. The real one held nine systems and the map. The session
opened on the empty one and would have reported a near-empty board as the truth.
The only thing that caught it was a hand-written warning note the user had put in
the decoy — which no stranger will have.

The tell is worth naming plainly: **a user who has been using Boots does not
suddenly have no systems.** If the board comes back empty for someone who talks
like they have work in flight, you have found the wrong folder, not an empty one.

**The command string is the same in both modes.** Only the tool changes:

```bash
BOOTS_HOME="<home>" bash "<bin>/boots-analytics" --brief
```

Always pass `BOOTS_HOME` explicitly, in **every** block. Two reasons, and both bite
silently. The scripts refuse to guess a path, on purpose: a fallback to a sandbox
path would write a record that vanishes with the session, which is the one failure
this whole design exists to prevent. And each bash block you run is its own
invocation — `device_bash` is a fresh `bash -c` every time, with no exported
variables and no working directory carried over from the last one. An `export` in
the preamble is gone by the next block.

**In bridge mode, `BOOTS_HOME` is the mount path, not the path the user would
type.** `device_bash` runs inside the user's local workspace, where their connected
folders appear under `/sessions/<session>/mnt/<folder-name>`. A raw `/Users/...`
path fails with `mkdir: cannot create directory '/Users': Permission denied` — a
confusing error for what is really a wrong-prefix problem. Resolve the mount path
once (`pwd` and `ls mnt/` in a `device_bash` call) and use it everywhere. Convert
back to the user-facing path only when *telling the user* where something is.

**Git writes do not work across the bridge.** Reads are fine, but `.git/index.lock`
cannot be unlinked, so `git commit` and anything that takes the index lock will
fail. Do not plan a flow that ends in a commit from a bridged session — make the
file changes and hand the commit to the user.

## First run (`BOOTS_MODE absent`)

Two cases, and they are different problems.

**No connected folder at all.** Boots cannot persist anything, and should say so
plainly before doing any work — not after. In plain words: Boots keeps track of
what you're building in a folder on your computer, and it needs one connected to
do that. Ask the user to connect a folder (the "Add folder" button in the desktop
app), or call `device_request_folder_access` on a folder you have confirmed exists.
Do not start a system you cannot record. Working for twenty minutes and then losing
it is worse than saying this up front.

**A connected folder, but no `Boots/` in it.** Just make one. Do not ask permission
to create a folder — that is exactly the "do the prep, don't ask permission to
prep" rule. Pick the most sensible connected folder, set the home up, and mention
in one line where it went.

*If the folder is directly visible* (`local`), one command does it:

```bash
bash "{{SKILL_DIR}}/bin/boots-setup" --home "<connected folder>/Boots"
```

*If the folder is only across the bridge*, the plugin's scripts live in the sandbox
and `device_bash` cannot see them, so the same setup takes three moves:

1. `device_bash`: `mkdir -p "<connected folder>/Boots/systems" "<connected folder>/Boots/analytics" "<connected folder>/Boots/.bin"`
2. Send each file in `{{SKILL_DIR}}/bin/` plus the plugin's `VERSION`
   with `SendUserFile`, then `device_commit_files` each returned `fileUuid` to
   `<connected folder>/Boots/.bin/<name>`.
3. `device_bash`: `chmod +x "<connected folder>/Boots/.bin/"*`

Either way the point is the same: the scripts end up at `<home>/.bin/`, which is
what makes them runnable from whichever tool this session has. Re-running setup is
safe — it refreshes the scripts and never touches `systems/`, `map.md`, or
`config.yaml`.

Then check whether the user is bringing existing work with them:

```bash
BOOTS_HOME="<home>" bash "<bin>/boots-migrate-systems" --dry-run
```

This finds a Boots home from another platform (`~/.boots/systems/`) or a legacy
per-repo `state/systems/`. If it reports anything, show what it found and ask once
whether to bring those systems across. It copies, never moves.

## Moving, and multiple homes

If the probe finds more than one candidate `Boots/` folder, **ask which one rather
than picking**. Picking is how a decoy wins: an empty home in a connected folder
looks exactly like a real one that happens to be new, and the difference only shows
up as a board that is missing the user's work.

If the user has moved the folder, the probe finds it at the new path on its own —
nothing stores an absolute path between sessions.

## What the user hears

Never "the Boots home," "`BOOTS_HOME`," "bridge mode," or a raw path in the middle
of a sentence. They hear **"the folder on your computer where I keep track of what
you're building."** When you do need to name the place — because they want to look
at it — resolve the absolute path and give them the move that turns a path into a
place: in Finder, press ⌘⇧G, paste this, hit enter. See rule 3 and rule 10 in
`boots/SKILL.md`.
