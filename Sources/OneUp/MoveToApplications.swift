import AppKit

/// "Move 1UP to Applications? It needs to be there to open at login." Move and Relaunch · Not Now.
@MainActor
enum MoveToApplications {
  static var isInApplications: Bool {
    let path = Bundle.main.bundlePath
    return path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
  }

  static func offerIfNeeded() {
    let path = Bundle.main.bundlePath
    guard path.hasSuffix(".app"), !isInApplications, !Prefs.moveDeclined else { return }
    let alert = NSAlert()
    alert.messageText = "Move 1UP to Applications?"
    alert.informativeText = "It needs to be there to open at login."
    alert.addButton(withTitle: "Move and Relaunch")
    alert.addButton(withTitle: "Not Now")
    NSApp.activate(ignoringOtherApps: true)
    if alert.runModal() == .alertFirstButtonReturn {
      do { try moveAndRelaunch(from: URL(fileURLWithPath: path)) } catch {
        let failed = NSAlert(error: error)
        failed.runModal()
      }
    } else {
      Prefs.moveDeclined = true
    }
  }

  private static func moveAndRelaunch(from source: URL) throws {
    let dest = URL(fileURLWithPath: "/Applications/1UP.app")
    let fm = FileManager.default
    if fm.fileExists(atPath: dest.path) { try fm.trashItem(at: dest, resultingItemURL: nil) }
    try fm.copyItem(at: source, to: dest)
    let config = NSWorkspace.OpenConfiguration()
    config.createsNewApplicationInstance = true
    NSWorkspace.shared.openApplication(at: dest, configuration: config) { _, _ in
      DispatchQueue.main.async { NSApp.terminate(nil) }
    }
  }
}
