import Foundation
import XCTest

@testable import OneUpCore

/// Replays a reducer fixture: `{"steps":[{"t_ms":0,"status":{…},"transcriptAppend":["…"]}],
/// "expect":[{"t_ms":1600,"state":"done","line":"Interrupted · ran 0s"}]}`.
/// `t_ms` is relative to `base` (default: the first status's `statusUpdatedAt`). A step with
/// `"status": null` is an unreadable file. Optional: `firstLaunch`, `transcriptExists`, `lookedAt` (t_ms list).
struct FixtureRunner {
  struct Step {
    var t: Int64
    var status: [String: Any]?
    var append: [String]
  }
  struct Expectation {
    var t: Int64
    var state: String
    var line: String?
  }

  static func run(named name: String, file: StaticString = #filePath, line: UInt = #line) throws {
    let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/reducer"), "fixture \(name)", file: file, line: line)
    let obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let steps = (obj["steps"] as? [[String: Any]] ?? []).map { s in
      Step(t: (s["t_ms"] as? NSNumber)?.int64Value ?? 0, status: s["status"] as? [String: Any],
           append: s["transcriptAppend"] as? [String] ?? [])
    }
    let expects = (obj["expect"] as? [[String: Any]] ?? []).map { e in
      Expectation(t: (e["t_ms"] as? NSNumber)?.int64Value ?? 0, state: e["state"] as? String ?? "", line: e["line"] as? String)
    }
    let firstLaunch = obj["firstLaunch"] as? Bool ?? false
    let transcriptExists = obj["transcriptExists"] as? Bool ?? true
    let lookedAt = (obj["lookedAt"] as? [NSNumber] ?? []).map { $0.int64Value }
    let firstStatus = steps.first?.status
    let base = (obj["base"] as? NSNumber)?.int64Value
      ?? (firstStatus?["statusUpdatedAt"] as? NSNumber)?.int64Value
      ?? (firstStatus?["startedAt"] as? NSNumber)?.int64Value ?? 0
    let startedAt = (firstStatus?["startedAt"] as? NSNumber)?.int64Value ?? base

    var memory = SessionMemory(lastLookedAt: firstLaunch ? base : startedAt)
    var scan = TranscriptScan()
    var lastRead: StatusRead = .failed("no step yet")
    var stepIndex = 0
    var lookedIndex = 0
    var lastReduceAt: Int64 = .min
    var state: SessionState = .idle(backgroundShell: false)

    func reduce(at t: Int64) {
      let r = Reducer.reduce(memory: memory, read: lastRead, transcript: TranscriptInfo(exists: transcriptExists, latestTurnEnd: scan.latestTurnEnd), now: base + t)
      memory = r.memory
      state = r.state
      lastReduceAt = t
    }

    for e in expects.sorted(by: { $0.t < $1.t }) {
      while stepIndex < steps.count, steps[stepIndex].t <= e.t {
        let s = steps[stepIndex]
        if !s.append.isEmpty { scan = scan.merged(with: TranscriptTail.scan(lines: s.append)) }
        if let status = s.status {
          lastRead = (try? StatusFile.parse(object: status)).map(StatusRead.ok) ?? .failed("bad shape")
        } else {
          lastRead = .failed("unreadable")
        }
        reduce(at: s.t)
        stepIndex += 1
      }
      while lookedIndex < lookedAt.count, lookedAt[lookedIndex] <= e.t {
        memory = Reducer.markLookedAt(memory: memory, now: base + lookedAt[lookedIndex])
        reduce(at: lookedAt[lookedIndex])
        lookedIndex += 1
      }
      if lastReduceAt < e.t { reduce(at: e.t) }
      XCTAssertEqual(state.code, e.state, "\(name) at t=\(e.t): expected \(e.state), got \(state) (\(state.line))", file: file, line: line)
      if let l = e.line {
        XCTAssertEqual(state.line, l, "\(name) at t=\(e.t)", file: file, line: line)
      }
    }
  }
}
