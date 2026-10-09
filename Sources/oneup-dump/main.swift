import Foundation
import OneUpCore

// Prints one line per session every second: HH:MM:SS  pid  state  line  ·  title
let home = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
  ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude", isDirectory: true)
let once = CommandLine.arguments.contains("--once")
let engine = SessionEngine(options: .init(homeConfigDir: home, stateURL: once ? nil : StateStore.defaultURL()))
let clock = DateFormatter()
clock.dateFormat = "HH:MM:ss"
clock.dateFormat = "HH:mm:ss"

func printSnapshot(_ s: Snapshot) {
  let stamp = clock.string(from: Date())
  if s.cannotTell { print("\(stamp)  ?  \(s.folderError ?? "can't read Claude Code status")") }
  if s.rows.isEmpty { print("\(stamp)  (no sessions)") }
  for group in StateGroup.allCases {
    for row in s.rows(in: group) {
      let code = row.state.code.padding(toLength: 9, withPad: " ", startingAt: 0)
      let time = row.timeColumn(now: s.now)
      print("\(stamp)  \(String(row.pid).padding(toLength: 6, withPad: " ", startingAt: 0)) \(code) \(row.subLine)\(time.isEmpty ? "" : "  [\(time)]")  ·  \(row.title)")
    }
  }
  fflush(stdout)
}

printSnapshot(engine.refresh())
if !once {
  while true {
    Thread.sleep(forTimeInterval: 1)
    printSnapshot(engine.refresh())
  }
}
