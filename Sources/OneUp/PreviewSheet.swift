import AppKit
import OneUpCore

/// `1UP --render-preview out.png`: every demo state from the spec's menu bar table, for every theme,
/// on a light and a dark bar at 2×. Used to compare against the spec's preview without a screenshot.
@MainActor
enum PreviewSheet {
  static let demos: [(String, Counts, Bool)] = {
    func c(_ w: Int = 0, _ n: Int = 0, _ d: Int = 0, waited: Bool = false) -> Counts {
      var x = Counts()
      x.working = w
      x.needsYou = n
      x.done = d
      x.needsYouWaited = waited
      return x
    }
    return [
      ("idle", c(), false), ("work3", c(3), false), ("mix1", c(2, 1), false), ("mix3", c(2, 2, waited: true), false),
      ("done", c(0, 0, 2), false), ("mix2", c(1, 1, 3), false), ("err", c(), true),
    ]
  }()

  static func render(themes: [Theme], to url: URL) throws {
    let scale: CGFloat = 2
    let cell = CGSize(width: 150, height: 30)
    let cols = demos.count, rows = themes.count * 2
    let size = CGSize(width: cell.width * CGFloat(cols) + 8, height: cell.height * CGFloat(rows) + 8)
    guard let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale), bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    else { return }
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.interpolationQuality = .none
    for (ti, theme) in themes.enumerated() {
      for dark in [false, true] {
        let row = ti * 2 + (dark ? 1 : 0)
        let y = size.height - 4 - cell.height * CGFloat(row + 1)
        ctx.setFillColor(dark ? NSColor(hex: 0x1e2034).cgColor : NSColor(hex: 0xeceef6).cgColor)
        ctx.fill(CGRect(x: 4, y: y, width: cell.width * CGFloat(cols), height: cell.height))
        let ink = dark ? NSColor(hex: 0xeef0fb) : NSColor(hex: 0x1b1e33)
        for (di, demo) in demos.enumerated() {
          let image = StatusImageRenderer.render(.init(
            theme: theme, counts: demo.1, cannotTell: demo.2, frame: 1, dark: dark, ink: ink, increaseContrast: false, reduceMotion: false))
          let x = 4 + cell.width * CGFloat(di) + 4
          let rect = CGRect(x: x, y: y + (cell.height - image.size.height) / 2, width: image.size.width, height: image.size.height)
          if image.isTemplate {
            // Template images are tinted by the system; the sheet tints them with the bar colour.
            let tinted = NSImage(size: image.size, flipped: false) { r in
              image.draw(in: r)
              ink.set()
              r.fill(using: .sourceAtop)
              return true
            }
            tinted.draw(in: rect)
          } else {
            image.draw(in: rect)
          }
          let glyphs = [ThemeArt.glyph(theme: theme, kind: .needsYou, tints: Tints.forAppearance(dark: dark), ink: ink),
                        ThemeArt.glyph(theme: theme, kind: .done, tints: Tints.forAppearance(dark: dark), ink: ink),
                        ThemeArt.glyph(theme: theme, kind: .working, tints: Tints.forAppearance(dark: dark), ink: ink)]
          if di == demos.count - 1 {
            for (gi, g) in glyphs.enumerated() {
              g.draw(in: CGRect(x: x + 80 + CGFloat(gi) * 18, y: y + 8, width: 14, height: 14))
            }
          }
        }
      }
    }
    guard let png = rep.representation(using: .png, properties: [:]) else { return }
    try png.write(to: url)
  }
}

import SwiftUI

extension PreviewSheet {
  /// `1UP --render-panel out.png`: the panel with the spec's sample sessions, light and dark.
  static func renderPanel(themes: [Theme], problems: [String], to url: URL) throws {
    let model = AppModel(themes: themes, problems: problems)
    let now = SessionEngine.nowMs()
    func row(_ key: String, _ title: String, _ folder: String, _ app: String?, _ state: SessionState, _ ago: Int64) -> SessionRow {
      SessionRow(key: key, pid: 1, sessionId: key, title: title, folder: folder, app: app, state: state, since: now - ago, startedAt: now - ago - 1000,
                 version: "2.1.295", configDir: URL(fileURLWithPath: "/"), rawStatus: "")
    }
    var snap = Snapshot(rows: [
      row("a", "Fix the quiz tally for drag-drop", "quiz-matrix", "VS Code", .needsYou(.permission), 100_000),
      row("b", "Historical reporting header", "history", "VS Code", .working, 260_000),
      row("c", "Level the Spanish fiction batch", "leveler", "iTerm2", .working, 95_000),
      row("d", "Pages background tokens", "pages-bg", "VS Code", .done(.ended(durationMs: 14 * 60_000)), 130_000),
      row("e", "Oral AI retry notice", "oral", "Terminal", .done(.interrupted(ranMs: 3 * 60_000)), 40_000),
      row("f", "rc-a11y QA plan", "rc-a11y", "Terminal", .idle(backgroundShell: true), 3_600_000),
    ], now: now)
    snap.counts.done = 2
    model.apply(snap)
    model.idleOpen = true
    model.selectedKey = "d"
    let light = ImageRenderer(content: PanelRoot(model: model, maxHeight: 520, actions: .init(), scrolls: false).frame(width: 340).background(Color(nsColor: NSColor(hex: 0xf4f4f7))).environment(\.colorScheme, .light))
    let dark = ImageRenderer(content: PanelRoot(model: model, maxHeight: 520, actions: .init(), scrolls: false).frame(width: 340).background(Color(nsColor: NSColor(hex: 0x1c1e32))).environment(\.colorScheme, .dark))
    light.scale = 2
    dark.scale = 2
    guard let l = light.nsImage, let d = dark.nsImage else { throw NSError(domain: "preview", code: 1) }
    let size = CGSize(width: l.size.width + d.size.width + 24, height: max(l.size.height, d.size.height) + 16)
    let out = NSImage(size: size, flipped: false) { _ in
      NSColor(hex: 0xf5f6fb).setFill()
      NSRect(origin: .zero, size: size).fill()
      l.draw(at: CGPoint(x: 8, y: 8), from: .zero, operation: .sourceOver, fraction: 1)
      d.draw(at: CGPoint(x: l.size.width + 16, y: 8), from: .zero, operation: .sourceOver, fraction: 1)
      return true
    }
    guard let tiff = out.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else { return }
    try png.write(to: url)
  }
}

extension PreviewSheet {
  /// `1UP --render-all dir`: menu bar sheet, the panel in its three states, settings and the welcome card.
  static func renderAll(themes: [Theme], problems: [String], to dir: URL) throws {
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try render(themes: themes, to: dir.appendingPathComponent("menubar.png"))
    try renderPanel(themes: themes, problems: problems, to: dir.appendingPathComponent("panel.png"))

    let empty = AppModel(themes: themes, problems: problems)
    empty.apply(Snapshot(now: SessionEngine.nowMs()))
    try write(PanelRoot(model: empty, maxHeight: 520, actions: .init(), scrolls: false).frame(width: 340), to: dir.appendingPathComponent("panel-empty.png"))

    let broken = AppModel(themes: themes, problems: problems)
    let now = SessionEngine.nowMs()
    broken.apply(Snapshot(folderError: "The sessions folder /Users/hobe/.claude/sessions can't be read.", unreadableSince: now - 40_000, lastGoodRead: now - 34_000, now: now))
    try write(PanelRoot(model: broken, maxHeight: 520, actions: .init(), scrolls: false).frame(width: 340), to: dir.appendingPathComponent("panel-cannot-tell.png"))

    let settings = AppModel(themes: themes, problems: problems)
    settings.apply(Snapshot(rows: [], versions: ["2.1.295"], now: now))
    settings.setupResults = [
      SetupResult(title: "Sessions", pass: true, detail: "Found 6 sessions in 1 config folder", fix: nil),
      SetupResult(title: "Claude Code version", pass: true, detail: "Tested with 2.1.295", fix: nil),
      SetupResult(title: "Login", pass: false, detail: "macOS is holding 1UP for approval", fix: .openLoginItems),
    ]
    try write(SettingsView(model: settings, actions: .init(), startChecked: true), to: dir.appendingPathComponent("settings.png"))

    let welcome = AppModel(themes: themes, problems: problems)
    welcome.apply(Snapshot(rows: (0..<6).map { i in
      SessionRow(key: "\(i)", pid: Int32(i), sessionId: "", title: "t", folder: "f", app: nil, state: .idle(backgroundShell: false), since: now, startedAt: now, version: nil, configDir: URL(fileURLWithPath: "/"), rawStatus: "idle")
    }, now: now))
    try write(WelcomeView(model: welcome, gotIt: {}), to: dir.appendingPathComponent("welcome.png"))
  }

  private static func write<V: View>(_ view: V, to url: URL) throws {
    let light = ImageRenderer(content: view.background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .light))
    light.scale = 2
    guard let img = light.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
    else { throw NSError(domain: "preview", code: 2, userInfo: [NSLocalizedDescriptionKey: url.lastPathComponent]) }
    try png.write(to: url)
  }
}

extension PreviewSheet {
  /// `1UP --render-icon dir`: writes dir/AppIcon.iconset from the fallback theme's icon so make-app.sh can run iconutil.
  /// The art is generated rather than stored, so the icon can never drift from the theme it comes from.
  static func renderIconSet(themes: [Theme], to dir: URL) throws {
    guard let theme = themes.first(where: { $0.id == Theme.fallbackID }) ?? themes.first else {
      throw NSError(domain: "icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "no theme to draw"])
    }
    let iconset = dir.appendingPathComponent("AppIcon.iconset", isDirectory: true)
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
    let master = try masterIcon(theme: theme)
    for size in [16, 32, 128, 256, 512] {
      for scale in [1, 2] {
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try writePNG(try resized(master, to: size * scale), to: iconset.appendingPathComponent(name))
      }
    }
  }

  /// Apple's icon grid: an 824 pt rounded square on a 1024 canvas. The sprite sits in the middle at 36×.
  private static func masterIcon(theme: Theme) throws -> CGImage {
    let side = 1024
    let ctx = try context(side)
    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    ctx.addPath(CGPath(roundedRect: plate, cornerWidth: 185, cornerHeight: 185, transform: nil))
    ctx.setFillColor(NSColor(hex: 0x05060f).cgColor)
    ctx.fillPath()
    let scale: CGFloat = 36
    let origin = (CGFloat(side) - CGFloat(Theme.iconSize) * scale) / 2
    ThemeArt.drawThemeIcon(
      theme: theme, ink: NSColor(hex: 0xf2f4ff), at: CGPoint(x: origin, y: origin), scale: scale,
      in: PixelCanvas(ctx: ctx, height: CGFloat(side)))
    guard let image = ctx.makeImage() else { throw NSError(domain: "icon", code: 2) }
    return image
  }

  private static func resized(_ image: CGImage, to px: Int) throws -> CGImage {
    let ctx = try context(px)
    ctx.interpolationQuality = px < image.width ? .high : .none
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: px, height: px))
    guard let out = ctx.makeImage() else { throw NSError(domain: "icon", code: 3) }
    return out
  }

  private static func context(_ side: Int) throws -> CGContext {
    guard let ctx = CGContext(
      data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw NSError(domain: "icon", code: 4) }
    return ctx
  }

  private static func writePNG(_ image: CGImage, to url: URL) throws {
    guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
      throw NSError(domain: "icon", code: 5, userInfo: [NSLocalizedDescriptionKey: url.lastPathComponent])
    }
    try png.write(to: url)
  }
}
