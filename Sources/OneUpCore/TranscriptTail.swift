import Foundation

public struct TranscriptScan: Equatable, Sendable {
  public var customTitle: String?
  public var aiTitle: String?
  public var latestTurnEnd: TurnEnd?
  public init(customTitle: String? = nil, aiTitle: String? = nil, latestTurnEnd: TurnEnd? = nil) {
    self.customTitle = customTitle
    self.aiTitle = aiTitle
    self.latestTurnEnd = latestTurnEnd
  }

  /// Later records win over earlier ones, so `later` overrides wherever it has a value.
  public func merged(with later: TranscriptScan) -> TranscriptScan {
    TranscriptScan(
      customTitle: later.customTitle ?? customTitle,
      aiTitle: later.aiTitle ?? aiTitle,
      latestTurnEnd: later.latestTurnEnd ?? latestTurnEnd)
  }

  public var hasTitle: Bool { customTitle != nil || aiTitle != nil }
}

/// Reads only `custom-title`, `ai-title` and `system/turn_duration` records out of transcript bytes.
public enum TranscriptTail {
  static let markers: [Data] = [
    Data("\"turn_duration\"".utf8), Data("\"custom-title\"".utf8), Data("\"ai-title\"".utf8),
  ]

  /// `skipPartialFirstLine` is true when the chunk starts mid-file (tail reads).
  public static func scan(_ data: Data, skipPartialFirstLine: Bool) -> TranscriptScan {
    var result = TranscriptScan()
    var start = data.startIndex
    if skipPartialFirstLine {
      guard let nl = data[start...].firstIndex(of: 0x0A) else { return result }
      start = data.index(after: nl)
    }
    while start < data.endIndex {
      let end = data[start...].firstIndex(of: 0x0A) ?? data.endIndex
      let line = data[start..<end]
      if !line.isEmpty, markers.contains(where: { line.range(of: $0) != nil }) {
        apply(line: line, to: &result)
      }
      start = end == data.endIndex ? end : data.index(after: end)
    }
    return result
  }

  public static func scan(lines: [String]) -> TranscriptScan {
    var result = TranscriptScan()
    for line in lines { apply(line: Data(line.utf8), to: &result) }
    return result
  }

  private static func apply(line: Data, to result: inout TranscriptScan) {
    guard let obj = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
      let type = obj["type"] as? String
    else { return }
    switch type {
    case "custom-title":
      if let t = obj["customTitle"] as? String { result.customTitle = t }
    case "ai-title":
      if let t = obj["aiTitle"] as? String { result.aiTitle = t }
    case "system":
      guard obj["subtype"] as? String == "turn_duration", (obj["isSidechain"] as? Bool) != true,
        let ts = obj["timestamp"] as? String, let ms = TimeFormat.epochMs(iso: ts)
      else { return }
      let duration = (obj["durationMs"] as? NSNumber)?.int64Value ?? 0
      result.latestTurnEnd = TurnEnd(timestampMs: ms, durationMs: duration)
    default:
      return
    }
  }
}
