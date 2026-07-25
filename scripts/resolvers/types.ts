import { ALL_HOST_CONFIGS } from '../../hosts/index';

/** Host union, derived from configs. */
export type Host = (typeof ALL_HOST_CONFIGS)[number]['name'];

export interface HostPaths {
  /** Skill root for this host (e.g. '~/.claude/skills' or '$BOOTS_ROOT'). */
  skillRoot: string;
  /** Project-local skill root (repo-relative). */
  localSkillRoot: string;
  /** bin dir for helper scripts. */
  binDir: string;
  /** The boots skill's own dir (holds bin/, forms/, examples/). */
  skillDir: string;
  /**
   * Where a system's records live: `<boots-home>/systems/<slug>/`. This is the
   * global Boots home (`~/.boots`), NOT the skill root — systems are the user's
   * work and must be findable from any directory, so they never live per-repo.
   * The bin scripts read the same convention at runtime via
   * `${BOOTS_HOME:-$HOME/.boots}/systems`.
   */
  systemsDir: string;
  /**
   * The global Boots home itself (`~/.boots`) — the parent of `systems/`. Holds
   * the cross-system records that belong to no single system, chiefly `map.md`.
   */
  bootsHome: string;
  /**
   * `<boots-home>/map.md` — Boots' standing answer to "what is this person
   * actually building", the questions in play, and which systems serve each.
   * One per user, above the systems, read by the router and `boots-rethink`.
   */
  mapFile: string;
}

/**
 * HOST_PATHS — derived from host configs. Non-Claude hosts use $BOOTS_ROOT
 * env vars set by the preamble bootstrap; Claude uses absolute ~ paths.
 */
function buildHostPaths(): Record<string, HostPaths> {
  const paths: Record<string, HostPaths> = {};
  for (const config of ALL_HOST_CONFIGS) {
    if (config.usesEnvVars) {
      paths[config.name] = {
        skillRoot: '$BOOTS_ROOT',
        localSkillRoot: config.localSkillRoot,
        binDir: '$BOOTS_BIN',
        skillDir: '$BOOTS_ROOT/boots',
        systemsDir: '$BOOTS_HOME/systems',
        bootsHome: '$BOOTS_HOME',
        mapFile: '$BOOTS_HOME/map.md',
      };
    } else {
      const root = `~/${config.globalRoot}`;
      paths[config.name] = {
        skillRoot: root,
        localSkillRoot: config.localSkillRoot,
        binDir: `${root}/boots/bin`,
        skillDir: `${root}/boots`,
        // Boots home is fixed at ~/.boots regardless of where skills install.
        systemsDir: '~/.boots/systems',
        bootsHome: '~/.boots',
        mapFile: '~/.boots/map.md',
      };
    }
  }
  return paths;
}

export const HOST_PATHS: Record<string, HostPaths> = buildHostPaths();

/**
 * Context passed to every resolver. Built from a template's own frontmatter
 * (skillName, preambleTier, interactive) plus the target host.
 */
export interface TemplateContext {
  skillName: string;
  tmplPath: string;
  host: Host;
  paths: HostPaths;
  preambleTier?: number;
  interactive?: boolean;
}

export type ResolverFn = (ctx: TemplateContext, args?: string[]) => string;

/** A resolver is either a bare function or a gated { resolve, appliesTo } entry. */
export type ResolverValue =
  | ResolverFn
  | { resolve: ResolverFn; appliesTo?: (ctx: TemplateContext) => boolean };

export function unwrapResolver(entry: ResolverValue): {
  resolve: ResolverFn;
  appliesTo?: (ctx: TemplateContext) => boolean;
} {
  return typeof entry === 'function' ? { resolve: entry } : entry;
}
