# 1UP

macOS menu bar app (Swift 6, macOS 14+) that shows Claude Code session states. docs/SPEC.md is the source of truth (docs/SPEC.html is the same spec with the live preview and reference scene code); behaviour changes update the spec in the same PR.

## Commands
- Build everything: `swift build` · Test: `swift test` · Format: `swift-format -i -r Sources Tests` (if installed)
- Build and open the app bundle: `tools/make-app.sh` (writes `build/1UP.app`) then `open build/1UP.app`
- Run the core without UI: `swift run oneup-dump`
- Re-render the theme folders from the spec's scene code: `node tools/render-themes.mjs`
- Capture fixtures from this Mac: `tools/capture-fixtures.sh`
- Generate an Xcode project (optional, needs XcodeGen): `xcodegen`

## Rules
- All state logic lives in OneUpCore (pure, synchronous, no AppKit). The app target only watches, draws and clicks.
- Never guess a state. Unknown shapes become "?" plus a log line.
- Every reducer rule and every VERIFIED test-matrix row has a fixture test with a matching name (SPIKE rows join once they pass).
- Inside ~/.claude, read only `sessions/*.json` and the tail of each session's top-level transcript. Never open .key files or sockets, never write inside ~/.claude.
- No network except the Sparkle update check.
- Themes are folders in Resources/Themes with no code. Layout, tints and counts belong to StatusItem.
- v1 asks for no macOS permissions. Anything that would need one is out of scope.
- Comments explain why, not what. No commented-out code.
- One PR per milestone, with screenshots for UI changes.
