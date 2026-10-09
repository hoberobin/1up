import Foundation

/// Why a session is waiting, from the status file's `waitingFor`.
public enum WaitReason: Equatable, Sendable, Codable {
  case permission
  case inputNeeded
  case sandbox
  case worker
  case goal
  case dialog
  case other(String)

  public init(raw: String?) {
    switch raw {
    case "permission prompt": self = .permission
    case "input needed": self = .inputNeeded
    case "sandbox request": self = .sandbox
    case "worker request": self = .worker
    case "goal proposal": self = .goal
    case "dialog open": self = .dialog
    default: self = .other(raw ?? "")
    }
  }

  public var line: String {
    switch self {
    case .permission: return "Wants approval"
    case .inputNeeded: return "Asked a question"
    case .sandbox: return "Wants sandbox access"
    case .worker: return "Worker needs approval"
    case .goal: return "Proposed a goal"
    case .dialog: return "A dialog is open"
    case .other(let raw): return raw.isEmpty ? "Waiting" : "Waiting: \(raw)"
    }
  }

  public var isDialog: Bool { self == .dialog }
}

public enum DoneKind: Equatable, Sendable, Codable {
  /// A `turn_duration` record arrived. `durationMs` is nil for a session with no transcript yet.
  case ended(durationMs: Int64?)
  /// The status left busy/waiting and no record followed within the grace period.
  case interrupted(ranMs: Int64)

  public var line: String {
    switch self {
    case .ended(let ms?): return "Ended · ran \(TimeFormat.age(ms: ms))"
    case .ended(nil): return "Ended"
    case .interrupted(let ms): return "Interrupted · ran \(TimeFormat.age(ms: ms))"
    }
  }
}

public enum StateGroup: String, Sendable, Codable, CaseIterable {
  case needsYou, done, working, idle
}

public enum SessionState: Equatable, Sendable, Codable {
  case working
  case needsYou(WaitReason)
  case done(DoneKind)
  case idle(backgroundShell: Bool)
  /// `settled` is false during the first 20 s, when the row is listed under Working without counting.
  case unknown(reason: String, settled: Bool)

  public var group: StateGroup {
    switch self {
    case .working: return .working
    case .needsYou: return .needsYou
    case .done: return .done
    case .idle: return .idle
    case .unknown(_, let settled): return settled ? .needsYou : .working
    }
  }

  /// The plain-words state shown first on a row's second line.
  public var line: String {
    switch self {
    case .working: return "Working"
    case .needsYou(let reason): return reason.line
    case .done(let kind): return kind.line
    case .idle(let shell): return shell ? "Idle · background shell running" : "Idle"
    case .unknown(let reason, _): return reason
    }
  }

  /// Short code used by fixtures, logs and `oneup-dump`.
  public var code: String {
    switch self {
    case .working: return "working"
    case .needsYou: return "needs-you"
    case .done: return "done"
    case .idle: return "idle"
    case .unknown: return "unknown"
    }
  }

  public var isDone: Bool { if case .done = self { return true } else { return false } }
  public var countsAsNeedsYou: Bool { group == .needsYou }
  public var countsAsWorking: Bool { self == .working }
}
