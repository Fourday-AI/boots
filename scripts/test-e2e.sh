#!/usr/bin/env bash
# Boots end-to-end tests.
#
#   bash scripts/test-e2e.sh          # offline suite — no network, no secrets, CI-safe
#   bash scripts/test-e2e.sh --live   # + live checks (GitHub upgrade detection, real
#                                      #   ingest/pulse round-trip against the backend)
#
# The offline suite drives the real bin/ scripts through their documented test seams
# (BOOTS_DIR, BOOTS_STATE_DIR, BOOTS_HOME, BOOTS_REMOTE_REPO, BOOTS_SUPABASE_URL) in
# throwaway scratch dirs, and points the telemetry sync at a local capture server so
# the privacy transform (slug hashing, _repo stripping, tier scrubbing) is asserted on
# the actual bytes that would leave the machine — no live backend, no anon key needed.
#
# --live adds: (1) real upgrade detection against this repo's GitHub origin (needs the
# gh CLI, as the VERSION fetch is GitHub-specific), and (2) a real POST to
# telemetry-ingest + GET community-pulse using the PUBLIC anon key from supabase/
# config.sh. The ingest write lands in the production community DB under a clearly
# tagged installation_id; if BOOTS_SUPABASE_SERVICE_KEY is exported, the live section
# deletes its own test rows afterward.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$REPO/boots/bin"
LIVE=0; [ "${1:-}" = "--live" ] && LIVE=1

PASS=0; FAIL=0
if [ -t 1 ]; then G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; B=$'\033[1m'; Z=$'\033[0m'; else G=; R=; Y=; B=; Z=; fi
ok()   { PASS=$((PASS+1)); printf '  %sPASS%s %s\n' "$G" "$Z" "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  %sFAIL%s %s\n' "$R" "$Z" "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
sect() { printf '\n%s== %s ==%s\n' "$B" "$1" "$Z"; }
# assert_eq <label> <expected> <actual>
assert_eq()  { [ "$2" = "$3" ] && ok "$1" || bad "$1" "expected [$2], got [$3]"; }
# assert_has <label> <needle> <haystack>
assert_has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "missing [$2] in: $3" ;; esac; }
# assert_not <label> <needle> <haystack>
assert_not() { case "$3" in *"$2"*) bad "$1" "unexpected [$2] in: $3" ;; *) ok "$1" ;; esac; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/boots-e2e-XXXXXX")"
MOCK_PID=""
cleanup() { [ -n "$MOCK_PID" ] && kill "$MOCK_PID" 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT

# ─────────────────────────────────────────────────────────────────────────────
sect "update check — state machine (offline)"
# Each case runs in its own scratch repo-root (VERSION) + state dir (cache/markers).
uc() { BOOTS_DIR="$1" BOOTS_STATE_DIR="$2" BOOTS_HOME="$2" "$BIN/boots-update-check" ${3:-}; }

# U1 up-to-date: fresh UP_TO_DATE cache matching local → silent
D="$WORK/u1"; S="$WORK/u1s"; mkdir -p "$D" "$S"; printf '0.1.0.0\n' >"$D/VERSION"
printf 'UP_TO_DATE 0.1.0.0' >"$S/last-update-check"
assert_eq "up-to-date → silent" "" "$(uc "$D" "$S")"

# U2 upgrade available: fresh UPGRADE_AVAILABLE cache (old==local), no snooze → prints it
D="$WORK/u2"; S="$WORK/u2s"; mkdir -p "$D" "$S"; printf '0.1.0.0\n' >"$D/VERSION"
printf 'UPGRADE_AVAILABLE 0.1.0.0 0.2.0.0' >"$S/last-update-check"
assert_eq "upgrade available → UPGRADE_AVAILABLE line" "UPGRADE_AVAILABLE 0.1.0.0 0.2.0.0" "$(uc "$D" "$S")"

# U3 snooze suppresses the same upgrade
D="$WORK/u3"; S="$WORK/u3s"; mkdir -p "$D" "$S"; printf '0.1.0.0\n' >"$D/VERSION"
printf 'UPGRADE_AVAILABLE 0.1.0.0 0.2.0.0' >"$S/last-update-check"
printf '0.2.0.0 1 %s\n' "$(date +%s)" >"$S/update-snoozed"
assert_eq "snoozed upgrade → silent" "" "$(uc "$D" "$S")"

# U4 kill switch → silent (exits before any fetch)
D="$WORK/u4"; S="$WORK/u4s"; mkdir -p "$D" "$S"; printf '0.1.0.0\n' >"$D/VERSION"
printf 'UPGRADE_AVAILABLE 0.1.0.0 0.2.0.0' >"$S/last-update-check"
BOOTS_HOME="$S" "$BIN/boots-config" set update_check false >/dev/null 2>&1
assert_eq "kill switch → silent" "" "$(uc "$D" "$S")"

# U5 just-upgraded marker is consumed and announced
D="$WORK/u5"; S="$WORK/u5s"; mkdir -p "$D" "$S"; printf '0.1.0.0\n' >"$D/VERSION"
printf 'UP_TO_DATE 0.1.0.0' >"$S/last-update-check"; printf '0.0.9.0\n' >"$S/just-upgraded-from"
OUT="$(uc "$D" "$S")"
assert_has "just-upgraded → JUST_UPGRADED line" "JUST_UPGRADED 0.0.9.0 0.1.0.0" "$OUT"
[ -f "$S/just-upgraded-from" ] && bad "just-upgraded marker consumed" "marker still present" || ok "just-upgraded marker consumed"

# U6 no git remote → dormant/silent (never wedges a skill)
D="$WORK/u6"; S="$WORK/u6s"; mkdir -p "$D" "$S"; printf '0.1.0.0\n' >"$D/VERSION"
assert_eq "no remote → silent" "" "$(uc "$D" "$S")"

# U7 NON-GITHUB origin resolves a real version (offline, over a local bare repo).
# Regression guard: the fetch used to be gated on the origin containing
# github.com, so a clone hosted anywhere else fell through with an empty REMOTE
# and cached UP_TO_DATE forever — reporting itself current with no error, no
# upgrade, and nothing in the output to hint why. Because the upstream is each
# user's own `origin`, that silently froze every fork off GitHub. A local bare
# repo is a non-github remote by definition, so this also runs in CI with no
# network. Asserts the version came back over plain git, not the raw CDN or gh.
HOST="$WORK/u7host.git"; D="$WORK/u7"; S="$WORK/u7s"; mkdir -p "$S"
git init -q --bare "$HOST"
git init -q "$WORK/u7src" && (
  cd "$WORK/u7src" && git config user.email t@t && git config user.name t
  printf '0.9.0.0\n' >VERSION && git add -A && git commit -qm v && git branch -M main
  git push -q "$HOST" main
) >/dev/null 2>&1
git clone -q "$HOST" "$D" >/dev/null 2>&1; printf '0.1.0.0\n' >"$D/VERSION"
assert_eq "non-github origin → upgrade detected" "UPGRADE_AVAILABLE 0.1.0.0 0.9.0.0" "$(uc "$D" "$S")"
# The fallback shallow-fetches into .git. That must never disturb the checkout:
# an update check is a read, and a user mid-edit must not find their tree moved.
assert_eq "update check leaves the working tree alone" "" "$(git -C "$D" status --porcelain -- . ':!VERSION' 2>/dev/null)"

# ─────────────────────────────────────────────────────────────────────────────
sect "telemetry — client privacy transform (offline, via local capture server)"
# Stand up a local server that records POST bodies and returns {inserted:N}, so the
# real sync runs unmodified and we inspect exactly what it would send.
MOCK_PY="$WORK/mock.py"; BODY="$WORK/sent.jsonl"; PORTF="$WORK/port"
cat >"$MOCK_PY" <<'PY'
import http.server, sys, json
bodyfile, portfile = sys.argv[1], sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get('content-length', 0) or 0)
        body = self.rfile.read(n).decode('utf-8', 'replace')
        open(bodyfile, 'a').write(body + "\n")
        try:
            recs = json.loads(body); cnt = len(recs) if isinstance(recs, list) else 1
        except Exception:
            cnt = 1
        resp = json.dumps({"inserted": cnt}, separators=(",", ":")).encode()  # match the real fn (no spaces)
        self.send_response(200)
        self.send_header('content-type', 'application/json')
        self.send_header('content-length', str(len(resp)))
        self.end_headers(); self.wfile.write(resp)
    def log_message(self, *a): pass
srv = http.server.HTTPServer(('127.0.0.1', 0), H)
open(portfile, 'w').write(str(srv.server_address[1]))
srv.serve_forever()
PY

if ! command -v python3 >/dev/null 2>&1; then
  bad "python3 available for capture server" "python3 not found — skipping transform tests"
else
  python3 "$MOCK_PY" "$BODY" "$PORTF" & MOCK_PID=$!
  disown "$MOCK_PID" 2>/dev/null || true   # suppress the shell's "Terminated" notice on cleanup kill
  for _ in $(seq 1 50); do [ -s "$PORTF" ] && break; sleep 0.1; done
  PORT="$(cat "$PORTF" 2>/dev/null || echo)"
  if [ -z "$PORT" ]; then
    bad "capture server started" "no port file"
  else
    MOCK_URL="http://127.0.0.1:$PORT"
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # T1 community tier: slug hashed, _repo stripped, runs keep installation_id, cursors advance
    H="$WORK/tel-comm"; mkdir -p "$H/analytics"
    # The extra _folder/_count fields are deliberate: underscore means local-only by
    # convention, and the transform must honour the CONVENTION, not a list of the
    # keys we happen to write today. Anything appended to this buffer by another
    # host — or by hand — has to be stripped too.
    printf '{"v":1,"ts":"%s","event":"created","system":"my-secret-system","from_stage":null,"to_stage":"clarify","outcome":"advanced","form":null,"platform":"claude-code","_repo":"private-repo-name","_folder":"private-folder-name","_count":7}\n' "$ts" >"$H/analytics/funnel.jsonl"
    printf '{"v":1,"ts":"%s","event":"skill_run","skill":"boots-clarify","outcome":"success","duration_s":2.0,"os":"darwin","installation_id":"keep-me-123"}\n' "$ts" >"$H/analytics/runs.jsonl"
    BOOTS_HOME="$H" "$BIN/boots-config" set telemetry community >/dev/null 2>&1
    BOOTS_HOME="$H" BOOTS_SUPABASE_URL="$MOCK_URL" BOOTS_SUPABASE_ANON_KEY="test-anon" "$BIN/boots-telemetry-sync"
    SENT="$(cat "$BODY" 2>/dev/null || echo)"
    assert_not "community: plaintext slug never sent" "my-secret-system" "$SENT"
    assert_not "community: _repo stripped"            "private-repo-name" "$SENT"
    assert_not "community: _repo key stripped"        '"_repo"'           "$SENT"
    assert_not "community: every _-prefixed field stripped, not just _repo" "private-folder-name" "$SENT"
    assert_not "community: _-prefixed numeric field stripped"               '"_count"'            "$SENT"
    # the funnel record's system must now be a 16-hex hash
    HASHED="$(printf '%s' "$SENT" | grep -o '"event":"created"[^}]*"system":"[0-9a-f]\{16\}"' | head -1)"
    [ -n "$HASHED" ] && ok "community: slug replaced by 16-hex hash" || bad "community: slug hashed" "no hashed system in: $SENT"
    assert_has "community: run keeps installation_id" '"installation_id":"keep-me-123"' "$SENT"
    assert_eq "community: funnel cursor advanced" "1" "$(cat "$H/analytics/.sync-cursor-funnel" 2>/dev/null || echo 0)"
    assert_eq "community: runs cursor advanced"   "1" "$(cat "$H/analytics/.sync-cursor-runs" 2>/dev/null || echo 0)"

    # T2 anonymous tier: installation_id stripped from run records
    : >"$BODY"
    H="$WORK/tel-anon"; mkdir -p "$H/analytics"
    printf '{"v":1,"ts":"%s","event":"skill_run","skill":"boots-ship","outcome":"success","duration_s":9.0,"os":"linux","installation_id":"should-vanish"}\n' "$ts" >"$H/analytics/runs.jsonl"
    BOOTS_HOME="$H" "$BIN/boots-config" set telemetry anonymous >/dev/null 2>&1
    BOOTS_HOME="$H" BOOTS_SUPABASE_URL="$MOCK_URL" BOOTS_SUPABASE_ANON_KEY="test-anon" "$BIN/boots-telemetry-sync"
    SENT="$(cat "$BODY" 2>/dev/null || echo)"
    assert_not "anonymous: installation_id stripped" "should-vanish" "$SENT"
    assert_has "anonymous: run still sent"            '"skill":"boots-ship"' "$SENT"

    # T3 off tier: nothing is sent at all
    : >"$BODY"
    H="$WORK/tel-off"; mkdir -p "$H/analytics"
    printf '{"v":1,"ts":"%s","event":"created","system":"x","to_stage":"clarify","platform":"claude-code"}\n' "$ts" >"$H/analytics/funnel.jsonl"
    BOOTS_HOME="$H" "$BIN/boots-config" set telemetry off >/dev/null 2>&1
    BOOTS_HOME="$H" BOOTS_SUPABASE_URL="$MOCK_URL" BOOTS_SUPABASE_ANON_KEY="test-anon" "$BIN/boots-telemetry-sync"
    assert_eq "off tier → nothing sent" "" "$(cat "$BODY" 2>/dev/null || echo)"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
sect "funnel — emit → per-system log → rollup (offline)"
H="$WORK/funnel"; mkdir -p "$H"
BOOTS_HOME="$H" "$BIN/boots-event" --system "demo-sys" --event created --to clarify --outcome advanced 2>/dev/null
BOOTS_HOME="$H" "$BIN/boots-event" --system "demo-sys" --event transition --from clarify --to scope --outcome advanced 2>/dev/null
EV="$H/systems/demo-sys/events.jsonl"
if [ -f "$EV" ]; then
  assert_eq "events.jsonl has 2 rows" "2" "$(wc -l <"$EV" | tr -d ' ')"
else
  bad "events.jsonl written" "no file at $EV"
fi
# rollup needs a system.md to list the system on the board
mkdir -p "$H/systems/demo-sys"
printf 'stage: scope\nstatus: active\n' >"$H/systems/demo-sys/system.md"
ROLL="$(BOOTS_HOME="$H" "$BIN/boots-analytics" --brief 2>/dev/null)"
assert_has "rollup emits FUNNEL line"   "FUNNEL"   "$ROLL"
assert_has "rollup emits PIPELINE line" "PIPELINE" "$ROLL"
assert_has "rollup lists the system"    "demo-sys" "$ROLL"

# ─────────────────────────────────────────────────────────────────────────────
sect "funnel — host attribution and stageless events (offline)"
# Boots runs on more than one AI host. Every one of these failed silently in the
# wild: Cowork sessions reported as claude-code, and a transition that named no
# stage counted in the totals while being invisible to every stage rollup.
H2="$WORK/funnel-host"; mkdir -p "$H2" "$WORK/hosts/rcw-01abcdef/x" "$WORK/hosts/plain-repo"
emit_from() { ( cd "$1" && shift && BOOTS_HOME="$H2" "$BIN/boots-event" "$@" 2>/dev/null ); }
FUN2="$H2/analytics/funnel.jsonl"

# F1 a Cowork session (working tree under an rcw-<id> folder) is attributed to cowork
emit_from "$WORK/hosts/rcw-01abcdef/x" --system "host-sys" --event created --to clarify
assert_has "cowork session tagged platform:cowork" '"platform":"cowork"' "$(tail -1 "$FUN2" 2>/dev/null)"

# F2 an ordinary local repo still reports claude-code — the detection must not over-fire
emit_from "$WORK/hosts/plain-repo" --system "host-sys" --event transition --from clarify --to scope
assert_has "local session tagged platform:claude-code" '"platform":"claude-code"' "$(tail -1 "$FUN2" 2>/dev/null)"

# F3 an explicit --platform always beats detection (a skill that knows, wins)
emit_from "$WORK/hosts/rcw-01abcdef/x" --system "host-sys" --event transition --from scope --to build --platform claude-code
assert_has "explicit --platform overrides detection" '"platform":"claude-code"' "$(tail -1 "$FUN2" 2>/dev/null)"

# F4 a stageless transition is REPAIRED from the record — the record is the truth
mkdir -p "$H2/systems/host-sys"; printf 'stage: verify\nstatus: active\n' >"$H2/systems/host-sys/system.md"
BOOTS_HOME="$H2" "$BIN/boots-event" --system "host-sys" --event transition 2>/dev/null
assert_has "stageless transition repaired from system.md" '"to_stage":"verify"' "$(tail -1 "$FUN2" 2>/dev/null)"

# F5 …and DROPPED when there is no record to repair from, rather than written stageless
BEFORE="$(wc -l <"$FUN2" | tr -d ' ')"
BOOTS_HOME="$H2" "$BIN/boots-event" --system "no-record-sys" --event transition 2>/dev/null
assert_eq "stageless transition with no record is dropped" "$BEFORE" "$(wc -l <"$FUN2" | tr -d ' ')"

# F6 the slug indexes a path — it must never walk out of the systems dir
BOOTS_HOME="$H2" "$BIN/boots-event" --system "../../../etc/evil" --event created --to clarify 2>/dev/null
assert_eq "traversal slug cannot escape the systems dir" "" "$(find "$H2/.." -maxdepth 2 -name 'evil*' 2>/dev/null)"

# F7 duration: an idle session left open overnight must not be logged as a run time
H3="$WORK/dur"; mkdir -p "$H3"; printf 'telemetry: community\n' >"$H3/config.yaml"
BOOTS_SUPABASE_URL="http://127.0.0.1:9" BOOTS_HOME="$H3" "$BIN/boots-telemetry-log" \
  --skill boots-scope --duration 62374 --outcome success --session-id "dur-1" 2>/dev/null
BOOTS_SUPABASE_URL="http://127.0.0.1:9" BOOTS_HOME="$H3" "$BIN/boots-telemetry-log" \
  --skill boots-scope --duration 300 --outcome success --session-id "dur-2" 2>/dev/null
DURS="$(grep -o '"duration_s":[^,]*' "$H3/analytics/runs.jsonl" 2>/dev/null | tr '\n' ' ')"
assert_eq "17h idle session logged as unknown, 5m run kept" \
  '"duration_s":null "duration_s":300' "$(printf '%s' "$DURS" | sed 's/ $//')"

# F8 session ids carry entropy — a container and a laptop must not mint the same id
# and finalize each other's pending markers as crashes.
assert_has "session id has a random component" 'RANDOM' \
  "$(grep -m1 '_SESSION_ID=' "$REPO/boots/SKILL.md" 2>/dev/null)"

# F9 BOTH layers report the same host. The funnel knowing it's Cowork while the run
# log says claude-code is worse than neither knowing — it makes the two streams
# un-joinable and quietly wrong.
H4="$WORK/layers"; mkdir -p "$H4"; printf 'telemetry: community\n' >"$H4/config.yaml"
BOOTS_PLATFORM="cowork" BOOTS_HOME="$H4" "$BIN/boots-event" \
  --system "two-layer" --event created --to clarify 2>/dev/null
BOOTS_PLATFORM="cowork" BOOTS_SUPABASE_URL="http://127.0.0.1:9" BOOTS_HOME="$H4" \
  "$BIN/boots-telemetry-log" --skill boots-clarify --duration 12 --outcome success --session-id "L-1" 2>/dev/null
assert_has "funnel layer records the host" '"platform":"cowork"' "$(tail -1 "$H4/analytics/funnel.jsonl" 2>/dev/null)"
assert_has "run layer records the same host" '"platform":"cowork"' "$(tail -1 "$H4/analytics/runs.jsonl" 2>/dev/null)"

# F10 a crash is attributed to the host it CRASHED on, not the host that noticed.
# A laptop finalizing a dead container's marker must not claim the crash as its own.
printf '{"skill":"boots-build","ts":"2026-01-01T00:00:00Z","session_id":"ghost-1","platform":"cowork"}\n' \
  >"$H4/analytics/.pending-ghost-1"
BOOTS_PLATFORM="claude-code" BOOTS_SUPABASE_URL="http://127.0.0.1:9" BOOTS_HOME="$H4" \
  "$BIN/boots-telemetry-log" --skill boots-scope --outcome success --session-id "L-2" 2>/dev/null
GHOST="$(grep 'ghost-1' "$H4/analytics/runs.jsonl" 2>/dev/null | tail -1)"
assert_has "crashed session keeps its own platform" '"platform":"cowork"' "$GHOST"
assert_has "…and is still recorded as unknown"      '"outcome":"unknown"' "$GHOST"

# F11 a marker from before platform existed must say unknown, not guess the finalizer's
printf '{"skill":"boots-build","ts":"2026-01-01T00:00:00Z","session_id":"old-1"}\n' \
  >"$H4/analytics/.pending-old-1"
BOOTS_PLATFORM="claude-code" BOOTS_SUPABASE_URL="http://127.0.0.1:9" BOOTS_HOME="$H4" \
  "$BIN/boots-telemetry-log" --skill boots-scope --outcome success --session-id "L-3" 2>/dev/null
assert_has "pre-platform marker records unknown, not a guess" '"platform":"unknown"' \
  "$(grep 'old-1' "$H4/analytics/runs.jsonl" 2>/dev/null | tail -1)"

# ─────────────────────────────────────────────────────────────────────────────
sect "cross-system layer — map + question (offline)"
# The cross-system skills (boots-rethink, and the map reads in boots/clarify/scope/ship)
# are PROSE — whether they reason well can only be judged by running them. What IS
# mechanically checkable are the invariants they depend on, and those are exactly the
# ones that break silently: a path that stops resolving, or a private file that stops
# being ignored. Both fail in ways no one would notice until harm was done.

# X1 the map path resolves per host. Regression guard for adding a host and forgetting
# the path seam — the map would then be written somewhere the skills never read.
MAPC="$(grep -c '~/\.boots/map\.md' "$REPO/boots-rethink/SKILL.md" 2>/dev/null || echo 0)"
[ "$MAPC" -ge 2 ] && ok "map path resolved in boots-rethink (claude host)" \
                  || bad "map path resolved in boots-rethink (claude host)" "found $MAPC refs to ~/.boots/map.md"

# X2 no unresolved template tokens anywhere in the generated skills. A typo'd token
# name renders literally and the instruction silently becomes nonsense.
UNRES="$(grep -l '{{' "$REPO"/boots*/SKILL.md 2>/dev/null | head -3)"
assert_eq "no unresolved {{TOKENS}} in generated skills" "" "$UNRES"

# X3 PRIVACY: map.md must be gitignored. A normal install now clones to
# ~/.claude/skills/.boots and keeps runtime state in ~/.boots, so the two are no
# longer the same directory — but a dev clone AT ~/.boots still puts a user's
# record of what they're building at the repo root. If this ever stops being
# ignored, a `git add -A` publishes it.
IGN="$(cd "$REPO" && git check-ignore map.md 2>/dev/null)"
assert_eq "map.md is gitignored (privacy)" "map.md" "$IGN"

# X4 every skill dir on disk is either a product skill (on the .gitignore allow-list)
# or deliberately private. Catches a new product skill added without its `!` line —
# it would be invisible to git and never ship.
ALLOW="$(cd "$REPO" && grep -oE '^!/boots[a-z0-9-]*/' .gitignore | sed 's|^!/||;s|/$||' | sort)"
# Read the index, not HEAD: a skill added without its `!` line should fail here
# the moment it's staged, not one commit after it has already been missed.
TRACKED="$(cd "$REPO" && git ls-files | cut -d/ -f1 | grep -E '^boots' | sort -u)"
assert_eq "gitignore allow-list matches tracked skills" "$ALLOW" "$TRACKED"

# X5 boots-rethink specifically is on the allow-list and tracked (the newest skill is
# the one most likely to be missed).
case "$ALLOW" in *boots-rethink*) ok "boots-rethink is on the allow-list" ;; *) bad "boots-rethink is on the allow-list" ;; esac

# ─────────────────────────────────────────────────────────────────────────────
if [ "$LIVE" -eq 1 ]; then
  sect "LIVE — update check against GitHub origin"
  if ! command -v gh >/dev/null 2>&1; then
    printf '  %sSKIP%s gh CLI not found — upgrade-detection needs it for the VERSION fetch\n' "$Y" "$Z"
  else
    ORIGIN="$(git -C "$REPO" remote get-url origin 2>/dev/null || echo)"
    if [ -z "$ORIGIN" ]; then
      printf '  %sSKIP%s no origin remote on this clone\n' "$Y" "$Z"
    else
      REMOTEVER="$(git -C "$REPO" show origin/main:VERSION 2>/dev/null | tr -d '[:space:]')"
      # L1 outdated install → UPGRADE_AVAILABLE
      D="$WORK/l1"; S="$WORK/l1s"; mkdir -p "$D" "$S"; printf '0.0.0.1\n' >"$D/VERSION"
      git -C "$D" init -q 2>/dev/null; git -C "$D" remote add origin "$ORIGIN" 2>/dev/null
      OUT="$(BOOTS_DIR="$D" BOOTS_STATE_DIR="$S" BOOTS_HOME="$S" "$BIN/boots-update-check")"
      assert_has "outdated install → UPGRADE_AVAILABLE" "UPGRADE_AVAILABLE 0.0.0.1" "$OUT"
      [ -n "$REMOTEVER" ] && assert_has "reports the real remote version" "$REMOTEVER" "$OUT"
      # L2 dev running ahead → semver guard → silent
      D="$WORK/l2"; S="$WORK/l2s"; mkdir -p "$D" "$S"; printf '99.0.0.0\n' >"$D/VERSION"
      git -C "$D" init -q 2>/dev/null; git -C "$D" remote add origin "$ORIGIN" 2>/dev/null
      assert_eq "dev ahead of remote → silent" "" "$(BOOTS_DIR="$D" BOOTS_STATE_DIR="$S" BOOTS_HOME="$S" "$BIN/boots-update-check")"
    fi
  fi

  sect "LIVE — telemetry ingest + community-pulse round-trip"
  # Public anon key from committed config (RLS blocks all reads with it).
  . "$REPO/supabase/config.sh"
  URL="${BOOTS_SUPABASE_URL:-}"; KEY="${BOOTS_SUPABASE_ANON_KEY:-}"
  if [ -z "$URL" ] || [ -z "$KEY" ]; then
    printf '  %sSKIP%s supabase/config.sh has no URL/key — backend not provisioned\n' "$Y" "$Z"
  else
    IID="e2e-selftest-$(date +%s)"
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    RESP="$(curl -s -w '\n%{http_code}' --max-time 15 -X POST "$URL/functions/v1/telemetry-ingest" \
      -H "Content-Type: application/json" -H "apikey: $KEY" \
      -d "[{\"v\":1,\"ts\":\"$ts\",\"event\":\"created\",\"system\":\"e2e-hash\",\"to_stage\":\"clarify\",\"outcome\":\"advanced\",\"platform\":\"claude-code\",\"installation_id\":\"$IID\"},{\"v\":1,\"ts\":\"$ts\",\"event\":\"skill_run\",\"skill\":\"e2e-probe\",\"outcome\":\"success\",\"installation_id\":\"$IID\"}]" 2>/dev/null)"
    CODE="$(printf '%s' "$RESP" | tail -1)"; JSON="$(printf '%s' "$RESP" | sed '$d')"
    assert_eq "ingest → HTTP 200" "200" "$CODE"
    assert_has "ingest → inserted count" '"inserted":2' "$JSON"

    # anon must NOT be able to read any table back
    READ="$(curl -s --max-time 15 "$URL/rest/v1/funnel_events?select=system&limit=1" -H "apikey: $KEY" -H "Authorization: Bearer $KEY" 2>/dev/null)"
    assert_eq "anon cannot read rows (RLS) → []" "[]" "$READ"

    PULSE="$(curl -s --max-time 15 "$URL/functions/v1/community-pulse" -H "apikey: $KEY" 2>/dev/null)"
    assert_has "pulse → status ok"        '"status":"ok"'     "$PULSE"
    assert_has "pulse → has weekly_active" '"weekly_active"'  "$PULSE"
    assert_has "pulse → has pipeline"      '"pipeline"'       "$PULSE"

    # Self-clean the test rows IF a service key is provided (never committed).
    if [ -n "${BOOTS_SUPABASE_SERVICE_KEY:-}" ]; then
      for T in funnel_events run_events installations; do
        curl -s --max-time 15 -X DELETE "$URL/rest/v1/$T?installation_id=eq.$IID" \
          -H "apikey: $BOOTS_SUPABASE_SERVICE_KEY" -H "Authorization: Bearer $BOOTS_SUPABASE_SERVICE_KEY" >/dev/null 2>&1
      done
      ok "live test rows cleaned up (service key present)"
    else
      printf '  %sNOTE%s left 2 tagged rows in prod (installation_id=%s); export BOOTS_SUPABASE_SERVICE_KEY to auto-clean\n' "$Y" "$Z" "$IID"
    fi
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
printf '\n%s────────────────────────%s\n' "$B" "$Z"
printf '%s%d passed%s, %s%d failed%s' "$G" "$PASS" "$Z" "$([ "$FAIL" -gt 0 ] && echo "$R")" "$FAIL" "$Z"
[ "$LIVE" -eq 0 ] && printf '   %s(offline suite; run with --live for network checks)%s' "$Y" "$Z"
printf '\n'
[ "$FAIL" -eq 0 ]
