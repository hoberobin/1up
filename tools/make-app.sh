#!/bin/zsh
# Builds the release binary with SwiftPM and assembles build/1UP.app (ad-hoc signed).
# Usage: tools/make-app.sh [--debug] [--open]
set -euo pipefail
cd "$(dirname "$0")/.."
config=release
open_after=0
for a in "$@"; do
  case "$a" in
    --debug) config=debug ;;
    --open) open_after=1 ;;
  esac
done
swift build -c "$config" --product oneup-app
bin="$(swift build -c "$config" --show-bin-path)/oneup-app"
app=build/1UP.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/1UP"
cp Sources/OneUp/Support/Info.plist "$app/Contents/Info.plist"
cp -R Resources/Themes "$app/Contents/Resources/Themes"
[ -f build/AppIcon.icns ] && cp build/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
echo -n 'APPL????' > "$app/Contents/PkgInfo"
codesign --force --sign - --entitlements Sources/OneUp/Support/1UP.entitlements "$app" 2>/dev/null \
  || codesign --force --sign - "$app"
echo "Built $app"
if [ "$open_after" = 1 ]; then
  pkill -x 1UP 2>/dev/null || true
  open "$app"
fi
