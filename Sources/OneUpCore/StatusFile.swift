import Foundation

public enum StatusFileError: Error, Equatable, Sendable, CustomStringConvertible {
  case notJSON
  case notObject
  case missing(String)
  case wrongType(String)

  public var description: String {
    switch self {
    case .notJSON: return "Not valid JSON"
    case .notObject: return "Not a JSON object"
    case .missing(let f): return "Missing field \"\(f)\""
    case .wrongType(let f): return "Field \"\(f)\" has the wrong type"
    }
  }
}

/// One `~/.claude/sessions/<pid>.json`, shape-checked. Unknown keys are ignored.
public struct StatusFile: Equatable, Sendable {
  public var pid: Int32
  public var sessionId: String
  public var cwd: String
  public var kind: String
  public var status: String
  public var startedAt: Int64
  public var procStart: String
  public var entrypoint: String
  public var waitingFor: String?
  public var name: String?
  public var nameSource: String?
  public var version: String?
  public var statusUpdatedAt: Int64?
  public var updatedAt: Int64?

  public init(
    pid: Int32, sessionId: String, cwd: String, kind: String = "interactive", status: String,
    startedAt: Int64, procStart: String, entrypoint: String = "cli", waitingFor: String? = nil,
    name: String? = nil, nameSource: String? = nil, version: String? = nil,
    statusUpdatedAt: Int64? = nil, updatedAt: Int64? = nil
  ) {
    self.pid = pid
    self.sessionId = sessionId
    self.cwd = cwd
    self.kind = kind
    self.status = status
    self.startedAt = startedAt
    self.procStart = procStart
    self.entrypoint = entrypoint
    self.waitingFor = waitingFor
    self.name = name
    self.nameSource = nameSource
    self.version = version
    self.statusUpdatedAt = statusUpdatedAt
    self.updatedAt = updatedAt
  }

  public static func parse(_ data: Data) throws -> StatusFile {
    let any: Any
    do { any = try JSONSerialization.jsonObject(with: data) } catch { throw StatusFileError.notJSON }
    guard let obj = any as? [String: Any] else { throw StatusFileError.notObject }
    return try parse(object: obj)
  }

  public static func parse(object obj: [String: Any]) throws -> StatusFile {
    func req<T>(_ key: String, _ as: T.Type) throws -> T {
      guard let v = obj[key], !(v is NSNull) else { throw StatusFileError.missing(key) }
      guard let t = v as? T else { throw StatusFileError.wrongType(key) }
      return t
    }
    func opt<T>(_ key: String, _ as: T.Type) throws -> T? {
      guard let v = obj[key], !(v is NSNull) else { return nil }
      guard let t = v as? T else { throw StatusFileError.wrongType(key) }
      return t
    }
    func int64(_ key: String, required: Bool) throws -> Int64? {
      guard let v = obj[key], !(v is NSNull) else {
        if required { throw StatusFileError.missing(key) }
        return nil
      }
      // `v is Bool` is true for every small NSNumber, so booleans are told apart by their CF type.
      if let n = v as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() { return n.int64Value }
      throw StatusFileError.wrongType(key)
    }
    let pidNum = try req("pid", NSNumber.self)
    return StatusFile(
      pid: pidNum.int32Value,
      sessionId: try req("sessionId", String.self),
      cwd: try req("cwd", String.self),
      kind: try req("kind", String.self),
      status: try req("status", String.self),
      startedAt: try int64("startedAt", required: true)!,
      procStart: try req("procStart", String.self),
      entrypoint: try opt("entrypoint", String.self) ?? "cli",
      waitingFor: try opt("waitingFor", String.self),
      name: try opt("name", String.self),
      nameSource: try opt("nameSource", String.self),
      version: try opt("version", String.self),
      statusUpdatedAt: try int64("statusUpdatedAt", required: false),
      updatedAt: try int64("updatedAt", required: false)
    )
  }

  /// Only interactive CLI sessions are listed; `claude -p`, SDK and IDE chats are not.
  public var isInteractiveCLI: Bool { kind == "interactive" && entrypoint == "cli" }

  /// When the current status began, in epoch ms. Falls back for files that predate `statusUpdatedAt`.
  public var statusSince: Int64 { statusUpdatedAt ?? updatedAt ?? startedAt }

  public var isUserNamed: Bool { nameSource == "user" && !(name ?? "").isEmpty }

  private static let procStartFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "EEE MMM d HH:mm:ss yyyy"
    return f
  }()

  /// `procStart` is `ps` lstart format in UTC with a space-padded day ("Thu Oct  8 21:51:57 2026").
  public static func parseProcStart(_ s: String) -> Date? {
    let collapsed = s.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    return procStartFormatter.date(from: collapsed)
  }

  public var procStartDate: Date? { StatusFile.parseProcStart(procStart) }

  /// Identity for a row: the same pid can be reused by a later process, so startedAt joins the key.
  public var key: String { "\(pid):\(startedAt)" }
}
