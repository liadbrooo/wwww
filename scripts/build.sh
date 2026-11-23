#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p "dist/LYRO Cut.app/Contents/MacOS" "dist/LYRO Cut.app/Contents/Resources" .build
sdk="$(xcrun --sdk macosx --show-sdk-path)"
for arch in arm64 x86_64; do
  xcrun swiftc -swift-version 5 -O -parse-as-library -target "$arch-apple-macos14.0" -sdk "$sdk" Sources/*.swift -o ".build/cut-$arch"
done
lipo -create .build/cut-arm64 .build/cut-x86_64 -output "dist/LYRO Cut.app/Contents/MacOS/LYRO Cut"
cp Info.plist "dist/LYRO Cut.app/Contents/Info.plist"
mkdir -p .build/brand/AppIcon.iconset
xcrun swift scripts/Brand.swift .build/brand
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" .build/brand/icon.png --out ".build/brand/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size*2))
  sips -z "$double" "$double" .build/brand/icon.png --out ".build/brand/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns .build/brand/AppIcon.iconset -o "dist/LYRO Cut.app/Contents/Resources/AppIcon.icns"
codesign --force --sign - "dist/LYRO Cut.app"
codesign --verify --deep --strict "dist/LYRO Cut.app"
ditto -c -k --sequesterRsrc --keepParent "dist/LYRO Cut.app" "dist/LYRO-Cut-0.2.0-macOS.zip"

if command -v create-dmg >/dev/null; then
  mkdir -p .build/dmg
  ditto "dist/LYRO Cut.app" ".build/dmg/LYRO Cut.app"
  create-dmg --volname "LYRO Cut" --background .build/brand/background.png --window-pos 200 120 --window-size 660 400 --icon-size 100 --icon "LYRO Cut.app" 180 190 --app-drop-link 480 190 --hide-extension "LYRO Cut.app" --no-internet-enable "dist/LYRO-Cut-0.2.0.dmg" .build/dmg
else
  mkdir -p .build/dmg
  ditto "dist/LYRO Cut.app" ".build/dmg/LYRO Cut.app"
  ln -sf /Applications .build/dmg/Applications
  hdiutil create -volname "LYRO Cut" -srcfolder .build/dmg -format UDZO -ov "dist/LYRO-Cut-0.2.0.dmg"
fi
