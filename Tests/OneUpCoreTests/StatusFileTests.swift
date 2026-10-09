import XCTest

@testable import OneUpCore

final class StatusFileTests: XCTestCase {
  let sample = """
    {"pid":3628,"sessionId":"32adac4e-ffd8-4643-8867-90e973cef265","cwd":"/Users/me/Sites/LevelLearning/work-stu-weekly-challenge",
     "startedAt":1791496321053,"procStart":"Thu Oct  8 21:51:57 2026","version":"2.1.295","peerProtocol":1,
     "peerFeatures":["notify_idle"],"kind":"interactive","entrypoint":"cli","pidDomain":"darwin",
     "messagingSocketPath":"/tmp/cc-socks/3628.sock","name":"work-stu-weekly-challenge-ac","nameSource":"derived",
     "nameSince":1791496321053,"status":"idle","updatedAt":1791501764274,"statusUpdatedAt":1791501764274}
    """

  func testParsesRealShape() throws {
    let s = try StatusFile.parse(Data(sample.utf8))
    XCTAssertEqual(s.pid, 3628)
    XCTAssertEqual(s.status, "idle")
    XCTAssertEqual(s.statusSince, 1791501764274)
    XCTAssertTrue(s.isInteractiveCLI)
    XCTAssertFalse(s.isUserNamed)
    XCTAssertEqual(s.key, "3628:1791496321053")
    XCTAssertEqual(s.version, "2.1.295")
  }

  func testProcStartIsUTCWithPaddedDay() throws {
    let d = try XCTUnwrap(StatusFile.parseProcStart("Thu Oct  8 21:51:57 2026"))
    XCTAssertEqual(Int(d.timeIntervalSince1970), 1791496317)
    XCTAssertNotNil(StatusFile.parseProcStart("Fri Oct 10 00:12:42 2026"))
    XCTAssertNil(StatusFile.parseProcStart("yesterday"))
  }

  func testMissingRequiredFieldFails() {
    let bad = sample.replacingOccurrences(of: "\"status\":\"idle\",", with: "")
    XCTAssertThrowsError(try StatusFile.parse(Data(bad.utf8))) { e in
      XCTAssertEqual(e as? StatusFileError, .missing("status"))
    }
  }

  func testWrongTypeFails() {
    let bad = sample.replacingOccurrences(of: "\"pid\":3628", with: "\"pid\":\"3628\"")
    XCTAssertThrowsError(try StatusFile.parse(Data(bad.utf8))) { e in
      XCTAssertEqual(e as? StatusFileError, .wrongType("pid"))
    }
  }

  func testNotJSONAndNotObject() {
    XCTAssertThrowsError(try StatusFile.parse(Data("{\"pid\":".utf8))) { XCTAssertEqual($0 as? StatusFileError, .notJSON) }
    XCTAssertThrowsError(try StatusFile.parse(Data("[1,2]".utf8))) { XCTAssertEqual($0 as? StatusFileError, .notObject) }
  }

  func testEntrypointDefaultsToCLIAndUnknownKeysIgnored() throws {
    let min = """
      {"pid":1,"sessionId":"s","cwd":"/x","kind":"interactive","status":"busy","startedAt":5,"procStart":"Thu Oct  8 21:51:57 2026","future":{"a":1}}
      """
    let s = try StatusFile.parse(Data(min.utf8))
    XCTAssertEqual(s.entrypoint, "cli")
    XCTAssertTrue(s.isInteractiveCLI)
    XCTAssertEqual(s.statusSince, 5)
  }

  func testSmallIntegersAreNotBooleans() throws {
    let min = """
      {"pid":1,"sessionId":"s","cwd":"/x","kind":"interactive","status":"busy","startedAt":1,"procStart":"x","statusUpdatedAt":0,"updatedAt":1}
      """
    let s = try StatusFile.parse(Data(min.utf8))
    XCTAssertEqual(s.startedAt, 1)
    XCTAssertEqual(s.statusUpdatedAt, 0)
    let bool = min.replacingOccurrences(of: "\"startedAt\":1", with: "\"startedAt\":true")
    XCTAssertThrowsError(try StatusFile.parse(Data(bool.utf8))) { XCTAssertEqual($0 as? StatusFileError, .wrongType("startedAt")) }
  }

  func testNonInteractiveNotListed() throws {
    let sdk = sample.replacingOccurrences(of: "\"entrypoint\":\"cli\"", with: "\"entrypoint\":\"sdk-ts\"")
    XCTAssertFalse(try StatusFile.parse(Data(sdk.utf8)).isInteractiveCLI)
    let print = sample.replacingOccurrences(of: "\"kind\":\"interactive\"", with: "\"kind\":\"print\"")
    XCTAssertFalse(try StatusFile.parse(Data(print.utf8)).isInteractiveCLI)
  }
}
