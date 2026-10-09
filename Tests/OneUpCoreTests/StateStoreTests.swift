import XCTest

@testable import OneUpCore

final class StateStoreTests: XCTestCase {
  func testRoundTripAndPrune() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
    XCTAssertNil(StateStore.load(from: url), "no file means first launch")
    var m = SessionMemory(lastLookedAt: 10)
    m.lastState = .done(.interrupted(ranMs: 3))
    m.pendingDone = .interrupted(ranMs: 3)
    var gone = SessionMemory(lastLookedAt: 1)
    gone.exitedAt = 0
    let state = StateFile(sessions: ["1:10": m, "2:20": gone])
    try StateStore.save(state, to: url)
    XCTAssertEqual(StateStore.load(from: url), state)
    let pruned = StateStore.pruned(state, now: StateStore.pruneAfterExitMs + 1)
    XCTAssertEqual(Array(pruned.sessions.keys), ["1:10"])
    XCTAssertEqual(StateStore.pruned(state, now: 1000).sessions.count, 2)
  }

  func testTimeFormat() {
    XCTAssertEqual(TimeFormat.age(ms: 45_000), "45s")
    XCTAssertEqual(TimeFormat.age(ms: 59_999), "59s")
    XCTAssertEqual(TimeFormat.age(ms: 4 * 60_000 + 59_000), "4m")
    XCTAssertEqual(TimeFormat.age(ms: 2 * 3_600_000 + 59 * 60_000), "2h")
    XCTAssertEqual(TimeFormat.age(ms: -5), "0s")
    XCTAssertEqual(TimeFormat.spokenAge(ms: 3 * 60_000), "3 minutes")
    XCTAssertEqual(TimeFormat.epochMs(iso: "2026-10-08T21:56:00.151Z"), 1791496560151)
    XCTAssertEqual(TimeFormat.epochMs(iso: "2026-10-08T21:56:00Z"), 1791496560000)
  }
}
