import OneUpCore
import SwiftUI

/// Every session, by state. Rows are 44 pt; the footer stays while rows scroll.
struct PanelView: View {
  @Bindable var model: AppModel
  let maxHeight: CGFloat
  let actions: PanelActions
  /// The offscreen preview renders the rows without a ScrollView, which ImageRenderer leaves blank.
  var scrolls = true
  @FocusState private var focused: Bool

  private var tints: Tints { Tints.forAppearance(dark: true) }

  var body: some View {
    VStack(spacing: 0) {
      if model.snapshot.cannotTell {
        cannotTell
      } else if model.snapshot.rows.isEmpty {
        Text("No Claude Code sessions running. Start **claude** in any terminal and it shows up here.")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else if scrolls {
        ScrollViewReader { proxy in
          ScrollView {
            rowList
          }
          .frame(maxHeight: maxHeight - 44)
          .onChange(of: model.selectedKey) { _, key in
            if let key { withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(key, anchor: .center) } }
          }
        }
        .fixedSize(horizontal: false, vertical: true)
      } else {
        rowList
      }
      footer
    }
    .font(.system(size: 13))
    .focusable()
    .focusEffectDisabled()
    .focused($focused)
    .onAppear { focused = true }
    .onKeyPress(.upArrow) { move(-1); return .handled }
    .onKeyPress(.downArrow) { move(1); return .handled }
    .onKeyPress(.return) { activateSelected(); return .handled }
    .onKeyPress(.escape) { actions.close(); return .handled }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("1UP sessions")
  }

  private var rowList: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(StateGroup.allCases, id: \.self) { group in
        let rows = model.snapshot.rows(in: group)
        if !rows.isEmpty {
          groupLabel(group, count: rows.count)
          if group != .idle || model.idleOpen {
            ForEach(rows) { row in
              SessionRowView(row: row, now: model.now, selected: model.selectedKey == row.key) {
                activate(row)
              }
              .id(row.key)
            }
          }
        }
      }
    }
    .padding(6)
  }

  private var cannotTell: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Can't read Claude Code status").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(nsColor: tints.fail))
      Text(model.snapshot.folderError ?? "The sessions folder can't be read. Check my setup shows which folder and why.")
        .font(.system(size: 12)).foregroundStyle(.secondary)
      if let last = model.snapshot.lastGoodRead {
        Text("Last good read \(TimeFormat.age(ms: model.now - last)) ago.").font(.system(size: 12)).foregroundStyle(.secondary)
      }
      HStack(spacing: 8) {
        Button("Retry") { model.retry() }
        Button("Check my setup…") { actions.checkSetup() }
      }
      .controlSize(.small)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func groupLabel(_ group: StateGroup, count: Int) -> some View {
    HStack(spacing: 6) {
      Image(nsImage: ThemeArt.glyph(theme: model.theme, kind: group, tints: tints, ink: .labelColor))
        .interpolation(.none)
        .frame(width: 14, height: 14)
      if group == .idle {
        Button {
          model.idleOpen.toggle()
        } label: {
          Text("Idle (\(count)) \(model.idleOpen ? "▾" : "▸")")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.idleOpen ? "Hide idle sessions" : "Show \(count) idle sessions")
      } else {
        Text(title(for: group))
      }
    }
    .font(.system(size: 11, weight: .semibold))
    .foregroundStyle(.secondary)
    .padding(EdgeInsets(top: 10, leading: 8, bottom: 4, trailing: 8))
    .accessibilityAddTraits(.isHeader)
  }

  private func title(for group: StateGroup) -> String {
    switch group {
    case .needsYou: return "Needs you"
    case .done: return "Done"
    case .working: return "Working"
    case .idle: return "Idle"
    }
  }

  private var footer: some View {
    HStack {
      Button("Mark all looked at") { model.markAllLookedAt() }
        .disabled(model.counts.done == 0)
      Spacer()
      Button {
        actions.openSettings()
      } label: {
        Label("Settings", systemImage: "gearshape").labelStyle(.titleAndIcon)
      }
      .accessibilityLabel("Settings")
    }
    .buttonStyle(.plain)
    .font(.system(size: 12))
    .foregroundStyle(.secondary)
    .padding(EdgeInsets(top: 8, leading: 14, bottom: 9, trailing: 14))
    .overlay(alignment: .top) { Divider() }
  }

  private func move(_ delta: Int) {
    let rows = model.orderedRows
    guard !rows.isEmpty else { return }
    let current = rows.firstIndex { $0.key == model.selectedKey }
    let next = current.map { min(max($0 + delta, 0), rows.count - 1) } ?? (delta > 0 ? 0 : rows.count - 1)
    model.selectedKey = rows[next].key
  }

  private func activateSelected() {
    guard let row = model.orderedRows.first(where: { $0.key == model.selectedKey }) else { return }
    activate(row)
  }

  /// Clicking (or Return on) a Done row marks it looked at. Other rows have no action in v1.
  private func activate(_ row: SessionRow) {
    model.selectedKey = row.key
    if row.state.isDone { model.markLookedAt(key: row.key) }
  }
}

struct SessionRowView: View {
  let row: SessionRow
  let now: Int64
  let selected: Bool
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 1) {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          Text(row.title).font(.system(size: 13)).lineLimit(1).truncationMode(.tail)
          Spacer(minLength: 0)
          Text(row.timeColumn(now: now)).font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary)
        }
        Text(row.subLine).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
      }
      .padding(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
      .frame(height: 44)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(background))
      .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(voiceOver)
    .accessibilityAddTraits(row.state.isDone ? .isButton : .isStaticText)
  }

  private var background: Color {
    if selected { return Color.accentColor.opacity(0.28) }
    if hovering { return Color.primary.opacity(0.08) }
    return .clear
  }

  /// "Fix the quiz tally, needs you, wants approval, waiting 1 minute, quiz-matrix in VS Code"
  private var voiceOver: String {
    var parts = [row.title]
    switch row.state {
    case .needsYou(let r): parts += ["needs you", r.line.lowercased(), "waiting \(TimeFormat.spokenAge(ms: now - row.since))"]
    case .done(let k): parts += ["done", k.line.lowercased(), "\(TimeFormat.spokenAge(ms: now - row.since)) ago"]
    case .working: parts += ["working", "for \(TimeFormat.spokenAge(ms: now - row.since))"]
    case .idle(let shell): parts.append(shell ? "idle, background shell running" : "idle")
    case .unknown(let reason, _): parts += ["can't tell", reason]
    }
    parts.append(row.app.map { "\(row.folder) in \($0)" } ?? row.folder)
    return parts.joined(separator: ", ")
  }
}
