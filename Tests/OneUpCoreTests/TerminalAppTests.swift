import XCTest

@testable import OneUpCore

final class TerminalAppTests: XCTestCase {
  func testKnownTerminals() {
    XCTAssertEqual(TerminalApp.name(environment: ["TERM_PROGRAM": "vscode", "__CFBundleIdentifier": "com.microsoft.VSCode"]), "VS Code")
    XCTAssertEqual(TerminalApp.name(environment: ["TERM_PROGRAM": "vscode", "__CFBundleIdentifier": "com.todesktop.230313mzl4w4u92"]), "VS Code")
    XCTAssertEqual(TerminalApp.name(environment: ["TERM_PROGRAM": "vscode", "__CFBundleIdentifier": "com.cursor.Cursor"]), "Cursor")
    XCTAssertEqual(TerminalApp.name(environment: ["TERM_PROGRAM": "iTerm.app"]), "iTerm2")
    XCTAssertEqual(TerminalApp.name(environment: ["TERM_PROGRAM": "Apple_Terminal"]), "Terminal")
    XCTAssertEqual(TerminalApp.name(environment: ["TERM_PROGRAM": "ghostty"]), "Ghostty")
    XCTAssertEqual(TerminalApp.name(environment: ["TERM_PROGRAM": "SomethingNew"]), "SomethingNew")
    XCTAssertEqual(TerminalApp.name(environment: ["TERM_PROGRAM": "vscode", "TMUX": "/tmp/tmux-501/default,1,0"]), "VS Code · tmux")
    XCTAssertEqual(TerminalApp.name(environment: ["TERM_PROGRAM": "tmux", "TMUX": "x"]), "tmux")
    XCTAssertNil(TerminalApp.name(environment: [:]))
  }

  func testClaudeCommandDetection() {
    XCTAssertTrue(ProcessReader.isClaudeCommand(["claude", "--dangerously-skip-permissions"]))
    XCTAssertTrue(ProcessReader.isClaudeCommand(["/Users/me/.local/bin/claude"]))
    XCTAssertTrue(ProcessReader.isClaudeCommand(["node", "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"]))
    XCTAssertFalse(ProcessReader.isClaudeCommand(["node", "server.js"]))
    XCTAssertFalse(ProcessReader.isClaudeCommand(["claude-status-bar"]))
  }
}
