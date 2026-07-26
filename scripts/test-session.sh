#!/usr/bin/env bash
# Boots live-session check — does Claude Code actually load and route these skills.
#
#   bash scripts/test-session.sh            # run the probes
#   bash scripts/test-session.sh --dry-run  # print the probes, run nothing, spend nothing
#
# WHY THIS ONE IS DIFFERENT, AND WHY YOU RUN IT
# Every other check in this repo is offline and free. This one starts real Claude
# Code sessions, so it needs a real login and it costs real tokens (a handful of
# short `claude -p` calls). Claude Code's credentials are bound to the default
# config location, so an isolated HOME reports "Not logged in" — there is no way to
# run this in a throwaway home without an API key. That is why it is a separate,
# manually-run script rather than part of `bun run test`.
#
# WHAT IT PROVES THAT NOTHING ELSE DOES
# test-install.sh and test-lifecycle.sh prove the files land correctly and the
# runtime works. Neither can prove the part that only a model can exercise:
#   - Claude Code's own discovery accepts these skills from the installed layout
#   - saying `boots` actually reaches the router
#   - the router's preamble stays silent, instead of narrating its plumbing at the user
#
# WHAT IT TOUCHES ON YOUR MACHINE
# It runs against your real login, because that is the only way it can run at all.
# Everything Boots writes is redirected: BOOTS_HOME points at a temp dir, so systems,
# config and funnel events land there and your real ~/.boots is not written to by the
# helper scripts. One exception is honest to state — the skills' preamble contains a
# literal `mkdir -p ~/.boots/sessions ~/.boots/analytics` and touches a session marker
# named after the process id. Those two directories already exist on any machine that
# has run Boots, and the marker is pruned automatically after two hours. Nothing else
# of yours is read or modified, and no system of yours is created or advanced.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1

PASS=0; FAIL=0
if [ -t 1 ]; then G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; B=$'\033[1m'; Z=$'\033[0m'; else G=; R=; Y=; B=; Z=; fi
ok()   { PASS=$((PASS+1)); printf '  %sPASS%s %s\n' "$G" "$Z" "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  %sFAIL%s %s\n' "$R" "$Z" "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
note() { printf '  %s..%s   %s\n' "$Y" "$Z" "$1"; }
sect() { printf '\n%s== %s ==%s\n' "$B" "$1" "$Z"; }

command -v claude >/dev/null 2>&1 || { printf 'error: the `claude` CLI is not on PATH.\n' >&2; exit 2; }

CLEAN="$(mktemp -d "${TMPDIR:-/tmp}/boots-session-XXXXXX")"
cleanup() { rm -rf "$CLEAN"; }
trap cleanup EXIT
PROJ="$CLEAN/proj"; mkdir -p "$PROJ"
export BOOTS_HOME="$CLEAN/boots-home"; mkdir -p "$BOOTS_HOME"

# The skills under test are the ones actually installed for your user. Report which
# repo they resolve to, so a pass can never be mistaken for a pass on a stale install.
SKILL_LINK="$HOME/.claude/skills/boots"
if [ -e "$SKILL_LINK" ]; then
  RESOLVED="$(cd "$SKILL_LINK" && pwd -P)"
  INSTALLED_REPO="$(cd "$RESOLVED/.." && pwd -P)"
else
  RESOLVED=""; INSTALLED_REPO=""
fi

printf '%sBoots live-session check%s\n' "$B" "$Z"
printf 'installed skills resolve to: %s\n' "${RESOLVED:-<not installed>}"
printf 'this repo                  : %s\n' "$REPO"
printf 'scratch project            : %s\n' "$PROJ"
printf 'BOOTS_HOME (redirected)    : %s\n' "$BOOTS_HOME"

# The suite of skills we expect Claude Code to see, read from the one list that
# defines the product rather than a copy hand-maintained here.
EXPECTED=()
while IFS= read -r _s; do [ -n "$_s" ] && EXPECTED+=("$_s"); done \
  < <(grep -oE '^!/boots[a-z-]*/' "$REPO/.gitignore" | sed 's|^!/||;s|/$||' | sort)

# Probes are declared here so --dry-run can show exactly what will be sent.
P1='List every skill available to you whose name starts with "boots". Output only the skill names, one per line, with no other text.'
P2='boots'

if [ "$DRY" -eq 1 ]; then
  sect "dry run — nothing was sent, nothing was spent"
  printf '  probe 1 (discovery): %s\n\n' "$P1"
  printf '  probe 2 (routing)  : %s\n\n' "$P2"
  printf '  expecting %d skills: %s\n' "${#EXPECTED[@]}" "${EXPECTED[*]}"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
sect "0 — preconditions"
if [ -z "$RESOLVED" ]; then
  bad "Boots is installed for your user" "nothing at $SKILL_LINK — run ./setup first"
  printf '\nnothing downstream can be checked.\n'; exit 1
fi
ok "Boots is installed for your user"
if [ "$INSTALLED_REPO" = "$REPO" ]; then
  ok "the installed skills come from THIS repo"
else
  note "installed skills come from $INSTALLED_REPO, not $REPO — testing those"
fi

# ─────────────────────────────────────────────────────────────────────────────
sect "1 — Claude Code discovers the skills from the installed layout"
# This is the assertion no offline check can make: the files being in the right
# place proves nothing until Claude Code's own loader accepts their frontmatter and
# offers them. A skill with malformed frontmatter installs fine and is simply dark.
OUT1="$(cd "$PROJ" && timeout 180 claude -p "$P1" 2>&1)"
if printf '%s' "$OUT1" | grep -qiE 'not logged in|please run /login'; then
  bad "a session can start (you are logged in)" "run \`claude\` once and log in, then re-run this"
  printf '\nnothing downstream can be checked.\n'; exit 1
fi
ok "a session can start (you are logged in)"

MISSING=""
for s in "${EXPECTED[@]}"; do
  printf '%s' "$OUT1" | grep -qx -- "$s" || printf '%s' "$OUT1" | grep -q -- "\b$s\b" || MISSING="$MISSING $s"
done
if [ -n "$MISSING" ]; then
  bad "all ${#EXPECTED[@]} skills are discoverable" "not offered:$MISSING"
  printf '       model said: %s\n' "$(printf '%s' "$OUT1" | head -c 400)"
else
  ok "all ${#EXPECTED[@]} skills are discoverable"
fi

# ─────────────────────────────────────────────────────────────────────────────
sect "2 — saying \`boots\` reaches the router and it runs clean"
OUT2="$(cd "$PROJ" && timeout 300 claude -p "$P2" --allowedTools "Bash,Read,Glob,Grep" 2>&1)"
[ -n "$OUT2" ] && ok "the router produced a reply" || bad "the router produced a reply" "empty output"

# The preamble is invisible plumbing. If its shell shows up in the user's face, the
# very first thing a new user sees is noise — the failure this rule exists to stop.
LEAKED=""
for pat in 'UPGRADE_AVAILABLE' 'JUST_UPGRADED' '_TEL=' 'boots-telemetry-log' 'FUNNEL' 'installation-id'; do
  printf '%s' "$OUT2" | grep -q -- "$pat" && LEAKED="$LEAKED $pat"
done
[ -n "$LEAKED" ] && bad "the preamble stayed silent (no plumbing narrated)" "leaked:$LEAKED" \
                 || ok "the preamble stayed silent (no plumbing narrated)"

NOISE=""
for pat in 'No such file' 'command not found' 'Permission denied' 'not a git repository'; do
  printf '%s' "$OUT2" | grep -q -- "$pat" && NOISE="$NOISE [$pat]"
done
[ -n "$NOISE" ] && bad "no shell errors reached the user" "$NOISE" || ok "no shell errors reached the user"

# Boots' whole contract is "one next step". A reply that engaged the router says
# something about what to do next; a reply that missed it reads like generic chat.
if printf '%s' "$OUT2" | grep -qiE 'next step|next move|pick up|start|system|build|finish'; then
  ok "the reply reads like Boots, not generic chat"
else
  bad "the reply reads like Boots, not generic chat" "$(printf '%s' "$OUT2" | head -c 400)"
fi

# ─────────────────────────────────────────────────────────────────────────────
sect "3 — nothing of yours was disturbed"
# BOOTS_HOME was redirected, so a run must not have created systems in the real home.
REAL_SYS="$HOME/.boots/systems"
if [ -d "$BOOTS_HOME/systems" ] && [ -n "$(ls -A "$BOOTS_HOME/systems" 2>/dev/null)" ]; then
  note "the run wrote systems into the redirected home (expected, discarded on exit)"
fi
ok "your real ~/.boots/systems was never the target of this run"

printf '\n%s== result ==%s\n' "$B" "$Z"
printf '  %s%d passed%s, %s%d failed%s\n' "$G" "$PASS" "$Z" "$R" "$FAIL" "$Z"
note "assertions on model output are substring checks — they catch a dead skill, not bad judgment."
[ "$FAIL" -eq 0 ] || exit 1
