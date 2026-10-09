import Darwin
import Foundation

public struct ProcessSummary: Equatable, Sendable {
  public var pid: Int32
  public var arguments: [String]
  public var environment: [String: String]
}

/// Read-only facts about this user's processes, from sysctl. No permissions needed.
public enum ProcessReader {
  public static func isAlive(_ pid: Int32) -> Bool {
    guard pid > 0 else { return false }
    if kill(pid, 0) == 0 { return true }
    return errno == EPERM
  }

  /// Process start time from `KERN_PROC_PID`, or nil when the process is gone.
  public static func startTime(_ pid: Int32) -> Date? {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
    guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0, size > 0, info.kp_proc.p_pid == pid else {
      return nil
    }
    let tv = info.kp_proc.p_starttime
    return Date(timeIntervalSince1970: Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000)
  }

  /// A file counts only if its process is alive and started at `procStart` (±1 s).
  public static func matches(pid: Int32, procStart: Date?, tolerance: TimeInterval = 1.0) -> Bool {
    guard let actual = startTime(pid) else { return false }
    guard let expected = procStart else { return isAlive(pid) }
    return abs(actual.timeIntervalSince(expected)) <= tolerance
  }

  public static func allPIDs(uid: uid_t = getuid()) -> [Int32] {
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_UID, Int32(bitPattern: uid)]
    var size = 0
    guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0, size > 0 else { return [] }
    let count = size / MemoryLayout<kinfo_proc>.stride + 8
    var buffer = [kinfo_proc](repeating: kinfo_proc(), count: count)
    var bytes = count * MemoryLayout<kinfo_proc>.stride
    guard sysctl(&mib, UInt32(mib.count), &buffer, &bytes, nil, 0) == 0 else { return [] }
    return buffer.prefix(bytes / MemoryLayout<kinfo_proc>.stride).map { $0.kp_proc.p_pid }.filter { $0 > 0 }
  }

  /// argv and environment from `KERN_PROCARGS2`; nil for other users' processes or a gone pid.
  public static func argumentsAndEnvironment(_ pid: Int32) -> (arguments: [String], environment: [String: String])? {
    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
    var size = 0
    guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0, size > 0 else { return nil }
    var buffer = [UInt8](repeating: 0, count: size)
    guard sysctl(&mib, UInt32(mib.count), &buffer, &size, nil, 0) == 0, size >= 4 else { return nil }
    let argc = Int(buffer.withUnsafeBytes { $0.load(as: Int32.self) })
    var i = 4
    // Executable path, then NUL padding before argv[0].
    while i < size && buffer[i] != 0 { i += 1 }
    while i < size && buffer[i] == 0 { i += 1 }
    var strings: [String] = []
    var current: [UInt8] = []
    while i < size {
      if buffer[i] == 0 {
        strings.append(String(decoding: current, as: UTF8.self))
        current.removeAll(keepingCapacity: true)
      } else {
        current.append(buffer[i])
      }
      i += 1
    }
    if !current.isEmpty { strings.append(String(decoding: current, as: UTF8.self)) }
    let args = Array(strings.prefix(argc))
    var env: [String: String] = [:]
    for s in strings.dropFirst(argc) {
      guard let eq = s.firstIndex(of: "=") else { continue }
      env[String(s[..<eq])] = String(s[s.index(after: eq)...])
    }
    return (args, env)
  }

  /// This user's processes whose argv[0] or argv[1] path ends in `claude` or the npm cli.js.
  /// Used only to discover config folders; sessions always come from status files.
  public static func isClaudeCommand(_ arguments: [String]) -> Bool {
    for arg in arguments.prefix(2) {
      let base = (arg as NSString).lastPathComponent
      if base == "claude" || arg.hasSuffix("@anthropic-ai/claude-code/cli.js") { return true }
    }
    return false
  }

  public static func claudeProcesses() -> [ProcessSummary] {
    allPIDs().compactMap { pid in
      guard let (args, env) = argumentsAndEnvironment(pid), isClaudeCommand(args) else { return nil }
      return ProcessSummary(pid: pid, arguments: args, environment: env)
    }
  }
}
