import Foundation
import ServiceManagement

/// Open at login via SMAppService. Registration only works from a real .app bundle.
@MainActor
enum LoginItem {
  static var lastError: String?

  static var status: SMAppService.Status { SMAppService.mainApp.status }

  static var isEnabled: Bool { status == .enabled }

  /// Registers only from Applications: a login item pointing at Downloads breaks the moment the app moves.
  @discardableResult
  static func set(_ on: Bool) -> Bool {
    lastError = nil
    Prefs.openAtLogin = on
    if on && !MoveToApplications.isInApplications {
      lastError = "Move 1UP to Applications first, then turn this on."
      return false
    }
    do {
      if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
      return true
    } catch {
      lastError = error.localizedDescription
      return false
    }
  }

  /// Applies the saved preference at launch, once the app lives in Applications.
  static func applyPreference() {
    guard Prefs.openAtLogin, MoveToApplications.isInApplications else { return }
    if status != .enabled && status != .requiresApproval { set(true) }
  }

  static func openSystemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }
}
