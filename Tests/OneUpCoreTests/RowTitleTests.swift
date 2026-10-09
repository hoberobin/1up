import XCTest

@testable import OneUpCore

final class RowTitleTests: XCTestCase {
  func testFolderNameStripsWorkPrefix() {
    XCTAssertEqual(RowTitle.folderName(cwd: "/Users/me/Sites/LevelLearning/work-pages-bg"), "pages-bg")
    XCTAssertEqual(RowTitle.folderName(cwd: "/Users/me/Sites/1up"), "1up")
    XCTAssertEqual(RowTitle.folderName(cwd: "/Users/me/work-"), "work-")
  }

  func testPrecedence() {
    var s = StatusFile(pid: 1, sessionId: "s", cwd: "/a/work-quiz", status: "idle", startedAt: 0, procStart: "", name: "quiz-ab", nameSource: "derived")
    XCTAssertEqual(RowTitle.title(status: s, customTitle: nil, aiTitle: nil), "quiz")
    XCTAssertEqual(RowTitle.title(status: s, customTitle: nil, aiTitle: "Fix the tally"), "Fix the tally")
    XCTAssertEqual(RowTitle.title(status: s, customTitle: "My rename", aiTitle: "Fix the tally"), "My rename")
    s.nameSource = "user"
    s.name = "Renamed in status"
    XCTAssertEqual(RowTitle.title(status: s, customTitle: "My rename", aiTitle: nil), "Renamed in status")
    XCTAssertEqual(RowTitle.title(status: s, customTitle: "  ", aiTitle: "  "), "Renamed in status")
  }

  func testDuplicatesGetNumbersInStartOrder() {
    let out = RowTitle.disambiguate([
      (key: "b", title: "Same", startedAt: 20), (key: "a", title: "Same", startedAt: 10), (key: "c", title: "Other", startedAt: 5),
    ])
    XCTAssertEqual(out["a"], "Same #1")
    XCTAssertEqual(out["b"], "Same #2")
    XCTAssertEqual(out["c"], "Other")
  }
}
