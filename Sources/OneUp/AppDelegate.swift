import AppKit
import OneUpCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var model: AppModel!
  private var store: SessionStore!
  private var statusItem: StatusItemController!
  private var panel: PanelController!
  private var settings: SettingsWindowController?
  private var welcome: WelcomeController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let themesURL = ThemeLoader.locateBuiltIn(executableURL: Bundle.main.executableURL, resourceURL: Bundle.main.resourceURL)
    let loaded: (themes: [Theme], problems: [String]) = themesURL.map { ThemeLoader.loadAll(root: $0) } ?? ([], ["No Themes folder found next to the app"])
    model = AppModel(themes: loaded.themes, problems: loaded.problems)
    let model = self.model!

    let home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude", isDirectory: true)
    let firstLaunch = StateStore.load(from: StateStore.defaultURL()) == nil
    store = SessionStore(homeConfigDir: home, stateURL: StateStore.defaultURL(), logDirectory: ChangeLog.defaultDirectory()) { snap in
      Task { @MainActor in model.apply(snap) }
    }
    model.store = store

    statusItem = StatusItemController(model: model)
    panel = PanelController(model: model)
    statusItem.onLeftClick = { [weak self] in
      guard let self else { return }
      self.panel.toggle(relativeTo: self.statusItem.item.button)
    }
    statusItem.onOpenSettings = { [weak self] in self?.showSettings() }
    statusItem.onCheckForUpdates = { [weak self] in self?.checkForUpdates() }
    panel.onOpenSettings = { [weak self] in self?.showSettings() }
    panel.onCheckSetup = { [weak self] in
      self?.model.runSetupCheck()
      self?.showSettings(runCheck: true)
    }

    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)

    Task {
      await store.start()
      MoveToApplications.offerIfNeeded()
      LoginItem.applyPreference()
      if firstLaunch || !Prefs.welcomeShown {
        try? await Task.sleep(for: .milliseconds(600))
        welcome = WelcomeController(model: model) { Prefs.welcomeShown = true }
        welcome?.show(relativeTo: statusItem.item.button)
      }
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    let store = self.store
    Task { await store?.stop() }
  }

  @objc private func didWake() {
    Task { await store.refresh(force: true) }
  }

  private func showSettings(runCheck: Bool = false) {
    if settings == nil {
      settings = SettingsWindowController(model: model, actions: .init(checkForUpdates: { [weak self] in self?.checkForUpdates() }))
    }
    if runCheck { model.runSetupCheck() }
    settings?.show()
  }

  /// Sparkle lands with the signed release; until then this opens the Releases page.
  private func checkForUpdates() {
    NSWorkspace.shared.open(URL(string: "https://github.com/masterytrack/1up/releases")!)
  }
}
