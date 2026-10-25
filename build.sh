#!/bin/zsh
# Builds Pervitin.app and Pervitin.dmg into ./build. Needs Xcode (for swiftc
# and the macOS SDK); no Xcode project, no dependencies.
set -euo pipefail
cd "${0:A:h}"

APP=build/Pervitin.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Both architectures, optimised for size. The prefix map keeps this folder's
# path (and so your username) out of the binary.
for arch in arm64 x86_64; do
  xcrun swiftc Sources/*.swift \
    -target $arch-apple-macos13.0 -swift-version 5 \
    -module-name Pervitin -Osize -wmo -parse-as-library \
    -file-prefix-map "$PWD=." \
    -Xlinker -dead_strip -Xlinker -dead_strip_dylibs \
    -o build/Pervitin-$arch
done
xcrun lipo -create build/Pervitin-arm64 build/Pervitin-x86_64 -output "$APP/Contents/MacOS/Pervitin"
rm build/Pervitin-arm64 build/Pervitin-x86_64
xcrun strip "$APP/Contents/MacOS/Pervitin"

cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature, sandboxed, hardened runtime. No developer identity.
codesign --force --sign - --options runtime \
  --entitlements Resources/Pervitin.entitlements "$APP"

echo "Built $(du -sh "$APP" | cut -f1)  $APP"
zsh make-dmg.sh "$APP" build/Pervitin.dmg
