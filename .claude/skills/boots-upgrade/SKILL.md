---
name: boots-upgrade
description: >
  Update Boots to the latest version and show what's new. Detects the Boots repo,
  pulls the latest, re-runs setup, applies any migrations, then summarises the
  changes. Use when the user says "boots-upgrade", "update boots", "get the latest
  boots", or when a skill's preamble prints UPGRADE_AVAILABLE.
preamble-tier: 1
---
<!-- AUTO-GENERATED from SKILL.md.tmpl — do not edit directly -->
<!-- Regenerate: bun run gen:skill-docs -->

## Preamble (run first, then say nothing about it)

Run the block below silently. It is invisible plumbing — do NOT narrate it, echo it, or mention telemetry, branch, or sessions to the user (this suite's rule 5: never narrate your plumbing). Surface something ONLY if the update check prints `UPGRADE_AVAILABLE` or `JUST_UPGRADED` (see "Updates" below). Otherwise go straight to this skill's own opening as if the preamble were not here — it never replaces or precedes the skill's first move in the conversation.

```bash
_UPD=$(~/.claude/skills/boots/bin/boots-update-check 2>/dev/null || .claude/skills/boots/bin/boots-update-check 2>/dev/null || true)
[ -n "$_UPD" ] && echo "$_UPD" || true
mkdir -p ~/.boots/sessions ~/.boots/analytics
touch ~/.boots/sessions/"$PPID" 2>/dev/null || true
find ~/.boots/sessions -mmin +120 -type f -exec rm {} + 2>/dev/null || true
_TEL=$(~/.claude/skills/boots/bin/boots-config get telemetry 2>/dev/null || echo "off")
_TEL_PROMPTED=$([ -f ~/.boots/.consent-prompted ] && echo "yes" || echo "no")
_PROACTIVE=$(~/.claude/skills/boots/bin/boots-config get proactive 2>/dev/null || echo "true")
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
_SESSION_ID="$$-$(date +%s)"
_TEL_START=$(date +%s)
echo "TELEMETRY: ${_TEL:-off}"
echo "TEL_PROMPTED: $_TEL_PROMPTED"
echo "PROACTIVE: $_PROACTIVE"
echo "BRANCH: $_BRANCH"
# Ops run-start marker (Layer B). If this session dies before it logs an end event,
# the marker is left behind; the next boots-telemetry-log run finalizes any other
# session's stale marker as outcome:unknown, so a crash is recorded, not lost.
if [ "$_TEL" != "off" ]; then
  printf '{"skill":"boots-upgrade","ts":"%s","session_id":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_SESSION_ID" > ~/.boots/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
fi
```

## Updates (act on the preamble output)

If the preamble printed `UPGRADE_AVAILABLE <old> <new>`: read `~/.claude/skills/boots-upgrade/SKILL.md` and follow its inline upgrade flow (auto-upgrade if configured, else a 4-option AskUserQuestion: Yes / Always / Not now / Never). If it printed `JUST_UPGRADED <old> <new>`: say "Running Boots v{new} (just updated!)" and continue.

If `PROACTIVE` is `false`: don't proactively suggest other Boots skills this session.

## Telemetry consent (ask once — the one thing here you may surface)

Everything else in this preamble is silent plumbing. This is the exception: a single, one-time question. If `TEL_PROMPTED` is `yes`, skip it entirely. If `no`, ask once via AskUserQuestion, then always `touch ~/.boots/.consent-prompted` regardless of the answer.

> Help Boots get better? It can share which stages your systems pass through and where they stall — so the project can see where people get stuck. **No code, no file contents, and no repo or system names** (those stay on your machine). A stable, random ID only on the "community" tier.

- **A) Help Boots get better (community)** → `~/.claude/skills/boots/bin/boots-config set telemetry community`
- **B) No thanks** → ask once more: "Anonymous instead — aggregate counts only, no ID?" → yes: `~/.claude/skills/boots/bin/boots-config set telemetry anonymous` · no: `~/.claude/skills/boots/bin/boots-config set telemetry off`

Always, whatever they choose:
```bash
touch ~/.boots/.consent-prompted 2>/dev/null || true
```

Default is **off**. Nothing is sent anywhere unless the user actively picks community or anonymous here.

## Telemetry (run last)

After the workflow completes, log the ops run event (Layer B). OUTCOME is success/error/abort. This writes only to `~/.boots/`; run it even in plan mode.

```bash
_TEL_END=$(date +%s); _TEL_DUR=$(( _TEL_END - _TEL_START ))
rm -f ~/.boots/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
if [ "$_TEL" != "off" ] && [ -x ~/.claude/skills/boots/bin/boots-telemetry-log ]; then
  ~/.claude/skills/boots/bin/boots-telemetry-log --skill "boots-upgrade" --duration "$_TEL_DUR" --outcome "OUTCOME" --session-id "$_SESSION_ID" 2>/dev/null &
fi
```

Replace `OUTCOME` before running.

# Boots upgrade

Update Boots to the latest version and show what changed. Boots installs by
symlinking its skills from a cloned repo, so "upgrading" is: pull that repo, re-run
its setup, apply migrations. One repo, every project updated at once.

## Inline upgrade flow

Referenced by every skill's preamble when it prints `UPGRADE_AVAILABLE <old> <new>`.

### Step 1 — Ask (or auto-upgrade)

Check auto-upgrade first:

```bash
_AUTO=$(~/.claude/skills/boots/bin/boots-config get auto_upgrade 2>/dev/null || echo false)
echo "AUTO_UPGRADE=$_AUTO"
```

**If `AUTO_UPGRADE` is `true`:** skip the question, say "Updating Boots v{old} → v{new}…", go to Step 2. If setup fails, restore from the `.bak` and tell the user the auto-upgrade failed and the previous version is restored.

**Otherwise** ask once via AskUserQuestion — *"Boots v{new} is available (you're on v{old}). Update now?"* — with four options:

- **Yes, update now** → Step 2.
- **Always keep me up to date** → `~/.claude/skills/boots/bin/boots-config set auto_upgrade true`, then Step 2.
- **Not now** → write the escalating snooze below, then continue whatever the user was doing. Don't mention the update again this session.
- **Never ask again** → `~/.claude/skills/boots/bin/boots-config set update_check false`, tell them how to re-enable (`boots-config set update_check true`), continue.

Snooze (first = 24h, second = 48h, third+ = 1 week; a new version resets it):

```bash
_SF="$HOME/.boots/update-snoozed"; _RV="{new}"; _CL=0
if [ -f "$_SF" ] && [ "$(awk '{print $1}' "$_SF")" = "$_RV" ]; then _CL=$(awk '{print $2}' "$_SF"); case "$_CL" in *[!0-9]*) _CL=0 ;; esac; fi
_NL=$(( _CL + 1 )); [ "$_NL" -gt 3 ] && _NL=3
echo "$_RV $_NL $(date +%s)" > "$_SF"
```

### Step 2 — Upgrade

Resolve the Boots repo (the skill is symlinked from it) and pull:

```bash
_SELF=$(cd "$(dirname "$(readlink ~/.claude/skills/boots/bin/boots-update-check 2>/dev/null || echo ~/.claude/skills/boots/bin/boots-update-check)")" && pwd -P)
BOOTS_REPO=$(cd "$_SELF/../../../.." && pwd -P)
cd "$BOOTS_REPO" || { echo "Could not find the Boots repo"; exit 1; }
OLD_VERSION=$(cat VERSION 2>/dev/null || echo unknown)
if [ ! -d .git ]; then echo "Boots repo has no .git — can't auto-update. Pull it manually."; exit 1; fi
STASH=$(git stash 2>&1)
git fetch origin && git reset --hard origin/main
./setup >/dev/null 2>&1 || ./setup
```

If `$STASH` contains "Saved working directory", tell the user local changes were stashed and how to restore them (`git stash pop` in the Boots repo).

### Step 3 — Migrations

After setup, run any migration scripts newer than the old version. Each is an idempotent bash script in `migrations/` named `v<version>.sh`.

```bash
if [ -d "$BOOTS_REPO/migrations" ] && [ "$OLD_VERSION" != "unknown" ]; then
  for m in $(find "$BOOTS_REPO/migrations" -maxdepth 1 -name 'v*.sh' -type f 2>/dev/null | sort -V); do
    mv=$(basename "$m" .sh | sed 's/^v//')
    if [ "$(printf '%s\n%s' "$OLD_VERSION" "$mv" | sort -V | head -1)" = "$OLD_VERSION" ] && [ "$OLD_VERSION" != "$mv" ]; then
      echo "Running migration $mv…"; bash "$m" || echo "  (migration $mv had errors — non-fatal)"
    fi
  done
fi
```

### Step 4 — Mark + clear cache

```bash
mkdir -p ~/.boots
echo "$OLD_VERSION" > ~/.boots/just-upgraded-from
rm -f ~/.boots/last-update-check ~/.boots/update-snoozed
```

### Step 5 — What's new

Read `$BOOTS_REPO/SKILLS-CHANGELOG.md`. Summarise the entries between the old and new versions as 3–6 plain-language bullets — what the user can now do, not internal churn. Then: *"Boots v{new} — updated from v{old}. Here's what's new: …"* and continue whatever they were doing.

## Standalone (`boots-upgrade` invoked directly)

Force a fresh check, bypassing cache and snooze:

```bash
~/.claude/skills/boots/bin/boots-update-check --force 2>/dev/null || true
```

If it prints `UPGRADE_AVAILABLE <old> <new>`, run Steps 2–5. If it prints nothing, tell the user they're on the latest version (`cat` the VERSION file to name it). If there's no git remote yet (Boots not published), say so plainly — there's nothing to check against until the repo has an upstream.
