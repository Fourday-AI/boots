import type { HostConfig } from '../scripts/host-config';

/**
 * Codex host config — present up front so adding Codex is "regenerate", not
 * "rework every skill". Not exercised by default; `bun run gen:skill-docs
 * --host codex` produces .agents/skills/boots-<name> dirs with allowlist
 * frontmatter, a 1024-char description cap (Codex rejects longer), rewrites, an
 * openai.yaml sidecar. Kept minimal — expand suppressedResolvers as Boots
 * grows resolvers Codex can't run (e.g. anything that invokes Claude itself).
 */
const codex: HostConfig = {
  name: 'codex',
  displayName: 'OpenAI Codex CLI',
  cliCommand: 'codex',
  cliAliases: ['agents'],

  // Another terminal agent. Same capability axis as Claude Code — shell, disk,
  // fixed home — so it reads the same palette. This is the normal case: hosts
  // differ in packaging, not in what they can build.
  platform: {
    runtime: 'Codex',
    palette: 'claude-code',
    homeModel: 'fixed',
  },

  packaging: 'symlink',
  globalRoot: '.codex/skills',
  localSkillRoot: '.agents/skills',
  hostSubdir: '.agents',
  usesEnvVars: true,

  frontmatter: {
    mode: 'allowlist',
    keepFields: ['name', 'description'],
    descriptionLimit: 1024,
    descriptionLimitBehavior: 'error',
  },

  generation: {
    generateMetadata: true,
    metadataFormat: 'openai.yaml',
  },

  pathRewrites: [
    { from: '~/.claude/skills', to: '$BOOTS_ROOT' },
    { from: '.claude/skills', to: '.agents/skills' },
  ],

  suppressedResolvers: [],
};

export default codex;
