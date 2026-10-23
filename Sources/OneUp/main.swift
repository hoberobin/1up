import AppKit
import OneUpCore

if let i = CommandLine.arguments.firstIndex(of: "--render-preview"), i + 1 < CommandLine.arguments.count {
  let out = URL(fileURLWithPath: CommandLine.arguments[i + 1])
  let root = ThemeLoader.locateBuiltIn(executableURL: Bundle.main.executableURL, resourceURL: Bundle.main.resourceURL)
  let themes = root.map { ThemeLoader.loadAll(root: $0).themes } ?? []
  do {
    try PreviewSheet.render(themes: themes, to: out)
    print("wrote \(out.path) (\(themes.count) themes)")
  } catch {
    print("preview failed: \(error)")
    exit(1)
  }
  exit(0)
}

if let i = CommandLine.arguments.firstIndex(of: "--render-panel"), i + 1 < CommandLine.arguments.count {
  let out = URL(fileURLWithPath: CommandLine.arguments[i + 1])
  let root = ThemeLoader.locateBuiltIn(executableURL: Bundle.main.executableURL, resourceURL: Bundle.main.resourceURL)
  let loaded: (themes: [Theme], problems: [String]) = root.map { ThemeLoader.loadAll(root: $0) } ?? ([], [])
  do {
    try PreviewSheet.renderPanel(themes: loaded.themes, problems: loaded.problems, to: out)
    print("wrote \(out.path)")
  } catch {
    print("panel preview failed: \(error)")
    exit(1)
  }
  exit(0)
}

if let i = CommandLine.arguments.firstIndex(of: "--render-all"), i + 1 < CommandLine.arguments.count {
  let out = URL(fileURLWithPath: CommandLine.arguments[i + 1], isDirectory: true)
  let root = ThemeLoader.locateBuiltIn(executableURL: Bundle.main.executableURL, resourceURL: Bundle.main.resourceURL)
  let loaded: (themes: [Theme], problems: [String]) = root.map { ThemeLoader.loadAll(root: $0) } ?? ([], [])
  do {
    try PreviewSheet.renderAll(themes: loaded.themes, problems: loaded.problems, to: out)
    print("wrote \(out.path)")
  } catch {
    print("render-all failed: \(error)")
    exit(1)
  }
  exit(0)
}

if let i = CommandLine.arguments.firstIndex(of: "--render-icon"), i + 1 < CommandLine.arguments.count {
  let out = URL(fileURLWithPath: CommandLine.arguments[i + 1], isDirectory: true)
  let root = ThemeLoader.locateBuiltIn(executableURL: Bundle.main.executableURL, resourceURL: Bundle.main.resourceURL)
  let themes = root.map { ThemeLoader.loadAll(root: $0).themes } ?? []
  do {
    try PreviewSheet.renderIconSet(themes: themes, to: out)
    print("wrote \(out.appendingPathComponent("AppIcon.iconset").path)")
  } catch {
    print("icon failed: \(error)")
    exit(1)
  }
  exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
_ = app.setActivationPolicy(.accessory)
app.run()
