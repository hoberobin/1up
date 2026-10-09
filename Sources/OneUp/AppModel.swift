import AppKit
import Observation
import OneUpCore

/// UI state for the menu bar item, panel and settings. Everything here is read on the main actor.
@MainActor
@Observable
final class AppModel {
  var snapshot = Snapshot()
  var now: Int64 = SessionEngine.nowMs()
  var themes: [Theme]
  var themeProblems: [String]
  var theme: Theme
  var idleOpen = false
  var selectedKey: String?
  var setupResults: [SetupResult] = []
  var store: SessionStore?

  init(themes: [Theme], problems: [String]) {
    self.themes = themes
    self.themeProblems = problems
    let wanted = Prefs.theme
    guard let first = themes.first(where: { $0.id == wanted }) ?? themes.first(where: { $0.id == Theme.fallbackID }) ?? themes.first else {
      fatalError("No theme folder could be loaded: \(problems.joined(separator: "; "))")
    }
    theme = first
  }

  var counts: Counts { snapshot.counts }

  func selectTheme(id: String) {
    guard let t = themes.first(where: { $0.id == id }) else { return }
    theme = t
    Prefs.theme = id
  }

  func apply(_ snap: Snapshot) {
    snapshot = snap
    now = snap.now
    if let key = selectedKey, !snap.rows.contains(where: { $0.key == key }) { selectedKey = nil }
  }

  func tickClock() { now = SessionEngine.nowMs() }

  /// Rows in panel order: Needs you, Done, Working, Idle.
  var orderedRows: [SessionRow] {
    StateGroup.allCases.flatMap { group in group == .idle && !idleOpen ? [] : snapshot.rows(in: group) }
  }

  func markLookedAt(key: String) {
    guard let store else { return }
    Task { await store.markLookedAt(key: key) }
  }

  func markAllLookedAt() {
    guard let store else { return }
    Task { await store.markAllLookedAt() }
  }

  func retry() {
    guard let store else { return }
    Task { await store.refresh(force: true) }
  }

  func runSetupCheck() {
    setupResults = SetupCheck.run(snapshot: snapshot, themeProblems: themeProblems)
  }

  /// "1UP: 2 working, 1 needs you, 3 done" for VoiceOver.
  var accessibilityLabel: String {
    if snapshot.cannotTell { return "1UP: can't read Claude Code status" }
    let c = counts
    if c.isEmpty { return "1UP: nothing running" }
    var parts: [String] = []
    if c.working > 0 { parts.append("\(c.working) working") }
    if c.needsYou > 0 { parts.append(c.needsYou == 1 ? "1 needs you" : "\(c.needsYou) need you") }
    if c.done > 0 { parts.append("\(c.done) done") }
    return "1UP: " + parts.joined(separator: ", ")
  }

  var accessibilityHint: String? {
    guard let oldest = counts.oldestWaitingMs else { return nil }
    return "oldest waiting \(TimeFormat.spokenAge(ms: oldest))"
  }
}
