import Foundation

/// What 1UP remembers about one session (pid + startedAt). Persisted in state.json.
public struct SessionMemory: Codable, Equatable, Sendable {
  public var lastLookedAt: Int64
  public var busySince: Int64?
  public var lastStatus: String?
  public var lastWaitingFor: String?
  public var lastTurnEnd: Int64?
  public var offset: Int64
  public var title: String?
  public var sessionId: String?
  public var lastState: SessionState?
  /// First time idle/shell was seen after busy or waiting; drives the 1.5 s interrupt rule.
  public var idleSince: Int64?
  /// A Done decided without a new turn record. Stays until looked at or the next busy.
  public var pendingDone: DoneKind?
  public var unknownSince: Int64?
  public var exitedAt: Int64?

  public init(lastLookedAt: Int64) {
    self.lastLookedAt = lastLookedAt
    self.offset = 0
  }
}

public enum StatusRead: Equatable, Sendable {
  case ok(StatusFile)
  /// The file could not be read or failed the shape check; the text is shown on the row.
  case failed(String)
}

public struct TurnEnd: Equatable, Sendable, Codable {
  public var timestampMs: Int64
  public var durationMs: Int64
  public init(timestampMs: Int64, durationMs: Int64) {
    self.timestampMs = timestampMs
    self.durationMs = durationMs
  }
}

public struct TranscriptInfo: Equatable, Sendable {
  public var exists: Bool
  public var latestTurnEnd: TurnEnd?
  public init(exists: Bool, latestTurnEnd: TurnEnd?) {
    self.exists = exists
    self.latestTurnEnd = latestTurnEnd
  }
  public static let none = TranscriptInfo(exists: false, latestTurnEnd: nil)
}

public struct Reduction: Equatable, Sendable {
  public var state: SessionState
  public var memory: SessionMemory
  /// Epoch ms at which the caller must reduce again even if nothing changed on disk.
  public var recheckAt: Int64?
  /// The rule that decided the state, for the change log.
  public var rule: String
}

/// (previous memory, status file, latest turn_duration, now) → state. Pure and synchronous.
/// Rules are evaluated top to bottom; the first match wins. See docs/SPEC.md "Reducer".
public enum Reducer {
  public static let interruptGraceMs: Int64 = 1500
  public static let unknownGraceMs: Int64 = 20_000
  public static let needsYouWaitedMs: Int64 = 120_000

  public static func reduce(
    memory input: SessionMemory, read: StatusRead, transcript: TranscriptInfo, now: Int64
  ) -> Reduction {
    var m = input
    switch read {
    case .failed(let reason):
      return unknown(reason: "Can't read: \(reason)", memory: m, now: now)
    case .ok(let s):
      if m.sessionId != s.sessionId {
        m.sessionId = s.sessionId
        m.offset = 0
        m.title = nil
      }
      switch s.status {
      case "busy":
        if m.lastStatus != "busy" || m.busySince == nil {
          m.busySince = s.statusSince
          m.lastLookedAt = s.statusSince
        }
        m.idleSince = nil
        m.pendingDone = nil
        return finish(.working, s, m, rule: "busy")

      case "waiting":
        m.idleSince = nil
        m.pendingDone = nil
        m.lastWaitingFor = s.waitingFor
        return finish(.needsYou(WaitReason(raw: s.waitingFor)), s, m, rule: "waiting")

      case "idle", "shell":
        let shell = s.status == "shell"
        if let te = transcript.latestTurnEnd {
          m.lastTurnEnd = te.timestampMs
          if te.timestampMs > m.lastLookedAt {
            m.idleSince = nil
            m.pendingDone = nil
            return finish(.done(.ended(durationMs: te.durationMs)), s, m, rule: "turn_duration")
          }
        }
        if let pending = m.pendingDone {
          return finish(.done(pending), s, m, rule: "pending-done")
        }
        let cameFromTurn =
          m.lastStatus == "busy"
          || (m.lastStatus == "waiting" && !WaitReason(raw: m.lastWaitingFor).isDialog)
        if cameFromTurn {
          if !transcript.exists && m.lastStatus == "busy" {
            m.pendingDone = .ended(durationMs: nil)
            m.idleSince = nil
            return finish(.done(.ended(durationMs: nil)), s, m, rule: "no-transcript")
          }
          let since = m.idleSince ?? now
          m.idleSince = since
          if now - since < interruptGraceMs {
            // Keep the turn's state until the grace period ends; lastStatus stays so the rule re-fires.
            m.unknownSince = nil
            return Reduction(
              state: m.lastState ?? .working, memory: m, recheckAt: since + interruptGraceMs,
              rule: "interrupt-grace")
          }
          let ran = max(0, now - (m.busySince ?? since))
          m.pendingDone = .interrupted(ranMs: ran)
          return finish(.done(.interrupted(ranMs: ran)), s, m, rule: "interrupted")
        }
        m.idleSince = nil
        return finish(.idle(backgroundShell: shell), s, m, rule: "idle")

      default:
        return unknown(reason: "Unrecognised status \"\(s.status)\"", memory: m, now: now)
      }
    }
  }

  /// Row click, Return, or Mark all looked at.
  public static func markLookedAt(memory input: SessionMemory, now: Int64) -> SessionMemory {
    var m = input
    m.lastLookedAt = now
    m.pendingDone = nil
    m.idleSince = nil
    if case .done = m.lastState { m.lastState = nil }
    return m
  }

  private static func finish(
    _ state: SessionState, _ s: StatusFile, _ memory: SessionMemory, rule: String
  ) -> Reduction {
    var m = memory
    m.unknownSince = nil
    m.lastStatus = s.status
    m.lastState = state
    return Reduction(state: state, memory: m, recheckAt: nil, rule: rule)
  }

  private static func unknown(reason: String, memory: SessionMemory, now: Int64) -> Reduction {
    var m = memory
    let since = m.unknownSince ?? now
    m.unknownSince = since
    if now - since < unknownGraceMs {
      if let last = m.lastState {
        return Reduction(state: last, memory: m, recheckAt: since + unknownGraceMs, rule: "unknown-grace")
      }
      return Reduction(
        state: .unknown(reason: reason, settled: false), memory: m, recheckAt: since + unknownGraceMs,
        rule: "unknown-grace")
    }
    return Reduction(state: .unknown(reason: reason, settled: true), memory: m, recheckAt: nil, rule: "unknown")
  }
}
