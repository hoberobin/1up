import Foundation

/// Tail-reads one session's top-level transcript with a saved byte offset.
public enum TranscriptReader {
  public static let firstReadBytes: Int64 = 256 * 1024
  static let backwardChunk: Int64 = 1024 * 1024

  /// `<configDir>/projects/<cwd with non-alphanumerics as "-">/<sessionId>.jsonl`, else a glob on the id.
  public static func transcriptURL(configDir: URL, cwd: String, sessionId: String) -> URL? {
    let projects = configDir.appendingPathComponent("projects", isDirectory: true)
    let direct = projects.appendingPathComponent(projectDirName(cwd: cwd), isDirectory: true)
      .appendingPathComponent("\(sessionId).jsonl")
    if FileManager.default.fileExists(atPath: direct.path) { return direct }
    guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: projects.path) else { return nil }
    for d in dirs {
      let candidate = projects.appendingPathComponent(d, isDirectory: true).appendingPathComponent("\(sessionId).jsonl")
      if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
    }
    return nil
  }

  public static func projectDirName(cwd: String) -> String {
    String(cwd.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "-" })
  }

  public struct Result: Equatable, Sendable {
    public var scan: TranscriptScan
    public var offset: Int64
    public var exists: Bool
  }

  /// Reads from `offset` (0 = first read). A first read of a large file takes only the last 256 KB,
  /// then scans backwards once for a title if the tail had none. A shrunken file starts over.
  public static func read(url: URL?, offset: Int64, previous: TranscriptScan) -> Result {
    guard let url, let handle = try? FileHandle(forReadingFrom: url) else {
      return Result(scan: previous, offset: 0, exists: false)
    }
    defer { try? handle.close() }
    guard let size = (try? handle.seekToEnd()).map({ Int64($0) }) else {
      return Result(scan: previous, offset: offset, exists: true)
    }
    var from = offset
    var scan = previous
    var partial = false
    if size < from {
      from = 0
      scan = TranscriptScan()
    }
    if from == 0 && size > firstReadBytes {
      from = size - firstReadBytes
      partial = true
    }
    guard size > from, let data = readRange(handle, from: from, to: size) else {
      return Result(scan: scan, offset: size, exists: true)
    }
    scan = scan.merged(with: TranscriptTail.scan(data, skipPartialFirstLine: partial))
    if partial && !scan.hasTitle {
      scan = scanBackwardsForTitle(handle, before: from).merged(with: scan)
    }
    return Result(scan: scan, offset: size, exists: true)
  }

  private static func readRange(_ handle: FileHandle, from: Int64, to: Int64) -> Data? {
    guard (try? handle.seek(toOffset: UInt64(from))) != nil else { return nil }
    return try? handle.read(upToCount: Int(to - from))
  }

  private static func scanBackwardsForTitle(_ handle: FileHandle, before end: Int64) -> TranscriptScan {
    var hi = end
    var found = TranscriptScan()
    while hi > 0 {
      let lo = max(0, hi - backwardChunk)
      guard let data = readRange(handle, from: lo, to: hi) else { break }
      let chunk = TranscriptTail.scan(data, skipPartialFirstLine: lo > 0)
      found = TranscriptScan(customTitle: chunk.customTitle, aiTitle: chunk.aiTitle).merged(with: found)
      if found.hasTitle { break }
      hi = lo
    }
    found.latestTurnEnd = nil
    return found
  }
}
