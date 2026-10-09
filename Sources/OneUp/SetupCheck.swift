import Foundation
import OneUpCore
import ServiceManagement

struct SetupResult: Identifiable, Equatable {
  enum Fix: Equatable { case openLoginItems }
  var id: String { title }
  var title: String
  var pass: Bool
  var detail: String
  var fix: Fix?
}

/// Three checks that cover what 1UP depends on, each saying plainly what is wrong.
@MainActor
enum SetupCheck {
  static let oldestSupported = "2.1.261"
  static let newestTested = "2.1.295"

  static func run(snapshot: Snapshot, themeProblems: [String]) -> [SetupResult] {
    var results = [sessions(snapshot), version(snapshot), login()]
    if !themeProblems.isEmpty {
      results.append(SetupResult(title: "Themes", pass: false, detail: "Skipped: " + themeProblems.joined(separator: "; "), fix: nil))
    }
    return results
  }

  static func sessions(_ s: Snapshot) -> SetupResult {
    if let err = s.folderError {
      return SetupResult(title: "Sessions", pass: false, detail: err, fix: nil)
    }
    let n = s.rows.count, k = s.configDirs.count
    return SetupResult(title: "Sessions", pass: true, detail: "Found \(n) session\(n == 1 ? "" : "s") in \(k) config folder\(k == 1 ? "" : "s")", fix: nil)
  }

  static func version(_ s: Snapshot) -> SetupResult {
    let versions = s.versions.sorted(by: versionLess)
    guard let newest = versions.last else {
      return SetupResult(title: "Claude Code version", pass: true, detail: "No sessions yet, so the version is unknown. Tested with \(newestTested).", fix: nil)
    }
    if let old = versions.first, versionLess(old, oldestSupported) {
      return SetupResult(title: "Claude Code version", pass: false, detail: "Update Claude Code to see status (\(old) is older than \(oldestSupported))", fix: nil)
    }
    if versionLess(newestTested, newest) {
      return SetupResult(title: "Claude Code version", pass: true, detail: "New version \(newest), not yet verified (still working)", fix: nil)
    }
    return SetupResult(title: "Claude Code version", pass: true, detail: "Tested with \(newest)", fix: nil)
  }

  static func login() -> SetupResult {
    switch LoginItem.status {
    case .enabled: return SetupResult(title: "Login", pass: true, detail: "Opens at login", fix: nil)
    case .requiresApproval: return SetupResult(title: "Login", pass: false, detail: "macOS is holding 1UP for approval", fix: .openLoginItems)
    case .notFound: return SetupResult(title: "Login", pass: false, detail: "1UP must run from Applications to open at login", fix: nil)
    default:
      return Prefs.openAtLogin
        ? SetupResult(title: "Login", pass: false, detail: LoginItem.lastError ?? "Not registered to open at login yet", fix: nil)
        : SetupResult(title: "Login", pass: true, detail: "Open at login is off", fix: nil)
    }
  }

  static func versionLess(_ a: String, _ b: String) -> Bool {
    let pa = a.split(separator: ".").map { Int($0) ?? 0 }, pb = b.split(separator: ".").map { Int($0) ?? 0 }
    for i in 0..<max(pa.count, pb.count) {
      let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
      if x != y { return x < y }
    }
    return false
  }
}
