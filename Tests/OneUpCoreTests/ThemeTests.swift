import XCTest

@testable import OneUpCore

/// Every built-in theme folder passes the theme rules from the spec.
final class ThemeTests: XCTestCase {
  static let root: URL = {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<3 { url = url.deletingLastPathComponent() }
    return url.appendingPathComponent("Resources/Themes", isDirectory: true)
  }()
  static let tints = ["#e2680a", "#d8261c", "#1c9353", "#ff9a3d", "#ff4a3d", "#3fd184"].map { hex -> (UInt8, UInt8, UInt8) in
    let v = UInt32(hex.dropFirst(), radix: 16)!
    return (UInt8(v >> 16 & 0xff), UInt8(v >> 8 & 0xff), UInt8(v & 0xff))
  }

  func loadAll() throws -> [Theme] {
    let (themes, problems) = ThemeLoader.loadAll(root: ThemeTests.root)
    XCTAssertEqual(problems, [])
    XCTAssertEqual(themes.map(\.id), ["blocks", "chomp", "galaxy", "invaders", "kong"])
    return themes
  }

  func testAllBuiltInsLoadWithExpectedFrameCounts() throws {
    let frames = Dictionary(uniqueKeysWithValues: try loadAll().map { ($0.id, $0.frameCount) })
    XCTAssertEqual(frames, ["chomp": 4, "invaders": 24, "kong": 23, "galaxy": 32, "blocks": 7])
  }

  func testIconShapesDifferFromEachOtherAndFromIdleFrame() throws {
    for t in try loadAll() {
      XCTAssertNotEqual(t.need.alphaMask, t.done.alphaMask, "\(t.id): need and done must differ")
      XCTAssertFalse(t.need.isEmpty, "\(t.id): need.png empty")
      XCTAssertFalse(t.done.isEmpty, "\(t.id): done.png empty")
      let idle = t.idleMask
      XCTAssertTrue(idle.contains(true), "\(t.id): idle frame empty")
      let idleImage = PixelImage(width: Theme.sceneWidth, height: Theme.sceneHeight, rgba: idle.flatMap { $0 ? [255, 255, 255, 255] : [0, 0, 0, 0] })
      for x in 0...(Theme.sceneWidth - Theme.iconSize) {
        for y in 0...(Theme.sceneHeight - Theme.iconSize) {
          let window = idleImage.cropped(x: x, y: y, width: Theme.iconSize, height: Theme.iconSize).alphaMask
          XCTAssertNotEqual(window, t.need.alphaMask, "\(t.id): need matches the idle frame at \(x),\(y)")
          XCTAssertNotEqual(window, t.done.alphaMask, "\(t.id): done matches the idle frame at \(x),\(y)")
        }
      }
    }
  }

  func testSceneArtAvoidsTintColours() throws {
    for t in try loadAll() {
      for img in [t.scene, t.sceneDark].compactMap({ $0 }) {
        for y in 0..<img.height {
          for x in 0..<img.width {
            let c = img.color(x: x, y: y)
            guard c.a == 255 else { continue }
            for tint in ThemeTests.tints {
              XCTAssertFalse(c.r == tint.0 && c.g == tint.1 && c.b == tint.2, "\(t.id): scene uses a tint colour at \(x),\(y)")
            }
          }
        }
      }
    }
  }

  func testNothingFlashesFasterThanFourHertz() throws {
    for t in try loadAll() {
      XCTAssertLessThanOrEqual(t.fps, 8, "\(t.id): at most 8 fps, so a pixel toggling every frame is 4 Hz")
      guard t.frameCount > 2 else { continue }
      // Whole-scene blink: the silhouette must not alternate between two states on every frame.
      let masks = (0..<t.frameCount).map { t.sceneFrame($0, dark: false).unionAlpha(with: t.sceneInkFrame($0)) }
      var alternating = true
      for i in 2..<masks.count where masks[i] != masks[i - 2] || masks[i] == masks[i - 1] { alternating = false }
      XCTAssertFalse(alternating, "\(t.id): scene alternates between two frames at 4 Hz")
    }
  }

  func testBrokenFoldersAreSkippedWithReasons() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let good = ThemeTests.root.appendingPathComponent("chomp")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: good, to: tmp.appendingPathComponent("chomp"))
    try FileManager.default.copyItem(at: good, to: tmp.appendingPathComponent("renamed"))
    try FileManager.default.createDirectory(at: tmp.appendingPathComponent("empty"), withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: good, to: tmp.appendingPathComponent("noscene"))
    try FileManager.default.removeItem(at: tmp.appendingPathComponent("noscene/scene.png"))
    try Data(#"{"schema":1,"id":"noscene","name":"No scene"}"#.utf8).write(to: tmp.appendingPathComponent("noscene/theme.json"))
    try FileManager.default.copyItem(at: good, to: tmp.appendingPathComponent("wrongicon"))
    try FileManager.default.copyItem(at: good.appendingPathComponent("scene.png"), to: tmp.appendingPathComponent("wrongicon/need2.png"))
    try FileManager.default.removeItem(at: tmp.appendingPathComponent("wrongicon/need.png"))
    try FileManager.default.moveItem(at: tmp.appendingPathComponent("wrongicon/need2.png"), to: tmp.appendingPathComponent("wrongicon/need.png"))
    try Data(#"{"schema":1,"id":"wrongicon","name":"Wrong icon"}"#.utf8).write(to: tmp.appendingPathComponent("wrongicon/theme.json"))

    let (themes, problems) = ThemeLoader.loadAll(root: tmp)
    XCTAssertEqual(themes.map(\.id), ["chomp"])
    XCTAssertEqual(problems.count, 4)
    XCTAssertTrue(problems.contains { $0.hasPrefix("renamed: id \"chomp\" differs from folder") }, "\(problems)")
    XCTAssertTrue(problems.contains { $0.hasPrefix("empty: missing theme.json") })
    XCTAssertTrue(problems.contains { $0.hasPrefix("noscene: missing scene.png") })
    XCTAssertTrue(problems.contains { $0.hasPrefix("wrongicon: need.png is 176×16, expected 14×14") }, "\(problems)")
  }

  func testLocateBuiltInFromRepo() {
    let exe = ThemeTests.root.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/debug/oneup-app")
    XCTAssertEqual(ThemeLoader.locateBuiltIn(executableURL: exe, resourceURL: nil)?.standardizedFileURL, ThemeTests.root.standardizedFileURL)
  }
}
