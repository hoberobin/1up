# 1UP spec

Converted from the source-of-truth artifact (docs/SPEC.html keeps the live preview and the reference scene code). Where this text and the UI reference table disagree, the table wins.
*Internal tool · source of truth · spec v1.0*

# 1UP

In the arcade, 1UP flashes when it's your turn. This 1UP tells you when a Claude Code session needs you, without leaving what you're doing. While any session works, your arcade scene plays: dots get eaten, invaders march, barrels roll. An orange enemy means a session is waiting on you, and a green prize means a turn ended. Pick from five classic cabinets. macOS 14+Installs in under a minuteWorks with the Claude Code you already runNothing to configureNothing about your sessions leaves your Mac   **Code**FileEditViewTerminal  Thu 8 Oct 3:41 PM

---

*Get going*

## Three steps, nothing to configure

1. **Get 1UP**Download `1UP.dmg` from the repo's Releases page. The link goes here when the first signed build ships.
2. **Open it**Your arcade scene appears in the menu bar. If you opened it from the disk image or Downloads, 1UP offers to move itself to Applications so it can start at login.
3. **Click Got it**That's the whole setup. Sessions you already have open show up straight away, and 1UP asks for no permissions.

You don't sign in, add an API key, restart Claude Code, add hooks, edit settings or open a terminal. 1UP reads the status Claude Code already keeps for every session (version 2.1.261 or later). It finds every session and config folder by itself, however Claude Code was installed, including `npm run work` worktrees.

### Settings: two choices

- Open at login (on)
- Theme: Chomp, Invaders, Kong, Galaxy or Blocks, each shown as a live tile. Also in the menu bar icon's right-click menu.

If something looks wrong, **Check my setup** (in Settings and the "?" panel) checks the few things 1UP depends on and says plainly what's wrong. Updates install with one click. To uninstall, quit 1UP and move it to the Trash.

#### 1UP is watching 6 Claude Code sessions Found 6 sessions Every session read correctly Opens at login. Change it in Settings. Can't see the icon? ⌘-drag it left in the menu bar. The scene plays while sessions work. An orange icon means one needs you, a green one means a turn ended. Click the icon to see which session and where it's running.

---

*States*

## Three that matter, two that stay quiet

Every session is in exactly one state, and each one matches what its terminal shows.  NEEDS YOU*(preview: need)*

Claude has stopped and is waiting for you: a permission prompt, a question, a sandbox or worker request, a proposed goal, or a dialog left open. The theme's Needs-you icon (ghost, crab invader, fireball, bee or T-piece) appears with a count. It's orange when the session just started waiting and red once it has waited 2 minutes. Terminal: "Do you want to proceed?" or a question with options DONE*(preview: done)*

A turn ended and you haven't looked yet. That covers finished, interrupted and errored turns. The check means "look at this", not "it worked". Terminal: answer, "Interrupted" or an error, then an empty prompt WORKING*(preview: work)*

Claude is thinking, writing, or running a command in the foreground. The theme's working scene animates. Terminal: spinner and "esc to interrupt" IDLE*(preview: idle)*

At the prompt with nothing new. That includes sessions you've already looked at and sessions with only a leftover background shell running. Terminal: empty prompt CAN'T TELL*(preview: err)*

1UP can't read status. The menu bar shows "?" instead of counts and the panel says why. It never shows Done in this state. Panel: the reason, Retry and Check my setup…

---

*Panel*

## Every session, by state

Click the menu bar icon to see which session is in which state. 1UP tells you; you switch to the terminal yourself.

- **Order:** Needs you (longest waiting first), Done (oldest first), Working, then Idle, collapsed to one line.
- **Title:** your `/rename` name (from the transcript's `custom-title`, or the status file's `name` when its `nameSource` is "user"), or else the title Claude Code generates for every session, or else the folder name. When two live rows would show the same title, both get #1, #2 in start order.
- **Second line:** the state in plain words, then the folder and the app it runs in. For example "Wants approval · quiz-matrix · VS Code", "Asked a question · history · iTerm2", "Ended · ran 14m · pages-bg · VS Code", "Interrupted · ran 3m · leveler · Terminal".
- **Right column:** how long it has been in that state.
- **Worktrees read cleanly:** `work-pages-bg` shows as `pages-bg`.
- **Done clears** when you click its row, when you send that session a new prompt, or with Mark all looked at. Opening the panel alone clears nothing.

---

*Themes*

## Pick your arcade

Five classic arcade games, one set of rules. Working is always the moving scene with a count. Needs you is always orange, turning red after 2 minutes. Done is always green, and Idle is the same scene, still and in the menu bar's own colour. Every scene is the same width and every icon the same size, so switching themes never moves anything. Pick one in Settings, or right-click the menu bar icon.   *(preview: chomp)*

### Chompafter Pac-Man  *(preview: work3)*Working *(preview: need)*Needs you *(preview: needOld)*2 min+ *(preview: done)*Done *(preview: idle)*Idle

Pac-Man munches a row of dots. Needs you: ghost. Done: check mark.    *(preview: invaders)*

### Invadersafter Space Invaders  *(preview: work3)*Working *(preview: need)*Needs you *(preview: needOld)*2 min+ *(preview: done)*Done *(preview: idle)*Idle

A row of invaders marches while your cannon fires. Needs you: crab invader. Done: laser cannon.    *(preview: kong)*

### Kongafter Donkey Kong  *(preview: work3)*Working *(preview: need)*Needs you *(preview: needOld)*2 min+ *(preview: done)*Done *(preview: idle)*Idle

Kong beats his chest and rolls barrels down the girder. Needs you: fireball. Done: hammer.    *(preview: galaxy)*

### Galaxyafter Galaga  *(preview: work3)*Working *(preview: need)*Needs you *(preview: needOld)*2 min+ *(preview: done)*Done *(preview: idle)*Idle

Your fighter fires at a bee swooping in. Needs you: bee. Done: stage flag.    *(preview: blocks)*

### Blocksafter Tetris  *(preview: work3)*Working *(preview: need)*Needs you *(preview: needOld)*2 min+ *(preview: done)*Done *(preview: idle)*Idle

A T-piece drops into the gap and clears the line. Needs you: T-piece. Done: full block.     For builders and reviewers

---

*Start here*

## Handing this to a developer, or to Claude Code

- **This page is the source of truth.** The first commit copies it into the repo as `docs/SPEC.md`, and the live preview here stays the visual reference. Any change to behaviour updates the spec in the same PR.
- **Core first.** v1 does one thing: it tells you, accurately, which sessions need you, which finished and which are still working. Anything that could misfire (switching tabs, approving, controlling other apps) is out of v1.
- **v1 scope:**

| In v1 | Later, each behind its own test |
|---|---|
| Accurate state for every Claude Code session: Working, Needs you, Done, Idle, "?" | Alerts (needs a permission prompt and grouping rules) |
| Menu bar item and panel: which session, which state, where it runs | Keyboard shortcut, previews of the question or last reply |
| Five themes, loaded from theme folders | Your own themes in a folder, more cabinets |
| Settings (open at login, theme), Check my setup, welcome card | Jumping to the session's tab, VS Code extension |
| Signed DMG with one-click updates | Homebrew, background agents |
| No macOS permissions of any kind | Never: approving from 1UP, controlling other apps |

- **Read in this order:** States → Panel → Themes → Source of truth → Trust rules → UI reference → Build reference → Milestones.
- **Pixel-exact art:** the sprite grids below are the ones this page draws. Paste them into `Themes/*.swift` unchanged.

**Kickoff prompt for Claude Code (paste into a new session in the empty repo)**

```
You're building 1UP, a macOS menu bar app that shows the state of every Claude Code session on this Mac. The spec at docs/SPEC.md is the source of truth. Build exactly what it says, and if something is unclear or seems wrong, ask instead of guessing.

M0 is done by a human. Start at M1 and work milestone by milestone (M1 → M5), one PR per milestone. Where the spec's live preview and its text disagree, the UI reference table wins. Each PR must:
- meet that milestone's "Done when" line,
- add or update tests (OneUpCore is pure and fully tested with the fixtures in Tests/OneUpCoreTests/Fixtures),
- include side-by-side screenshots against the spec's preview for any UI change.

First task in M1: write tools/capture-fixtures.sh and capture real status files and transcript tails from this Mac into Tests/OneUpCoreTests/Fixtures/<version>/. The app target is generated with XcodeGen (project.yml); OneUpCore and oneup-dump are SwiftPM. Read docs/SPEC.md sections "Source of truth", "Trust rules", "UI reference" and "Build reference" first. Then propose the file list and the reducer tests before writing code.
```

**CLAUDE.md for the repo**

```
# 1UP

macOS menu bar app (Swift 6, macOS 14+) that shows Claude Code session states. docs/SPEC.md is the source of truth; behaviour changes update the spec in the same PR.

## Commands
- Generate the app project: `xcodegen` · Build core: `swift build` · Test: `swift test` · Format: `swift-format -i -r Sources Tests`
- Run the core without UI: `swift run oneup-dump`

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
```

**Sprite data, palettes and scene notes. '#' is the tint slot; '.' is transparent.**

```
{
 "sprites": {
  "GHOST": [
   ".....####.....",
   "...########...",
   "..##########..",
   ".##ww####ww##.",
   ".#wwww##wwww#.",
   ".#wwbb##wwbb#.",
   "##wwbb##wwbb##",
   "###ww####ww###",
   "##############",
   "##############",
   "##############",
   "##############",
   "##.###..###.##",
   "#...##..##...#"
  ],
  "CHECK": [
   "..............",
   "..............",
   "............##",
   "...........###",
   "..........###.",
   ".........###..",
   ".##.....###...",
   ".###...###....",
   "..###.###.....",
   "...#####......",
   "....###.......",
   ".....#........",
   "..............",
   ".............."
  ],
  "CRAB": [
   "...#.....#...",
   "....#...#....",
   "...#######...",
   "..##.###.##..",
   ".###########.",
   ".#.#######.#.",
   ".#.#.....#.#.",
   "....##.##...."
  ],
  "CANNON": [
   "......#......",
   ".....###.....",
   ".....###.....",
   ".###########.",
   "#############",
   "#############",
   "#############",
   "#############"
  ],
  "SQUID1": [
   "...##...",
   "..####..",
   ".######.",
   "##.##.##",
   "########",
   "..#..#..",
   ".#.##.#.",
   "#.#..#.#"
  ],
  "SQUID2": [
   "...##...",
   "..####..",
   ".######.",
   "##.##.##",
   "########",
   ".#.##.#.",
   "#......#",
   ".#....#."
  ],
  "GUN": [
   "....#....",
   "...###...",
   ".#######.",
   "#########",
   "#########"
  ],
  "KONG1": [
   "....bbbbbb....",
   "...bbbbbbbb...",
   "..bbffbbffbb..",
   "..bfwkffkwfb..",
   "..bffffffffb..",
   "...bfkkkkfb...",
   ".bbbbffffbbbb.",
   "bbbbbbbbbbbbbb",
   "bbb.bbbbbb.bbb",
   "bbb.bbbbbb.bbb",
   "bb..bbbbbb..bb",
   "....bb..bb....",
   "...bbb..bbb...",
   "..bbbb..bbbb.."
  ],
  "KONG2": [
   "bb..bbbbbb..bb",
   "bbbbbbbbbbbbbb",
   ".bbbffbbffbbb.",
   "..bfwkffkwfb..",
   "..bffffffffb..",
   "...bfkkkkfb...",
   "...bbffffbb...",
   "..bbbbbbbbbb..",
   "..bbbbbbbbbb..",
   "..bbbbbbbbbb..",
   "...bbbbbbbb...",
   "....bb..bb....",
   "...bbb..bbb...",
   "..bbbb..bbbb.."
  ],
  "BARREL1": [
   ".oooo.",
   "oddddo",
   "oooooo",
   "oooooo",
   "oddddo",
   ".oooo."
  ],
  "BARREL2": [
   ".oooo.",
   "oooooo",
   "oddddo",
   "oddddo",
   "oooooo",
   ".oooo."
  ],
  "FIRE": [
   "......#......",
   ".....##..#...",
   "..#..###.##..",
   "..##.######..",
   ".###########.",
   ".##yyyyyyy##.",
   "##ywkyyywky##",
   "##yyyyyyyyy##",
   "##yyyyyyyyy##",
   ".##yyyyyyy##.",
   ".###yyyyy###.",
   "..#########..",
   "....#####...."
  ],
  "HAMMER": [
   ".##########.",
   ".#dd####dd#.",
   ".##########.",
   ".....##.....",
   ".....##.....",
   ".....##.....",
   ".....##.....",
   ".....##.....",
   ".....##.....",
   "....####....",
   "....####...."
  ],
  "FIGHTER": [
   ".r............",
   ".rr...........",
   "..wwww........",
   "..wbbwww......",
   ".wwwwwwwww....",
   "wwwwwwwwwwwww.",
   ".wwwwwwwww....",
   "..wbbwww......",
   "..wwww........",
   ".rr...........",
   ".r............"
  ],
  "BEE": [
   "...#.....#...",
   "....#...#....",
   ".##.yyyyy.##.",
   "###yyyyyyy###",
   "###bbyyybb###",
   ".#.yybbbyy.#.",
   "...yyyyyyy...",
   "..##.yyy.##..",
   ".##...y...##.",
   ".#.........#."
  ],
  "BEESM": [
   ".#.....#.",
   "..#yyy#..",
   "##yyyyy##",
   "##bbybb##",
   ".#yyyyy#.",
   ".#.y.y.#.",
   "#.......#"
  ],
  "FLAG": [
   ".##..........",
   ".####........",
   ".######......",
   ".########....",
   ".##########..",
   ".########....",
   ".######......",
   ".####........",
   ".##..........",
   ".##..........",
   ".##..........",
   ".##..........",
   "####........."
  ],
  "PAC0": [
   "....#####....",
   "..#########..",
   ".###########.",
   ".###########.",
   "#############",
   "#############",
   "#############",
   "#############",
   "#############",
   ".###########.",
   ".###########.",
   "..#########..",
   "....#####...."
  ],
  "PAC1": [
   "....#####....",
   "..#########..",
   ".###########.",
   ".###########.",
   "###########..",
   "#########....",
   "#######......",
   "#########....",
   "###########..",
   ".###########.",
   ".###########.",
   "..#########..",
   "....#####...."
  ],
  "PAC2": [
   "....#####....",
   "..#########..",
   ".##########..",
   ".########....",
   "#######......",
   "######.......",
   "#####........",
   "######.......",
   "#######......",
   ".########....",
   ".##########..",
   "..#########..",
   "....#####...."
  ]
 },
 "palettes": {
  "fixed": {
   "w": "#ffffff",
   "b": "#2121de",
   "k": "#14172e",
   "y": "#ffd21f",
   "f": "#f2b26b",
   "o": "#c8641e",
   "d": "#5c2d0c",
   "r": "#e5484d"
  },
  "KONG1/KONG2": {
   "b": "#8b4a1c",
   "f": "#f2b26b",
   "w": "#ffffff",
   "k": "#2a1206"
  },
  "FIGHTER": {
   "w": "menu bar text colour",
   "r": "#e5484d",
   "b": "#3d5afe"
  },
  "BEESM (scene)": {
   "#": "#3d5afe",
   "y": "#ffd21f",
   "b": "#2121de"
  },
  "HAMMER": {
   "#": "done tint",
   "d": "rgba(0,0,0,0.35)"
  },
  "SQUID1/SQUID2/GUN (scene)": "menu bar text colour",
  "PAC0/PAC1/PAC2": "#e9b800 light, #ffd21f dark"
 },
 "tints": {
  "light": {
   "need": "#e2680a",
   "needWaited": "#d8261c",
   "done": "#1c9353"
  },
  "dark": {
   "need": "#ff9a3d",
   "needWaited": "#ff4a3d",
   "done": "#3fd184"
  }
 },
 "drawnInCode": {
  "chomp dots": "2x2 at x = L+17+i*8, scrolling 2 px per frame; PAC frames cycle 2,1,0,1",
  "kong girder": "#e5484d bar 2 px tall at cy+5 from L+15 to L+44, rivets #ffb3b3 every 4 px",
  "galaxy shots": "#f0a500 3x1 dashes",
  "blocks": "4 px cells (3 px block + bevel), tetromino colours I #00c8e0 O #f0c800 T #a43ff0 S #20b850 Z #e5322d J #2f5bf0 L #f08a00; need = T piece, done = 3x3 square, both tinted",
  "reference": "the inline script of this page (THEMES object) is the reference implementation of every scene"
 }
}
```

---

*Problem*

## Sessions wait on you and you don't know

We each run four to eight Claude Code sessions across terminal tabs and editor windows. A session that stops to ask a question or wait for approval sits there until someone happens to check its tab. Finished work waits too. We find out by cycling through tabs, which breaks whatever we were focused on.

1UP puts one honest answer in the menu bar: does anything need me, and has anything finished? Success looks like this:   **< 60 s**Median time from "needs you" to answered. Measured during the pilot from 1UP's own local log. **0**Wrong-state periods longer than 2 s in the release test run. **4 of 5**Pilot teammates still running it after two weeks. **0**Wrong states reported in `#1up` during the pilot's second week.

### What already exists

Several Claude Code menu bar monitors already exist. The spike starts by trying the two closest for a day each. If one passes our gate, we adopt it instead of building.

| Option | How it works | Where 1UP differs |
|---|---|---|
| Claude Code's own notifications and `claude agents` | A ping in the terminal, and a list view inside a terminal | A glanceable count from anywhere. The agent view also calls a session busy while only a leftover background shell runs. |
| Claude Status Bar (https://github.com/m1ckc3s/claude-status-bar) (open source) | Installs Claude Code hooks. Animated icon while working, a dot when permission is needed. | No hooks or settings edits. Open sessions show up right away instead of after their next action, and interrupted turns are caught, which the end-of-turn hook misses. |
| Glint (https://www.producthunt.com/products/glint-9/makers) | Reads local session logs. Shows status, current tool, tokens and subagents. | No licence check over the network, no setup, and a test gate the team owns |
| Claude Statistics (https://github.com/sj719045032/claude-statistics), Coucou | Live status, with approve or deny from the card or the notch | 1UP never approves outside the terminal, by design. |
| MenubarCC | A pixel-art crab per session | Five arcade themes on one fixed layout |
| A SwiftBar plugin around the watcher script | Counts and a list in an afternoon | The fallback if the spike fails |

---

*Source of truth*

## Read what Claude Code writes about itself

Every running Claude Code session keeps a small status file at `~/.claude/sessions/<pid>.json`. Claude Code rewrites it whenever the status or the waiting reason changes, and stamps the time in `statusUpdatedAt`. It is also rewritten on renames and bookkeeping, when only `updatedAt` moves. Claude Code's own `claude agents` command reads these same files.

1UP watches that folder and reads a file only when it changes. Done comes from the session's transcript, where Claude Code writes a `turn_duration` record at the end of every turn. Nothing else is read and nothing is polled every second.   **Why not use `claude agents --json` alone? It calls a finished turn "busy".** Two sessions reported `busy` for more than 24 hours. Both terminals were at an empty prompt. Each turn had ended, but a background shell the turn started was still running (a `wc -l` stuck on a socket, and a `npm run work logs | tail` that never exits). The status file says `shell` for exactly this case. The JSON output folds it into `busy`, and the agent view shows both as working. Using the JSON alone, 1UP would show Working forever and never show those turns as Done.

### How Claude Code's status becomes a 1UP state

| Status file says | 1UP shows | Panel line | Basis |
|---|---|---|---|
| `busy` | WORKING | Working | VERIFIED |
| `waiting` + `permission prompt` | NEEDS YOU | Wants approval | DOCUMENTED |
| `waiting` + `input needed` | NEEDS YOU | Asked a question | DOCUMENTED |
| `waiting` + `sandbox request` / `worker request` / `goal proposal` | NEEDS YOU | Wants sandbox access / Worker needs approval / Proposed a goal | VERIFIED in 2.1.295 |
| `waiting` + `dialog open` | NEEDS YOU | A dialog is open | DOCUMENTED as waiting on you |
| `waiting` + any other reason | NEEDS YOU | Waiting: <raw reason> | Safe default |
| `idle` or `shell`, and the transcript's latest `turn_duration` is later than when you last looked | DONE | Ended · ran 11m | VERIFIED 493 of 518 turns, every version 2.1.261–2.1.295 |
| Was `busy` or a Needs-you `waiting` (not dialog), now `idle`/`shell`, and no new `turn_duration` within 1.5 s | DONE | Interrupted · ran 3m | VERIFIED interrupts skip the record (3 of 4) |
| `idle` or `shell`, already looked at | IDLE | Idle, or Idle · background shell running | VERIFIED |
| Process gone | Row removed | None | VERIFIED |
| Unknown status, missing field, unreadable file | That row only: **?** with the raw value | Unrecognised status "xyz" | Safe default |

The status file is internal to Claude Code and has no documented contract. That's the cost of matching the terminal exactly. 1UP checks the file's shape on every read, pins the format with fixture tests per Claude Code version, and falls back to "can't tell" rather than guessing. Done is the only state 1UP works out itself, and it needs a real turn. The primary signal is a `turn_duration` record in the transcript that is newer than when you last looked. Interrupted turns usually skip that record, so a second rule covers them: the saved previous status was `busy` or a Needs-you `waiting`, and no record arrives within 1.5 s. A turn Claude starts by itself when a background task finishes is a real turn, so it ends in Done too. A background shell exiting, a dialog closing, or a brand-new session never creates Done. "Last looked at" is saved to disk, so a 1UP restart loses nothing.

---

*Trust rules*

## Rules that keep it honest

### Claude Code decides the state

Only the status Claude Code writes decides a row's state. Nothing is inferred from CPU, time or output.

### Never upgrade a doubt

Anything ambiguous shows its raw value or "?". A failed or stale read can never create a Done.

### Fresh, or it says so

Every 5 s 1UP lists the folder and checks each file's modified time, which catches anything a file event missed. If the folder can't be read for 20 s, the whole icon turns into "?". There is no in-between state.

### No rows for dead sessions

A file counts only if its process is alive and started at the file's `procStart` (±1 s, both in UTC). That rules out stale files whose pid was reused. The process name isn't checked, because an npm install of Claude Code runs as `node`.

### Every config folder

Each 5 s scan reads `CLAUDE_CONFIG_DIR` from the user's Claude Code processes and watches `<folder>/sessions` for every distinct folder, plus `~/.claude`. Sessions started with a different config folder still show up, with no setting to change.

### Every visible session

Every interactive session in your `~/.claude` is listed, whatever terminal or editor it runs in. Nothing can be hidden in v1.

### Survives restarts

"Last looked at" is saved per session. Quitting, updating or crashing 1UP loses nothing. A half-written file is retried three times within 150 ms before its row shows "?".

### A "?" never hides a waiting session

A row stuck on "?" for 20 s counts under Needs you and sorts to the top, so a session whose file changed shape can't silently wait on you.

### Proven before release

Every release passes the test matrix (Appendix B), run by hand on two Macs, one of them using VS Code.

---

*Design · menu bar item*

## Read it in a glance

Scenes animate at 8 fps from pre-rendered frames and stop while the screen is locked. With macOS Reduce Motion on, the theme's `idleFrame` holds still, in colour. The working count always shows, so no state relies on motion alone, and every state also has its own shape for colour-blind teammates.

| Situation | Menu bar | What you do |
|---|---|---|
| Nothing running | *(preview: idle)* | Nothing |
| 3 sessions working | *(preview: work3)* | Keep working elsewhere |
| 2 working, 1 needs you | *(preview: mix1)* | Click, then the Needs-you row |
| 2 working, 2 need you, one for 3 minutes | *(preview: mix3)* | Red icon: it's been waiting. Go now. |
| All finished, 2 unseen | *(preview: done)* | Review when you're ready |
| 1 working, 1 needs you, 3 done | *(preview: mix2)* | Answer the Needs-you row first |
| Status unreadable for 20 s | *(preview: err)* | Open the panel for the reason |

---

*Code & distribution*

## Small, readable, and boring to maintain

1UP should stay small enough to read in one sitting. Target under 2,000 lines of Swift, one dependency (Sparkle for updates), and no background services. Clean code here means each file has one job, the decision logic has no side effects, and every rule in this spec has a test with the same name.

**Repo layout · github.com/hoberobin/1up**

```
1up/
  Package.swift                 OneUpCore library + oneup-dump executable
  project.yml                   XcodeGen: the 1UP.app target (Info.plist, LSUIElement, entitlements, Sparkle)
  Sources/OneUpCore/             pure logic, no AppKit, fully unit-tested
    StatusFile.swift            decode + shape-check one sessions/*.json
    SessionState.swift          the five states and the mapping table
    Reducer.swift               (previous, status file, latest turn_duration, lastLookedAt) → state
    RowTitle.swift              user name → custom-title → ai-title → folder, then #n on duplicates
    TranscriptTail.swift        tail-reads titles and turn-end records only
  Sources/OneUp/                 thin macOS shell around OneUpCore
    SessionWatcher.swift        FSEvents + 5 s folder check + process-exit sources
    StatusItem.swift            draws the active theme's frames + counts
    ThemeLoader.swift           reads and validates theme folders
    PanelView.swift             SwiftUI panel
    Settings.swift, Welcome.swift, SetupCheck.swift
  Resources/Themes/             one folder per theme, no code (see below)
    chomp/ invaders/ kong/ galaxy/ blocks/
  Tests/OneUpCoreTests/
    Fixtures/<version>/       real status files and transcript snippets
    ReducerTests.swift          one test per row of the mapping table and test matrix
    ThemeTests.swift            every theme folder passes the theme rules
  tools/capture-fixtures.sh     copies live status files and transcript tails into Fixtures
  tools/render-themes.mjs       one-time export of the five built-in theme folders (output committed)
  CLAUDE.md                     build and test commands, the rules below
  .github/workflows/            test on every PR, release on tag
```

Code rules live in the repo's `CLAUDE.md` (see Start here). Release is one path: push a tag such as `v1.0.0` and CI builds, signs, notarises, staples, uploads the DMG and updates the Sparkle feed. Nobody signs on a laptop.

### Themes are folders, not code

A theme is a folder of small images and one JSON file. The app never has theme-specific code: it plays the frames, tints the two icons and draws the counts the same way for every theme. Adding a cabinet means adding a folder and nothing else.

**Resources/Themes/invaders/**

```
theme.json          {"schema": 1, "id": "invaders", "name": "Invaders", "after": "Space Invaders"}
scene.png           required · working frames left to right, each 44 × 16 px, 1–32 frames, loops
scene-ink.png       optional · alpha mask, same size, drawn in the menu bar's text colour
scene-dark.png      optional · replaces scene.png on a dark menu bar
need.png            required · 14 × 14 alpha mask, filled with the Needs-you tint
need-detail.png     optional · 14 × 14 RGBA, drawn untinted on top (eyes, faces)
done.png            required · 14 × 14 alpha mask, filled with the Done tint
done-detail.png     optional · 14 × 14 RGBA
icon.png            required · 14 × 14 RGBA, used in the panel and the theme picker
icon-ink.png        optional · 14 × 14 alpha mask drawn in the menu bar's text colour (white-on-dark sprites)
```

**theme.json schema**

```
{
  "schema":    1,                      required
  "id":        "invaders",             required · ^[a-z][a-z0-9-]{1,31}$ · equals the folder name
  "name":      "Invaders",             required · 1–16 characters
  "after":     "Space Invaders",       optional · shown under the name in the picker
  "fps":       8,                      optional · 1–8, default 8 (ThemeTests still reject flashing above 4 Hz)
  "idleFrame": 0                       optional · default 0, also used with Reduce Motion
}
```

- **Pixels:** every image is drawn at 1 px per point, scaled 2× with nearest-neighbour on Retina, so art stays crisp. Layers share the base image's size and origin and are drawn in this order: scene, ink, then for icons the tint mask and the detail. Masks use alpha only.

- **The app owns meaning, the theme owns art.** Needs you is filled orange, then red after 2 minutes. Done is filled green. Idle is the `idleFrame` of the scene (default 0) drawn in the menu bar's own colour at 50%. A theme can't change any of that.
- **One layout for every theme:** 44 × 16 scene, 14 × 14 icons, counts placed by the app (see UI reference), so switching themes never moves anything.
- **Validated on load:** wrong sizes, 0 or more than 32 frames, missing required files, an `id` that differs from the folder, or an unreadable JSON skip that theme, log why, and fall back to Chomp. The menu bar never shows a broken theme.
- **`ThemeTests` check every built-in folder:** sizes and frame counts, Needs-you and Done shapes that differ from each other and from the idle frame, scene art that doesn't use the exact tint colours, and nothing that flashes faster than 4 times a second.
- **Reduce Motion:** only `idleFrame` is shown, in colour.
- **Built-ins come from this page.** `tools/render-themes.mjs` runs the scene code from this spec's preview with the sprite data from Start here and writes the five folders. Its output is committed, so the app ships plain PNGs.
- **Original art and names** (Chomp, Invaders, Kong, Galaxy, Blocks), in the spirit of the classics, so a public repo stays clean.

### How it fits our setup

| Where | What 1UP does there |
|---|---|
| GitHub (`hoberobin/1up`, public) | Source, PR reviews and Releases. The `@claude review` flow works as on our main repo. |
| Claude Code | Builds it: the repo's `CLAUDE.md` carries the rules and this spec. Users need nothing extra: no hooks, no plugins, no settings. |
| `npm run work` worktrees | Rows show the worktree name, so `work-pages-bg` reads as `pages-bg`. |
| Slack | A `#1up` channel. If 1UP ever disagrees with a terminal, post what you saw and attach that day's log file. |

### Two ways to get it

- **Download:** `1UP.dmg` from Releases. Most people.
- **From source:** `git clone`, then `swift build` or open in Xcode. Signing is optional for your own Mac.

---

*UI reference*

## Every surface, sized and worded

### Menu bar item

| Property | Value |
|---|---|
| Layout | 6 pt padding · 44 × 16 scene · 4 · working count · 8 · 14 × 14 Needs-you icon · 3 · count · 8 · 14 × 14 Done icon · 3 · count · 6 pt padding. With no working count, the Needs-you icon sits 8 pt after the scene. Where this page's preview and this table disagree, the table wins. |
| Width | Sized to content, reserving two digits per count so 9 → 10 doesn't shift it. Above 99 it shows "99+". |
| Count type | SF Pro Text 13 pt semibold, monospaced digits. The working count uses the menu bar colour, Needs you uses its icon's tint, and Done is green. |
| Idle | The theme's `idleFrame` as a template image at 50%, no count |
| Can't tell | Scene at 40%, then a "?" in red, no counts |
| Inactive display, tinted menu bar | Everything drawn as template images; the icon shapes carry the meaning |
| Increase Contrast | 1 pt outline in the menu bar colour around tinted icons, no transparency |
| Hidden behind the notch | Not detectable. The welcome card opens as a popover anchored to the item, so if it appears in the middle of the screen instead, the card says "⌘-drag 1UP left in the menu bar so you can see it". |
| VoiceOver | "1UP: 2 working, 1 needs you, 3 done", "1UP: nothing running", or "1UP: can't read Claude Code status". The hint adds "oldest waiting 3 minutes". |

### Panel

| Property | Value |
|---|---|
| Window | Non-activating panel under the item, 340 pt wide. Max height is 70% of the screen or 520 pt; rows scroll, the footer stays. |
| Group label | 14 pt theme icon + 11 pt semibold, secondary colour, sentence case |
| Row | 44 pt tall, 6 pt vertical and 8 pt horizontal padding, 6 pt radius. Title 13 pt, truncates at the end. Time right-aligned 11 pt with monospaced digits. Sub-line 11 pt secondary. |
| Sub-line | `<state line> · <folder> · <app>`. Time lives only in the right column. |
| Empty | "No Claude Code sessions running. Start claude in any terminal and it shows up here." |
| Time column | Needs you "1m" · Working "4m" · Done "2m ago" · Idle blank. Durations round down. |
| "?" row | Sorted into Needs you after 20 s. Sub-line: Unrecognised status "xyz". |
| Footer | Mark all looked at (disabled when nothing is Done) · ⚙︎ Settings |
| Keys | ↑ ↓ move · Return marks looked at · Esc closes |
| Row VoiceOver | "Fix the quiz tally, needs you, wants approval, waiting 1 minute, quiz-matrix in VS Code" |

### Right-click menu

Open Panel · Mark All Looked At · — · Theme ▸ (five, checkmark on current) · Settings… ⌘, · — · Check for Updates… · Quit 1UP ⌘Q

### Settings (one 480 pt window, no tabs)

Open at login (switch) · Theme: five 88 × 56 live tiles with an accent ring on the current one · Check my setup button with results inline · footer "1UP 1.0.0 · Check for Updates · GitHub".

### Check my setup

| Check | Pass | Fail | Fix button |
|---|---|---|---|
| Sessions | Found 6 sessions in 1 config folder | Can't read a sessions folder (shows the path) | None |
| Claude Code version | Tested with 2.1.295 (read from each status file's `version`) | New version 2.2.0, not yet verified (still working) · or 2.1.260 or older: "Update Claude Code to see status" | None |
| Login | Opens at login | macOS is holding 1UP for approval | Open Login Items |

### Prompts

| When | Copy | Buttons |
|---|---|---|
| Opened outside Applications | Move 1UP to Applications? It needs to be there to open at login. | Move and Relaunch · Not Now |
| Update available | 1UP 1.1 is available. (release notes) | Install and Relaunch · Later |

English only in v1, with every string through `String(localized:)`. Durations use the system's abbreviated format. Tint values per theme: light need #e2680a, waited #d8261c, done #1c9353; dark #ff9a3d, #ff4a3d, #3fd184. Each tint keeps at least 3:1 contrast on both menu bar appearances.

---

*Milestones*

## Six milestones, each with a test you can see

| Milestone | Build | Done when |
|---|---|---|
| **M0 · Gate** 1–2 days | Try Claude Status Bar and Glint for a day each. Run every test matrix row by hand on two Macs (one using VS Code) with `1up-watch.py`, and confirm what `/rename` writes (`custom-title` and the status file's `nameSource`). | **Go** if there is zero Done without a real turn, no wrong-state period over 2 s, and p95 latency ≤ 2 s. **Pivot** to adopting an existing app or a SwiftBar plugin if a common case is wrong. **Stop** if the status files change shape between minor versions. |
| **M1 · Core** 2 days | `OneUpCore`: status reader, transcript tail reader, reducer, persistence, log. A `oneup-dump` command prints every session's state once a second. | Every reducer row and every VERIFIED matrix row has a passing fixture test. `oneup-dump` agrees with your terminals for a working day. |
| **M2 · Menu bar and panel** 2 days | `tools/render-themes.mjs` and the Chomp theme folder, menu bar item, panel with states and where each session runs, Done clearing | Screenshots match the UI reference, and this page's preview where the reference is silent, at 1× and 2×, light and dark. Keyboard and VoiceOver work as in the UI reference. |
| **M3 · Everyday use** 2 days | Welcome card, Check my setup, Settings, move to Applications | A teammate installs it without help in under a minute, and every Check my setup failure says what to do. |
| **M4 · Themes** 1 day | The other four theme folders and the theme picker | `ThemeTests` pass and every theme matches the gallery on this page. |
| **M5 · Ship and pilot** 1 week | Signing, notarising, Sparkle, README. Pilot with five people across at least three terminals, anything wrong reported in `#1up`. | The success numbers at the top of this half are met. Then share with everyone. |

### After the pilot: useful first, then fun

| Useful (each ships only after its own test) | Fun |
|---|---|
| Alerts for Needs you and long turns, cleared once handled | More cabinets: Frogger, Asteroids, Centipede, Dig Dug |
| ⌃⌥Space to open the panel | Drop your own theme folder into `~/Library/Application Support/1UP/Themes` |
| The question or last reply shown in each row | A bonus item when every session has ended and you've looked at them all |
| Jump to the session's tab, if it lands right 20 times out of 20 per terminal | End-of-day line, worded per theme ("Chomp ate 23 turns today") |

---

*Decisions*

## Answered, plus three for Hobe

| Question | Answer | Why |
|---|---|---|
| Read Claude Code's internal status files? | Yes | It's the only source that matches the terminal when background shells are running. Every read is shape-checked, and fixture tests pin the format per Claude Code version. We'll also ask Anthropic to add `shell` to `claude agents --json`. |
| Row titles? | `/rename` name, then Claude Code's generated session title, then folder #n | The generated title exists in 178 of 188 sessions. Claude Code's internal names collide. |
| Signed builds for the pilot? | Yes, signed and notarised from the first build | On macOS 15, unsigned apps need a trip to System Settings to open. |
| One-click updates? | Yes (Sparkle) in v1 | Claude Code ships weekly. Manual updates get skipped, and rows drift to "?". |
| Jump to the session's tab? | Not in v1. Rows say where the session runs instead. | It needs an extension, extra permissions and per-terminal cases, and a wrong landing costs trust. It comes back only if it passes its own 20-of-20 test. |
| Turns that ended before 1UP was installed? | Idle. Everything running at first launch counts as already looked at. | Simple, and you never start with a pile of checks. |
| Interrupted or errored turns? | Done. The row says "Interrupted · ran Xm" when the 1.5 s rule fired, otherwise "Ended · ran Xm". | Honest without reading reply text. |
| Alerts, shortcut, previews, report a mismatch, Homebrew? | Not in v1 | Each adds a moving part without making the core more accurate. Fixture tests and the daily log cover accuracy; post in `#1up` if something looks wrong. |
| How does Done clear? | Row click, Mark all looked at, or the next prompt in that session | Simple and predictable. Nothing watches your terminals. |

### The name

**1UP.** In arcades, 1UP flashes when it's player one's turn, which is this app's main job. It replaced the working name Waka, which only fit one theme and would have sat next to WakaTime (about 23 million installs) in VS Code's marketplace. Identifiers: app `1UP`, repo `hoberobin/1up`, Swift module `OneUpCore`.

### Still open

- **Public or private repo?** Recommended: public under `hoberobin/1up`, MIT licence (decided 2026-10-23; the repo lives there). Nothing in it is ours to protect, and public makes Releases and the update feed work with no logins. Private works too, but downloads and updates then need a hosted copy (for example an S3 bucket).
- **Who holds the team Apple Developer ID** for signing and notarising?
- **Backup owner** who can re-run the test when Claude Code changes its status files.

---

*Rollout & risks*

## For teammates

- **Privacy:** nothing about your sessions leaves your Mac. The only network use is the update check, which downloads the public release feed and sends nothing but the app version. 1UP reads `~/.claude/sessions/*.json` (never the `.key` files or sockets beside them), and from the end of each transcript only the session title and turn-end records. It writes only its preferences, the saved "last looked at" times, and a local log of state changes kept for 7 days at `~/Library/Logs/1UP/`.
- **Permissions:** none. 1UP never asks for alerts, Automation, Accessibility or Full Disk Access. If macOS holds the login item for approval, 1UP links straight to Login Items.
- **Not covered:** Claude Code on the web, the desktop app's chats, `claude -p` scripts, background sessions (`claude --bg`), other machines, other macOS users, and the VS Code extension's chat panel (CLI sessions in VS Code's terminal are covered).

| Risk | What happens | Mitigation |
|---|---|---|
| Claude Code changes its status file | Rows show "?" (shape check) | Fixture tests per version, owner re-runs the test matrix, Check my setup flags an unverified version |
| Two sessions running different Claude Code versions | Common: 2.1.293, 2.1.294 and 2.1.295 have been seen running side by side | Shape check is per file, not per install |
| A turn ends while a background shell lives on | Terminal at the prompt, `agents --json` says busy | Read `shell` from the file and show "Idle · background shell running" |
| Signing account owner leaves | Can't ship updates | Use the team Developer ID, not a personal one |
  Appendix · for whoever builds it

---

*A · Architecture*

## Event-driven, nothing polled every second

| Part | Build | Notes |
|---|---|---|
| App shell | Swift 6. AppKit `NSStatusItem` for the animated icon, SwiftUI panel in an `NSPanel` | `LSUIElement`, no Dock icon. Not sandboxed (it reads the Claude Code config folders it finds). Developer ID and hardened runtime. No Automation or Accessibility entitlements. |
| Watcher | FSEvents on the sessions folder (file-level events, 100 ms debounce, dirty flag if an event lands mid-read). A 5 s folder listing with modified times catches anything FSEvents drops, such as after sleep. | Near-zero cost while nothing changes. |
| Exit detection | `DispatchSource.makeProcessSource(.exit)` per pid | Removes rows the moment a session ends, including `kill -9`, with no polling. |
| Reducer | Pure Swift in `OneUpCore`, fixture-tested with saved status files from each Claude Code version | Key is pid + `startedAt`. Pid reuse is ruled out by matching `procStart` to the process start time. `sessionId` is just an attribute, so `/clear` and `/resume` keep the row. |
| Row titles | Transcript at `<configDir>/projects/<cwd with non-alphanumerics as "-">/<sessionId>.jsonl`, falling back to a glob on the sessionId | Read from the end: `custom-title`, `ai-title` and `turn_duration` only. Cached per session. |
| Where it runs | The app name comes from the session's `TERM_PROGRAM` (`vscode` → VS Code, `iTerm.app` → iTerm2, `Apple_Terminal` → Terminal; `__CFBundleIdentifier` tells Cursor from VS Code; with `TMUX` set it reads "VS Code · tmux"). Unknown values show the raw name. | The same read gives `CLAUDE_CONFIG_DIR` (see Every config folder). Read only, no permission needed. |
| Distribution | Notarised, stapled DMG on GitHub Releases and a Sparkle feed, both published by the tag workflow | Before registering the login item (`SMAppService`), 1UP checks it's running from /Applications and offers to move itself if not. |

---

*B · Test matrix*

## Release checklist: terminal vs 1UP

VERIFIED means checked against real status files and transcripts from Claude Code 2.1.261–2.1.295. DOCUMENTED means it comes from Claude Code's docs. SPIKE means it must pass the hand-run matrix in M0.

| Scenario | Terminal shows | 1UP must show | Status |
|---|---|---|---|
| Six sessions in one VS Code window, same folder | Six terminal tabs | Six rows with distinct titles | VERIFIED list · SPIKE titles |
| Turn ends while a background shell keeps running | Empty prompt | Done, then Idle · background shell running | VERIFIED status file says `shell` |
| Send a prompt | Spinner | Working within 1 s | SPIKE |
| Very short turn (under 1 s) | Answer appears | Done (new `turn_duration` record) | SPIKE |
| Permission prompt, including one raised by a subagent | "Do you want to proceed?" | Needs you · Wants approval | DOCUMENTED · SPIKE subagent |
| AskUserQuestion, plan approval, MCP form | Question with options | Needs you · Asked a question | SPIKE |
| `/config` or another menu left open | A dialog | Needs you · A dialog is open | SPIKE |
| Esc mid-turn | "Interrupted", prompt | Done · Interrupted (no turn record, 1.5 s rule) | VERIFIED transcripts |
| API error, rate limit, retry countdown | Error or countdown | Working while retrying, then Done | SPIKE |
| Auto-compact, `/compact` | "Compacting…" | Working, same row | SPIKE |
| `/clear`, `/resume` | Same tab | Same row | SPIKE |
| Long foreground Bash command | Command running | Working | SPIKE |
| `/exit`, close the tab, `kill -9` | Tab gone | Row gone within 1 s | SPIKE |
| 1UP quits and relaunches after a turn ended | Answer waiting | Still Done | SPIKE |
| Mac sleeps mid-turn, wakes | Resumes or errors | Fresh read on wake, matches | SPIKE |
| 15 sessions at once | 15 tabs | 15 rows, panel scrolls | SPIKE |
| `claude -p`, IDE extension chats | Not an interactive terminal | Not listed (`kind` ≠ interactive or `entrypoint` ≠ cli) | SPIKE |
| Background shell exits after you looked, Claude doesn't react | Nothing changes | No Done | SPIKE |
| Background task finishes and Claude reacts (16% of turns in the scan) | Claude works, then prompt | Working, then Done | VERIFIED transcripts |
| Two prompts queued while busy | Both answered | One Done (one turn record covers both) | VERIFIED transcripts |
| Close `/config` | Prompt | No Done | SPIKE |
| New session, no prompt yet | Empty prompt | Idle | SPIKE |
| Stale file from a crash, pid reused by another app | No session | No row | SPIKE (fixture) |
| File read mid-write | None | No "?" flash | SPIKE |
| Watcher misses events (paused, then resumed) | Whatever changed | Matches within 5 s | SPIKE |
| Two sessions with the same Claude Code name | Two tabs | Two rows, different titles | VERIFIED names collide |

### Running the matrix

For v1 the matrix is run by hand. Keep `1up-watch.py` (later `oneup-dump`) open beside the terminals, step through each row, and note the time from what the terminal shows to the line appearing. Pass: zero Done without a real turn, no disagreement longer than 2 s, p95 ≤ 2 s. Every failure becomes a fixture and a new row. Re-run whenever the Check my setup version line says "not yet verified".

---

*D · Build reference*

## What the transcripts showed, and the exact rules

### Transcript scan (188 sessions, Claude Code 2.1.261–2.1.295, read-only)

| Question | Answer |
|---|---|
| Does a finished turn write `turn_duration`? | Yes: 493 of 518 CLI turns. The rest were still running, interrupted, or queued behind another prompt. Short turns are included, down to 120 ms. |
| Interrupts (Esc)? | 3 of 4 write no record. The marker is a user record with text "[Request interrupted by user]" or "…for tool use]". Hence the 1.5 s rule. |
| API errors? | 4 of 4 write a record. The error is an assistant record with `isApiErrorMessage: true`. |
| Slash commands only (`/model`)? | No record, no Done |
| Compaction? | The turn still gets a record. Compaction itself is `system/compact_boundary`. |
| Subagents? | Never in the main transcript. Their files are under `<sessionId>/subagents/`, so read only the top-level `*.jsonl`. |
| Background-task turns? | 87 of 543 turns start with a task notification. They are real turns and end in Done. |
| Titles? | `custom-title` (from `/rename`) and `ai-title` (in 178 of 188 sessions). Both are re-appended many times and carry no timestamp, so the last one in the file wins. Status-file `nameSource` values seen: derived, user, collision, auto, hook, peer; only "user" is a rename. |
| Desktop app and SDK sessions? | Never write `turn_duration`, which is one more reason to list `kind: interactive` CLI sessions only |

### Reducer

| Before | Event | After |
|---|---|---|
| any | `status = busy` | Working; Done cleared ✱ |
| any | `waiting` + reason | Needs you |
| any | `idle`/`shell` and latest `turn_duration` > lastLookedAt | Done |
| Working, or Needs you (not dialog) | `idle`/`shell`, no new record within 1.5 s | Done · Interrupted |
| Needs you (dialog), Idle | `idle`/`shell` | Idle |
| Done | Row click, Mark all | Idle; lastLookedAt = now ✱ |
| any | Process exits, or `procStart` doesn't match | Row removed |
| Working | `idle` with no transcript yet (new session, just after `/clear`) | Done · Ended (no "ran"), never Interrupted; title = folder |
| any | Unreadable file or bad shape | "?", counted as Needs you after 20 s |

Rows are evaluated top to bottom; the first match wins. ✱ = persisted. A new session starts with lastLookedAt = its startedAt. Sessions already running at 1UP's first launch get lastLookedAt = now. Shape check: `pid`, `sessionId`, `cwd`, `kind`, `status`, `startedAt` and `procStart` are required, `entrypoint` is optional (missing means cli), unknown keys are ignored, and an unknown `status` gives "?", and an unknown `waitingFor` gives Needs you · Waiting: <raw>. `procStart` is UTC in `ps` format with a space-padded day. Parse it as en_US_POSIX UTC and compare with `sysctl(KERN_PROC_PID)` start time ±1 s.

### Timers, in one place

| Timer | Value |
|---|---|
| FSEvents debounce · half-written file retry | 100 ms · 3 × 50 ms |
| Interrupt grace (no turn record) | 1.5 s |
| Folder scan · "?" | 5 s · after 20 s unreadable |
| Needs-you icon turns red | 2 min |
| Log retention | 7 days |
| Animation | 8 fps, nothing flashes faster than 4 Hz |

### Pinned implementation rules

- **Busy resets the clock:** status `busy` sets `lastLookedAt = statusUpdatedAt` and `busySince = statusUpdatedAt` (both persisted), so an interrupted turn never shows the previous turn's "Ended".
- **Times:** `lastLookedAt`, `busySince` and `statusUpdatedAt` are epoch milliseconds. `turn_duration` is compared on its ISO `timestamp`. "Ended · ran" uses `durationMs`; "Interrupted · ran" uses now − `busySince`.
- **Ages:** the time column and the 2-minute red both use `statusUpdatedAt`, so they survive a 1UP restart. Under 60 s shows seconds ("45s"), under 60 min minutes ("4m"), otherwise hours ("2h"), always rounded down.
- **"?" in its first 20 s** keeps the row's last known state. A row with no last state is listed under Working without counting.
- **First launch** means no `state.json` exists: every session gets lastLookedAt = now. Later, a session unknown to `state.json` gets lastLookedAt = its `startedAt`.
- **Claude Code processes** are this user's processes whose `argv[0]` or `argv[1]` path ends in `claude` or `@anthropic-ai/claude-code/cli.js`. They are used only to discover config folders; sessions themselves always come from status files.
- **Folder name:** `basename(cwd)` with a leading `work-` removed.
- **First transcript read:** the last 256 KB, then forward from the saved offset. If no title was found, scan backwards once for one.
- **Fixture format:** `{"steps": [{"t_ms": 0, "status": {…}, "transcriptAppend": ["…"]}], "expect": [{"t_ms": 1600, "state": "done", "line": "Interrupted · ran 0s"}]}`. `tools/capture-fixtures.sh` replaces cwd, names, titles and socket paths with placeholders before writing.
- **`oneup-dump`** prints one line per session every second: `HH:MM:SS pid state line · title`.
- **Panel details:** the Idle group is a "Idle (n) ▸" toggle, sorted newest first. Group labels use the theme's Needs-you icon, Done icon, `icon.png` for Working, and a grey dot for Idle. With nothing running, the menu bar shows the idle scene at 50% with no counts.

### Rendering the five built-in themes

- `tools/render-themes.mjs` (Node, no dependencies) contains this page's `THEMES` scene code and sprite data unchanged. It samples the scene at `f = frame / 2` for N frames: Chomp 4, Invaders 24, Kong 23, Galaxy 32, Blocks 7.
- It writes `scene.png` in colour, `scene-ink.png` for pixels the page draws in the menu bar text colour (dots, invaders, cannon, fighter body), and `scene-dark.png` for Chomp's darker yellow.
- Fixed-colour pixels inside icons go to `*-detail.png`: ghost and fireball eyes, the bee's yellow and blue, the hammer's dark band, and the Blocks bevel.
- Invaders' and Galaxy's panel icons use `icon-ink.png`. Picker tiles are 88 × 56 at 2× on `#05060f` with ink `#f2f4ff`, like the gallery screens on this page.

### Files, platform, budgets

- **State:** `~/Library/Application Support/1UP/state.json` = `{v:1, sessions:{"pid:startedAt":{lastLookedAt, busySince, lastStatus, lastTurnEnd, offset, title}}}`. Written atomically on change and pruned 24 h after the process exits.
- **`waitingFor` values** are matched literally: `permission prompt` → Wants approval, `input needed` → Asked a question, `sandbox request` → Wants sandbox access, `worker request` → Worker needs approval, `goal proposal` → Proposed a goal, `dialog open` → A dialog is open. "Ran Xm" is measured from when the status became `busy`.
- **Session environment** (terminal, `CLAUDE_CONFIG_DIR`) is read with `sysctl(KERN_PROCARGS2)` for the claude pid, the same user's process, so no permission is needed.
- **Transcripts are tail-read** with a saved byte offset per session (transcripts reach 40+ MB). Start over if the file shrinks or `sessionId` changes after `/clear`.
- **Log:** `~/Library/Logs/1UP/YYYY-MM-DD.jsonl`, one `{mono, wall, key, raw, state, reason}` per change, also mirrored to `os_log`.
- **Settings keys:** `openAtLogin = true` · `theme = "chomp"`.
- **Platform:** macOS 14+, Swift 6 strict concurrency. `OneUpCore` is pure and synchronous. One `actor SessionStore` consumes an `AsyncStream` of file, timer and exit events. The UI model is `@MainActor @Observable`.
- **Budget:** under 0.5% CPU averaged while idle, under 40 MB memory, under 1 s from status write to menu bar.
- **Compatibility:** Claude Code 2.1.261 and later. An unseen version keeps working and shows "not yet verified" in Check my setup.
- **Release secrets (CI only):** Developer ID certificate and password, notarytool API key, Sparkle EdDSA key.
- **Fixtures:** `Tests/OneUpCoreTests/Fixtures/<version>/` holds real status files and transcript snippets for interrupt, API error, compaction, task notification and queued prompts.

---

*C · Spike tool*

## A 60-line watcher to check the idea

Run this in a spare terminal and use Claude normally in your other tabs. Each line is a state change. It uses simplified rules: Done comes from the previous status only, with no transcript and no "looked at", so a Done stays until that session's next prompt, and turns that ended before you start it show Idle. If a line ever disagrees with a terminal, note what you were doing. That list decides the gate.

**1up-watch.py · Python 3, no dependencies · python3 1up-watch.py**

```
#!/usr/bin/env python3
"""Prints a line each time a Claude Code session changes state. Ctrl-C to stop."""
import glob, json, os, time

DIR = os.path.join(os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude")), "sessions")
last = {}

def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        pass
    return True

def read(path):
    for _ in range(3):
        try:
            with open(path) as f:
                return json.load(f)
        except (OSError, ValueError):
            time.sleep(0.05)
    return None

def state(s, prev):
    st, why = s.get("status"), s.get("waitingFor")
    if st == "busy":
        return "WORKING"
    if st == "waiting":
        return f"NEEDS YOU ({why or 'waiting'})"
    if st in ("idle", "shell"):
        prev = prev or ""
        turn_ended = prev.startswith(("WORKING", "DONE")) or (prev.startswith("NEEDS") and "dialog open" not in prev)
        return ("DONE" if turn_ended else "IDLE") + (" + background shell" if st == "shell" else "")
    return f"? ({st})"

try:
    while True:
        seen = set()
        for path in glob.glob(os.path.join(DIR, "*.json")):
            s = read(path)
            if not s or s.get("kind") != "interactive" or not isinstance(s.get("pid"), int):
                continue
            if not alive(s["pid"]):
                continue
            key = (s["pid"], s.get("startedAt"))
            seen.add(key)
            now = state(s, last.get(key))
            if last.get(key) != now:
                print(time.strftime("%H:%M:%S"), f"{s.get('name') or str(s['pid']):32} {last.get(key, 'new'):>28} -> {now}", flush=True)
                last[key] = now
        for key in set(last) - seen:
            path = os.path.join(DIR, f"{key[0]}.json")
            if not alive(key[0]) or (read(path) or {}).get("startedAt") != key[1]:
                print(time.strftime("%H:%M:%S"), f"{key[0]:<32} {last.pop(key):>28} -> GONE", flush=True)
        time.sleep(0.25)
except KeyboardInterrupt:
    pass

```

**Sample output. The two "background shell" sessions are ones `claude agents --json` would call busy.**

```
15:50:17 work-stu-weekly-challenge-ac   new -> IDLE
15:50:17 work-stu-weekly-challenge-8f   new -> IDLE + background shell
15:50:17 work-stu-weekly-challenge-98   new -> WORKING
15:50:17 work-stu-weekly-challenge-27   new -> IDLE + background shell
15:50:17 work-stu-weekly-challenge-6d   new -> IDLE
15:50:17 work-stu-weekly-challenge-9a   new -> WORKING
```
