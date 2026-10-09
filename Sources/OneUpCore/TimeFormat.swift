import Foundation

public enum TimeFormat {
  /// Rounded down: under a minute "45s", under an hour "4m", otherwise "2h".
  public static func age(ms: Int64) -> String {
    let s = max(0, ms) / 1000
    if s < 60 { return "\(s)s" }
    if s < 3600 { return "\(s / 60)m" }
    return "\(s / 3600)h"
  }

  /// Spoken form for VoiceOver: "3 minutes", "45 seconds", "2 hours".
  public static func spokenAge(ms: Int64) -> String {
    let s = max(0, ms) / 1000
    func plural(_ n: Int64, _ unit: String) -> String { "\(n) \(unit)\(n == 1 ? "" : "s")" }
    if s < 60 { return plural(s, "second") }
    if s < 3600 { return plural(s / 60, "minute") }
    return plural(s / 3600, "hour")
  }

  nonisolated(unsafe) private static let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()
  nonisolated(unsafe) private static let isoPlain: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  /// Epoch milliseconds from a transcript `timestamp`.
  public static func epochMs(iso string: String) -> Int64? {
    guard let d = iso.date(from: string) ?? isoPlain.date(from: string) else { return nil }
    return Int64((d.timeIntervalSince1970 * 1000).rounded())
  }

  public static func isoString(ms: Int64) -> String {
    iso.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
  }
}
