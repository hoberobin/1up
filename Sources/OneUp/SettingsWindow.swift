import AppKit
import OneUpCore
import SwiftUI

/// One 480 pt window, no tabs: Open at login · Theme tiles · Check my setup · footer.
@MainActor
final class SettingsWindowController: NSWindowController {
  init(model: AppModel, actions: SettingsActions) {
    let hosting = NSHostingController(rootView: SettingsView(model: model, actions: actions))
    let window = NSWindow(contentViewController: hosting)
    window.title = "1UP Settings"
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.setContentSize(NSSize(width: 480, height: 420))
    window.isReleasedWhenClosed = false
    super.init(window: window)
  }

  required init?(coder: NSCoder) { fatalError("not used") }

  func show() {
    window?.center()
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }
}

struct SettingsActions {
  var checkForUpdates: () -> Void = {}
}

struct SettingsView: View {
  @Bindable var model: AppModel
  let actions: SettingsActions
  var startChecked = false
  @State private var openAtLogin = Prefs.openAtLogin
  @State private var checked = false

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 4) {
        Toggle("Open at login", isOn: $openAtLogin)
          .onChange(of: openAtLogin) { _, on in
            if !LoginItem.set(on) { openAtLogin = false }
            if checked { model.runSetupCheck() }
          }
        if let err = LoginItem.lastError {
          Text(err).font(.system(size: 11)).foregroundStyle(.secondary)
        }
      }
      VStack(alignment: .leading, spacing: 8) {
        Text("Theme")
        // Five 88 pt tiles with 6 pt gaps fill the 480 pt window edge to edge, so the row uses its own margins.
        HStack(alignment: .top, spacing: 6) {
          ForEach(model.themes) { theme in
            ThemeTile(theme: theme, selected: theme.id == model.theme.id) { model.selectTheme(id: theme.id) }
          }
        }
        .padding(.horizontal, -12)
      }
      VStack(alignment: .leading, spacing: 8) {
        Button("Check my setup") {
          model.runSetupCheck()
          checked = true
        }
        if checked {
          ForEach(model.setupResults) { r in
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Image(systemName: r.pass ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(r.pass ? .green : .orange)
              VStack(alignment: .leading, spacing: 2) {
                Text(r.title).font(.system(size: 12, weight: .semibold))
                Text(r.detail).font(.system(size: 12)).foregroundStyle(.secondary).textSelection(.enabled)
              }
              Spacer()
              if r.fix == .openLoginItems {
                Button("Open Login Items") { LoginItem.openSystemSettings() }.controlSize(.small)
              }
            }
          }
        }
      }
      Spacer(minLength: 0)
      HStack(spacing: 6) {
        Text("1UP \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
        Text("·")
        Button("Check for Updates") { actions.checkForUpdates() }.buttonStyle(.link)
        Text("·")
        Link("GitHub", destination: URL(string: "https://github.com/masterytrack/1up")!)
      }
      .font(.system(size: 12))
      .foregroundStyle(.secondary)
    }
    .padding(20)
    .frame(width: 480, alignment: .leading)
    .frame(minHeight: 380)
    .onAppear {
      openAtLogin = LoginItem.isEnabled || (Prefs.openAtLogin && LoginItem.status == .requiresApproval)
      if startChecked { checked = true }
    }
  }
}

/// 88 × 56 live tile with an accent ring on the current one.
struct ThemeTile: View {
  let theme: Theme
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        TimelineView(.periodic(from: .now, by: 1.0 / Double(theme.fps))) { context in
          let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
          let frame = reduce ? theme.idleFrame : Int(context.date.timeIntervalSinceReferenceDate * Double(theme.fps)) % theme.frameCount
          Image(nsImage: ThemeArt.tile(theme: theme, frame: frame))
            .interpolation(.none)
            .frame(width: 88, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 2))
        }
        Text(theme.name).font(.system(size: 11, weight: selected ? .semibold : .regular))
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(theme.name) theme\(theme.after.map { ", after \($0)" } ?? "")")
    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
  }
}
