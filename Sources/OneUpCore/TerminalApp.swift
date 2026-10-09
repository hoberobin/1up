import Foundation

/// Names the app a session runs in from its environment. Unknown values show the raw name.
public enum TerminalApp {
  public static func name(environment env: [String: String]) -> String? {
    var base: String?
    switch env["TERM_PROGRAM"] {
    case "vscode":
      base = (env["__CFBundleIdentifier"] ?? "").lowercased().contains("cursor") ? "Cursor" : "VS Code"
      if (env["__CFBundleIdentifier"] ?? "").lowercased().contains("windsurf") { base = "Windsurf" }
    case "iTerm.app": base = "iTerm2"
    case "Apple_Terminal": base = "Terminal"
    case "WarpTerminal": base = "Warp"
    case "ghostty": base = "Ghostty"
    case "WezTerm": base = "WezTerm"
    case "Hyper": base = "Hyper"
    case "tmux":
      base = nil
    case let raw?:
      base = raw
    case nil:
      base = nil
    }
    if base == nil, let term = env["TERM"], term.hasPrefix("xterm-kitty") { base = "kitty" }
    if base == nil, let bundle = env["__CFBundleIdentifier"], !bundle.isEmpty {
      base = bundle.split(separator: ".").last.map(String.init)
    }
    if env["TMUX"] != nil { return base.map { "\($0) · tmux" } ?? "tmux" }
    return base
  }
}
