import Darwin
import Foundation
import OneUpCore

/// Owns the engine. Consumes file events, the 5 s scan, reducer rechecks and process exits,
/// and publishes each new snapshot to the main actor.
actor SessionStore {
  private let engine: SessionEngine
  private let log: ChangeLog
  private let publish: @Sendable (Snapshot) -> Void
  private var watcher: FolderWatcher?
  private var watchedPaths: [String] = []
  private var exitSources: [Int32: DispatchSourceProcess] = [:]
  private var debounceTask: Task<Void, Never>?
  private var recheckTask: Task<Void, Never>?
  private var scanTask: Task<Void, Never>?
  private var lastSnapshot = Snapshot()

  static let debounceMs: UInt64 = 100
  static let scanSeconds: Double = 5

  init(homeConfigDir: URL, stateURL: URL, logDirectory: URL, publish: @escaping @Sendable (Snapshot) -> Void) {
    engine = SessionEngine(options: .init(homeConfigDir: homeConfigDir, stateURL: stateURL))
    log = ChangeLog(directory: logDirectory)
    self.publish = publish
    let log = self.log
    engine.onChange = { key, raw, state, rule, now in log.record(key: key, raw: raw, state: state, reason: rule, now: now) }
  }

  func start() {
    refresh(force: true)
    scanTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(SessionStore.scanSeconds))
        await self?.refresh(force: false)
      }
    }
  }

  func stop() {
    scanTask?.cancel()
    recheckTask?.cancel()
    debounceTask?.cancel()
    watcher = nil
    for s in exitSources.values { s.cancel() }
    exitSources.removeAll()
  }

  func fileEvent() {
    debounceTask?.cancel()
    debounceTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(SessionStore.debounceMs))
      guard !Task.isCancelled else { return }
      await self?.refresh(force: false)
    }
  }

  func refresh(force: Bool) {
    after(engine.refresh(force: force))
  }

  func tick() {
    after(engine.tick())
  }

  func processExited(pid: Int32) {
    exitSources[pid]?.cancel()
    exitSources[pid] = nil
    after(engine.processExited(pid: pid))
  }

  func markLookedAt(key: String) {
    after(engine.markLookedAt(key: key))
  }

  func markAllLookedAt() {
    after(engine.markAllLookedAt())
  }

  private func after(_ snap: Snapshot) {
    lastSnapshot = snap
    publish(snap)
    updateWatcher(configDirs: snap.configDirs)
    updateExitSources(pids: engine.knownPIDs)
    scheduleRecheck(at: engine.nextRecheckAt)
  }

  private func updateWatcher(configDirs: [URL]) {
    let paths = configDirs.map { $0.appendingPathComponent("sessions", isDirectory: true).path }
      .filter { FileManager.default.fileExists(atPath: $0) }
    guard paths != watchedPaths else { return }
    watchedPaths = paths
    watcher = paths.isEmpty ? nil : FolderWatcher(paths: paths) { [weak self] in
      Task { await self?.fileEvent() }
    }
  }

  private func updateExitSources(pids: [Int32]) {
    let wanted = Set(pids)
    for pid in exitSources.keys where !wanted.contains(pid) {
      exitSources[pid]?.cancel()
      exitSources[pid] = nil
    }
    for pid in wanted where exitSources[pid] == nil {
      exitSources[pid] = SessionStore.makeExitSource(pid: pid) { [weak self] in
        Task { await self?.processExited(pid: pid) }
      }
    }
  }

  private nonisolated static func makeExitSource(pid: Int32, handler: @escaping @Sendable () -> Void) -> DispatchSourceProcess {
    let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: DispatchQueue.global(qos: .utility))
    source.setEventHandler(handler: handler)
    source.resume()
    return source
  }

  private func scheduleRecheck(at: Int64?) {
    recheckTask?.cancel()
    guard let at else { return }
    let delay = max(0, at - SessionEngine.nowMs())
    recheckTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(delay + 20))
      guard !Task.isCancelled else { return }
      await self?.tick()
    }
  }
}
