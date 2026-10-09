import Foundation

/// `~/Library/Application Support/1UP/state.json`: `{v:1, sessions:{"pid:startedAt": SessionMemory}}`.
public struct StateFile: Codable, Equatable, Sendable {
  public var v: Int
  public var sessions: [String: SessionMemory]
  public init(sessions: [String: SessionMemory] = [:]) {
    self.v = 1
    self.sessions = sessions
  }
}

public enum StateStore {
  public static let pruneAfterExitMs: Int64 = 24 * 3600 * 1000

  public static func defaultURL() -> URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return base.appendingPathComponent("1UP", isDirectory: true).appendingPathComponent("state.json")
  }

  /// nil means no file: a first launch.
  public static func load(from url: URL) -> StateFile? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(StateFile.self, from: data)
  }

  /// Written atomically on change; a crash never leaves a half-written file.
  public static func save(_ state: StateFile, to url: URL) throws {
    let dir = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(state)
    try data.write(to: url, options: .atomic)
  }

  public static func pruned(_ state: StateFile, now: Int64) -> StateFile {
    var out = state
    out.sessions = state.sessions.filter { _, m in
      guard let exited = m.exitedAt else { return true }
      return now - exited < pruneAfterExitMs
    }
    return out
  }
}
