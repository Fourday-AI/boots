/**
 * RESOLVERS — maps {{PLACEHOLDER}} names to generator functions.
 *
 * Each resolver is `(ctx) => string`, optionally gated as `{ resolve, appliesTo }`.
 * Lean by design: Boots ships PREAMBLE (the universal block) + BIN_DIR. gstack's
 * domain resolvers (browse/design/review-army/gbrain/…) are intentionally absent —
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
};
