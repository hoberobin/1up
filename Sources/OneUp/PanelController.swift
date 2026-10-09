import AppKit
import OneUpCore
import SwiftUI

/// A non-activating panel under the item, 340 pt wide, max 70% of the screen or 520 pt.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
  static let width: CGFloat = 340
  static let maxHeight: CGFloat = 520

  private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
  }

  private let model: AppModel
  private let panel: KeyablePanel
  private let hosting: NSHostingView<PanelRoot>
  private var clickMonitor: Any?
  private var clock: Timer?
  private var closedAt: Date = .distantPast
  var onOpenSettings: (() -> Void)?
  var onCheckSetup: (() -> Void)?

  var isVisible: Bool { panel.isVisible }

  init(model: AppModel) {
    self.model = model
    panel = KeyablePanel(contentRect: NSRect(x: 0, y: 0, width: PanelController.width, height: 200), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    hosting = NSHostingView(rootView: PanelRoot(model: model, maxHeight: PanelController.maxHeight, actions: .init()))
    super.init()
    panel.isFloatingPanel = true
    panel.level = .popUpMenu
    panel.hidesOnDeactivate = false
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.isMovableByWindowBackground = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    panel.delegate = self
    panel.animationBehavior = .utilityWindow

    let effect = NSVisualEffectView()
    effect.material = .popover
    effect.state = .active
    effect.blendingMode = .behindWindow
    effect.wantsLayer = true
    effect.layer?.cornerRadius = 12
    effect.layer?.cornerCurve = .continuous
    effect.layer?.masksToBounds = true
    effect.layer?.borderWidth = 1
    effect.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
    effect.translatesAutoresizingMaskIntoConstraints = false
    hosting.translatesAutoresizingMaskIntoConstraints = false
    effect.addSubview(hosting)
    NSLayoutConstraint.activate([
      hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
      hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
      hosting.topAnchor.constraint(equalTo: effect.topAnchor),
      hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
    ])
    panel.contentView = effect
    hosting.rootView = PanelRoot(model: model, maxHeight: PanelController.maxHeight, actions: .init(
      close: { [weak self] in self?.close() },
      openSettings: { [weak self] in self?.close(); self?.onOpenSettings?() },
      checkSetup: { [weak self] in self?.close(); self?.onCheckSetup?() },
      resized: { [weak self] size in self?.fit(to: size) }))
  }

  func toggle(relativeTo button: NSStatusBarButton?) {
    if panel.isVisible { close() } else if Date().timeIntervalSince(closedAt) > 0.25 { open(relativeTo: button) }
  }

  func open(relativeTo button: NSStatusBarButton?) {
    model.tickClock()
    model.selectedKey = nil
    anchorButton = button
    fit(to: hosting.fittingSize)
    panel.makeKeyAndOrderFront(nil)
    clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.model.tickClock() }
    }
    clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
      Task { @MainActor in self?.close() }
    }
  }

  func close() {
    guard panel.isVisible else { return }
    panel.orderOut(nil)
    closedAt = Date()
    clock?.invalidate()
    clock = nil
    if let m = clickMonitor { NSEvent.removeMonitor(m) }
    clickMonitor = nil
  }

  private weak var anchorButton: NSStatusBarButton?

  /// Sized to content, capped, and placed under the status item (clamped to the screen).
  private func fit(to size: CGSize) {
    guard let button = anchorButton, let window = button.window else { return }
    let screen = window.screen ?? NSScreen.main
    let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let cap = min(PanelController.maxHeight, floor(visible.height * 0.7))
    let height = min(max(size.height, 60), cap)
    let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
    var x = buttonFrame.midX - PanelController.width / 2
    x = min(max(x, visible.minX + 8), visible.maxX - PanelController.width - 8)
    let y = buttonFrame.minY - 6 - height
    panel.setFrame(NSRect(x: round(x), y: round(y), width: PanelController.width, height: round(height)), display: true)
  }

  func windowDidResignKey(_ notification: Notification) { close() }
}

struct PanelActions {
  var close: () -> Void = {}
  var openSettings: () -> Void = {}
  var checkSetup: () -> Void = {}
  var resized: (CGSize) -> Void = { _ in }
}

struct PanelRoot: View {
  let model: AppModel
  let maxHeight: CGFloat
  let actions: PanelActions
  var scrolls = true

  var body: some View {
    PanelView(model: model, maxHeight: maxHeight, actions: actions, scrolls: scrolls)
      .frame(width: PanelController.width)
      .background(GeometryReader { proxy in Color.clear.preference(key: PanelSizeKey.self, value: proxy.size) })
      .onPreferenceChange(PanelSizeKey.self) { size in actions.resized(size) }
  }
}

struct PanelSizeKey: PreferenceKey {
  static let defaultValue = CGSize.zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}
