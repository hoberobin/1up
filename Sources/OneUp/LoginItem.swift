import Foundation
import ServiceManagement

/// Open at login via SMAppService. Registration only works from a real .app bundle.
@MainActor
enum LoginItem {
  static var lastError: String?

  static var status: SMAppService.Status { SMAppService.mainApp.status }

  static var isEnabled: Bool { status == .enabled }

  static func set(_ on: Bool) {
    lastError = nil
    do {
      if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    } catch {
      lastError = error.localizedDescription
    }
    Prefs.openAtLogin = on
  }

  /// Applies the saved preference at launch, once the app lives in Applications.
  static func applyPreference() {
    guard Prefs.openAtLogin, Bundle.main.bundlePath.hasSuffix(".app") else { return }
    if status != .enabled && status != .requiresApproval { set(true) }
  }

  static func openSystemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }
}
