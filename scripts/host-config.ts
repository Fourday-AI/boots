/**
 * Declarative host config system.
 *
 * Each supported host (Claude, Codex, …) is a typed HostConfig in hosts/*.ts.
 * Adding a host later = drop a new hosts/<name>.ts + register it in hosts/index.ts,
 * then `bun run gen:skill-docs --host <name>`. No per-skill rework.
 *
 * This is deliberately trimmed to only what the generation pipeline reads.
 * The ancestor HostConfig also carried runtimeRoot / sidecar / install / co-author
 * fields that belong to its bash setup, not the generator — Boots' setup owns
 * those separately, so they're omitted here.
 */

export interface HostConfig {
  /** Unique host identifier. Must match the filename in hosts/. */
  name: string;
  /** Human-readable name for logs/errors. */
  displayName: string;
  /** Binary name (for future host auto-detection). */
  cliCommand: string;
  /** Alternative binary names (e.g. ['agents'] for codex). */
  cliAliases?: string[];

  // --- Paths ---
  /** Global install path relative to $HOME. Drives HOST_PATHS. */
  globalRoot: string;
  /** Project-local skill path relative to repo root. */
  localSkillRoot: string;
  /** Output subdir under repo root for generated docs (e.g. '.agents'). */
  hostSubdir: string;
  /** Whether the preamble emits $BOOTS_ROOT env vars (true for non-Claude hosts). */
  usesEnvVars: boolean;

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
  return errors;
}
