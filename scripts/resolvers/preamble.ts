/**
 * Boots preamble — the universal block injected into every skill via {{PREAMBLE}}.
 *
 * The delivery model is a preamble in every skill, so update checks and telemetry
 * run no matter which skill the user enters through:
 *   - update check      → bin/boots-update-check
 *   - session tracking  → ~/.boots/sessions/<ppid>
 *   - config reads      → bin/boots-config (telemetry tier, proactive)
 *   - ops run start      → ~/.boots/runs.jsonl (Layer B; started here, closed in epilogue)
 *   - one-time consent   → AskUserQuestion, gated on a marker
 *
 * Every helper call is guarded (`2>/dev/null || true`), so a missing or failing
 * bin/ script leaves the preamble inert rather than breaking the skill. The funnel
 * (Layer A) is NOT here — stage skills emit transitions via bin/boots-event next to
 * the prose log they already write.
 *
 * Tiers (1–4) are accepted for forward-compat but v1 emits one lean preamble for
 * all skills; add tier-gated sections later if a skill needs the heavier framework.
 */

import type { TemplateContext } from './types';
import { getHostConfig } from '../../hosts/index';

function bootstrap(ctx: TemplateContext): string {
  const hostConfig = getHostConfig(ctx.host);
  const envRoot = hostConfig.usesEnvVars
    ? `_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
BOOTS_ROOT="$HOME/${hostConfig.globalRoot}"
[ -n "$_ROOT" ] && [ -d "$_ROOT/${ctx.paths.localSkillRoot}" ] && BOOTS_ROOT="$_ROOT/${ctx.paths.localSkillRoot}"
BOOTS_BIN="$BOOTS_ROOT/boots/bin"
`
    : '';
  const bin = ctx.paths.binDir;

  return `## Preamble (run first, then say nothing about it)

Run the block below silently. It is invisible plumbing — do NOT narrate it, echo it, or mention telemetry, branch, or sessions to the user (this suite's rule 5: never narrate your plumbing). Surface something ONLY if the update check prints \`UPGRADE_AVAILABLE\` or \`JUST_UPGRADED\` (see "Updates" below). Otherwise go straight to this skill's own opening as if the preamble were not here — it never replaces or precedes the skill's first move in the conversation.

\`\`\`bash
${envRoot}_UPD=$(${bin}/boots-update-check 2>/dev/null || boots/bin/boots-update-check 2>/dev/null || true)
[ -n "$_UPD" ] && echo "$_UPD" || true
mkdir -p ~/.boots/sessions ~/.boots/analytics
touch ~/.boots/sessions/"$PPID" 2>/dev/null || true
find ~/.boots/sessions -mmin +120 -type f -exec rm {} + 2>/dev/null || true
_TEL=$(${bin}/boots-config get telemetry 2>/dev/null || echo "off")
_TEL_PROMPTED=$([ -f ~/.boots/.consent-prompted ] && echo "yes" || echo "no")
_PROACTIVE=$(${bin}/boots-config get proactive 2>/dev/null || echo "true")
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
_SESSION_ID="$$-$(date +%s)"
_TEL_START=$(date +%s)
echo "TELEMETRY: \${_TEL:-off}"
echo "TEL_PROMPTED: $_TEL_PROMPTED"
echo "PROACTIVE: $_PROACTIVE"
echo "BRANCH: $_BRANCH"
# Ops run-start marker (Layer B). If this session dies before it logs an end event,
# the marker is left behind; the next boots-telemetry-log run finalizes any other
# session's stale marker as outcome:unknown, so a crash is recorded, not lost.
if [ "$_TEL" != "off" ]; then
  printf '{"skill":"${ctx.skillName}","ts":"%s","session_id":"%s"}\\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > ~/.boots/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
fi
\`\`\``;
}

function consent(ctx: TemplateContext): string {
  const bin = ctx.paths.binDir;
  return `## Telemetry consent (ask once — the one thing here you may surface)

Everything else in this preamble is silent plumbing. This is the exception: a single, one-time question. If \`TEL_PROMPTED\` is \`yes\`, skip it entirely. If \`no\`, ask once via AskUserQuestion, then always \`touch ~/.boots/.consent-prompted\` regardless of the answer.

> Help Boots get better? It can share which stages your systems pass through and where they stall — so the project can see where people get stuck. **No code, no file contents, and no repo or system names** (those stay on your machine). A stable, random ID only on the "community" tier.

- **A) Help Boots get better (community)** → \`${bin}/boots-config set telemetry community\`
- **B) No thanks** → ask once more: "Anonymous instead — aggregate counts only, no ID?" → yes: \`${bin}/boots-config set telemetry anonymous\` · no: \`${bin}/boots-config set telemetry off\`

Always, whatever they choose:
\`\`\`bash
touch ~/.boots/.consent-prompted 2>/dev/null || true
\`\`\`

Default is **off**. Nothing is sent anywhere unless the user actively picks community or anonymous here.`;
}

function upgradeReact(ctx: TemplateContext): string {
  return `## Updates (act on the preamble output)

If the preamble printed \`UPGRADE_AVAILABLE <old> <new>\`: read \`${ctx.paths.skillRoot}/boots-upgrade/SKILL.md\` and follow its inline upgrade flow (auto-upgrade if configured, else a 4-option AskUserQuestion: Yes / Always / Not now / Never). If it printed \`JUST_UPGRADED <old> <new>\`: say "Running Boots v{new} (just updated!)" and continue.

If \`PROACTIVE\` is \`false\`: don't proactively suggest other Boots skills this session.`;
}

function epilogue(ctx: TemplateContext): string {
  const bin = ctx.paths.binDir;
  return `## Telemetry (run last)

After the workflow completes, log the ops run event (Layer B). OUTCOME is success/error/abort. This writes only to \`~/.boots/\`; run it even in plan mode.

\`\`\`bash
_TEL_END=$(date +%s); _TEL_DUR=$(( _TEL_END - _TEL_START ))
rm -f ~/.boots/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
if [ "$_TEL" != "off" ] && [ -x ${bin}/boots-telemetry-log ]; then
  ${bin}/boots-telemetry-log --skill "${ctx.skillName}" --duration "$_TEL_DUR" --outcome "OUTCOME" --session-id "$_SESSION_ID" 2>/dev/null &
fi
\`\`\`

Replace \`OUTCOME\` before running.`;
}

export function generatePreamble(ctx: TemplateContext): string {
  const tier = ctx.preambleTier ?? 1;
  if (tier < 1 || tier > 4) {
    throw new Error(`Invalid preamble-tier: ${tier} in ${ctx.tmplPath}. Must be 1-4.`);
  }
  return [bootstrap(ctx), upgradeReact(ctx), consent(ctx), epilogue(ctx)]
    .filter(s => s && s.trim().length > 0)
    .join('\n\n');
}
