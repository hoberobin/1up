import AppKit
import OneUpCore

/// The menu bar item: renders the active theme, animates at the theme's fps while anything works,
/// and routes left click to the panel and right click to the menu.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
  let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let model: AppModel
  private var frame = 0
  private var animationTimer: Timer?
  private var heartbeat: Timer?
  private var screenLocked = false
  var onLeftClick: (() -> Void)?
  var onOpenSettings: (() -> Void)?
  var onCheckForUpdates: (() -> Void)?

  init(model: AppModel) {
    self.model = model
    super.init()
    guard let button = item.button else { return }
    button.target = self
    button.action = #selector(clicked(_:))
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    button.imagePosition = .imageOnly
    button.setAccessibilityRole(.menuButton)
    render()
    heartbeat = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.render() }
    }
    let dnc = DistributedNotificationCenter.default()
    dnc.addObserver(self, selector: #selector(screenDidLock), name: Notification.Name("com.apple.screenIsLocked"), object: nil)
    dnc.addObserver(self, selector: #selector(screenDidUnlock), name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(accessibilityChanged), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
  }

  var isDarkMenuBar: Bool {
    let appearance = item.button?.effectiveAppearance ?? NSApp.effectiveAppearance
    return appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
  }

  /// The menu bar's own text colour, as the item's appearance resolves it.
  var inkColor: NSColor {
    let appearance = item.button?.effectiveAppearance ?? NSApp.effectiveAppearance
    var color = NSColor.labelColor
    appearance.performAsCurrentDrawingAppearance { color = NSColor.labelColor.usingColorSpace(.sRGB) ?? NSColor.labelColor }
    return color
  }

  private var lastLabel = ""
  private var lastHint: String?

  func render() {
    let counts = model.counts
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    let animating = counts.working > 0 && !model.snapshot.cannotTell && !reduceMotion && !screenLocked
    updateAnimation(running: animating)
    let image = StatusImageRenderer.render(.init(
      theme: model.theme, counts: counts, cannotTell: model.snapshot.cannotTell, frame: frame, dark: isDarkMenuBar,
      ink: inkColor, increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast, reduceMotion: reduceMotion))
    guard let button = item.button else { return }
    if button.image !== image { button.image = image }
    let label = model.accessibilityLabel, hint = model.accessibilityHint
    if label != lastLabel || hint != lastHint {
      lastLabel = label
      lastHint = hint
      button.setAccessibilityLabel(label)
      button.setAccessibilityHelp(hint)
      button.toolTip = label.replacingOccurrences(of: "1UP: ", with: "1UP · ")
    }
  }

  private func updateAnimation(running: Bool) {
    if running, animationTimer == nil {
      let interval = 1.0 / Double(model.theme.fps)
      animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
        Task { @MainActor in
          guard let self else { return }
          self.frame += 1
          self.render()
        }
      }
    } else if !running, let t = animationTimer {
      t.invalidate()
      animationTimer = nil
      frame = 0
    }
  }

  @objc private func clicked(_ sender: Any?) {
    let event = NSApp.currentEvent
    if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
      showMenu()
    } else {
      onLeftClick?()
    }
  }

  @objc private func screenDidLock() { screenLocked = true; render() }
  @objc private func screenDidUnlock() { screenLocked = false; render() }
  @objc private func accessibilityChanged() { render() }

  // MARK: Menu · Open Panel · Mark All Looked At · — · Theme ▸ · Settings… ⌘, · — · Check for Updates… · Quit 1UP ⌘Q

  func showMenu() {
    let menu = NSMenu()
    menu.delegate = self
    menu.addItem(withTitle: "Open Panel", action: #selector(openPanel), keyEquivalent: "").target = self
    let mark = menu.addItem(withTitle: "Mark All Looked At", action: #selector(markAll), keyEquivalent: "")
    mark.target = self
    mark.isEnabled = model.counts.done > 0
    menu.addItem(.separator())
    let themeItem = menu.addItem(withTitle: "Theme", action: nil, keyEquivalent: "")
    let themeMenu = NSMenu()
    for theme in model.themes {
      let mi = themeMenu.addItem(withTitle: theme.name, action: #selector(pickTheme(_:)), keyEquivalent: "")
      mi.target = self
      mi.representedObject = theme.id
      mi.state = theme.id == model.theme.id ? .on : .off
      mi.image = ThemeArt.glyph(theme: theme, kind: .working, tints: Tints.forAppearance(dark: true), ink: .labelColor)
    }
    themeItem.submenu = themeMenu
    let settings = menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
    settings.target = self
    menu.addItem(.separator())
    menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "").target = self
    let quit = menu.addItem(withTitle: "Quit 1UP", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    quit.target = NSApp
    guard let button = item.button else { return }
    menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
  }

  @objc private func openPanel() { onLeftClick?() }
  @objc private func markAll() { model.markAllLookedAt() }
  @objc private func openSettings() { onOpenSettings?() }
  @objc private func checkForUpdates() { onCheckForUpdates?() }
  @objc private func pickTheme(_ sender: NSMenuItem) {
    guard let id = sender.representedObject as? String else { return }
    model.selectTheme(id: id)
    frame = 0
    render()
  }
}
