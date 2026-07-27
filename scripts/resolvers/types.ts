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
  /**
   * Shell-safe forms of the three above, for use INSIDE a ```bash block.
   *
   * The prose forms cannot be reused there, and getting this wrong is silent.
   * `~/.boots` must stay UNQUOTED for the tilde to expand, but a resolved home
   * is a path the user chose and routinely contains a space ("Boots Co-work"),
   * so it must be QUOTED. One spelling cannot satisfy both — quoting the tilde
   * form creates a literal directory named `~`, and leaving the resolved form
   * bare silently truncates the path at the first space and writes the record
   * somewhere that is not the home.
   *
   * So the shell forms are rendered per host with the quoting already correct.
   * A template must NOT add its own quotes around them.
   */
  bootsHomeSh: string;
  systemsDirSh: string;
  mapFileSh: string;
}

/**
 * HOST_PATHS — derived from host configs.
 *
 * Two things vary independently here, and conflating them is what produced a
 * Cowork build that wrote records into a sandbox:
 *
 *   WHERE THE SKILL LIVES (skillRoot / skillDir / binDir-for-fixed-hosts)
 *     — packaging. `~/.claude/skills` for Claude, `$BOOTS_ROOT` for the Codex
 *       bootstrap, `${CLAUDE_PLUGIN_ROOT}/skills` for a plugin host.
 *
 *   WHERE THE RECORD LIVES (bootsHome / systemsDir / mapFile)
 *     — platform.homeModel. A 'fixed' host can name `~/.boots` literally,
 *       because the agent's disk is the user's disk. A 'resolved' host must
 *       not: its filesystem is disposable and is not the user's, so every path
 *       goes through `$BOOTS_HOME`, which the preamble resolves per session.
 */
function buildHostPaths(): Record<string, HostPaths> {
  const paths: Record<string, HostPaths> = {};
  for (const config of ALL_HOST_CONFIGS) {
    // --- where the skill lives (packaging) ---
    const skillRoot = config.skillRootExpr
      ?? (config.usesEnvVars ? '$BOOTS_ROOT' : `~/${config.globalRoot}`);
    const skillDir = `${skillRoot}/boots`;

    // --- where the record lives (platform.homeModel) ---
    const resolved = config.platform.homeModel === 'resolved';
    const bootsHome = resolved ? '$BOOTS_HOME' : '~/.boots';

    // A resolved-home host cannot ship its bin scripts inside the skill and run
    // them: in the cloud case the tool that can reach the user's folders cannot
    // see the sandbox the plugin was unpacked into. So the scripts are installed
    // INTO the home, at <home>/.bin, which is the only runnable copy.
    //
    // `<bin>` and `<home>` stay as literal placeholders the agent substitutes
    // once, from Step A of the preamble — deliberately NOT shell variables. Each
    // bash block a skill runs is a separate invocation with nothing carried over,
    // so an exported variable from the preamble is gone by the next block, and a
    // path that silently expands to empty would write the record into the sandbox
    // and lose it. A visible `<bin>` that was never substituted fails loudly; an
    // empty `$BOOTS_BIN` fails silently. Blocks that need the home set
    // `BOOTS_HOME="<home>"` themselves, which is why bootsHome is a shell var.
    const binDir = resolved
      ? '<bin>'
      : (config.usesEnvVars ? '$BOOTS_BIN' : `${skillRoot}/boots/bin`);

    // Shell-safe home. `$HOME/.boots` rather than `~/.boots` precisely because it
    // survives being quoted; the tilde does not. See HostPaths.bootsHomeSh.
    const homeSh = resolved ? '"$BOOTS_HOME"' : '"$HOME/.boots"';

    paths[config.name] = {
      skillRoot,
      localSkillRoot: config.localSkillRoot,
      binDir,
      skillDir,
      systemsDir: `${bootsHome}/systems`,
      bootsHome,
      mapFile: `${bootsHome}/map.md`,
      bootsHomeSh: homeSh,
      // The trailing segment stays OUTSIDE the quotes so a glob still globs:
      // `"$BOOTS_HOME"/systems/*/system.md` expands, `"$BOOTS_HOME/systems/*"` does not.
      systemsDirSh: `${homeSh}/systems`,
      mapFileSh: `${homeSh.slice(0, -1)}/map.md"`,
    };
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
