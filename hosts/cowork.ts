import type { HostConfig } from '../scripts/host-config';

/**
 * Cowork host config.
 *
 * Cowork is the first host that differs from Claude Code on the CAPABILITY axis,
 * not just the packaging one (see the header of scripts/host-config.ts). Three
 * differences drive everything below:
 *
 * 1. THE SESSION IS DISPOSABLE. A Cowork session runs in a sandbox that is wiped
 *    when it ends, and in the cloud case that sandbox is not the user's computer
 *    at all — their folders are reached over a device bridge. So the Boots home
 *    cannot be a path (`homeModel: 'resolved'`); every session has to find it,
 *    and a skill that hardcodes `~/.boots` writes a record that evaporates. This
 *    is not theoretical: it happened to the author three times in two days, each
 *    time silently opening a second, empty home on top of a real one.
 *
 * 2. IT INSTALLS AS A PLUGIN. There is no `git clone && ./setup` — the user
 *    installs a bundle from a marketplace (`packaging: 'plugin'`). Two
 *    consequences: `boots-upgrade` is meaningless here, because updating is the
 *    marketplace's job, not a `git pull`; and the skills refer to their own
 *    installed location as `${CLAUDE_PLUGIN_ROOT}`, which the host sets at run
 *    time.
 *
 * 3. IT CAN BUILD THINGS A TERMINAL CANNOT. Scheduled tasks that fire with nobody
 *    watching, managed connections to the user's apps, persisted pages. That is
 *    the whole reason `platform.palette` points at its own file: the list of
 *    forms, how to verify each, and what "shipped" means for each all differ, and
 *    that knowledge lives in `boots/forms/cowork.md` — never in a skill body.
 */
const cowork: HostConfig = {
  name: 'cowork',
  displayName: 'Cowork',
  cliCommand: 'cowork',
  cliAliases: [],

  platform: {
    runtime: 'Cowork',
    palette: 'cowork',
    // The one that matters. See reference/boots-home.md for the protocol the
    // preamble emits because of this line.
    homeModel: 'resolved',
  },

  packaging: 'plugin',
  // Not a real install path — a Cowork plugin is installed by the host, not
  // symlinked into a folder under $HOME. Kept as the conventional location so
  // validation and any future auto-detection have something well-formed.
  globalRoot: '.claude/plugins/boots',
  localSkillRoot: '.claude/skills',
  // Where the build step writes the installable bundle, relative to the repo.
  hostSubdir: 'dist/cowork',
  // Cowork skills do not bootstrap $BOOTS_ROOT from git — the plugin root is
  // handed to them by the host, and the Boots home is resolved, not derived.
  usesEnvVars: false,
  skillRootExpr: '${CLAUDE_PLUGIN_ROOT}/skills',

  frontmatter: {
    mode: 'denylist',
    stripFields: ['voice-triggers'],
    descriptionLimit: null,
  },

  generation: {
    generateMetadata: false,
    // Updating is the marketplace's job here, so the upgrade skill has nothing
    // to do and would tell the user to run a `git pull` they do not have.
    skipSkills: ['boots-upgrade'],
  },

  pathRewrites: [
    // Any straggling literal install path becomes the plugin-relative one. The
    // templates should not contain these at all (they use {{SKILL_DIR}} and
    // friends); this is a backstop, not the mechanism.
    { from: '~/.claude/skills/boots', to: '${CLAUDE_PLUGIN_ROOT}/skills/boots' },
    { from: '~/.claude/skills', to: '${CLAUDE_PLUGIN_ROOT}/skills' },
  ],

  suppressedResolvers: [],
};

export default cowork;
