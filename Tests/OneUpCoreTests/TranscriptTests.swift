import XCTest

@testable import OneUpCore

final class TranscriptTests: XCTestCase {
  let turn = #"{"parentUuid":"x","isSidechain":false,"type":"system","subtype":"turn_duration","durationMs":101984,"timestamp":"2026-10-08T21:56:00.151Z","uuid":"u","sessionId":"s"}"#
  let later = #"{"type":"system","subtype":"turn_duration","durationMs":2411,"timestamp":"2026-10-08T21:57:17.342Z","sessionId":"s"}"#
  let sidechain = #"{"type":"system","subtype":"turn_duration","durationMs":1,"isSidechain":true,"timestamp":"2026-10-08T23:00:00.000Z"}"#
  let ai = #"{"type":"ai-title","aiTitle":"Historical reporting","sessionId":"s"}"#
  let custom = #"{"type":"custom-title","customTitle":"Question types (86bbd7131)","sessionId":"s"}"#

  func testTurnDurationRecordShape() {
    let scan = TranscriptTail.scan(lines: [turn])
    XCTAssertEqual(scan.latestTurnEnd, TurnEnd(timestampMs: 1791496560151, durationMs: 101984))
  }

  func testLastRecordWins() {
    let scan = TranscriptTail.scan(lines: [turn, ai, custom, later, #"{"type":"ai-title","aiTitle":"Newer title"}"#])
    XCTAssertEqual(scan.latestTurnEnd?.durationMs, 2411)
    XCTAssertEqual(scan.aiTitle, "Newer title")
    XCTAssertEqual(scan.customTitle, "Question types (86bbd7131)")
  }

  func testSidechainAndOtherRecordsIgnored() {
    let scan = TranscriptTail.scan(lines: [sidechain, #"{"type":"user","message":{"content":"turn_duration custom-title ai-title"}}"#, "not json"])
    XCTAssertNil(scan.latestTurnEnd)
    XCTAssertFalse(scan.hasTitle)
  }

  func testPartialFirstLineSkipped() {
    let data = Data(("garbage\",\"subtype\":\"turn_duration\"}\n" + later + "\n").utf8)
    let scan = TranscriptTail.scan(data, skipPartialFirstLine: true)
    XCTAssertEqual(scan.latestTurnEnd?.durationMs, 2411)
    let whole = TranscriptTail.scan(Data((turn + "\n" + later).utf8), skipPartialFirstLine: false)
    XCTAssertEqual(whole.latestTurnEnd?.durationMs, 2411)
  }

  func testProjectDirName() {
    XCTAssertEqual(TranscriptReader.projectDirName(cwd: "/Users/me/Sites/work-x_y"), "-Users-me-Sites-work-x-y")
  }

  func testTailReadThenForwardThenBackwardTitle() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("t.jsonl")
    var body = ai + "\n"
    let filler = #"{"type":"user","message":{"content":""# + String(repeating: "x", count: 4000) + "\"}}\n"
    for _ in 0..<100 { body += filler }
    body += turn + "\n"
    try body.write(to: url, atomically: true, encoding: .utf8)

    let first = TranscriptReader.read(url: url, offset: 0, previous: TranscriptScan())
    XCTAssertTrue(first.exists)
    XCTAssertEqual(first.scan.latestTurnEnd?.durationMs, 101984)
    XCTAssertEqual(first.scan.aiTitle, "Historical reporting", "title must be found by the backward scan")
    XCTAssertEqual(first.offset, Int64(body.utf8.count))

    let handle = try FileHandle(forWritingTo: url)
    _ = try handle.seekToEnd()
    try handle.write(contentsOf: Data((later + "\n").utf8))
    try handle.close()
    let second = TranscriptReader.read(url: url, offset: first.offset, previous: first.scan)
    XCTAssertEqual(second.scan.latestTurnEnd?.durationMs, 2411)
    XCTAssertEqual(second.scan.aiTitle, "Historical reporting")

    try Data((custom + "\n").utf8).write(to: url)
    let shrunk = TranscriptReader.read(url: url, offset: second.offset, previous: second.scan)
    XCTAssertEqual(shrunk.scan.customTitle, "Question types (86bbd7131)")
    XCTAssertNil(shrunk.scan.latestTurnEnd, "a shrunken file starts over")

    let missing = TranscriptReader.read(url: dir.appendingPathComponent("nope.jsonl"), offset: 0, previous: TranscriptScan())
    XCTAssertFalse(missing.exists)
  }
}
