import XCTest

@testable import OneUpCore

/// One test per reducer row and per VERIFIED test-matrix row. Fixtures live in Fixtures/reducer.
final class ReducerTests: XCTestCase {
  func testBusyIsWorking() throws { try FixtureRunner.run(named: "busy") }
  func testWaitingPermissionNeedsYou() throws { try FixtureRunner.run(named: "waiting-permission") }
  func testWaitingInputNeedsYou() throws { try FixtureRunner.run(named: "waiting-input") }
  func testWaitingUnknownReasonNeedsYou() throws { try FixtureRunner.run(named: "waiting-other") }
  func testTurnDurationAfterLookedAtIsDone() throws { try FixtureRunner.run(named: "turn-ended") }
  func testInterruptedWithoutRecordAfterGrace() throws { try FixtureRunner.run(named: "interrupted") }
  func testInterruptedFromPermissionPrompt() throws { try FixtureRunner.run(named: "interrupted-from-waiting") }
  func testDialogClosedIsIdle() throws { try FixtureRunner.run(named: "dialog-closed") }
  func testBackgroundShellAfterLookedAt() throws { try FixtureRunner.run(named: "shell-idle") }
  func testTurnEndsWhileBackgroundShellRuns() throws { try FixtureRunner.run(named: "shell-turn-ended") }
  func testUnknownStatusKeepsLastStateThenSettles() throws { try FixtureRunner.run(named: "unknown-status") }
  func testUnreadableFileWithNoLastState() throws { try FixtureRunner.run(named: "unreadable-new") }
  func testNoTranscriptYetEndsWithoutRan() throws { try FixtureRunner.run(named: "no-transcript") }
  func testFirstLaunchOldTurnIsIdle() throws { try FixtureRunner.run(named: "first-launch") }
  func testNewSessionTurnAfterStartIsDone() throws { try FixtureRunner.run(named: "new-session-turn") }
  func testSlashCommandOnlyNoDone() throws { try FixtureRunner.run(named: "slash-command") }
  func testQueuedPromptsOneDone() throws { try FixtureRunner.run(named: "queued-prompts") }
  func testBackgroundTaskTurnIsDone() throws { try FixtureRunner.run(named: "background-task-turn") }
  func testLookedAtClearsDoneUntilNextTurn() throws { try FixtureRunner.run(named: "looked-at") }
  func testBusyClearsDone() throws { try FixtureRunner.run(named: "busy-clears-done") }
  func testApiErrorTurnIsDone() throws { try FixtureRunner.run(named: "api-error") }
  func testInterruptedRestartKeepsDone() throws { try FixtureRunner.run(named: "interrupted-persists") }

  func testWaitReasonLines() {
    XCTAssertEqual(WaitReason(raw: "permission prompt").line, "Wants approval")
    XCTAssertEqual(WaitReason(raw: "input needed").line, "Asked a question")
    XCTAssertEqual(WaitReason(raw: "sandbox request").line, "Wants sandbox access")
    XCTAssertEqual(WaitReason(raw: "worker request").line, "Worker needs approval")
    XCTAssertEqual(WaitReason(raw: "goal proposal").line, "Proposed a goal")
    XCTAssertEqual(WaitReason(raw: "dialog open").line, "A dialog is open")
    XCTAssertEqual(WaitReason(raw: "xyz").line, "Waiting: xyz")
    XCTAssertEqual(WaitReason(raw: nil).line, "Waiting")
  }

  func testBusyResetsClock() {
    let m = SessionMemory(lastLookedAt: 5000)
    let s = StatusFile(pid: 1, sessionId: "a", cwd: "/x", status: "busy", startedAt: 1000, procStart: "", statusUpdatedAt: 3000)
    let r = Reducer.reduce(memory: m, read: .ok(s), transcript: .none, now: 6000)
    XCTAssertEqual(r.memory.lastLookedAt, 3000)
    XCTAssertEqual(r.memory.busySince, 3000)
    XCTAssertEqual(r.state, .working)
  }

  func testUnknownRowsGroupAndCount() {
    XCTAssertEqual(SessionState.unknown(reason: "x", settled: false).group, .working)
    XCTAssertFalse(SessionState.unknown(reason: "x", settled: false).countsAsWorking)
    XCTAssertEqual(SessionState.unknown(reason: "x", settled: true).group, .needsYou)
    XCTAssertTrue(SessionState.unknown(reason: "x", settled: true).countsAsNeedsYou)
  }

  func testSessionStateRoundTripsThroughJSON() throws {
    let states: [SessionState] = [.working, .needsYou(.other("q")), .done(.interrupted(ranMs: 12)), .done(.ended(durationMs: nil)), .idle(backgroundShell: true), .unknown(reason: "r", settled: true)]
    for s in states {
      let data = try JSONEncoder().encode(s)
      XCTAssertEqual(try JSONDecoder().decode(SessionState.self, from: data), s)
    }
  }
}
