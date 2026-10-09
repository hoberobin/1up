import Foundation

/// Settings keys: `openAtLogin = true` · `theme = "chomp"`, plus two one-time flags.
@MainActor
enum Prefs {
  private static let d = UserDefaults.standard

  static var openAtLogin: Bool {
    get { d.object(forKey: "openAtLogin") as? Bool ?? true }
    set { d.set(newValue, forKey: "openAtLogin") }
  }
  static var theme: String {
    get { d.string(forKey: "theme") ?? "chomp" }
    set { d.set(newValue, forKey: "theme") }
  }
  static var welcomeShown: Bool {
    get { d.bool(forKey: "welcomeShown") }
    set { d.set(newValue, forKey: "welcomeShown") }
  }
  static var moveDeclined: Bool {
    get { d.bool(forKey: "moveDeclined") }
    set { d.set(newValue, forKey: "moveDeclined") }
  }
}
