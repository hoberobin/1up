#!/bin/zsh
# Builds the release binary with SwiftPM and assembles build/1UP.app (ad-hoc signed), with its icon.
# Usage: tools/make-app.sh [--debug] [--open] [--zip]
#   --zip also writes build/1UP.zip, the file a GitHub Release carries.
set -euo pipefail
cd "$(dirname "$0")/.."
config=release
open_after=0
zip_after=0
for a in "$@"; do
  case "$a" in
    --debug) config=debug ;;
    --open) open_after=1 ;;
    --zip) zip_after=1 ;;
  esac
done
# Release builds are universal so Intel Macs on the team get the same zip.
archs=()
[ "$config" = release ] && archs=(--arch arm64 --arch x86_64)
swift build -c "$config" "${archs[@]}" --product oneup-app
bin="$(swift build -c "$config" "${archs[@]}" --show-bin-path)/oneup-app"
mkdir -p build
rm -rf build/AppIcon.iconset
"$bin" --render-icon build
iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
app=build/1UP.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/1UP"
cp Sources/OneUp/Support/Info.plist "$app/Contents/Info.plist"
cp -R Resources/Themes "$app/Contents/Resources/Themes"
cp build/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
echo -n 'APPL????' > "$app/Contents/PkgInfo"
codesign --force --sign - --entitlements Sources/OneUp/Support/1UP.entitlements "$app" 2>/dev/null \
  || codesign --force --sign - "$app"
echo "Built $app"
if [ "$zip_after" = 1 ]; then
  rm -f build/1UP.zip
  ditto -c -k --keepParent "$app" build/1UP.zip
  echo "Zipped build/1UP.zip"
fi
if [ "$open_after" = 1 ]; then
  pkill -x 1UP 2>/dev/null || true
  open "$app"
fi
