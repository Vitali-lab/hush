#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
APP="dist/Hush.app"

echo "Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/Hush"
if [[ ! -f "$BIN_PATH" ]]; then
  echo "Binary not found at $BIN_PATH" >&2
  exit 1
fi

if [[ ! -f scripts/AppIcon.icns ]]; then
  ./scripts/make_icon.sh
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/Hush"
cp scripts/Info.plist "$APP/Contents/Info.plist"
cp scripts/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

for lproj in scripts/Resources/*.lproj(N); do
  cp -R "$lproj" "$APP/Contents/Resources/"
done

# SwiftPM's generated Bundle.module looks for dependency resource bundles at
# the .app root, where codesign refuses to seal them. Hush does not touch those
# resources at runtime (WhisperKit downloads its tokenizer), so they are left out.
# If a dependency starts requiring them, vendor the bundle inside Contents/Resources
# and patch the accessor instead of dropping files into the bundle root.

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  IDENTITY="$CODESIGN_IDENTITY"
else
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Apple Development/ {print $2; exit}')"
  IDENTITY="${IDENTITY:--}"
fi

echo "Signing as: $IDENTITY"
codesign --force --deep --options runtime \
  --entitlements scripts/Hush.entitlements \
  --sign "$IDENTITY" "$APP"

echo "Built $APP"
