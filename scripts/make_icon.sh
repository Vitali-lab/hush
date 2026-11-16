#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

WORK="$(mktemp -d "${TMPDIR:-/tmp}/sotto-icon.XXXXXX")"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

swift scripts/make_icon.swift "$WORK/icon-1024.png" >/dev/null

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

sips -z 1024 1024 "$WORK/icon-1024.png" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o scripts/AppIcon.icns
rm -rf "$WORK"
echo "Wrote scripts/AppIcon.icns"
