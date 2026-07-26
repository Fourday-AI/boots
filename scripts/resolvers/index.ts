/**
 * RESOLVERS — maps {{PLACEHOLDER}} names to generator functions.
 *
 * Each resolver is `(ctx) => string`, optionally gated as `{ resolve, appliesTo }`.
 * Lean by design: Boots ships PREAMBLE (the universal block) + BIN_DIR. The ancestor's
 * domain-specific resolvers are intentionally absent —
 * add resolvers here only when a real skill needs one.
 */

import type { ResolverValue } from './types';
import { generatePreamble } from './preamble';
import { generateFunnelEmit, generateFunnelRollup } from './funnel';

export const RESOLVERS: Record<string, ResolverValue> = {
  PREAMBLE: generatePreamble,
  FUNNEL_EMIT: generateFunnelEmit,
  FUNNEL_ROLLUP: generateFunnelRollup,
  BIN_DIR: (ctx) => ctx.paths.binDir,
  // The boots skill's own dir (holds bin/, forms/, examples/) — for skills that
  // read a bundled resource like the first-run example.
  SKILL_DIR: (ctx) => ctx.paths.skillDir,
  // Where a system's records live — the global Boots home, not a repo. Skills
  // reference `{{SYSTEMS_DIR}}/<slug>/...` so the path is defined once here and
  // stays in lockstep with the bin scripts' runtime default (~/.boots/systems).
  SYSTEMS_DIR: (ctx) => ctx.paths.systemsDir,
  // The Boots home itself — parent of systems/, holds the cross-system records.
  BOOTS_HOME: (ctx) => ctx.paths.bootsHome,
  // The map: Boots' standing answer to "what is this person actually building",
  // the questions in play, and which systems serve each. Lives above the systems
  // because a question outlives any one system that serves it.
  MAP_FILE: (ctx) => ctx.paths.mapFile,
};
