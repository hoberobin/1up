import Foundation

/// One theme folder, validated. The app plays frames, tints the two icons and draws counts itself.
public struct Theme: Equatable, Sendable, Identifiable {
  public static let sceneWidth = 44
  public static let sceneHeight = 16
  public static let iconSize = 14
  public static let maxFrames = 32
  public static let maxFPS = 8
  public static let fallbackID = "chomp"

  public var id: String
  public var name: String
  public var after: String?
  public var fps: Int
  public var idleFrame: Int
  public var directory: URL
  public var scene: PixelImage
  public var sceneInk: PixelImage?
  public var sceneDark: PixelImage?
  public var need: PixelImage
  public var needDetail: PixelImage?
  public var done: PixelImage
  public var doneDetail: PixelImage?
  public var icon: PixelImage
  public var iconInk: PixelImage?

  public var frameCount: Int { scene.width / Theme.sceneWidth }

  public func sceneFrame(_ index: Int, dark: Bool) -> PixelImage {
    let i = ((index % frameCount) + frameCount) % frameCount
    let base = dark ? (sceneDark ?? scene) : scene
    return base.cropped(x: i * Theme.sceneWidth, y: 0, width: Theme.sceneWidth, height: Theme.sceneHeight)
  }

  public func sceneInkFrame(_ index: Int) -> PixelImage? {
    guard let ink = sceneInk else { return nil }
    let i = ((index % frameCount) + frameCount) % frameCount
    return ink.cropped(x: i * Theme.sceneWidth, y: 0, width: Theme.sceneWidth, height: Theme.sceneHeight)
  }

  /// The idle silhouette: idleFrame's art plus its ink, used as a template image.
  public var idleMask: [Bool] { sceneFrame(idleFrame, dark: false).unionAlpha(with: sceneInkFrame(idleFrame)) }
}

public enum ThemeError: Error, Equatable, CustomStringConvertible {
  case missingFile(String)
  case badJSON(String)
  case badField(String)
  case idMismatch(String, folder: String)
  case badSize(String, expected: String, actual: String)
  case badFrameCount(Int)

  public var description: String {
    switch self {
    case .missingFile(let f): return "missing \(f)"
    case .badJSON(let why): return "theme.json: \(why)"
    case .badField(let f): return "theme.json: bad \(f)"
    case .idMismatch(let id, let folder): return "id \"\(id)\" differs from folder \"\(folder)\""
    case .badSize(let f, let e, let a): return "\(f) is \(a), expected \(e)"
    case .badFrameCount(let n): return "scene.png has \(n) frames, expected 1–32"
    }
  }
}

public enum ThemeLoader {
  nonisolated(unsafe) private static let idPattern = try! NSRegularExpression(pattern: "^[a-z][a-z0-9-]{1,31}$")

  /// Every subfolder that validates, plus one problem line per folder that did not.
  public static func loadAll(root: URL) -> (themes: [Theme], problems: [String]) {
    guard let names = try? FileManager.default.contentsOfDirectory(atPath: root.path) else {
      return ([], ["Themes folder \(root.path) can't be read"])
    }
    var themes: [Theme] = []
    var problems: [String] = []
    for name in names.sorted() {
      let dir = root.appendingPathComponent(name, isDirectory: true)
      var isDir: ObjCBool = false
      guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
      do { themes.append(try load(directory: dir)) } catch { problems.append("\(name): \(error)") }
    }
    return (themes, problems)
  }

  public static func load(directory: URL) throws -> Theme {
    let folder = directory.lastPathComponent
    let jsonURL = directory.appendingPathComponent("theme.json")
    guard let data = try? Data(contentsOf: jsonURL) else { throw ThemeError.missingFile("theme.json") }
    guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
      throw ThemeError.badJSON("not a JSON object")
    }
    guard (obj["schema"] as? NSNumber)?.intValue == 1 else { throw ThemeError.badField("schema") }
    guard let id = obj["id"] as? String, idPattern.firstMatch(in: id, range: NSRange(id.startIndex..., in: id)) != nil else {
      throw ThemeError.badField("id")
    }
    guard id == folder else { throw ThemeError.idMismatch(id, folder: folder) }
    guard let name = obj["name"] as? String, (1...16).contains(name.count) else { throw ThemeError.badField("name") }
    let after = obj["after"] as? String
    let fps = (obj["fps"] as? NSNumber)?.intValue ?? Theme.maxFPS
    guard (1...Theme.maxFPS).contains(fps) else { throw ThemeError.badField("fps") }
    let idleFrame = (obj["idleFrame"] as? NSNumber)?.intValue ?? 0

    func required(_ file: String) throws -> PixelImage {
      let url = directory.appendingPathComponent(file)
      guard FileManager.default.fileExists(atPath: url.path) else { throw ThemeError.missingFile(file) }
      guard let img = PixelImage(contentsOf: url) else { throw ThemeError.badSize(file, expected: "a PNG", actual: "unreadable") }
      return img
    }
    func optional(_ file: String) throws -> PixelImage? {
      let url = directory.appendingPathComponent(file)
      guard FileManager.default.fileExists(atPath: url.path) else { return nil }
      return try required(file)
    }
    func check(_ img: PixelImage?, _ file: String, width: Int, height: Int) throws {
      guard let img else { return }
      guard img.width == width, img.height == height else {
        throw ThemeError.badSize(file, expected: "\(width)×\(height)", actual: "\(img.width)×\(img.height)")
      }
    }

    let scene = try required("scene.png")
    guard scene.height == Theme.sceneHeight, scene.width % Theme.sceneWidth == 0 else {
      throw ThemeError.badSize("scene.png", expected: "n×44 by 16", actual: "\(scene.width)×\(scene.height)")
    }
    let frames = scene.width / Theme.sceneWidth
    guard (1...Theme.maxFrames).contains(frames) else { throw ThemeError.badFrameCount(frames) }
    guard idleFrame >= 0, idleFrame < frames else { throw ThemeError.badField("idleFrame") }
    let sceneInk = try optional("scene-ink.png")
    try check(sceneInk, "scene-ink.png", width: scene.width, height: scene.height)
    let sceneDark = try optional("scene-dark.png")
    try check(sceneDark, "scene-dark.png", width: scene.width, height: scene.height)
    let s = Theme.iconSize
    let need = try required("need.png")
    try check(need, "need.png", width: s, height: s)
    let needDetail = try optional("need-detail.png")
    try check(needDetail, "need-detail.png", width: s, height: s)
    let done = try required("done.png")
    try check(done, "done.png", width: s, height: s)
    let doneDetail = try optional("done-detail.png")
    try check(doneDetail, "done-detail.png", width: s, height: s)
    let icon = try required("icon.png")
    try check(icon, "icon.png", width: s, height: s)
    let iconInk = try optional("icon-ink.png")
    try check(iconInk, "icon-ink.png", width: s, height: s)

    return Theme(
      id: id, name: name, after: after, fps: fps, idleFrame: idleFrame, directory: directory, scene: scene,
      sceneInk: sceneInk, sceneDark: sceneDark, need: need, needDetail: needDetail, done: done, doneDetail: doneDetail,
      icon: icon, iconInk: iconInk)
  }

  /// Finds the bundled Themes folder from an app bundle, a `swift run` binary, or the working directory.
  public static func locateBuiltIn(executableURL: URL?, resourceURL: URL?) -> URL? {
    var candidates: [URL] = []
    if let resourceURL { candidates.append(resourceURL.appendingPathComponent("Themes", isDirectory: true)) }
    if let exe = executableURL {
      var dir = exe.deletingLastPathComponent()
      for _ in 0..<6 {
        candidates.append(dir.appendingPathComponent("Resources/Themes", isDirectory: true))
        dir = dir.deletingLastPathComponent()
      }
    }
    candidates.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/Themes", isDirectory: true))
    return candidates.first { FileManager.default.fileExists(atPath: $0.appendingPathComponent("chomp/theme.json").path) }
  }
}
