import Foundation
import os

/// `~/Library/Logs/1UP/YYYY-MM-DD.jsonl`, one record per state change, kept 7 days, mirrored to os_log.
public final class ChangeLog: @unchecked Sendable {
  public static let retentionDays = 7
  private let directory: URL
  private let logger = Logger(subsystem: "com.hoberobin.oneup", category: "state")
  private let lock = NSLock()
  private let dayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  public init(directory: URL) {
    self.directory = directory
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    prune()
  }

  public static func defaultDirectory() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Logs/1UP", isDirectory: true)
  }

  public func record(key: String, raw: String, state: SessionState, reason: String, now: Int64) {
    let entry: [String: Any] = [
      "mono": Int64(DispatchTime.now().uptimeNanoseconds / 1_000_000),
      "wall": TimeFormat.isoString(ms: now),
      "key": key, "raw": raw, "state": state.code, "line": state.line, "reason": reason,
    ]
    logger.info("\(key, privacy: .public) \(raw, privacy: .public) -> \(state.code, privacy: .public) (\(reason, privacy: .public))")
    guard let data = try? JSONSerialization.data(withJSONObject: entry) else { return }
    let file = directory.appendingPathComponent(dayFormatter.string(from: Date(timeIntervalSince1970: Double(now) / 1000)) + ".jsonl")
    lock.lock()
    defer { lock.unlock() }
    if let handle = try? FileHandle(forWritingTo: file) {
      defer { try? handle.close() }
      _ = try? handle.seekToEnd()
      try? handle.write(contentsOf: data + Data([0x0A]))
    } else {
      try? (data + Data([0x0A])).write(to: file)
    }
  }

  public func prune(now: Date = Date()) {
    guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
    let cutoff = now.addingTimeInterval(-Double(ChangeLog.retentionDays) * 86400)
    for name in names where name.hasSuffix(".jsonl") {
      guard let day = dayFormatter.date(from: String(name.dropLast(6))), day < cutoff else { continue }
      try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }
  }
}
