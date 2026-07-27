# Adding a platform

Boots runs on more than one runtime. This is how to add another one, and — more
importantly — how to tell whether you are adding a **host** or a **platform**,
because they cost very different amounts.

## First, work out which one you have

**A new host, same platform.** The runtime is the same *kind* of machine as one
Boots already targets: it has a shell, a disk, and a folder it reads `SKILL.md`
from. Cursor, Factory, Kiro, OpenCode are all this. They differ in where the file
goes and what frontmatter they accept, and in nothing else that matters to Boots.

→ **One config file, no prose.** Copy `hosts/codex.ts`, change the paths, point
`platform.palette` at `claude-code`. Done.

**A new platform.** The runtime can build *different things*, or its relationship
to the user's files is different. Cowork is this: it runs work on a schedule with
nobody watching, connects to the user's apps, persists pages — and its filesystem
is thrown away when the session ends, so it cannot even keep a record the way a
terminal host does.

→ **Three files.** A host config, a forms palette, and (only if the home is not a
fixed path) a home protocol.

The test is not "does it install differently". It is **"would the answer to *what
should this system be?* change?"** If a user's Monday-morning digest has to become
a scheduled task here and a cron script there, that is a platform. If it is the
same skill in a different folder, that is a host.

## Adding a host (same platform)

1. `hosts/<name>.ts` — copy the nearest existing one. Set `platform.palette` to the
   palette that already describes this runtime's capabilities.
2. Register it in `hosts/index.ts` (import, and append to `ALL_HOST_CONFIGS`).
3. `bun run gen:skill-docs --host <name>`.

No skill is touched. That is the whole point of the split.

## Adding a platform

### 1. `hosts/<name>.ts`

The two groups that matter:

```ts
  platform: {
    runtime: 'Cowork',      // what the user calls it; renders {{RUNTIME}}
    palette: 'cowork',      // boots/forms/cowork.md; renders {{DEFAULT_PLATFORM}}
    homeModel: 'resolved',  // 'fixed' if the agent's disk IS the user's disk
  },
  packaging: 'plugin',      // or 'symlink' for a host that installs via ./setup
```

`homeModel` is the consequential one. `'fixed'` means the Boots home is a path
(`~/.boots`) and there is nothing to work out. `'resolved'` means every session
must *find* it, because the agent's filesystem is not the user's and does not
survive the session. Choosing `'fixed'` for a runtime that is really `'resolved'`
produces a Boots that writes the user's records into a sandbox and loses them —
which is not a hypothetical, it is what the first Cowork build did.

### 2. `boots/forms/<palette>.md`

**This is where all platform-specific prose goes.** The forms available, how to
choose between them, how to verify each, what "shipped" means for each, and the
plain-English words to use with the user for each. `boots/forms/README.md` has the
section contract; copy the shape of an existing palette and fill it in.

Do not put any of this in a skill body. A skill body that says "Cowork" is a skill
body that needs a second copy for the next platform, and a second copy is how the
first Cowork build drifted in both directions without anyone noticing.

### 3. `boots/reference/home-<homeModel>.md` (only for a new home model)

Rendered into every skill by `{{HOME_PROTOCOL}}`. `home-resolved.md` already
exists; you only need a new one if you invent a third way for a session to relate
to the user's files. A `'fixed'` platform needs no file — the resolver renders
nothing, which is correct.

### 4. Register and build

```bash
# hosts/index.ts: import it, append to ALL_HOST_CONFIGS
bun run gen:skill-docs --host <name>
bun run scripts/build-plugin.ts --host <name>   # if packaging is 'plugin'
bash scripts/test-platform.sh                   # the invariants below
```

## The placeholders a skill body may use

This is the whole platform vocabulary. There are deliberately few of them, and
adding a fifth should be an argument, not a reflex — the palette is where new
platform knowledge belongs.

| Placeholder | Renders | Use it for |
| --- | --- | --- |
| `{{RUNTIME}}` | `Cowork` | naming the product in a sentence |
| `{{DEFAULT_PLATFORM}}` | `cowork` | the palette a system defaults to |
| `{{FORMS_DIR}}` | `…/skills/boots/forms` | pointing at the palettes |
| `{{HOME_PROTOCOL}}` | a section, or nothing | the home-resolution rules |

Plus the path placeholders, which are packaging rather than platform:
`{{SKILL_DIR}}`, `{{BIN_DIR}}`, `{{BOOTS_HOME}}`, `{{SYSTEMS_DIR}}`, `{{MAP_FILE}}`.

**Inside a ```bash block, use the `_SH` variants** — `{{BOOTS_HOME_SH}}`,
`{{SYSTEMS_DIR_SH}}`, `{{MAP_FILE_SH}}` — and **do not add your own quotes**. They
arrive quoted correctly for the host. The prose forms cannot be reused in shell:
`~/.boots` must stay unquoted for the tilde to expand, while a resolved home is a
path the user chose and routinely has a space in it (`Boots Co-work`), so it must
be quoted. Quoting the tilde silently creates a directory literally named `~`;
leaving the resolved form bare silently truncates at the first space. Both write
the user's records somewhere that is not the home, and neither errors.

## The invariants (`scripts/test-platform.sh`)

These are what keep the seam from rotting back into per-platform copies:

- no skill template names a runtime or a palette literally
- every host config validates, and every palette it names exists
- generated output for one platform contains nothing from another
- no generated bash block contains a quoted tilde
- no generated skill carries an unresolved placeholder or a build-machine path
- a `packaging: 'plugin'` host produces a bundle that is loadable, not merely present
