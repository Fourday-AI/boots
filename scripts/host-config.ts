/**
 * Declarative host config system.
 *
 * Each supported host (Claude, Codex, Cowork, …) is a typed HostConfig in
 * hosts/*.ts. Adding a host = drop a new hosts/<name>.ts + register it in
 * hosts/index.ts, then `bun run gen:skill-docs --host <name>`. No per-skill rework.
 *
 * This is deliberately trimmed to only what the generation pipeline reads.
 * The ancestor HostConfig also carried runtimeRoot / sidecar / install / co-author
 * fields that belong to its bash setup, not the generator — Boots' setup owns
 * those separately, so they're omitted here.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * TWO AXES, AND THEY ARE NOT THE SAME AXIS
 *
 * The ancestor of this file assumed every host was the same KIND of machine: a
 * terminal agent with a shell, a disk, and a folder it reads SKILL.md from. Nine
 * such hosts differ only in WHERE the file goes and WHAT FRONTMATTER it accepts —
 * so a host was pure packaging config, and none of the skills' prose ever changed.
 *
 * Cowork broke that assumption. It differs in what the runtime can DO:
 *   - its filesystem is disposable, wiped when the session ends, so the Boots home
 *     cannot be a fixed path in it — the session has to FIND the user's home
 *   - it reaches the user's disk over a bridge, not directly
 *   - it can build forms no terminal host has: work that runs on a schedule with
 *     nobody watching, connections to the user's apps, pages that persist
 *
 * So a HostConfig now carries two independent groups:
 *
 *   PACKAGING (`globalRoot`, `hostSubdir`, `frontmatter`, `packaging`, …)
 *     — where the built skill goes and what shape it is. Cosmetic. Every
 *       terminal host differs here and only here.
 *
 *   PLATFORM (`platform`)
 *     — what the runtime can do. Drives which forms palette the skills read,
 *       what the product is called, and how a session locates the Boots home.
 *
 * The rule that keeps this from rotting: platform-specific PROSE belongs in
 * `boots/forms/<palette>.md`, never in a skill body. A skill body may vary only
 * through the placeholders resolved from this config. If you find yourself wanting
 * to add a second paragraph here, it belongs in the palette instead.
 * See docs/adding-a-platform.md.
 * ─────────────────────────────────────────────────────────────────────────────
 */

/**
 * How a session locates the Boots home (where every record lives).
 *
 * 'fixed'    — a known absolute path on the machine the agent runs on (`~/.boots`).
 *              True for every terminal host: the agent's disk IS the user's disk.
 * 'resolved' — must be discovered at the start of every session, because the
 *              agent's filesystem is NOT the user's and is thrown away when the
 *              session ends. True for Cowork. Skills built for a 'resolved' host
 *              carry the home-resolution protocol in their preamble and must never
 *              hardcode a path.
 */
export type HomeModel = 'fixed' | 'resolved';

/**
 * How built skills reach the host.
 *
 * 'symlink' — `./setup` links each skill dir into the host's skills folder in
 *             place, so `git pull && ./setup` updates every project at once.
 * 'plugin'  — the repo emits an installable bundle (a manifest plus a skills/
 *             tree) that the user installs through the host's own plugin
 *             mechanism. There is no symlink and no `./setup` on the user's side.
 */
export type Packaging = 'symlink' | 'plugin';

export interface PlatformConfig {
  /**
   * The product name as the user knows it. Renders `{{RUNTIME}}`.
   * "Claude Code", "Cowork".
   */
  runtime: string;
  /**
   * Which forms palette this platform's skills read: `boots/forms/<palette>.md`.
   * This is the capability layer — the list of shapes a system can take on this
   * runtime, and how to verify and ship each. Renders `{{DEFAULT_PLATFORM}}`.
   */
  palette: string;
  /** How a session finds the Boots home. See HomeModel. */
  homeModel: HomeModel;
}

export interface HostConfig {
  /** Unique host identifier. Must match the filename in hosts/. */
  name: string;
  /** Human-readable name for logs/errors. */
  displayName: string;
  /** Binary name (for future host auto-detection). */
  cliCommand: string;
  /** Alternative binary names (e.g. ['agents'] for codex). */
  cliAliases?: string[];

  // --- Platform (the capability axis — see the header) ---
  platform: PlatformConfig;

  // --- Packaging ---
  /** How built skills reach the host. See Packaging. Defaults to 'symlink'. */
  packaging?: Packaging;
  /** Global install path relative to $HOME. Drives HOST_PATHS. */
  globalRoot: string;
  /** Project-local skill path relative to repo root. */
  localSkillRoot: string;
  /** Output subdir under repo root for generated docs (e.g. '.agents'). */
  hostSubdir: string;
  /** Whether the preamble emits $BOOTS_ROOT env vars (true for non-Claude hosts). */
  usesEnvVars: boolean;
  /**
   * Override for how a skill refers to its own installed location, when the host
   * neither uses `~/<globalRoot>` (Claude) nor the `$BOOTS_ROOT` bootstrap (Codex).
   * A plugin host knows its root at run time from its own variable, so Cowork sets
   * this to `${CLAUDE_PLUGIN_ROOT}/skills`. Renders `{{SKILL_DIR}}`'s parent.
   */
  skillRootExpr?: string;

  // --- Frontmatter transformation ---
  frontmatter: {
    /** 'allowlist': only keepFields survive. 'denylist': strip listed fields. */
    mode: 'allowlist' | 'denylist';
    keepFields?: string[];
    stripFields?: string[];
    /** Max chars for description. null = no limit. */
    descriptionLimit?: number | null;
    descriptionLimitBehavior?: 'error' | 'truncate' | 'warn';
    extraFields?: Record<string, unknown>;
    renameFields?: Record<string, string>;
    conditionalFields?: Array<{ if: Record<string, unknown>; add: Record<string, unknown> }>;
  };

  // --- Generation ---
  generation: {
    /** Emit a sidecar metadata file (e.g. openai.yaml for Codex). */
    generateMetadata: boolean;
    metadataFormat?: string | null;
    /** Skill dirs to exclude for this host. */
    skipSkills?: string[];
    /** Skill dirs to include (allowlist). Union logic: include minus skip. */
    includeSkills?: string[];
  };

  // --- Content rewrites ---
  /** Literal replaceAll on generated content. Order matters. */
  pathRewrites: Array<{ from: string; to: string }>;
  toolRewrites?: Record<string, string>;
  /** Resolver names that render as '' for this host. */
  suppressedResolvers?: string[];
}

// --- Validation ---

const NAME_REGEX = /^[a-z][a-z0-9-]*$/;
const PATH_REGEX = /^[a-zA-Z0-9_.\/${}~-]+$/;

export function validateHostConfig(config: HostConfig): string[] {
  const errors: string[] = [];
  if (!NAME_REGEX.test(config.name)) errors.push(`name '${config.name}' must be lowercase alphanumeric with hyphens`);
  if (!config.displayName) errors.push('displayName is required');
  if (!PATH_REGEX.test(config.globalRoot)) errors.push(`globalRoot '${config.globalRoot}' has invalid characters`);
  if (!PATH_REGEX.test(config.localSkillRoot)) errors.push(`localSkillRoot '${config.localSkillRoot}' has invalid characters`);
  if (!PATH_REGEX.test(config.hostSubdir)) errors.push(`hostSubdir '${config.hostSubdir}' has invalid characters`);
  if (!['allowlist', 'denylist'].includes(config.frontmatter.mode)) errors.push(`frontmatter.mode must be 'allowlist' or 'denylist'`);

  // Platform (the capability axis). A host that names a palette Boots does not
  // ship would generate skills that tell the agent to read a file that isn't
  // there — silently, at run time, in the user's session. Catch it at build.
  const p = config.platform;
  if (!p) {
    errors.push('platform is required — every host must declare its capability axis (see host-config.ts header)');
  } else {
    if (!p.runtime) errors.push('platform.runtime is required (the product name the user knows)');
    if (!NAME_REGEX.test(p.palette || '')) errors.push(`platform.palette '${p.palette}' must be lowercase alphanumeric with hyphens`);
    if (!['fixed', 'resolved'].includes(p.homeModel)) errors.push(`platform.homeModel must be 'fixed' or 'resolved'`);
  }
  if (config.packaging && !['symlink', 'plugin'].includes(config.packaging)) {
    errors.push(`packaging must be 'symlink' or 'plugin'`);
  }
  if (config.skillRootExpr && !PATH_REGEX.test(config.skillRootExpr)) {
    errors.push(`skillRootExpr '${config.skillRootExpr}' has invalid characters`);
  }
  return errors;
}

/** Does the palette this host names actually exist in the repo? */
export function paletteFileFor(config: HostConfig): string {
  return `boots/forms/${config.platform.palette}.md`;
}
