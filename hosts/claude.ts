import type { HostConfig } from '../scripts/host-config';

const claude: HostConfig = {
  name: 'claude',
  displayName: 'Claude Code',
  cliCommand: 'claude',
  cliAliases: [],

  // A terminal agent: its disk is the user's disk, so the Boots home is a fixed
  // path and every form in the palette is something you can build with a shell.
  platform: {
    runtime: 'Claude Code',
    palette: 'claude-code',
    homeModel: 'fixed',
  },

  packaging: 'symlink',
  globalRoot: '.claude/skills',
  localSkillRoot: '.claude/skills',
  hostSubdir: '.claude',
  usesEnvVars: false,

  frontmatter: {
    mode: 'denylist',
    stripFields: ['voice-triggers'],
    descriptionLimit: null,
  },

  generation: {
    generateMetadata: false,
  },

  pathRewrites: [], // primary host — no rewrites
  toolRewrites: {},
  suppressedResolvers: [],
};

export default claude;
