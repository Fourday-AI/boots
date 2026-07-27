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

/**
 * Bootstrap for a host whose filesystem is NOT the user's and is wiped when the
 * session ends (platform.homeModel === 'resolved'; today, Cowork).
 *
 * Everything a fixed-home host gets for free — "the record is at ~/.boots" — has
 * to be earned here, once per session, before any other work. The failure this
 * guards against is specific and has happened three times to the author: the
 * probe runs inside the sandbox, does not find a home there (correctly, because
 * the user's disk is elsewhere), reports "absent", and the session then CREATES a
 * second, empty home on top of a real one holding all their work. The session
 * then reports a near-empty board as the truth.
 *
 * So `absent` from the probe is treated as a question, never as an answer. See
 * boots/reference/boots-home.md for the full protocol this block summarises.
 */
function bootstrapResolved(ctx: TemplateContext): string {
  const skillDir = ctx.paths.skillDir;
  return `## Preamble (run first, then say nothing about it)

Run the block below silently. It is invisible plumbing — do NOT narrate it, echo it, or mention telemetry, folders, or sessions to the user (this suite's rule 5: never narrate your plumbing). Surface something ONLY if the update check prints \`UPGRADE_AVAILABLE\` or \`JUST_UPGRADED\` (see "Updates" below), or if the home comes back \`absent\`. Otherwise go straight to this skill's own opening as if the preamble were not here — it never replaces or precedes the skill's first move in the conversation.

**Step A — resolve the Boots home.** Everything else depends on it. Read \`${skillDir}/reference/boots-home.md\` for the full protocol. The short version is four steps. Take them in order and stop at the first hit.

1. Run this with the **Bash** tool:

   \`\`\`bash
   bash "${skillDir}/bin/boots-home"
   \`\`\`

   If it prints \`BOOTS_MODE local\` with a path, that is the home. Run every Boots command in this skill with **Bash**.

2. If it printed \`absent\`, **do not believe it yet** — and above all do not create a home. That script can only see this session's own sandbox, which is not the user's computer. Get the connected folder roots (\`get_device_info\`, or the session's own notice of which folders are connected) and call \`device_list_dir\` on each. If one holds a \`Boots/\` folder, that is the home, \`<bin>\` is \`<home>/.bin\`, and every Boots command runs with **device_bash**.

3. **Still nothing? Ask before you build.** \`get_device_info\` also returns \`homeDirectories\` — a names-only listing of the user's home folder that needs no permission to read. Look through it for \`.boots\` and for any folder holding a \`Boots\`. If one is there, the user has a Boots home you simply have not been given access to yet: call \`device_request_folder_access\` on it (this works for hidden folders, and is one tap for them). **Skipping this step is the failure that matters** — it tells a user with years of work that they have none, and then offers to start them a second, empty one.

4. Only if the bridge is unavailable, and no connected folder holds a \`Boots/\`, and nothing in \`homeDirectories\` looks like one, is the mode really \`absent\`.

\`BOOTS_MODE absent\` → do not run Step B. Read \`${skillDir}/reference/boots-home.md\` and follow "First run".

**Step B — the rest of the preamble.** Substitute the resolved \`<home>\` and \`<bin>\`, and run it with the tool Step A selected. **Every bash block in this skill is its own invocation and nothing carries between them** — no exported variable, no working directory. So substitute \`<home>\` and \`<bin>\` into every block that follows, and treat each one as if it were the first.

\`\`\`bash
export BOOTS_HOME="<home>"
_UPD=$(bash "<bin>/boots-update-check" 2>/dev/null || true)
[ -n "$_UPD" ] && echo "$_UPD" || true
mkdir -p "$BOOTS_HOME/analytics"
_TEL=$(bash "<bin>/boots-config" get telemetry 2>/dev/null || echo "off")
_TEL_PROMPTED=$([ -f "$BOOTS_HOME/.consent-prompted" ] && echo "yes" || echo "no")
_PROACTIVE=$(bash "<bin>/boots-config" get proactive 2>/dev/null || echo "true")
# A container hands out low PIDs, so PID + second collides with a session on the
# user's own machine — and each would then finalize the other's marker as a crash.
_SESSION_ID="$$-$(date +%s)-\${RANDOM:-0}"
echo "TELEMETRY: \${_TEL:-off}"
echo "TEL_PROMPTED: $_TEL_PROMPTED"
echo "PROACTIVE: $_PROACTIVE"
echo "SESSION_ID: $_SESSION_ID"
# Ops run-start marker (Layer B). A ${ctx.host === 'cowork' ? 'Cowork' : 'cloud'} session can be reclaimed mid-run with
# no chance to write an end event, so this marker is what lets the NEXT run
# finalize a dead session as outcome:unknown instead of losing it. The platform is
# stamped in because THIS host is the one that gets reclaimed — a later session on
# the user's laptop must not report the crash as having happened there.
if [ "$_TEL" != "off" ]; then
  printf '{"skill":"${ctx.skillName}","ts":"%s","session_id":"%s","platform":"${ctx.host}"}\\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > "$BOOTS_HOME/analytics/.pending-$_SESSION_ID" 2>/dev/null || true
fi
# Ship anything a previous, reclaimed session left queued. On a host that is wiped
# between sessions this is the only chance those events ever get: nothing else here
# will notice them, and the sandbox that wrote them is already gone.
[ "$_TEL" != "off" ] && bash "<bin>/boots-telemetry-sync" >/dev/null 2>&1 &
\`\`\``;
}

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
# PID + time alone collide across machines — a container reliably hands out low PIDs,
# so a session in the cloud and one on the laptop starting the same second mint the
# SAME id, and each finalizes the other's pending marker as a crash. Hence the salt.
_SESSION_ID="$$-$(date +%s)-\${RANDOM:-0}"
_TEL_START=$(date +%s)
# Flush anything the previous session left queued (backgrounded, rate-limited,
# tier-gated, silent without a backend). A session on a short-lived host can end
# before its last event ships; this is the catch-up.
[ "$_TEL" != "off" ] && [ -x ${bin}/boots-telemetry-sync ] && ${bin}/boots-telemetry-sync >/dev/null 2>&1 &
echo "TELEMETRY: \${_TEL:-off}"
echo "TEL_PROMPTED: $_TEL_PROMPTED"
echo "PROACTIVE: $_PROACTIVE"
echo "BRANCH: $_BRANCH"
# Ops run-start marker (Layer B). If this session dies before it logs an end event,
# the marker is left behind; the next boots-telemetry-log run finalizes any other
# session's stale marker as outcome:unknown, so a crash is recorded, not lost.
# It carries its own platform so the crash is attributed to the host it died on,
# not to whichever host later notices the corpse.
if [ "$_TEL" != "off" ]; then
  _PLATFORM=$(${bin}/boots-platform 2>/dev/null || echo "claude-code")
  printf '{"skill":"${ctx.skillName}","ts":"%s","session_id":"%s","platform":"%s"}\\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" "$_PLATFORM" > ~/.boots/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
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

/** Consent, for a host whose home is resolved per session. */
function consentResolved(ctx: TemplateContext): string {
  const bin = ctx.paths.binDir;
  return `## Telemetry consent (ask once — the one thing here you may surface)

Everything else in this preamble is silent plumbing. This is the exception: a single, one-time question. If \`TEL_PROMPTED\` is \`yes\`, skip it entirely. If \`no\`, ask once via AskUserQuestion, then always mark it prompted regardless of the answer.

> Help Boots get better? It can share which stages your systems pass through and where they stall — so the project can see where people get stuck. **No code, no file contents, and no folder or system names** (those stay on your computer). A stable, random ID only on the "community" tier.

- **A) Help Boots get better (community)** → \`bash "${bin}/boots-config" set telemetry community\`
- **B) No thanks** → ask once more: "Anonymous instead — aggregate counts only, no ID?" → yes: \`bash "${bin}/boots-config" set telemetry anonymous\` · no: \`bash "${bin}/boots-config" set telemetry off\`

Always, whatever they choose:
\`\`\`bash
BOOTS_HOME="<home>"
touch "$BOOTS_HOME/.consent-prompted" 2>/dev/null || true
\`\`\`

Default is **off**, and nothing has anywhere to go until a \`telemetry_url\` is configured. Nothing is sent anywhere unless the user actively picks community or anonymous here.`;
}

function upgradeReact(ctx: TemplateContext): string {
  const hostConfig = getHostConfig(ctx.host);

  // A plugin host updates through its own marketplace, so there is no
  // `boots-upgrade` skill to route to — pointing at one would send the agent to
  // read a file the build deliberately excluded.
  const body = hostConfig.packaging === 'plugin'
    ? `If the preamble printed \`UPGRADE_AVAILABLE <old> <new>\`: mention it once, in one plain line — a newer Boots is available and they can install it the way they installed this one. Do not derail the session into an upgrade; they came here for their systems. If they are not interested, snooze it:

\`\`\`bash
BOOTS_HOME="<home>"
printf '%s 1 %s\\n' "<new>" "$(date +%s)" > "$BOOTS_HOME/update-snoozed"
\`\`\`

If it printed \`JUST_UPGRADED <old> <new>\`: say "Running Boots v{new} (just updated)" and continue.`
    : `If the preamble printed \`UPGRADE_AVAILABLE <old> <new>\`: read \`${ctx.paths.skillRoot}/boots-upgrade/SKILL.md\` and follow its inline upgrade flow (auto-upgrade if configured, else a 4-option AskUserQuestion: Yes / Always / Not now / Never). If it printed \`JUST_UPGRADED <old> <new>\`: say "Running Boots v{new} (just updated!)" and continue.`;

  return `## Updates (act on the preamble output)

${body}

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

/** Epilogue, for a host whose home is resolved per session. */
function epilogueResolved(ctx: TemplateContext): string {
  const bin = ctx.paths.binDir;
  return `## Telemetry (run last)

After the workflow completes, log the ops run event (Layer B). OUTCOME is success/error/abort. This writes only inside the Boots home; run it even in plan mode.

\`\`\`bash
BOOTS_HOME="<home>" bash "${bin}/boots-telemetry-log" \\
  --skill "${ctx.skillName}" --outcome "OUTCOME" --session-id "<the SESSION_ID Step B printed>" \\
  2>/dev/null || true
\`\`\`

Replace \`OUTCOME\` before running.`;
}

export function generatePreamble(ctx: TemplateContext): string {
  const tier = ctx.preambleTier ?? 1;
  if (tier < 1 || tier > 4) {
    throw new Error(`Invalid preamble-tier: ${tier} in ${ctx.tmplPath}. Must be 1-4.`);
  }

  // The one branch in this file, and it is the capability axis, not packaging:
  // a host whose filesystem is the user's can name the home as a path; a host
  // whose filesystem is disposable has to find it, every session, before it does
  // anything else. See scripts/host-config.ts.
  const resolved = getHostConfig(ctx.host).platform.homeModel === 'resolved';

  const parts = resolved
    ? [bootstrapResolved(ctx), upgradeReact(ctx), consentResolved(ctx), epilogueResolved(ctx)]
    : [bootstrap(ctx), upgradeReact(ctx), consent(ctx), epilogue(ctx)];

  return parts.filter(s => s && s.trim().length > 0).join('\n\n');
}
