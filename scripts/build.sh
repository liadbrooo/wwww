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
codesign --force --sign - "dist/LYRO Cut.app"
codesign --verify --deep --strict "dist/LYRO Cut.app"
ditto -c -k --sequesterRsrc --keepParent "dist/LYRO Cut.app" "dist/LYRO-Cut-0.1.0-macOS.zip"
