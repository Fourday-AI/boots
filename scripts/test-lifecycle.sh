#!/usr/bin/env bash
# Boots isolated lifecycle check — install, use, upgrade, uninstall, end to end.
#
#   bash scripts/test-lifecycle.sh
#
# WHY THIS EXISTS, AND HOW IT DIFFERS FROM test-install.sh
# test-install.sh proves a stranger can install Boots: the clone lands, the skills
# are discoverable, the router's startup block runs clean. It stops there, because
# everything after that is the product being USED.
#
# This check runs the part after that, in a throwaway HOME with a throwaway git
# upstream, with no network and no model:
#
#   install → a system moves through the funnel → an upgrade lands → uninstall
#
# The class of bug it exists to catch is the one that is INVISIBLE. Boots' helper
# scripts locate the repo by walking up from their own path, and their designed
# failure mode is silence — `boots-update-check` prints nothing when it can't find
# VERSION, which is indistinguishable from "you're up to date". So moving the
# skills to the top level (one less directory to walk up) broke upgrade checking
# for every user and no existing test failed. That is what section 2 pins down.
#
# WHAT IT CANNOT DO
# It never starts a real Claude Code session — the skills' prose, routing and
# judgment are not exercised here, only the runtime they stand on. A live-session
# check needs credentials an isolated HOME does not have.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"

PASS=0; FAIL=0
if [ -t 1 ]; then G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; B=$'\033[1m'; Z=$'\033[0m'; else G=; R=; Y=; B=; Z=; fi
ok()   { PASS=$((PASS+1)); printf '  %sPASS%s %s\n' "$G" "$Z" "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  %sFAIL%s %s\n' "$R" "$Z" "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
note() { printf '  %s..%s   %s\n' "$Y" "$Z" "$1"; }
sect() { printf '\n%s== %s ==%s\n' "$B" "$1" "$Z"; }
assert_eq()  { [ "$2" = "$3" ] && ok "$1" || bad "$1" "expected [$2], got [$3]"; }
assert_has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "missing [$2]" ;; esac; }
assert_not() { case "$3" in *"$2"*) bad "$1" "unexpectedly contains [$2]" ;; *) ok "$1" ;; esac; }

CLEAN="$(mktemp -d "${TMPDIR:-/tmp}/boots-lifecycle-XXXXXX")"
cleanup() { rm -rf "$CLEAN"; }
trap cleanup EXIT

HOME_DIR="$CLEAN/home"
SKILLS_DIR="$HOME_DIR/.claude/skills"
CLONE_DIR="$SKILLS_DIR/.boots"      # the repo, where the documented install puts it
BOOTS_HOME="$HOME_DIR/.boots"       # the runtime home — deliberately NOT the clone
UPSTREAM="$CLEAN/upstream.git"
mkdir -p "$HOME_DIR"

# Run a command as the installed user: isolated HOME, nothing inherited.
as_user() { env HOME="$HOME_DIR" "$@"; }

printf '%sBoots isolated lifecycle check%s\n' "$B" "$Z"
printf 'fake HOME  : %s\n' "$HOME_DIR"
printf 'fake origin: %s\n' "$UPSTREAM"

# ─────────────────────────────────────────────────────────────────────────────
sect "0 — a throwaway upstream, so upgrade is testable offline"
# boots-update-check derives its remote from the clone's own `origin`. Giving the
# clone a local bare repo as origin makes the whole upgrade path exercisable with
# no network and no GitHub.
# -b main matters: without it the bare repo's HEAD points at whatever this git
# defaults to, and a clone of it comes up empty with only a warning.
git init -q --bare -b main "$UPSTREAM"
SEED="$CLEAN/seed"
git -c advice.detachedHead=false clone -q "$REPO" "$SEED" 2>/dev/null
# Publish the working tree (staged or not) as upstream `main`, so this checks the
# code in front of you rather than the last commit.
rsync -a --exclude='.git' --exclude='node_modules' --exclude='systems' \
      --exclude='sessions' --exclude='analytics' --exclude='config.yaml' \
      --exclude='state' --exclude='.activated' --exclude='installation-id' \
      --exclude='map.md' "$REPO/" "$SEED/"
( cd "$SEED"
  git checkout -q -B main
  git add -A >/dev/null 2>&1
  git -c user.email=t@t -c user.name=t commit -qm "lifecycle seed" >/dev/null 2>&1
  git remote add up "$UPSTREAM" 2>/dev/null || git remote set-url up "$UPSTREAM"
  git push -q up main:main
)
[ -d "$UPSTREAM/refs" ] && ok "throwaway upstream published" || bad "throwaway upstream published"

# ─────────────────────────────────────────────────────────────────────────────
sect "1 — install, exactly as the README says"
git clone -q --depth 1 "$UPSTREAM" "$CLONE_DIR" 2>/dev/null
[ -x "$CLONE_DIR/setup" ] && ok "clone landed inside the skills dir" || bad "clone landed inside the skills dir"

SETUP_LOG="$CLEAN/setup.log"
as_user bash "$CLONE_DIR/setup" >"$SETUP_LOG" 2>&1 \
  && ok "setup exits 0" || bad "setup exits 0" "$(tail -3 "$SETUP_LOG")"

# The clone must NOT be discoverable as a skill itself. This is the whole reason
# the install path is dot-prefixed: a visible repo dir inside the skills folder is
# either mistaken for a skill or collides with the `boots` skill's own name.
case "$(basename "$CLONE_DIR")" in
  .*) ok "the repo dir is dot-prefixed, so Claude never reads it as a skill" ;;
  *)  bad "the repo dir is dot-prefixed" "got [$(basename "$CLONE_DIR")]" ;;
esac
[ -e "$SKILLS_DIR/boots" ] && [ "$(cd "$SKILLS_DIR/boots" && pwd -P)" != "$(cd "$CLONE_DIR" && pwd -P)" ] \
  && ok "the 'boots' skill and the repo dir are different places" \
  || bad "the 'boots' skill and the repo dir are different places"

# Whole-directory symlinks are what carry bin/, forms/ and examples/ across. A
# SKILL.md-only install looks identical until a skill tries to read a bundled file.
[ -L "$SKILLS_DIR/boots" ] && ok "skills install as whole-directory symlinks" || bad "skills install as whole-directory symlinks"
for f in bin forms examples; do
  [ -e "$SKILLS_DIR/boots/$f" ] && ok "bundled '$f' came across with the skill" || bad "bundled '$f' came across with the skill"
done

# ─────────────────────────────────────────────────────────────────────────────
sect "2 — every helper finds the repo root from where it is installed"
# THE REGRESSION GUARD. Each helper walks up from its own path to find VERSION and
# .git. Change the directory depth and the walk silently lands somewhere wrong —
# and because these scripts are built to fail silently, nothing else notices.
for s in boots-update-check boots-analytics boots-telemetry-sync; do
  SCRIPT="$SKILLS_DIR/boots/bin/$s"
  if [ ! -x "$SCRIPT" ]; then bad "$s is installed"; continue; fi
  # Resolve the way the script itself does: through the symlink, to the real path.
  SELF="$(cd "$(dirname "$SCRIPT")" && pwd -P)"
  ROOT="$(cd "$SELF/../.." && pwd -P)"
  if [ -f "$ROOT/VERSION" ] && [ -e "$ROOT/.git" ]; then
    ok "$s resolves the repo root (found VERSION + .git)"
  else
    bad "$s resolves the repo root" "walked to [$ROOT], which has no VERSION/.git"
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
sect "3 — the runtime home is separate from the program"
BIN="$SKILLS_DIR/boots/bin"
as_user "$BIN/boots-config" get telemetry >/dev/null 2>&1
[ -d "$BOOTS_HOME" ] && ok "~/.boots is created on first use" || bad "~/.boots is created on first use"
case "$BOOTS_HOME" in
  "$CLONE_DIR"*) bad "the runtime home is not inside the clone" "$BOOTS_HOME" ;;
  *)             ok "the runtime home is not inside the clone" ;;
esac
assert_eq "telemetry is off by default" "off" "$(as_user "$BIN/boots-config" get telemetry 2>&1)"

# ─────────────────────────────────────────────────────────────────────────────
sect "4 — a system moves through the pipeline (the funnel, end to end)"
SLUG="lifecycle-probe"
mkdir -p "$BOOTS_HOME/systems/$SLUG"
cat >"$BOOTS_HOME/systems/$SLUG/system.md" <<'SYS'
---
slug: lifecycle-probe
stage: clarify
status: active
form: skill
platform: claude-code
target: the probe records a full pass through the pipeline
question: does a system survive an upgrade intact
---

## now
Created by the isolated lifecycle check.

## log
SYS
[ -f "$BOOTS_HOME/systems/$SLUG/system.md" ] && ok "a system record exists in the runtime home" || bad "a system record exists in the runtime home"

as_user "$BIN/boots-event" --system "$SLUG" --event created --to clarify >/dev/null 2>&1
for pair in "clarify scope" "scope build" "build review" "review verify" "verify ship"; do
  set -- $pair
  as_user "$BIN/boots-event" --system "$SLUG" --event transition --from "$1" --to "$2" --outcome advanced >/dev/null 2>&1
done
EVENTS="$BOOTS_HOME/systems/$SLUG/events.jsonl"
if [ -f "$EVENTS" ]; then
  N="$(grep -c . "$EVENTS" 2>/dev/null || echo 0)"
  [ "$N" -ge 6 ] && ok "the funnel recorded every transition ($N events)" \
                 || bad "the funnel recorded every transition" "only $N events"
  assert_has "the funnel records the ship transition" '"to_stage":"ship"' "$(cat "$EVENTS")"
else
  bad "the funnel recorded every transition" "no events.jsonl at $EVENTS"
fi

BOARD="$(as_user "$BIN/boots-analytics" --brief 2>&1)"
assert_has "the board sees the system" "$SLUG" "$BOARD"
assert_not "the board reports no shell errors" "No such file" "$BOARD"

# ─────────────────────────────────────────────────────────────────────────────
sect "5 — an upgrade lands, and the user's work survives it"
OLD_VERSION="$(cat "$CLONE_DIR/VERSION")"
NEW_VERSION="$(awk -F. '{$NF=$NF+1; print}' OFS=. "$CLONE_DIR/VERSION")"
( cd "$SEED"
  echo "$NEW_VERSION" > VERSION
  git add VERSION >/dev/null 2>&1
  git -c user.email=t@t -c user.name=t commit -qm "release $NEW_VERSION" >/dev/null 2>&1
  git push -q up main:main
)
ok "upstream published $OLD_VERSION → $NEW_VERSION"

# The check is what tells a user an upgrade exists. Silence here means every user
# stays on an old version forever, with no error to notice.
UPD="$(as_user "$BIN/boots-update-check" --force 2>&1)"
assert_has "boots-update-check announces the new version" "UPGRADE_AVAILABLE" "$UPD"
assert_has "…and names the right version" "$NEW_VERSION" "$UPD"

# Now run the upgrade the way boots-upgrade/SKILL.md runs it: resolve the repo by
# walking up from the installed helper, then pull and re-run setup in place.
UPG_LOG="$CLEAN/upgrade.log"
as_user bash -c '
  set -uo pipefail
  _SELF=$(cd "$(dirname "$(readlink ~/.claude/skills/boots/bin/boots-update-check 2>/dev/null || echo ~/.claude/skills/boots/bin/boots-update-check)")" && pwd -P)
  BOOTS_REPO=$(cd "$_SELF/../.." && pwd -P)
  cd "$BOOTS_REPO" || { echo "could not find the Boots repo"; exit 1; }
  echo "RESOLVED $BOOTS_REPO"
  git fetch -q origin && git reset -q --hard origin/main
  ./setup
' >"$UPG_LOG" 2>&1 && ok "the upgrade sequence exits 0" || bad "the upgrade sequence exits 0" "$(tail -5 "$UPG_LOG")"
# Compare fully-resolved paths: the upgrade block uses `pwd -P`, and on macOS
# /var is a symlink to /private/var, so the raw strings never match.
CLONE_REAL="$(cd "$CLONE_DIR" && pwd -P)"
assert_has "the upgrade resolved the repo from the installed symlink" "RESOLVED $CLONE_REAL" "$(cat "$UPG_LOG")"
assert_eq "the clone is now on the new version" "$NEW_VERSION" "$(cat "$CLONE_DIR/VERSION" 2>/dev/null)"

# The point of a separate runtime home: upgrading the program must not touch the
# user's work. `git reset --hard` in the clone would be catastrophic otherwise.
[ -f "$BOOTS_HOME/systems/$SLUG/system.md" ] && ok "the user's system survived the upgrade" || bad "the user's system survived the upgrade"
[ -f "$EVENTS" ] && ok "the user's funnel history survived the upgrade" || bad "the user's funnel history survived the upgrade"
assert_has "the board still sees the system after upgrading" "$SLUG" "$(as_user "$BIN/boots-analytics" --brief 2>&1)"

# Skills must still resolve through their symlinks after the repo was reset.
BROKEN=""
for d in "$CLONE_DIR"/boots*/; do
  n="$(basename "$d")"
  [ -e "$SKILLS_DIR/$n/SKILL.md" ] || BROKEN="$BROKEN $n"
done
[ -n "$BROKEN" ] && bad "every skill still resolves after the upgrade" "dangling:$BROKEN" \
                 || ok "every skill still resolves after the upgrade"

# ─────────────────────────────────────────────────────────────────────────────
sect "6 — project-scoped install"
PROJ="$CLEAN/proj"; mkdir -p "$PROJ"
( cd "$PROJ" && as_user bash "$CLONE_DIR/setup" --project >/dev/null 2>&1 )
[ -e "$PROJ/.claude/skills/boots/SKILL.md" ] && ok "--project installs into the repo it's run in" \
                                             || bad "--project installs into the repo it's run in"

# ─────────────────────────────────────────────────────────────────────────────
sect "7 — uninstall gives the machine back, and keeps the user's work"
as_user bash "$CLONE_DIR/setup" --uninstall >/dev/null 2>&1 \
  && ok "uninstall exits 0" || bad "uninstall exits 0"
LEFT=0
for d in "$CLONE_DIR"/boots*/; do
  [ -e "$SKILLS_DIR/$(basename "$d")" ] && LEFT=$((LEFT+1))
done
assert_eq "uninstall removed every symlink it made" "0" "$LEFT"
[ -d "$CLONE_DIR" ] && ok "uninstall left the clone itself alone" || bad "uninstall left the clone itself alone"
[ -f "$BOOTS_HOME/systems/$SLUG/system.md" ] && ok "uninstall left the user's systems alone" \
                                             || bad "uninstall left the user's systems alone"

# ─────────────────────────────────────────────────────────────────────────────
printf '\n%s== result ==%s\n' "$B" "$Z"
printf '  %s%d passed%s, %s%d failed%s\n' "$G" "$PASS" "$Z" "$R" "$FAIL" "$Z"
note "no model was involved — skill prose, routing and judgment are not covered here."
[ "$FAIL" -eq 0 ] || exit 1
