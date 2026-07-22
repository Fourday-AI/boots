import type { TemplateContext } from './types';

/**
 * {{FUNNEL_EMIT:to}} or {{FUNNEL_EMIT:to:event}}
 *
 * Renders the "record the move" instruction a skill runs when it moves a system
 * through the pipeline — the funnel emit (Layer A). This is NOT usage tracking
 * (every skill's run is logged by the preamble's ops layer); it is the narrower
 * "systems moving through stages" view that shows where work flows and stalls.
 *
 * Args: [to, event?].
 *   - `to`  — the stage this skill lands the system on. Hardcode it (scope, build,
 *     ship…); pass "?" when the target stage is dynamic (track promotes a thread to
 *     wherever it had reached) so the model fills it from the record.
 *   - `event` — created | transition | shipped | retired (default transition).
 *
 * The `from` stage is ALWAYS the record's real prior stage, filled by the model
 * from what it just read — never a hardcoded linear assumption. That way a system
 * entered directly, out of order, or re-run is recorded truthfully. Omitted for a
 * brand-new record (created).
 */
export function generateFunnelEmit(ctx: TemplateContext, args?: string[]): string {
  const toArg = (args?.[0] ?? '').trim();
  const event = (args?.[1] ?? 'transition').trim();
  const bin = ctx.paths.binDir;

  const toClause = (!toArg || toArg === '?')
    ? `--to "<the stage you set on the record>"`
    : `--to ${toArg}`;

  const fromClause = event === 'created'
    ? ''
    : `--from "<the stage the record was actually at before you moved it>" `;

  const outcome = event === 'retired' ? 'abandoned' : 'advanced';

  const when =
    event === 'created' ? "create this system's record"
    : event === 'shipped' ? "mark this system shipped"
    : event === 'retired' ? "retire this system"
    : event === 'reopened' ? "send this shipped system back into the pipeline for real rework"
    : "move this system to its next stage";

  return `## Record the move (silent — do not narrate it)

When you ${when}, record it so the board and \`boots-surface\` can see where systems flow and stall. Invisible bookkeeping (this suite's rule 5): run it, say nothing about it.

\`\`\`bash
${bin}/boots-event --system "<slug>" --event ${event} ${fromClause}${toClause} --outcome ${outcome} 2>/dev/null || true
\`\`\`

Fill every \`<...>\` from the record you just read — the folder slug under \`${ctx.paths.systemsDir}/\`, and the real stages (not an assumed linear step: use the stage the record was actually at). If the user stalled rather than moved forward, change \`--outcome\` to \`blocked\`; if they walked away from it, \`abandoned\`.`;
}

/**
 * {{FUNNEL_ROLLUP}}
 *
 * The read side. Emits the instruction a board skill runs to fold the funnel
 * into its view — the timing/flow layer that system.md alone can't give:
 * how long each system has sat, where work piles up, what got abandoned.
 * Used by the router, boots-surface, and boots-retire.
 */
export function generateFunnelRollup(ctx: TemplateContext): string {
  const bin = ctx.paths.binDir;
  return `## The funnel — read flow and staleness (run this, fold it in)

Before you report the board, run the rollup. It reads every system's event history
and gives you what \`system.md\` cannot: how long each system has sat untouched, where
systems pile up, and what has been abandoned.

\`\`\`bash
${bin}/boots-analytics --brief 2>/dev/null || true
\`\`\`

Read the output: \`FUNNEL\` (totals — shipped / active / stalled), \`PIPELINE\` (how
many systems at each stage), \`GRAVEYARD\` (the stage systems get abandoned from), and
one \`SYS\` line per system with its \`cold=Nd\` (days since it last moved). Lead with
what is **near-finished but stalled** — something one step from done that has gone cold
is worth more than a fresh idea. Name the graveyard stage only if it is real (not
\`none yet\`). Translate everything to plain words — never show the user the stage
vocabulary or the raw output.`;
}
