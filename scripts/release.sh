#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' scripts/Info.plist)"
APP="dist/Hush.app"
DMG="dist/Hush-macOS-arm64.dmg"
ZIP="dist/Hush-macOS-arm64.zip"

echo "Building Hush $VERSION…"
./scripts/build_app.sh

codesign --verify --deep --strict "$APP"
echo "Signature OK"

rm -rf dist/dmg-root
mkdir -p dist/dmg-root
cp -R "$APP" dist/dmg-root/
ln -s /Applications dist/dmg-root/Applications

cat > dist/dmg-root/README.txt <<'EOF'
Hush — on-device dictation for macOS

1. Drag Hush into Applications.
2. Launch it and allow Microphone and Accessibility.
3. Download a speech model on first run.

The app is signed but not notarized. On first launch:
right-click Hush → Open, or run:
xattr -dr com.apple.quarantine /Applications/Hush.app

Requires macOS 14+ on Apple Silicon.
https://github.com/Vitali-lab/hush
EOF

rm -f "$DMG" "$ZIP"
hdiutil create -volname "Hush" -srcfolder dist/dmg-root -ov -format UDZO "$DMG" >/dev/null
ditto -c -k --keepParent "$APP" "$ZIP"

(cd dist && shasum -a 256 Hush-macOS-arm64.dmg Hush-macOS-arm64.zip > SHA256SUMS.txt)

cat > dist/RELEASE_NOTES.md <<EOF
# Hush $VERSION

On-device dictation for macOS. Hold a shortcut, speak, release — your words
appear at the cursor. No account, no cloud, no telemetry.

## Download

- **Installer:** \`Hush-macOS-arm64.dmg\`
- **Zip:** \`Hush-macOS-arm64.zip\`
- **Checksums:** \`SHA256SUMS.txt\`

Requires macOS 14+ on Apple Silicon.

## Install

1. Open the DMG and drag Hush into Applications.
2. Launch Hush and allow Microphone and Accessibility.
3. Download the speech model once (~630 MB). After that everything is offline.

Hush is signed but not notarized yet. On first launch macOS may ask for
confirmation: right-click **Hush → Open**, or run
\`xattr -dr com.apple.quarantine /Applications/Hush.app\`.

## What's new

See [CHANGELOG.md](https://github.com/Vitali-lab/hush/blob/main/CHANGELOG.md).

## Checksums

\`\`\`
$(cat dist/SHA256SUMS.txt)
\`\`\`
EOF

echo
echo "Built:"
ls -lh "$DMG" "$ZIP" dist/SHA256SUMS.txt
echo
echo "Publish with:"
echo "  gh release create v$VERSION \"$DMG\" \"$ZIP\" dist/SHA256SUMS.txt \\"
echo "    --title \"Hush $VERSION\" --notes-file dist/RELEASE_NOTES.md"
