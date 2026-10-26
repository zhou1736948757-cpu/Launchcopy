#!/usr/bin/env bash
# Phase 1J — safe local .app assembly for Launchcopy (release-candidate packaging)
# Does NOT sign, notarize, install login items, kill processes, or delete old candidates.
#
# Default: build into a unique staging directory under .build/candidates/.
# Set LEGACY_DESTRUCTIVE=1 only when you explicitly want the Phase 1H kill/rm behavior
# (not used by RC validation).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_NAME="${PRODUCT_NAME:-Launchcopy}"
BUNDLE_ID="${BUNDLE_ID:-com.launchcopy.app}"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
CONFIGURATION="${CONFIGURATION:-release}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-PagingPrototypeApp}"
CANDIDATE_ID="${CANDIDATE_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
CANDIDATES_PARENT="${CANDIDATES_PARENT:-$ROOT/.build/candidates}"
LEGACY_DESTRUCTIVE="${LEGACY_DESTRUCTIVE:-0}"
NATIVE_UI_TEST_PROFILE="${NATIVE_UI_TEST_PROFILE:-}"
NATIVE_UI_TEST_FIXTURE="${NATIVE_UI_TEST_FIXTURE:-}"
GESTURE_VALIDATION_PROFILE="${GESTURE_VALIDATION_PROFILE:-}"
INTEGRATED_PREVIEW_PROFILE="${INTEGRATED_PREVIEW_PROFILE:-}"
NATIVE_UI_TEST_ENTRY_MODE="absent"
GESTURE_VALIDATION_ENTRY_MODE="absent"
INTEGRATED_PREVIEW_ENTRY_MODE="absent"
PROFILE_ISOLATED="false"

# Optional explicit destination (must not already exist unless LEGACY_DESTRUCTIVE=1).
# Default unique path: .build/candidates/<id>/Launchcopy.app
if [[ -n "${OUT_APP:-}" ]]; then
  APP_DIR="$OUT_APP"
else
  STAGE_DIR="${STAGE_DIR:-$CANDIDATES_PARENT/$CANDIDATE_ID}"
  APP_DIR="$STAGE_DIR/${PRODUCT_NAME}.app"
fi

die() { echo "paging-package: ERROR: $*" >&2; exit 1; }
log() { echo "paging-package: $*"; }

# --- validate identifiers (reject path traversal / unsafe XML) ---
[[ "$PRODUCT_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || die "unsafe PRODUCT_NAME"
[[ "$BUNDLE_ID" =~ ^[A-Za-z0-9.-]+$ ]] || die "unsafe BUNDLE_ID"
[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,3}$ ]] || die "unsafe VERSION"
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || die "unsafe BUILD_NUMBER"
[[ "$EXECUTABLE_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || die "unsafe EXECUTABLE_NAME"

# All three entries are opt-in and must fail before Swift or artifact writes.
# Ordinary native UI tests remain fake-only. Gesture validation and integrated
# preview each require their own dedicated identity and explicit profile.
if [[ -n "$INTEGRATED_PREVIEW_PROFILE" && ( -n "$NATIVE_UI_TEST_PROFILE" || -n "$NATIVE_UI_TEST_FIXTURE" || -n "$GESTURE_VALIDATION_PROFILE" ) ]]; then
  die "integrated preview and native test profiles/fixtures or gesture validation are mutually exclusive"
fi
if [[ -n "$GESTURE_VALIDATION_PROFILE" && ( -n "$NATIVE_UI_TEST_PROFILE" || -n "$NATIVE_UI_TEST_FIXTURE" ) ]]; then
  die "gesture validation and native test profiles/fixtures are mutually exclusive"
fi
if [[ -n "$NATIVE_UI_TEST_FIXTURE" ]]; then
  [[ "$NATIVE_UI_TEST_FIXTURE" == "sources-v1" ]] || die "invalid native test fixture"
  [[ -n "$NATIVE_UI_TEST_PROFILE" ]] || die "native test fixture requires explicit native test profile"
fi
if [[ -n "$NATIVE_UI_TEST_PROFILE" ]]; then
  [[ "$NATIVE_UI_TEST_PROFILE" =~ ^[a-z0-9][a-z0-9-]{0,47}$ ]] || die "invalid native test profile"
  [[ "$BUNDLE_ID" == "com.launchcopy.ui-test" ]] || die "native test entry requires reserved bundle ID"
  [[ "$LEGACY_DESTRUCTIVE" == "0" ]] || die "native test entry requires non-destructive packaging"
  python3 -B - "$ROOT/Scripts/verify-native-ui-test-entry.py" "$APP_DIR" "$NATIVE_UI_TEST_PROFILE" "$NATIVE_UI_TEST_FIXTURE" <<'PY' || die "native test destination rejected"
import importlib.util
import sys

try:
    spec = importlib.util.spec_from_file_location("native_entry_metadata", sys.argv[1])
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    checker.validate_native_destination(sys.argv[2], sys.argv[3], sys.argv[4])
except Exception:
    sys.exit(1)
PY
  NATIVE_UI_TEST_ENTRY_MODE="marker-v1"
  if [[ "$NATIVE_UI_TEST_FIXTURE" == "sources-v1" ]]; then
    NATIVE_UI_TEST_ENTRY_MODE="marker-v2-sources-v1"
  fi
  PROFILE_ISOLATED="true"
elif [[ "$BUNDLE_ID" == "com.launchcopy.ui-test" ]]; then
  die "reserved bundle ID requires explicit native test profile"
fi

if [[ -n "$GESTURE_VALIDATION_PROFILE" ]]; then
  [[ "$GESTURE_VALIDATION_PROFILE" =~ ^[a-z0-9][a-z0-9-]{0,47}$ ]] || die "invalid gesture validation profile"
  [[ "$BUNDLE_ID" == "com.launchcopy.gesture-validation" ]] || die "gesture validation entry requires reserved bundle ID"
  [[ "$LEGACY_DESTRUCTIVE" == "0" ]] || die "gesture validation entry requires non-destructive packaging"
  python3 -B - "$ROOT/Scripts/verify-gesture-validation-entry.py" "$APP_DIR" "$GESTURE_VALIDATION_PROFILE" <<'PY' || die "gesture validation destination rejected"
import importlib.util
import sys

try:
    spec = importlib.util.spec_from_file_location("gesture_entry_metadata", sys.argv[1])
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    checker.validate_gesture_destination(sys.argv[2], sys.argv[3])
except Exception:
    sys.exit(1)
PY
  GESTURE_VALIDATION_ENTRY_MODE="marker-v1"
  PROFILE_ISOLATED="true"
elif [[ "$BUNDLE_ID" == "com.launchcopy.gesture-validation" ]]; then
  die "reserved bundle ID requires explicit gesture validation profile"
fi

if [[ -n "$INTEGRATED_PREVIEW_PROFILE" ]]; then
  [[ "$INTEGRATED_PREVIEW_PROFILE" =~ ^[a-z0-9][a-z0-9-]{0,47}$ ]] || die "invalid integrated preview profile"
  [[ "$BUNDLE_ID" == "com.launchcopy.integrated-preview" ]] || die "integrated preview entry requires reserved bundle ID"
  [[ "$LEGACY_DESTRUCTIVE" == "0" ]] || die "integrated preview entry requires non-destructive packaging"
  python3 -B - "$ROOT/Scripts/verify-integrated-preview-entry.py" "$APP_DIR" "$INTEGRATED_PREVIEW_PROFILE" <<'PY' || die "integrated preview destination rejected"
import importlib.util
import sys

try:
    spec = importlib.util.spec_from_file_location("integrated_preview_entry_metadata", sys.argv[1])
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    checker.validate_integrated_destination(sys.argv[2], sys.argv[3])
except Exception:
    sys.exit(1)
PY
  INTEGRATED_PREVIEW_ENTRY_MODE="marker-v1"
  PROFILE_ISOLATED="true"
elif [[ "$BUNDLE_ID" == "com.launchcopy.integrated-preview" ]]; then
  die "reserved bundle ID requires explicit integrated preview profile"
fi

# Destination must stay under candidates parent (or explicit OUT_APP under ROOT/.build).
APP_PARENT="$(dirname "$APP_DIR")"
ROOT_ABS="$(cd "$ROOT" && pwd -P)"
# Validate canonical project containment BEFORE mkdir, including symlink ancestors.
APP_PARENT_ABS="$(python3 -B - "$ROOT_ABS" "$APP_PARENT" <<'PY_BOUNDARY'
from pathlib import Path
import sys
try:
    root = Path(sys.argv[1]).resolve(strict=True)
    parent = Path(sys.argv[2]).resolve(strict=False)
    relative = parent.relative_to(root / ".build")
    if not relative.parts:
        raise ValueError()
except Exception:
    sys.exit(1)
print(parent)
PY_BOUNDARY
)" || die "destination outside canonical project build boundary"
mkdir -p "$APP_PARENT_ABS"
# Use the validated physical parent for every subsequent artifact write.
APP_PARENT="$APP_PARENT_ABS"
APP_DIR="$APP_PARENT_ABS/$(basename "$APP_DIR")"
PLIST="$APP_DIR/Contents/Info.plist"

if [[ -e "$APP_DIR" ]]; then
  if [[ "$LEGACY_DESTRUCTIVE" == "1" ]]; then
    log "LEGACY_DESTRUCTIVE=1: removing existing $APP_DIR"
    # Optional process stop only in legacy mode.
    log "LEGACY_DESTRUCTIVE=1: stopping Launchcopy by exact name (pkill -x)…"
    pkill -x Launchcopy 2>/dev/null || true
    sleep 0.2
    rm -rf "$APP_DIR"
  else
    die "destination already exists: $APP_DIR (refuse to overwrite; choose a new CANDIDATE_ID/OUT_APP)"
  fi
fi

cd "$ROOT"

log "building SwiftPM executable ($CONFIGURATION)…"
if [[ "$CONFIGURATION" == "release" ]]; then
  swift build -c release --product "$EXECUTABLE_NAME"
  BUILD_OUT="$(swift build -c release --show-bin-path)"
else
  swift build --product "$EXECUTABLE_NAME"
  BUILD_OUT="$(swift build --show-bin-path)"
fi
# Pure Foundation developer probe shares the exact typed resource schema.
# It is not shipped in the app and does not execute the application.
swift build -c "$CONFIGURATION" --product LocalizationResourceProbe
RESOURCE_PROBE="$BUILD_OUT/LocalizationResourceProbe"
[[ -x "$RESOURCE_PROBE" ]] || die "expected localization resource probe missing"
BIN="$BUILD_OUT/$EXECUTABLE_NAME"
[[ -x "$BIN" ]] || die "expected binary missing after build: $BIN (no broad find fallback)"

log "assembling $APP_DIR from $BIN"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN" "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"

# Known SwiftPM localization bundle; absence is a packaging failure, not a
# reason to rely on the generated accessor's development-path fallback.
RESOURCE_BUNDLE_NAME="PagingPrototype_LauncherLocalization.bundle"
RESOURCE_BUNDLE="$BUILD_OUT/$RESOURCE_BUNDLE_NAME"
[[ -d "$RESOURCE_BUNDLE" ]] || die "expected localization bundle missing: $RESOURCE_BUNDLE"
cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/$RESOURCE_BUNDLE_NAME"
for LANGUAGE in en zh-hans ja; do
  [[ -f "$APP_DIR/Contents/Resources/$RESOURCE_BUNDLE_NAME/$LANGUAGE.lproj/Localizable.strings" ]] || die "missing packaged localization: $LANGUAGE"
done

# Info.plist via plutil (no unchecked XML interpolation of free-form strings beyond validated IDs)
PLIST="$APP_DIR/Contents/Info.plist"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleLocalizations</key>
  <array><string>en</string><string>zh-Hans</string><string>ja</string></array>
  <key>CFBundleExecutable</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
</dict>
</plist>
EOF

plutil -lint "$PLIST" >/dev/null || die "Info.plist failed plutil -lint"

if [[ "$PROFILE_ISOLATED" == "true" ]]; then
  if [[ -n "$GESTURE_VALIDATION_PROFILE" ]]; then
    plutil -insert LaunchcopyGestureValidationEntry -xml "<dict><key>version</key><integer>1</integer><key>profile</key><string>${GESTURE_VALIDATION_PROFILE}</string></dict>" "$PLIST" || die "gesture validation marker assembly failed"
    python3 -B "$ROOT/Scripts/verify-gesture-validation-entry.py" "$APP_DIR" || die "gesture validation metadata rejected"
  elif [[ -n "$INTEGRATED_PREVIEW_PROFILE" ]]; then
    plutil -insert LaunchcopyIntegratedPreviewEntry -xml "<dict><key>version</key><integer>1</integer><key>profile</key><string>${INTEGRATED_PREVIEW_PROFILE}</string></dict>" "$PLIST" || die "integrated preview marker assembly failed"
    python3 -B "$ROOT/Scripts/verify-integrated-preview-entry.py" "$APP_DIR" || die "integrated preview metadata rejected"
  elif [[ "$NATIVE_UI_TEST_FIXTURE" == "sources-v1" ]]; then
    plutil -insert LaunchcopyUITestEntry -xml "<dict><key>version</key><integer>2</integer><key>profile</key><string>${NATIVE_UI_TEST_PROFILE}</string><key>fixture</key><string>sources-v1</string></dict>" "$PLIST" || die "native test marker assembly failed"
  else
    plutil -insert LaunchcopyUITestEntry -xml "<dict><key>version</key><integer>1</integer><key>profile</key><string>${NATIVE_UI_TEST_PROFILE}</string></dict>" "$PLIST" || die "native test marker assembly failed"
  fi
  if [[ -n "$NATIVE_UI_TEST_PROFILE" ]]; then
    python3 -B "$ROOT/Scripts/verify-native-ui-test-entry.py" "$APP_DIR" || die "native test metadata rejected"
  fi
fi

"$RESOURCE_PROBE" "$APP_DIR" || die "packaged localization resource schema smoke failed"

if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

# Translation resources are part of candidate identity, not covered by exe hash.
RESOURCE_MANIFEST="$APP_PARENT/LOCALIZATION_RESOURCES.sha256"
(
  cd "$APP_DIR"
  find "Contents/Resources/$RESOURCE_BUNDLE_NAME" -type f -print | LC_ALL=C sort |
    while IFS= read -r RESOURCE_FILE; do shasum -a 256 "$RESOURCE_FILE"; done
) > "$RESOURCE_MANIFEST"

# Identity sidecar (not included in its own hash input beyond listing)
MANIFEST="$APP_PARENT/CANDIDATE_MANIFEST.txt"
{
  echo "product=$PRODUCT_NAME"
  echo "bundle_id=$BUNDLE_ID"
  echo "version=$VERSION"
  echo "build=$BUILD_NUMBER"
  echo "configuration=$CONFIGURATION"
  echo "native_ui_test_entry_mode=$NATIVE_UI_TEST_ENTRY_MODE"
  echo "gesture_validation_entry_mode=$GESTURE_VALIDATION_ENTRY_MODE"
  echo "integrated_preview_entry_mode=$INTEGRATED_PREVIEW_ENTRY_MODE"
  echo "profile_isolated=$PROFILE_ISOLATED"
  echo "info_plist_sha256=$(shasum -a 256 "$PLIST" | awk '{print $1}')"
  echo "candidate_id=$CANDIDATE_ID"
  echo "app_path=$APP_DIR"
  echo "source_bin=$BIN"
  echo "localization_bundle=$RESOURCE_BUNDLE_NAME"
  echo "localization_manifest_sha256=$(shasum -a 256 "$RESOURCE_MANIFEST" | awk '{print $1}')"
  echo "built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if command -v git >/dev/null; then
    echo "git_head=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
    echo "git_dirty=$(git -C "$ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  fi
  if command -v shasum >/dev/null; then
    echo "exe_sha256=$(shasum -a 256 "$APP_DIR/Contents/MacOS/$PRODUCT_NAME" | awk '{print $1}')"
  fi
  echo "files:"
  (cd "$APP_DIR" && find . -type f -print | LC_ALL=C sort)
} > "$MANIFEST"

log "assembled $APP_DIR"
log "manifest $MANIFEST"
log "NOTE unsigned; not notarized; private MultitouchSupport may affect distribution"
if command -v shasum >/dev/null; then
  shasum -a 256 "$APP_DIR/Contents/MacOS/$PRODUCT_NAME" | awk '{print "paging-package: exe-sha256="$1}'
fi
