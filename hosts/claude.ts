import type { HostConfig } from '../scripts/host-config';

const claude: HostConfig = {
  name: 'claude',
  displayName: 'Claude Code',
  cliCommand: 'claude',
  cliAliases: [],

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
