import Foundation

/// One listed session, ready for the panel and the menu bar.
public struct SessionRow: Identifiable, Equatable, Sendable {
  public var id: String { key }
  public var key: String
  public var pid: Int32
  public var sessionId: String
  public var title: String
  public var folder: String
  public var app: String?
  public var state: SessionState
  /// When the current status began (epoch ms); drives the time column and the 2-minute red.
  public var since: Int64
  public var startedAt: Int64
  public var version: String?
  public var configDir: URL
  public var rawStatus: String

  public init(key: String, pid: Int32, sessionId: String, title: String, folder: String, app: String?, state: SessionState, since: Int64,
              startedAt: Int64, version: String?, configDir: URL, rawStatus: String) {
    self.key = key
    self.pid = pid
    self.sessionId = sessionId
    self.title = title
    self.folder = folder
    self.app = app
    self.state = state
    self.since = since
    self.startedAt = startedAt
    self.version = version
    self.configDir = configDir
    self.rawStatus = rawStatus
  }

  /// `<state line> · <folder> · <app>`.
  public var subLine: String {
    var parts = [state.line, folder]
    if let app { parts.append(app) }
    return parts.joined(separator: " · ")
  }

  /// Right column: Needs you "1m", Working "4m", Done "2m ago", Idle blank.
  public func timeColumn(now: Int64) -> String {
    switch state {
    case .working, .needsYou: return TimeFormat.age(ms: now - since)
    case .done: return TimeFormat.age(ms: now - since) + " ago"
    case .idle: return ""
    case .unknown(_, let settled): return settled ? TimeFormat.age(ms: now - since) : ""
    }
  }

  public func hasWaitedLong(now: Int64) -> Bool {
    state.countsAsNeedsYou && now - since >= Reducer.needsYouWaitedMs
  }
}

public struct Counts: Equatable, Sendable {
  public var working = 0
  public var needsYou = 0
  public var done = 0
  public var idle = 0
  public var needsYouWaited = false
  public var oldestWaitingMs: Int64?

  public init() {}

  public var isEmpty: Bool { working == 0 && needsYou == 0 && done == 0 }
}

public struct Snapshot: Equatable, Sendable {
  public var rows: [SessionRow]
  public var counts: Counts
  public var configDirs: [URL]
  /// Set when a sessions folder could not be listed; after 20 s the whole icon turns into "?".
  public var folderError: String?
  public var unreadableSince: Int64?
  public var lastGoodRead: Int64?
  public var versions: Set<String>
  public var now: Int64

  public init(rows: [SessionRow] = [], counts: Counts = Counts(), configDirs: [URL] = [], folderError: String? = nil,
              unreadableSince: Int64? = nil, lastGoodRead: Int64? = nil, versions: Set<String> = [], now: Int64 = 0) {
    self.rows = rows
    self.counts = counts
    self.configDirs = configDirs
    self.folderError = folderError
    self.unreadableSince = unreadableSince
    self.lastGoodRead = lastGoodRead
    self.versions = versions
    self.now = now
  }

  public var cannotTell: Bool {
    guard let since = unreadableSince else { return false }
    return now - since >= Reducer.unknownGraceMs
  }

  public func rows(in group: StateGroup) -> [SessionRow] {
    let rows = rows.filter { $0.state.group == group }
    switch group {
    case .needsYou, .done, .working: return rows.sorted { $0.since < $1.since }
    case .idle: return rows.sorted { $0.since > $1.since }
    }
  }
}

/// Lists every sessions folder, reads changed files, reduces, and keeps memories. Synchronous;
/// the app drives it from an actor and `oneup-dump` from a loop.
public final class SessionEngine {
  public struct Options: Sendable {
    public var homeConfigDir: URL
    public var stateURL: URL?
    public var discoverConfigDirs: Bool
    public var readEnvironment: Bool
    public init(homeConfigDir: URL, stateURL: URL?, discoverConfigDirs: Bool = true, readEnvironment: Bool = true) {
      self.homeConfigDir = homeConfigDir
      self.stateURL = stateURL
      self.discoverConfigDirs = discoverConfigDirs
      self.readEnvironment = readEnvironment
    }
  }

  private struct Live {
    var status: StatusFile
    var configDir: URL
    var fileURL: URL
    var modified: Date?
    var transcriptURL: URL?
    var scan: TranscriptScan
    var transcriptExists: Bool
    var app: String?
    var appResolved: Bool
    var state: SessionState
  }

  public let options: Options
  public private(set) var snapshot = Snapshot()
  public private(set) var nextRecheckAt: Int64?
  public var onChange: ((_ key: String, _ raw: String, _ state: SessionState, _ rule: String, _ now: Int64) -> Void)?

  private var state: StateFile
  private var live: [String: Live] = [:]
  private var extraConfigDirs: [URL] = []
  private var firstLaunch: Bool
  private var dirty = false

  public init(options: Options) {
    self.options = options
    if let url = options.stateURL, let loaded = StateStore.load(from: url) {
      state = loaded
      firstLaunch = false
    } else {
      state = StateFile()
      firstLaunch = true
    }
  }

  public var knownPIDs: [Int32] { live.values.map { $0.status.pid } }

  // MARK: Refresh

  /// Full pass: discover config folders, list each sessions folder, read changed files, reduce.
  @discardableResult
  public func refresh(now: Int64 = SessionEngine.nowMs(), force: Bool = false) -> Snapshot {
    if options.discoverConfigDirs { extraConfigDirs = discoverConfigDirs() }
    let dirs = ([options.homeConfigDir] + extraConfigDirs).uniqued()
    var seen = Set<String>()
    var folderError: String?
    var anyGood = false
    nextRecheckAt = nil
    for dir in dirs {
      let sessionsDir = dir.appendingPathComponent("sessions", isDirectory: true)
      let names: [String]
      do {
        names = try FileManager.default.contentsOfDirectory(atPath: sessionsDir.path)
        anyGood = true
      } catch {
        if dir == options.homeConfigDir || FileManager.default.fileExists(atPath: dir.path) {
          folderError = "The sessions folder \(sessionsDir.path) can't be read."
        }
        continue
      }
      for name in names where name.hasSuffix(".json") {
        let url = sessionsDir.appendingPathComponent(name)
        if let key = consider(url: url, configDir: dir, now: now, force: force) { seen.insert(key) }
      }
    }
    for key in Set(live.keys).subtracting(seen) { remove(key: key, now: now) }
    if anyGood {
      snapshot.unreadableSince = nil
      snapshot.lastGoodRead = now
    } else if snapshot.unreadableSince == nil {
      snapshot.unreadableSince = now
    }
    snapshot.folderError = folderError
    snapshot.configDirs = dirs
    firstLaunch = false
    rebuild(now: now)
    persistIfNeeded(now: now)
    return snapshot
  }

  /// Re-evaluates timers (interrupt grace, "?" grace) without touching disk.
  @discardableResult
  public func tick(now: Int64 = SessionEngine.nowMs()) -> Snapshot {
    nextRecheckAt = nil
    for key in live.keys.sorted() {
      guard var l = live[key] else { continue }
      let memory = state.sessions[key] ?? SessionMemory(lastLookedAt: now)
      let r = Reducer.reduce(
        memory: memory, read: .ok(l.status),
        transcript: TranscriptInfo(exists: l.transcriptExists, latestTurnEnd: l.scan.latestTurnEnd), now: now)
      apply(reduction: r, to: &l, key: key, memory: memory, now: now)
      live[key] = l
    }
    rebuild(now: now)
    persistIfNeeded(now: now)
    return snapshot
  }

  /// Called when a process exit source fires, so the row goes within the second.
  @discardableResult
  public func processExited(pid: Int32, now: Int64 = SessionEngine.nowMs()) -> Snapshot {
    for (key, l) in live where l.status.pid == pid {
      if !ProcessReader.matches(pid: pid, procStart: l.status.procStartDate) { remove(key: key, now: now) }
    }
    rebuild(now: now)
    persistIfNeeded(now: now)
    return snapshot
  }

  @discardableResult
  public func markLookedAt(key: String, now: Int64 = SessionEngine.nowMs()) -> Snapshot {
    guard var l = live[key] else { return snapshot }
    let memory = Reducer.markLookedAt(memory: state.sessions[key] ?? SessionMemory(lastLookedAt: now), now: now)
    state.sessions[key] = memory
    dirty = true
    let r = Reducer.reduce(
      memory: memory, read: .ok(l.status),
      transcript: TranscriptInfo(exists: l.transcriptExists, latestTurnEnd: l.scan.latestTurnEnd), now: now)
    apply(reduction: r, to: &l, key: key, memory: memory, now: now)
    live[key] = l
    rebuild(now: now)
    persistIfNeeded(now: now)
    return snapshot
  }

  @discardableResult
  public func markAllLookedAt(now: Int64 = SessionEngine.nowMs()) -> Snapshot {
    for key in live.keys where live[key]!.state.isDone { markLookedAt(key: key, now: now) }
    return snapshot
  }

  // MARK: Internals

  private func consider(url: URL, configDir: URL, now: Int64, force: Bool) -> String? {
    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
    let modified = attrs?[.modificationDate] as? Date
    let pidFromName = Int32((url.lastPathComponent as NSString).deletingPathExtension)
    if let pid = pidFromName, let existing = live.first(where: { $0.value.status.pid == pid && $0.value.fileURL == url }) {
      if !force, existing.value.modified == modified, modified != nil {
        return refreshExisting(key: existing.key, now: now)
      }
    }
    let read = readStatus(url: url)
    switch read {
    case .failed(let reason):
      // A file we never parsed cannot be matched to a process, so it is listed by pid only.
      guard let pid = pidFromName, ProcessReader.isAlive(pid) else { return nil }
      guard let existing = live.first(where: { $0.value.status.pid == pid && $0.value.fileURL == url }) else { return nil }
      var l = existing.value
      l.modified = modified
      let memory = state.sessions[existing.key] ?? SessionMemory(lastLookedAt: now)
      let r = Reducer.reduce(memory: memory, read: .failed(reason), transcript: .none, now: now)
      apply(reduction: r, to: &l, key: existing.key, memory: memory, now: now)
      live[existing.key] = l
      return existing.key
    case .ok(let s):
      guard s.isInteractiveCLI else { return nil }
      guard ProcessReader.matches(pid: s.pid, procStart: s.procStartDate) else { return nil }
      let key = s.key
      var l = live[key] ?? Live(
        status: s, configDir: configDir, fileURL: url, modified: modified, transcriptURL: nil,
        scan: TranscriptScan(), transcriptExists: false, app: nil, appResolved: false, state: .idle(backgroundShell: false))
      if live[key] == nil, let stale = live.first(where: { $0.value.status.pid == s.pid && $0.key != key }) {
        remove(key: stale.key, now: now)
      }
      l.status = s
      l.modified = modified
      l.configDir = configDir
      l.fileURL = url
      var memory = state.sessions[key] ?? SessionMemory(lastLookedAt: firstLaunch ? now : s.startedAt)
      memory.exitedAt = nil
      if memory.sessionId != s.sessionId {
        l.transcriptURL = nil
        l.scan = TranscriptScan()
        memory.offset = 0
      }
      if l.transcriptURL == nil {
        l.transcriptURL = TranscriptReader.transcriptURL(configDir: configDir, cwd: s.cwd, sessionId: s.sessionId)
      }
      let t = TranscriptReader.read(url: l.transcriptURL, offset: memory.sessionId == s.sessionId ? memory.offset : 0, previous: l.scan)
      l.scan = t.scan
      l.transcriptExists = t.exists
      if !t.exists { l.transcriptURL = nil }
      if !l.appResolved && options.readEnvironment {
        l.app = ProcessReader.argumentsAndEnvironment(s.pid).flatMap { TerminalApp.name(environment: $0.environment) }
        l.appResolved = true
      }
      let r = Reducer.reduce(
        memory: memory, read: .ok(s), transcript: TranscriptInfo(exists: t.exists, latestTurnEnd: t.scan.latestTurnEnd),
        now: now)
      var m = r.memory
      m.offset = t.offset
      m.title = RowTitle.title(status: s, customTitle: t.scan.customTitle, aiTitle: t.scan.aiTitle)
      apply(reduction: Reduction(state: r.state, memory: m, recheckAt: r.recheckAt, rule: r.rule), to: &l, key: key, memory: memory, now: now)
      live[key] = l
      return key
    }
  }

  /// Unchanged status file: still re-read the transcript tail (a turn may have ended) and re-run timers.
  private func refreshExisting(key: String, now: Int64) -> String? {
    guard var l = live[key] else { return nil }
    guard ProcessReader.matches(pid: l.status.pid, procStart: l.status.procStartDate) else {
      remove(key: key, now: now)
      return nil
    }
    let memory = state.sessions[key] ?? SessionMemory(lastLookedAt: now)
    if l.transcriptURL == nil {
      l.transcriptURL = TranscriptReader.transcriptURL(configDir: l.configDir, cwd: l.status.cwd, sessionId: l.status.sessionId)
    }
    let t = TranscriptReader.read(url: l.transcriptURL, offset: memory.offset, previous: l.scan)
    l.scan = t.scan
    l.transcriptExists = t.exists
    let r = Reducer.reduce(
      memory: memory, read: .ok(l.status), transcript: TranscriptInfo(exists: t.exists, latestTurnEnd: t.scan.latestTurnEnd), now: now)
    var m = r.memory
    m.offset = t.offset
    m.title = RowTitle.title(status: l.status, customTitle: t.scan.customTitle, aiTitle: t.scan.aiTitle)
    apply(reduction: Reduction(state: r.state, memory: m, recheckAt: r.recheckAt, rule: r.rule), to: &l, key: key, memory: memory, now: now)
    live[key] = l
    return key
  }

  private func apply(reduction r: Reduction, to l: inout Live, key: String, memory: SessionMemory, now: Int64) {
    if r.memory != memory {
      state.sessions[key] = r.memory
      dirty = true
    }
    if let at = r.recheckAt { nextRecheckAt = min(nextRecheckAt ?? at, at) }
    if l.state != r.state || live[key] == nil {
      onChange?(key, l.status.status, r.state, r.rule, now)
    }
    l.state = r.state
  }

  private func remove(key: String, now: Int64) {
    live[key] = nil
    if var m = state.sessions[key] {
      m.exitedAt = now
      state.sessions[key] = m
      dirty = true
    }
  }

  /// Three quick retries cover a file caught mid-write.
  private func readStatus(url: URL) -> StatusRead {
    var lastError = "unreadable"
    for attempt in 0..<3 {
      if attempt > 0 { Thread.sleep(forTimeInterval: 0.05) }
      do {
        let data = try Data(contentsOf: url)
        return .ok(try StatusFile.parse(data))
      } catch let e as StatusFileError {
        lastError = e.description
      } catch {
        lastError = error.localizedDescription
      }
    }
    return .failed(lastError)
  }

  private func discoverConfigDirs() -> [URL] {
    var dirs: [URL] = []
    for p in ProcessReader.claudeProcesses() {
      guard let dir = p.environment["CLAUDE_CONFIG_DIR"], !dir.isEmpty else { continue }
      dirs.append(URL(fileURLWithPath: (dir as NSString).expandingTildeInPath, isDirectory: true).standardizedFileURL)
    }
    return dirs.uniqued()
  }

  private func rebuild(now: Int64) {
    let titles = RowTitle.disambiguate(live.map { (key: $0.key, title: state.sessions[$0.key]?.title ?? RowTitle.folderName(cwd: $0.value.status.cwd), startedAt: $0.value.status.startedAt) })
    var rows: [SessionRow] = []
    var counts = Counts()
    var versions = Set<String>()
    for (key, l) in live {
      let row = SessionRow(
        key: key, pid: l.status.pid, sessionId: l.status.sessionId, title: titles[key] ?? "", folder: RowTitle.folderName(cwd: l.status.cwd),
        app: l.app, state: l.state, since: l.status.statusSince, startedAt: l.status.startedAt, version: l.status.version,
        configDir: l.configDir, rawStatus: l.status.status)
      rows.append(row)
      if let v = l.status.version { versions.insert(v) }
      switch l.state.group {
      case .working: if l.state.countsAsWorking { counts.working += 1 }
      case .needsYou:
        counts.needsYou += 1
        let waited = now - row.since
        if waited >= Reducer.needsYouWaitedMs { counts.needsYouWaited = true }
        counts.oldestWaitingMs = max(counts.oldestWaitingMs ?? 0, waited)
      case .done: counts.done += 1
      case .idle: counts.idle += 1
      }
    }
    snapshot.rows = rows.sorted { $0.startedAt < $1.startedAt }
    snapshot.counts = counts
    snapshot.versions = versions
    snapshot.now = now
  }

  private func persistIfNeeded(now: Int64) {
    guard dirty, let url = options.stateURL else { return }
    state = StateStore.pruned(state, now: now)
    try? StateStore.save(state, to: url)
    dirty = false
  }

  public static func nowMs() -> Int64 { Int64((Date().timeIntervalSince1970 * 1000).rounded()) }
}

extension Array where Element: Hashable {
  func uniqued() -> [Element] {
    var seen = Set<Element>()
    return filter { seen.insert($0).inserted }
  }
}
