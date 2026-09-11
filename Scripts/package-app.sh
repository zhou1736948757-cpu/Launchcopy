#!/usr/bin/env bash
# Phase 1H — reproducible local .app assembly for Launchcopy
# Does NOT sign, notarize, or install login items.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_NAME="${PRODUCT_NAME:-Launchcopy}"
BUNDLE_ID="${BUNDLE_ID:-com.launchcopy.app}"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
CONFIGURATION="${CONFIGURATION:-release}"
OUT_DIR="${OUT_DIR:-$ROOT/.build/packaged}"
APP_DIR="$OUT_DIR/${PRODUCT_NAME}.app"

cd "$ROOT"

# 先关掉正在跑的 Launchcopy / 旧可执行文件，再删旧包，避免打到半旧二进制或文件占用。
echo "paging-package: stopping old Launchcopy processes…"
pkill -x Launchcopy 2>/dev/null || true
# 精确路径匹配，避免误杀无关进程
ps aux | awk '/Launch_Copy\/PagingPrototype\/\.build\/.*(Launchcopy|PagingPrototypeApp)/ && !/awk/ {print $2}' \
  | while read -r pid; do kill -TERM "$pid" 2>/dev/null || true; done
sleep 0.4
ps aux | awk '/Launch_Copy\/PagingPrototype\/\.build\/.*(Launchcopy|PagingPrototypeApp)/ && !/awk/ {print $2}' \
  | while read -r pid; do kill -KILL "$pid" 2>/dev/null || true; done

if [[ -d "$APP_DIR" ]]; then
  echo "paging-package: removing old bundle $APP_DIR"
  rm -rf "$APP_DIR"
fi
# 兼容误留的旧名包
if [[ -d "$OUT_DIR/PagingPrototypeApp.app" ]]; then
  rm -rf "$OUT_DIR/PagingPrototypeApp.app"
fi

echo "paging-package: building SwiftPM executable ($CONFIGURATION)…"
if [[ "$CONFIGURATION" == "release" ]]; then
  swift build -c release
  BIN="$ROOT/.build/release/PagingPrototypeApp"
else
  swift build
  BIN="$ROOT/.build/debug/PagingPrototypeApp"
fi

if [[ ! -x "$BIN" ]]; then
  # Apple Silicon path layout
  BIN=$(find "$ROOT/.build" -type f -name PagingPrototypeApp -perm -111 | head -1)
fi
test -x "$BIN"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN" "$APP_DIR/Contents/MacOS/Launchcopy"
chmod +x "$APP_DIR/Contents/MacOS/Launchcopy"

# Minimal Info.plist (unsigned local validation)
PLIST="$APP_DIR/Contents/Info.plist"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh-Hans</string>
  <key>CFBundleExecutable</key>
  <string>Launchcopy</string>
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

plutil -lint "$PLIST" >/dev/null

# Optional icon
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# PkgInfo
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

echo "paging-package: assembled $APP_DIR"
echo "paging-package: NOTE unsigned; not notarized; private MultitouchSupport may affect distribution"
if command -v shasum >/dev/null; then
  shasum -a 256 "$APP_DIR/Contents/MacOS/Launchcopy" | awk '{print "paging-package: exe-sha256="$1}'
fi
