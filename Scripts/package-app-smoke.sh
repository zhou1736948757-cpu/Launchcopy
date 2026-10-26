#!/usr/bin/env bash
# Phase 1J — non-destructive packaging fixture checks (no process kill, no overwrite).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/Scripts/package-app.sh"
TMP="$ROOT/.build/package-smoke-$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

fail=0
assert() {
  if "$@"; then
    echo "OK: $*"
  else
    echo "FAIL: $*" >&2
    fail=1
  fi
}

# 1) Refuse unsafe product name
if CANDIDATES_PARENT="$TMP/c1" PRODUCT_NAME='bad/name' bash "$SCRIPT" 2>"$TMP/err1"; then
  echo "FAIL: unsafe PRODUCT_NAME should die" >&2; fail=1
else
  grep -q 'unsafe PRODUCT_NAME' "$TMP/err1" && echo "OK: rejects unsafe PRODUCT_NAME" || { echo "FAIL: message"; fail=1; }
fi

# 2) Successful unique candidate (debug for speed)
CANDIDATE_ID="smoke1" CANDIDATES_PARENT="$TMP/c2" CONFIGURATION=debug \
  bash "$SCRIPT" | tee "$TMP/out2"
APP="$TMP/c2/smoke1/Launchcopy.app"
assert test -x "$APP/Contents/MacOS/Launchcopy"
assert plutil -lint "$APP/Contents/Info.plist"
assert test -f "$TMP/c2/smoke1/CANDIDATE_MANIFEST.txt"
assert test -f "$TMP/c2/smoke1/LOCALIZATION_RESOURCES.sha256"
for LANGUAGE in en zh-hans ja; do
  assert test -f "$APP/Contents/Resources/PagingPrototype_LauncherLocalization.bundle/$LANGUAGE.lproj/Localizable.strings"
done
assert bash -c 'cd "$1" && shasum -a 256 -c "$2"' _ "$APP" "$TMP/c2/smoke1/LOCALIZATION_RESOURCES.sha256"

# 3) Refuse overwrite of existing destination
if CANDIDATE_ID="smoke1" CANDIDATES_PARENT="$TMP/c2" CONFIGURATION=debug bash "$SCRIPT" 2>"$TMP/err3"; then
  echo "FAIL: overwrite should be refused" >&2; fail=1
else
  grep -q 'already exists' "$TMP/err3" && echo "OK: refuses overwrite" || { echo "FAIL: overwrite message"; fail=1; }
fi

# 4) Confirm no pkill in default path (script text gate)
if grep -n 'pkill' "$SCRIPT" | grep -v LEGACY >/dev/null && ! grep -q 'LEGACY_DESTRUCTIVE' "$SCRIPT"; then
  echo "FAIL: pkill without legacy gate" >&2; fail=1
else
  echo "OK: pkill gated behind LEGACY_DESTRUCTIVE"
fi

exit "$fail"
