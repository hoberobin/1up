# 1UP

A macOS menu bar app that shows the state of every Claude Code session on your Mac: which ones are
working, which need you, and which finished while you were elsewhere. Five arcade themes, one layout.

`docs/SPEC.md` is the source of truth (`docs/SPEC.html` is the same spec with the live preview).

## Run it

```sh
tools/make-app.sh --open      # builds build/1UP.app with SwiftPM and opens it
```

Or from Xcode: `brew install xcodegen && xcodegen && open 1UP.xcodeproj`.

On first launch 1UP offers to move itself to Applications (so it can open at login) and shows a welcome
card anchored to the menu bar item. Click the item for the panel, right-click for the menu.

## Develop

```sh
swift build                   # core, app binary and oneup-dump
swift test                    # reducer fixtures, engine, themes, captured real files
swift run oneup-dump          # one line per session every second, no UI
node tools/render-themes.mjs  # rebuild Resources/Themes from the spec's scene code
tools/capture-fixtures.sh     # copy scrubbed status files + transcript tails into Tests/.../Fixtures/<version>
.build/debug/oneup-app --render-preview out.png   # every menu bar state, every theme, light and dark
.build/debug/oneup-app --render-panel out.png     # the panel with sample sessions
```

Layout: `Sources/OneUpCore` (pure logic, tested), `Sources/OneUp` (AppKit/SwiftUI shell),
`Sources/oneup-dump`, `Resources/Themes/<id>/` (PNG layers + theme.json, no code), `tools/`.

## What it reads and writes

Reads `~/.claude/sessions/*.json` (never the `.key` files or sockets) and the tail of each session's
top-level transcript for titles and turn-end records. Writes `~/Library/Application Support/1UP/state.json`,
a 7-day change log in `~/Library/Logs/1UP/`, and its preferences. No network, no macOS permissions.

## Not yet in this build

Signing, notarisation, the DMG and Sparkle updates (spec milestone M5) wait on the team Developer ID and
the public/private repo decision. "Check for Updates…" opens the Releases page until then.
