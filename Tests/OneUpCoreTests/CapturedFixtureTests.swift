import XCTest

@testable import OneUpCore

/// Real status files and transcript tails captured per Claude Code version by tools/capture-fixtures.sh.
/// A new version's files must still parse; if they stop, the shape changed and the reducer rows need a look.
final class CapturedFixtureTests: XCTestCase {
  func versionFolders() throws -> [URL] {
    let root = try XCTUnwrap(Bundle.module.resourceURL).appendingPathComponent("Fixtures")
    let names = try FileManager.default.contentsOfDirectory(atPath: root.path)
    return names.filter { $0.first?.isNumber == true }.sorted().map { root.appendingPathComponent($0) }
  }

  func testEveryCapturedStatusFileParses() throws {
    let folders = try versionFolders()
    XCTAssertFalse(folders.isEmpty, "capture fixtures with tools/capture-fixtures.sh")
    for folder in folders {
      let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasPrefix("status-") }
      XCTAssertFalse(files.isEmpty, "\(folder.lastPathComponent) has no status files")
      for f in files {
        let s = try StatusFile.parse(Data(contentsOf: folder.appendingPathComponent(f)))
        XCTAssertEqual(s.version, folder.lastPathComponent, f)
        XCTAssertTrue(s.isInteractiveCLI, f)
        XCTAssertNotNil(s.procStartDate, "\(f): procStart must parse")
        XCTAssertTrue(["busy", "waiting", "idle", "shell"].contains(s.status), "\(f): unseen status \(s.status)")
        let r = Reducer.reduce(memory: SessionMemory(lastLookedAt: s.startedAt), read: .ok(s), transcript: .none, now: s.statusSince + 1)
        if case .unknown = r.state { XCTFail("\(f) reduced to unknown") }
      }
    }
  }

  func testEveryCapturedTranscriptTailScans() throws {
    for folder in try versionFolders() {
      let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasPrefix("transcript-") }
      for f in files {
        let data = try Data(contentsOf: folder.appendingPathComponent(f))
        let scan = TranscriptTail.scan(data, skipPartialFirstLine: false)
        XCTAssertTrue(scan.hasTitle || scan.latestTurnEnd != nil, "\(f): nothing recognised")
        if let te = scan.latestTurnEnd { XCTAssertGreaterThan(te.timestampMs, 1_700_000_000_000, f) }
      }
    }
  }
}
