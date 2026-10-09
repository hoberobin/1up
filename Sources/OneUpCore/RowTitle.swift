import Foundation

public enum RowTitle {
  /// `basename(cwd)` with a leading `work-` removed, so `work-pages-bg` reads as `pages-bg`.
  public static func folderName(cwd: String) -> String {
    var name = (cwd as NSString).lastPathComponent
    if name.isEmpty { name = cwd }
    if name.hasPrefix("work-") && name.count > 5 { name = String(name.dropFirst(5)) }
    return name
  }

  /// `/rename` name → Claude Code's generated title → folder name.
  public static func title(status: StatusFile, customTitle: String?, aiTitle: String?) -> String {
    if status.isUserNamed, let name = status.name { return name }
    if let c = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty { return c }
    if let a = aiTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !a.isEmpty { return a }
    return folderName(cwd: status.cwd)
  }

  /// When two live rows share a title, both get " #1", " #2" in start order.
  public static func disambiguate(_ rows: [(key: String, title: String, startedAt: Int64)]) -> [String: String] {
    var byTitle: [String: [(key: String, startedAt: Int64)]] = [:]
    for r in rows { byTitle[r.title, default: []].append((r.key, r.startedAt)) }
    var out: [String: String] = [:]
    for (title, items) in byTitle {
      if items.count == 1 {
        out[items[0].key] = title
        continue
      }
      for (i, item) in items.sorted(by: { $0.startedAt < $1.startedAt }).enumerated() {
        out[item.key] = "\(title) #\(i + 1)"
      }
    }
    return out
  }
}
