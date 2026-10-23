import CoreServices
import Foundation

/// FSEvents on the sessions folders, file-level, 100 ms latency. The 5 s scan covers anything it drops.
final class FolderWatcher: @unchecked Sendable {
  private var stream: FSEventStreamRef?
  private let queue = DispatchQueue(label: "com.hoberobin.oneup.fsevents")
  private let handler: @Sendable () -> Void

  init?(paths: [String], handler: @escaping @Sendable () -> Void) {
    self.handler = handler
    var context = FSEventStreamContext()
    context.info = Unmanaged.passUnretained(self).toOpaque()
    let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
      guard let info else { return }
      Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue().handler()
    }
    let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagUseCFTypes)
    guard let stream = FSEventStreamCreate(nil, callback, &context, paths as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.1, flags) else {
      return nil
    }
    self.stream = stream
    FSEventStreamSetDispatchQueue(stream, queue)
    FSEventStreamStart(stream)
  }

  deinit {
    if let stream {
      FSEventStreamStop(stream)
      FSEventStreamInvalidate(stream)
      FSEventStreamRelease(stream)
    }
  }
}
