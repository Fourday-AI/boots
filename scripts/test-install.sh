#!/usr/bin/env bash
# Boots clean-room install check.
#
#   bash scripts/test-install.sh                  # against this local clone
#   bash scripts/test-install.sh <repo-url>       # against any URL (the real test)
#   BOOTS_TEST_REPO_URL=<url> bash scripts/test-install.sh
#
# WHY THIS EXISTS
# Every other test in this repo runs against a machine that already has Boots
# working. That is the one machine where a broken install cannot fail. This check
# builds a throwaway HOME with no Claude Code skills dir, no ~/.boots, and no prior
# install, then walks the exact steps a stranger is handed in the README and asserts
# the result. It is the only test that can fail the way a tester fails.
#
# THE URL IS A PARAMETER ON PURPOSE
# While the repo is private, a clone here uses the operator's own credentials — so a
# local-path run proves every step EXCEPT the one that actually broke: a stranger
# being allowed to clone at all. The moment the repo goes public, re-run this against
# the public URL. That run, and only that run, closes the question.
#
# WHAT IT CANNOT DO
# It cannot start a real Claude Code session, so it proves the skills are installed,
# discoverable and structurally valid, and that the router's own startup block runs
# clean under a cold HOME. The last mile — pasting the install line into a real
# session and saying `boots` — stays a human step. This check exists so that human
# step is the only one left, not the first place anything is checked.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
REPO_URL="${1:-${BOOTS_TEST_REPO_URL:-$REPO}}"

PASS=0; FAIL=0
if [ -t 1 ]; then G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; B=$'\033[1m'; Z=$'\033[0m'; else G=; R=; Y=; B=; Z=; fi
ok()   { PASS=$((PASS+1)); printf '  %sPASS%s %s\n' "$G" "$Z" "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  %sFAIL%s %s\n' "$R" "$Z" "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
note() { printf '  %s..%s   %s\n' "$Y" "$Z" "$1"; }
sect() { printf '\n%s== %s ==%s\n' "$B" "$1" "$Z"; }
assert_eq()  { [ "$2" = "$3" ] && ok "$1" || bad "$1" "expected [$2], got [$3]"; }
assert_has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "missing [$2]" ;; esac; }

CLEAN="$(mktemp -d "${TMPDIR:-/tmp}/boots-install-XXXXXX")"
cleanup() { rm -rf "$CLEAN"; }
trap cleanup EXIT

# The throwaway HOME. Nothing outside it is touched, and nothing inside it exists
# before this line — no ~/.claude, no ~/.boots, no config, no prior version marker.
HOME_DIR="$CLEAN/home"
mkdir -p "$HOME_DIR"
# Where the documented install puts the repo: inside Claude Code's skills dir, dot
# -prefixed so Claude never mistakes the repo itself for a skill. Distinct from
# ~/.boots, which stays the runtime home (systems, config) and is NOT the clone.
CLONE_DIR="$HOME_DIR/.claude/skills/.boots"

printf '%sBoots clean-room install check%s\n' "$B" "$Z"
printf 'repo url : %s\n' "$REPO_URL"
printf 'fake HOME: %s\n' "$HOME_DIR"
case "$REPO_URL" in
  http*|git@*) ;;
  *) note "local path — proves setup, NOT that a stranger may clone. Re-run with the public URL after the flip." ;;
esac

# The skills a user is entitled to after install: the git-tracked allow-list in
# .gitignore, which is the only list of what is actually part of the product.
# (read loop, not mapfile — macOS ships bash 3.2 and this must run on the operator's machine)
PRODUCT_SKILLS=()
while IFS= read -r _s; do
  [ -n "$_s" ] && PRODUCT_SKILLS+=("$_s")
done < <(grep -oE '^!/boots[a-z-]*/' "$REPO/.gitignore" | sed 's|^!/||;s|/$||' | sort)
[ "${#PRODUCT_SKILLS[@]}" -gt 0 ] || { printf 'error: could not read the skills allow-list from .gitignore\n' >&2; exit 2; }

# ─────────────────────────────────────────────────────────────────────────────
sect "cold HOME is genuinely cold"
[ -e "$HOME_DIR/.claude" ] && bad "no pre-existing Claude Code skills dir" || ok "no pre-existing Claude Code skills dir"
[ -e "$HOME_DIR/.boots" ]  && bad "no pre-existing ~/.boots"               || ok "no pre-existing ~/.boots"

# ─────────────────────────────────────────────────────────────────────────────
sect "the documented install command is the one we run"
# Pull the install line out of the README rather than paraphrasing it, so this check
# fails when the docs drift from what actually works. A test of a command nobody is
# handed proves nothing.
README_CMD="$(grep -oE 'git clone --depth 1 [^ ]+ ~/\.claude/skills/\.boots && ~/\.claude/skills/\.boots/setup' "$REPO/README.md" | head -1)"
if [ -n "$README_CMD" ]; then
  ok "README carries a one-paste install command"
  README_URL="$(printf '%s' "$README_CMD" | awk '{print $5}')"
  case "$README_URL" in
    http*) ok "README install command clones over https ($README_URL)" ;;
    *)     bad "README install command clones over https" "got [$README_URL]" ;;
  esac
else
  bad "README carries a one-paste install command" "no 'git clone --depth 1 <url> ~/.claude/skills/.boots && ~/.claude/skills/.boots/setup' line found in README.md"
fi

# ─────────────────────────────────────────────────────────────────────────────
sect "step 1 — clone"
CLONE_LOG="$CLEAN/clone.log"
if git clone --depth 1 "$REPO_URL" "$CLONE_DIR" >"$CLONE_LOG" 2>&1; then
  ok "clone succeeds"
else
  bad "clone succeeds" "$(tail -3 "$CLONE_LOG")"
  printf '\n%sclone failed — nothing downstream can be checked. This is exactly the tester-facing break.%s\n' "$R" "$Z"
  printf '\n%s== result ==%s\n  %s%d passed%s, %s%d failed%s\n' "$B" "$Z" "$G" "$PASS" "$Z" "$R" "$FAIL" "$Z"
  exit 1
fi

[ -x "$CLONE_DIR/setup" ] && ok "setup is present and executable" || bad "setup is present and executable"

# The clone is what a stranger receives. Anything private in it is a leak, and
# anything missing from it is a broken install for them but not for us.
for leak in systems state config.yaml installation-id .activated sessions analytics .env; do
  [ -e "$CLONE_DIR/$leak" ] && bad "clone carries no private '$leak'" "present in the clone a stranger receives" || ok "clone carries no private '$leak'"
done
UNLISTED=""
for d in "$CLONE_DIR"/boots*/; do
  [ -d "$d" ] || continue
  n="$(basename "$d")"
  printf '%s\n' "${PRODUCT_SKILLS[@]}" | grep -qx "$n" || UNLISTED="$UNLISTED $n"
done
[ -n "$UNLISTED" ] && bad "clone ships only allow-listed skills" "unlisted:$UNLISTED" || ok "clone ships only allow-listed skills"

# ─────────────────────────────────────────────────────────────────────────────
sect "step 2 — setup, run as the user runs it"
SETUP_LOG="$CLEAN/setup.log"
# env -i would drop PATH and break git/bun; overriding HOME is what isolates this.
if env HOME="$HOME_DIR" bash "$CLONE_DIR/setup" >"$SETUP_LOG" 2>&1; then
  ok "setup exits 0 on a cold HOME"
else
  bad "setup exits 0 on a cold HOME" "$(tail -5 "$SETUP_LOG")"
fi
SETUP_OUT="$(cat "$SETUP_LOG")"

# A fresh install must not silently skip a skill because something was in the way.
case "$SETUP_OUT" in
  *"skipped"*) bad "setup skipped nothing on a cold HOME" "$(grep skipped "$SETUP_LOG")" ;;
  *)           ok "setup skipped nothing on a cold HOME" ;;
esac
case "$SETUP_OUT" in
  *"error"*|*"warning"*) bad "setup printed no errors or warnings" "$(grep -iE 'error|warning' "$SETUP_LOG")" ;;
  *)                     ok "setup printed no errors or warnings" ;;
esac

# ─────────────────────────────────────────────────────────────────────────────
sect "step 3 — the skills are actually installed and usable"
DEST="$HOME_DIR/.claude/skills"
[ -d "$DEST" ] && ok "Claude Code skills dir was created" || bad "Claude Code skills dir was created" "$DEST missing"

for s in "${PRODUCT_SKILLS[@]}"; do
  if [ ! -L "$DEST/$s" ]; then
    bad "$s is installed" "no symlink at $DEST/$s"
  elif [ ! -e "$DEST/$s/SKILL.md" ]; then
    bad "$s is installed" "symlink present but $s/SKILL.md does not resolve (dangling link)"
  else
    # Claude Code discovers a skill by its frontmatter; a SKILL.md without a name
    # and description is installed but invisible, which reads as "Boots is broken".
    head1="$(head -1 "$DEST/$s/SKILL.md")"
    if [ "$head1" != "---" ]; then
      bad "$s is installed" "SKILL.md has no frontmatter block"
    elif ! awk '/^---$/{n++; next} n==1' "$DEST/$s/SKILL.md" | grep -q '^name:'; then
      bad "$s is installed" "frontmatter has no name:"
    elif ! awk '/^---$/{n++; next} n==1' "$DEST/$s/SKILL.md" | grep -q '^description:'; then
      bad "$s is installed" "frontmatter has no description:"
    else
      ok "$s is installed and discoverable"
    fi
  fi
done

# The router is the entry point. If nothing else works, this is the one that must.
[ -e "$DEST/boots/SKILL.md" ] && ok "the entry point (say 'boots') resolves" || bad "the entry point (say 'boots') resolves"

# ─────────────────────────────────────────────────────────────────────────────
sect "step 4 — the CLAUDE.md block the user is told to paste"
BLOCK="$(awk '/^## Boots$/{f=1} f' "$SETUP_LOG")"
[ -n "$BLOCK" ] && ok "setup prints the '## Boots' block to paste" || bad "setup prints the '## Boots' block to paste"

# The block names the skills. If it names one that is not installed, the agent is
# told to call something that does not exist; if it omits one, that skill is dark.
LISTED="$(printf '%s' "$BLOCK" | tr ',' '\n' | grep -oE '\bboots(-[a-z]+)?\b' | sort -u)"
if [ -n "$LISTED" ]; then
  MISSING=""; EXTRA=""
  for s in "${PRODUCT_SKILLS[@]}"; do printf '%s\n' "$LISTED" | grep -qx "$s" || MISSING="$MISSING $s"; done
  while read -r l; do
    [ -n "$l" ] || continue
    printf '%s\n' "${PRODUCT_SKILLS[@]}" | grep -qx "$l" || EXTRA="$EXTRA $l"
  done <<<"$LISTED"
  [ -n "$EXTRA" ]   && bad "the block names no skill that isn't installed" "names:$EXTRA" || ok "the block names no skill that isn't installed"
  [ -n "$MISSING" ] && bad "the block names every installed skill"        "omits:$MISSING" || ok "the block names every installed skill"
fi
assert_has "the block points at the global notes home" "~/.boots/systems/" "$BLOCK"

# ─────────────────────────────────────────────────────────────────────────────
sect "step 5 — the router's own startup runs clean on a cold machine"
# This is the first thing that executes when a stranger says `boots`. If it errors,
# their very first message is a wall of shell noise. Run the real block, cold.
BIN="$DEST/boots/bin"
[ -d "$BIN" ] && ok "the helper scripts came across with the skill" || bad "the helper scripts came across with the skill" "$BIN missing"

STARTUP="$(env HOME="$HOME_DIR" bash -c '
  set -uo pipefail
  mkdir -p ~/.boots/sessions ~/.boots/analytics
  '"$BIN"'/boots-update-check 2>&1
  echo "TELEMETRY: $('"$BIN"'/boots-config get telemetry 2>&1 || echo FAILED)"
  echo "PROACTIVE: $('"$BIN"'/boots-config get proactive 2>&1 || echo FAILED)"
  '"$BIN"'/boots-analytics --brief 2>&1
' 2>&1)"

assert_has "telemetry defaults to off on a fresh install" "TELEMETRY: off" "$STARTUP"
case "$STARTUP" in
  *"No such file"*|*"command not found"*|*"Permission denied"*|*FAILED*)
    bad "startup produces no shell errors" "$STARTUP" ;;
  *)  ok "startup produces no shell errors" ;;
esac
# A brand-new user has no systems. The board must say so calmly, not crash and not
# print an empty funnel — "No systems yet" is the correct answer on day one.
case "$STARTUP" in
  *"No systems yet"*|*FUNNEL*) ok "the board answers calmly with zero systems" ;;
  *)                           bad "the board answers calmly with zero systems" "$STARTUP" ;;
esac
[ -f "$HOME_DIR/.boots/.activated" ] && bad "a fresh install still gets the first-run welcome" "already marked activated" || ok "a fresh install still gets the first-run welcome"

# Nothing may leave the machine on a default install.
CONSENT="$(env HOME="$HOME_DIR" "$BIN/boots-telemetry-sync" 2>&1; echo "rc=$?")"
assert_has "telemetry sync is a no-op while off" "rc=0" "$CONSENT"

# ─────────────────────────────────────────────────────────────────────────────
sect "step 6 — uninstall gives the machine back"
UNINSTALL_LOG="$CLEAN/uninstall.log"
if env HOME="$HOME_DIR" bash "$CLONE_DIR/setup" --uninstall >"$UNINSTALL_LOG" 2>&1; then
  ok "uninstall exits 0"
else
  bad "uninstall exits 0" "$(tail -3 "$UNINSTALL_LOG")"
fi
LEFT=0
for s in "${PRODUCT_SKILLS[@]}"; do [ -e "$DEST/$s" ] && LEFT=$((LEFT+1)); done
assert_eq "uninstall removes every installed skill" "0" "$LEFT"

# ─────────────────────────────────────────────────────────────────────────────
printf '\n%s== result ==%s\n' "$B" "$Z"
printf '  %s%d passed%s, %s%d failed%s\n' "$G" "$PASS" "$Z" "$R" "$FAIL" "$Z"
case "$REPO_URL" in
  http*|git@*) ;;
  *) printf '  %sNOTE%s this ran against a local path. The stranger-can-clone question is still open\n       until this same check passes against the public URL.\n' "$Y" "$Z" ;;
esac
[ "$FAIL" -eq 0 ] || exit 1
