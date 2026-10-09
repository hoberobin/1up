import AppKit
import OneUpCore
import SwiftUI

/// First-launch card anchored to the item. Says what was found and what the colours mean; Got it closes it.
@MainActor
final class WelcomeController {
  private let popover = NSPopover()

  init(model: AppModel, done: @escaping () -> Void) {
    popover.behavior = .semitransient
    popover.contentViewController = NSHostingController(rootView: WelcomeView(model: model) { [popover] in
      popover.performClose(nil)
      done()
    })
  }

  func show(relativeTo button: NSStatusBarButton?) {
    guard let button else { return }
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
  }
}

struct WelcomeView: View {
  let model: AppModel
  let gotIt: () -> Void

  var body: some View {
    let n = model.snapshot.rows.count
    let unreadable = model.snapshot.rows.filter { if case .unknown = $0.state { return true } else { return false } }.count
    VStack(alignment: .leading, spacing: 10) {
      Text("1UP is watching \(n) Claude Code session\(n == 1 ? "" : "s")").font(.system(size: 15, weight: .semibold))
      check("Found \(n) session\(n == 1 ? "" : "s")", ok: true)
      check(unreadable == 0 ? "Every session read correctly" : "\(unreadable) session\(unreadable == 1 ? "" : "s") couldn't be read", ok: unreadable == 0)
      Text("Opens at login. Change it in Settings.").font(.system(size: 11)).foregroundStyle(.secondary)
      Text("Can't see the icon? ⌘-drag it left in the menu bar.").font(.system(size: 11)).foregroundStyle(.secondary)
      Text("The scene plays while sessions work. An orange icon means one needs you, a green one means a turn ended. Click the icon to see which session and where it's running.")
        .font(.system(size: 11)).foregroundStyle(.secondary)
      HStack { Spacer(); Button("Got it", action: gotIt).keyboardShortcut(.defaultAction) }
    }
    .padding(16)
    .frame(width: 320)
  }

  private func check(_ text: String, ok: Bool) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(ok ? "✓" : "!").foregroundStyle(ok ? .green : .orange).fontWeight(.bold)
      Text(text)
    }
    .font(.system(size: 13))
  }
}
