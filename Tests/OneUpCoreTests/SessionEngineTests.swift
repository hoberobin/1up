import XCTest

@testable import OneUpCore

/// Drives the engine against a temporary config folder. The listed session is this test process,
/// whose real start time satisfies the procStart match.
final class SessionEngineTests: XCTestCase {
  var configDir: URL!
  var stateURL: URL!

  override func setUpWithError() throws {
    configDir = FileManager.default.temporaryDirectory.appendingPathComponent("1up-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: configDir.appendingPathComponent("sessions"), withIntermediateDirectories: true)
    stateURL = configDir.appendingPathComponent("state.json")
  }

  func procStart(for pid: Int32) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "EEE MMM d HH:mm:ss yyyy"
    return f.string(from: ProcessReader.startTime(pid)!)
  }

  func write(pid: Int32, status: String, waitingFor: String? = nil, startedAt: Int64 = 1_700_000_000_000, statusUpdatedAt: Int64, procStart: String? = nil, sessionId: String = "abc", kind: String = "interactive") throws {
    var obj: [String: Any] = [
      "pid": Int(pid), "sessionId": sessionId, "cwd": "/tmp/work-engine-test", "kind": kind, "entrypoint": "cli", "status": status,
      "startedAt": startedAt, "procStart": procStart ?? self.procStart(for: pid), "version": "2.1.295", "updatedAt": statusUpdatedAt,
      "statusUpdatedAt": statusUpdatedAt, "name": "engine-test", "nameSource": "derived",
    ]
    if let w = waitingFor { obj["waitingFor"] = w }
    let data = try JSONSerialization.data(withJSONObject: obj)
    try data.write(to: configDir.appendingPathComponent("sessions/\(pid).json"), options: .atomic)
  }

  func writeTranscript(sessionId: String = "abc", lines: [String]) throws {
    let dir = configDir.appendingPathComponent("projects/\(TranscriptReader.projectDirName(cwd: "/tmp/work-engine-test"))", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try (lines.joined(separator: "\n") + "\n").write(to: dir.appendingPathComponent("\(sessionId).jsonl"), atomically: true, encoding: .utf8)
  }

  func makeEngine() -> SessionEngine {
    SessionEngine(options: .init(homeConfigDir: configDir, stateURL: stateURL, discoverConfigDirs: false, readEnvironment: false))
  }

  func testLiveProcessListedDeadOnesNot() throws {
    let me = getpid()
    try write(pid: me, status: "busy", statusUpdatedAt: 1_700_000_000_000)
    try write(pid: 999_999, status: "busy", statusUpdatedAt: 1_700_000_000_000, procStart: "Thu Oct  8 21:51:57 2026")
    try write(pid: me, status: "busy", statusUpdatedAt: 1_700_000_000_000, kind: "print")
    try FileManager.default.moveItem(at: configDir.appendingPathComponent("sessions/\(me).json"), to: configDir.appendingPathComponent("sessions/\(me)-copy.json"))
    try write(pid: me, status: "busy", statusUpdatedAt: 1_700_000_000_000)
    let snap = makeEngine().refresh(now: 1_700_000_001_000)
    XCTAssertEqual(snap.rows.count, 1)
    XCTAssertEqual(snap.rows.first?.state, .working)
    XCTAssertEqual(snap.rows.first?.folder, "engine-test")
    XCTAssertEqual(snap.rows.first?.title, "engine-test")
    XCTAssertEqual(snap.counts.working, 1)
    XCTAssertNil(snap.folderError)
    XCTAssertEqual(snap.versions, ["2.1.295"])
  }

  func testPidReuseWithWrongStartTimeIsNotListed() throws {
    try write(pid: getpid(), status: "busy", statusUpdatedAt: 1, procStart: "Thu Oct  8 21:51:57 2020")
    let rows = makeEngine().refresh(now: 1000).rows
    XCTAssertEqual(rows.count, 0, "\(rows)")
  }

  func testInterruptThenPersistAcrossRelaunch() throws {
    let me = getpid()
    let t0: Int64 = 1_700_000_000_000
    try write(pid: me, status: "busy", statusUpdatedAt: t0)
    try writeTranscript(lines: [#"{"type":"ai-title","aiTitle":"Engine title","sessionId":"abc"}"#])
    let engine = makeEngine()
    let first = engine.refresh(now: t0 + 100)
    XCTAssertEqual(first.rows.first?.state, .working)
    XCTAssertEqual(first.rows.first?.title, "Engine title")
    try write(pid: me, status: "idle", statusUpdatedAt: t0 + 1000)
    let grace = engine.refresh(now: t0 + 1100, force: true)
    XCTAssertEqual(grace.rows.first?.state, .working)
    XCTAssertEqual(engine.nextRecheckAt, t0 + 2600)
    let done = engine.tick(now: t0 + 2700)
    XCTAssertEqual(done.rows.first?.state, .done(.interrupted(ranMs: 2700)))
    XCTAssertEqual(done.counts.done, 1)

    let relaunched = makeEngine()
    XCTAssertEqual(relaunched.refresh(now: t0 + 5000).rows.first?.state, .done(.interrupted(ranMs: 2700)), "state.json keeps the Done")
    let cleared = relaunched.markAllLookedAt(now: t0 + 6000)
    XCTAssertEqual(cleared.rows.first?.state, .idle(backgroundShell: false))
    XCTAssertEqual(cleared.counts.done, 0)

    try writeTranscript(lines: [
      #"{"type":"ai-title","aiTitle":"Engine title","sessionId":"abc"}"#,
      #"{"type":"system","subtype":"turn_duration","durationMs":4000,"timestamp":"\#(TimeFormat.isoString(ms: t0 + 7000))","sessionId":"abc"}"#,
    ])
    let newTurn = relaunched.refresh(now: t0 + 7100, force: true)
    XCTAssertEqual(newTurn.rows.first?.state, .done(.ended(durationMs: 4000)), "a turn record newer than looked-at is Done")
    XCTAssertEqual(newTurn.rows.first?.subLine, "Ended · ran 4s · engine-test")
  }

  func testNoTranscriptEndsWithoutRan() throws {
    let me = getpid()
    let t0: Int64 = 1_700_000_000_000
    try write(pid: me, status: "busy", statusUpdatedAt: t0)
    let engine = makeEngine()
    XCTAssertEqual(engine.refresh(now: t0 + 100).rows.first?.state, .working)
    try write(pid: me, status: "idle", statusUpdatedAt: t0 + 1000)
    XCTAssertEqual(engine.refresh(now: t0 + 1100, force: true).rows.first?.state, .done(.ended(durationMs: nil)))
  }

  func testWaitingCountsAndWaitedFlag() throws {
    let me = getpid()
    let t0: Int64 = 1_700_000_000_000
    try write(pid: me, status: "waiting", waitingFor: "permission prompt", statusUpdatedAt: t0)
    let engine = makeEngine()
    var snap = engine.refresh(now: t0 + 1000)
    XCTAssertEqual(snap.counts.needsYou, 1)
    XCTAssertFalse(snap.counts.needsYouWaited)
    XCTAssertEqual(snap.rows.first?.subLine, "Wants approval · engine-test")
    XCTAssertEqual(snap.rows.first?.timeColumn(now: t0 + 1000), "1s")
    snap = engine.tick(now: t0 + 130_000)
    XCTAssertTrue(snap.counts.needsYouWaited)
    XCTAssertEqual(snap.counts.oldestWaitingMs, 130_000)
  }

  func testMissingSessionsFolderBecomesCannotTell() throws {
    try FileManager.default.removeItem(at: configDir.appendingPathComponent("sessions"))
    let engine = makeEngine()
    var snap = engine.refresh(now: 1000)
    XCTAssertNotNil(snap.folderError)
    XCTAssertFalse(snap.cannotTell)
    snap = engine.refresh(now: 1000 + Reducer.unknownGraceMs)
    XCTAssertTrue(snap.cannotTell)
    try FileManager.default.createDirectory(at: configDir.appendingPathComponent("sessions"), withIntermediateDirectories: true)
    snap = engine.refresh(now: 30_000)
    XCTAssertFalse(snap.cannotTell)
    XCTAssertNil(snap.folderError)
    XCTAssertEqual(snap.lastGoodRead, 30_000)
  }

  func testHalfWrittenFileDoesNotFlash() throws {
    let me = getpid()
    let t0: Int64 = 1_700_000_000_000
    try write(pid: me, status: "busy", statusUpdatedAt: t0)
    let engine = makeEngine()
    XCTAssertEqual(engine.refresh(now: t0).rows.first?.state, .working)
    try Data("{\"pid\":\(me),\"sess".utf8).write(to: configDir.appendingPathComponent("sessions/\(me).json"))
    let snap = engine.refresh(now: t0 + 500, force: true)
    XCTAssertEqual(snap.rows.first?.state, .working, "unknown keeps the last state for 20 s")
    XCTAssertEqual(snap.rows.count, 1)
  }

  func testRowsSortedByGroup() {
    let base = SessionRow(key: "k", pid: 1, sessionId: "s", title: "t", folder: "f", app: nil, state: .idle(backgroundShell: false), since: 0, startedAt: 0, version: nil, configDir: URL(fileURLWithPath: "/"), rawStatus: "idle")
    var a = base; a.key = "a"; a.state = .needsYou(.permission); a.since = 200
    var b = base; b.key = "b"; b.state = .needsYou(.inputNeeded); b.since = 100
    var c = base; c.key = "c"; c.state = .idle(backgroundShell: false); c.since = 50
    var d = base; d.key = "d"; d.state = .idle(backgroundShell: true); d.since = 500
    let snap = Snapshot(rows: [a, b, c, d])
    XCTAssertEqual(snap.rows(in: .needsYou).map(\.key), ["b", "a"], "longest waiting first")
    XCTAssertEqual(snap.rows(in: .idle).map(\.key), ["d", "c"], "idle newest first")
  }
}

extension SessionEngineTests {
  func testUnparseableNewFileIsListedThenCountsAsNeedsYou() throws {
    let me = getpid()
    try Data("{\"pid\":\(me),\"status\":\"busy\"".utf8).write(to: configDir.appendingPathComponent("sessions/\(me).json"))
    let engine = makeEngine()
    var snap = engine.refresh(now: 1000)
    XCTAssertEqual(snap.rows.count, 1)
    XCTAssertEqual(snap.rows.first?.state.group, .working)
    XCTAssertEqual(snap.counts.working, 0, "listed without counting during the grace period")
    XCTAssertEqual(snap.rows.first?.title, "Session \(me)")
    snap = engine.refresh(now: 1000 + Reducer.unknownGraceMs, force: true)
    XCTAssertEqual(snap.rows.first?.state.group, .needsYou)
    XCTAssertEqual(snap.counts.needsYou, 1)
    XCTAssertEqual(snap.rows.first?.state.line, "Can't read: Not valid JSON")
    try write(pid: me, status: "busy", statusUpdatedAt: 30_000)
    snap = engine.refresh(now: 31_000, force: true)
    XCTAssertEqual(snap.rows.count, 1, "the placeholder row is replaced once the file parses")
    XCTAssertEqual(snap.rows.first?.state, .working)
  }
}

extension SessionEngineTests {
  func testUnparseableFileKeepsItsReasonOnRecheck() throws {
    let me = getpid()
    try Data("{\"pid\":\(me),\"status\":\"busy\"".utf8).write(to: configDir.appendingPathComponent("sessions/\(me).json"))
    let engine = makeEngine()
    var snap = engine.refresh(now: 1000)
    XCTAssertEqual(snap.rows.first?.state.line, "Can't read: Not valid JSON")
    XCTAssertEqual(engine.nextRecheckAt, 1000 + Reducer.unknownGraceMs)
    snap = engine.tick(now: 1000 + Reducer.unknownGraceMs)
    XCTAssertEqual(snap.rows.first?.state, .unknown(reason: "Can't read: Not valid JSON", settled: true), "the timer recheck must not reinterpret the placeholder")
    snap = engine.markAllLookedAt(now: 2000 + Reducer.unknownGraceMs)
    XCTAssertEqual(snap.rows.first?.state, .unknown(reason: "Can't read: Not valid JSON", settled: true))
  }
}
