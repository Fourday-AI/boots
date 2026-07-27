#!/usr/bin/env bash
# test-platform.sh — the invariants that keep the platform seam from rotting.
#
# Boots targets more than one runtime. The cheap way to do that is a second copy
# of every skill per platform, and it is cheap right up until the copies drift —
# which is exactly what happened to the first Cowork build: within a week it was
# missing a skill the repo had AND ahead of the repo on a router bullet and nine
# translation-table rows, in both directions, unnoticed, because there was nothing
# checking.
#
# So: skill bodies are platform-NEUTRAL, and everything platform-specific lives in
# a host config or a forms palette. These assertions are what enforce that.
# See docs/adding-a-platform.md.
#
#   bash scripts/test-platform.sh
set -uo pipefail
cd "$(dirname "$0")/.."

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

# Half of what follows shells out to bun. Without it, the config checks return
# empty and the grep for "INVALID" finds nothing — which reads as a PASS. A test
# that goes green because its tooling is absent is worse than no test, so refuse
# to run rather than report a result nobody should trust.
if ! command -v bun >/dev/null 2>&1; then
  printf 'error: bun is not on PATH.\n' >&2
  printf '       This suite cannot check host configs or generate skills without it,\n' >&2
  printf '       and several checks would pass vacuously. Install bun and re-run.\n' >&2
  exit 2
fi

echo "── 1. skill bodies name no runtime and no palette ──"

# The templates are the shared source. A literal product name in one is a body
# that cannot serve a second platform without being copied.
HITS=$(grep -rn 'Claude Code\|Cowork\|OpenAI Codex' boots*/SKILL.md.tmpl 2>/dev/null || true)
if [ -z "$HITS" ]; then ok "no template names a runtime"
else bad "a template names a runtime literally" "$HITS"; fi

HITS=$(grep -rn 'claude-code\.md\|cowork\.md\|^platform: claude-code\|^platform: cowork' boots*/SKILL.md.tmpl 2>/dev/null || true)
if [ -z "$HITS" ]; then ok "no template hardcodes a palette"
else bad "a template hardcodes a palette" "$HITS"; fi

# The home is a path only on a fixed-home platform. A literal one in a SHARED body
# is a record written into a sandbox on every other platform.
#
# A skill that only ever ships to fixed-home hosts is exempt: boots-upgrade is a
# `git pull && ./setup` flow, meaningless where updating is the marketplace's job,
# so every resolved-home host skips it and it may name ~/.boots freely. That
# exemption is DERIVED from the host configs, not listed here — so a skill stops
# being exempt the moment a resolved-home host starts shipping it.
EXEMPT=$(bun -e '
  const { ALL_HOST_CONFIGS } = await import("./hosts/index.ts");
  const fs = await import("fs");
  const skills = fs.readdirSync(".").filter(d =>
    /^boots(-|$)/.test(d) && fs.existsSync(`${d}/SKILL.md.tmpl`));
  const exempt = skills.filter(s =>
    ALL_HOST_CONFIGS
      .filter(c => !(c.generation.skipSkills || []).includes(s))
      .every(c => c.platform.homeModel === "fixed"));
  console.log(exempt.join(" "));
' 2>/dev/null)
[ -n "$EXEMPT" ] && printf '       (fixed-home-only, exempt: %s)\n' "$EXEMPT"

HITS=""
for f in boots*/SKILL.md.tmpl; do
  d=$(dirname "$f")
  case " $EXEMPT " in *" $d "*) continue ;; esac
  H=$(grep -n '~/\.boots\|\$HOME/\.boots' "$f" 2>/dev/null || true)
  [ -n "$H" ] && HITS="$HITS$f: $H"$'\n'
done
if [ -z "$HITS" ]; then ok "no shared template hardcodes the Boots home"
else bad "a shared template hardcodes the Boots home" "$HITS"; fi

echo "── 2. every host config is valid and its palette exists ──"

CONFIG_REPORT=$(bun -e '
  const { ALL_HOST_CONFIGS } = await import("./hosts/index.ts");
  const { validateHostConfig, paletteFileFor } = await import("./scripts/host-config.ts");
  const fs = await import("fs");
  for (const c of ALL_HOST_CONFIGS) {
    const errs = validateHostConfig(c);
    if (errs.length) console.log(`INVALID ${c.name}: ${errs.join("; ")}`);
    const p = paletteFileFor(c);
    if (!fs.existsSync(p)) console.log(`NOPALETTE ${c.name}: ${p}`);
    else console.log(`OK ${c.name} palette=${c.platform.palette} home=${c.platform.homeModel} packaging=${c.packaging ?? "symlink"}`);
  }
' 2>&1)
echo "$CONFIG_REPORT" | sed 's/^/       /'
if echo "$CONFIG_REPORT" | grep -q 'INVALID\|NOPALETTE\|error'; then
  bad "a host config is invalid or names a missing palette"
else ok "all host configs valid, all palettes present"; fi

echo "── 3. generate every host, then check the outputs in isolation ──"

bun run scripts/gen-skill-docs.ts --host claude >/dev/null 2>&1 || bad "claude generation failed"
bun run scripts/gen-skill-docs.ts --host cowork >/dev/null 2>&1 || bad "cowork generation failed"
bun run scripts/build-plugin.ts --host cowork >/dev/null 2>&1 || bad "cowork bundle build failed"

# No cross-contamination. Each platform's output must contain only its own world.
LEAK=$(grep -l 'Cowork\|CLAUDE_PLUGIN_ROOT\|device_bash\|scheduled task' boots*/SKILL.md 2>/dev/null || true)
if [ -z "$LEAK" ]; then ok "claude output carries nothing from cowork"
else bad "cowork concepts leaked into the claude output" "$LEAK"; fi

LEAK=$(grep -rl 'Claude Code\|~/\.claude/skills' dist/cowork/skills/*/SKILL.md 2>/dev/null || true)
if [ -z "$LEAK" ]; then ok "cowork output carries nothing from claude code"
else bad "claude code concepts leaked into the cowork output" "$LEAK"; fi

echo "── 4. no generated bash contains a quoted tilde ──"

# `"~/.boots"` does not expand — it creates a directory literally named `~`, and
# it fails silently. This is a real bug that shipped once; it does not get to
# ship twice.
QT=$(grep -rn '"~/' boots*/SKILL.md dist/cowork/skills/*/SKILL.md 2>/dev/null || true)
if [ -z "$QT" ]; then ok "no quoted tilde in any generated skill"
else bad "a quoted tilde reached generated output (it will not expand)" "$QT"; fi

echo "── 5. nothing unresolved, nothing from this machine ──"

STRAY=$(grep -rn '{{[A-Z_]*}}' boots*/SKILL.md dist/cowork/skills/*/SKILL.md 2>/dev/null || true)
if [ -z "$STRAY" ]; then ok "no unresolved placeholders"
else bad "an unresolved placeholder reached generated output" "$STRAY"; fi

ABS=$(grep -rln '/Users/\|/home/claude/' boots*/SKILL.md dist/cowork/skills/*/SKILL.md 2>/dev/null || true)
if [ -z "$ABS" ]; then ok "no build-machine paths in generated output"
else bad "a path from the build machine reached generated output" "$ABS"; fi

echo "── 6. the resolved-home platform ships what it needs to resolve ──"

for f in dist/cowork/skills/boots/bin/boots-home \
         dist/cowork/skills/boots/reference/boots-home.md \
         dist/cowork/skills/boots/forms/cowork.md \
         dist/cowork/.claude-plugin/plugin.json; do
  [ -f "$f" ] && ok "bundled: ${f#dist/cowork/}" || bad "missing from bundle: ${f#dist/cowork/}"
done
[ -x dist/cowork/skills/boots/bin/boots-home ] \
  && ok "boots-home is executable" || bad "boots-home is not executable"

# The whole reason this platform exists: `absent` must never read as a licence to
# create a home. Assert the generated skill actually says so.
if grep -q 'do not believe it yet' dist/cowork/skills/boots/SKILL.md \
   && grep -q 'homeDirectories' dist/cowork/skills/boots/SKILL.md; then
  ok "the cowork skill carries the do-not-invent-a-home protocol"
else
  bad "the cowork skill lost the do-not-invent-a-home protocol"
fi

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
