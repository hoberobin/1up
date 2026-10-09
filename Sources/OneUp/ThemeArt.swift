import AppKit
import OneUpCore

/// Tints per appearance. Each keeps at least 3:1 contrast on its menu bar.
struct Tints {
  var need: NSColor
  var needWaited: NSColor
  var done: NSColor
  var fail: NSColor

  static let light = Tints(need: NSColor(hex: 0xe2680a), needWaited: NSColor(hex: 0xd8261c), done: NSColor(hex: 0x1c9353), fail: NSColor(hex: 0xcf3439))
  static let dark = Tints(need: NSColor(hex: 0xff9a3d), needWaited: NSColor(hex: 0xff4a3d), done: NSColor(hex: 0x3fd184), fail: NSColor(hex: 0xff666b))

  static func forAppearance(dark: Bool) -> Tints { dark ? .dark : .light }
}

extension NSColor {
  convenience init(hex: UInt32, alpha: CGFloat = 1) {
    self.init(
      srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255,
      alpha: alpha)
  }

  var rgba8: (UInt8, UInt8, UInt8, UInt8) {
    let c = usingColorSpace(.sRGB) ?? self
    return (UInt8((c.redComponent * 255).rounded()), UInt8((c.greenComponent * 255).rounded()), UInt8((c.blueComponent * 255).rounded()), UInt8((c.alphaComponent * 255).rounded()))
  }
}

/// A CGContext with its height, so callers can place art by its top-left corner. CGImages are
/// drawn bottom-up; a flipped NSImage handler would turn them upside down.
struct PixelCanvas {
  let ctx: CGContext
  let height: CGFloat
  func rect(x: CGFloat, top: CGFloat, width: CGFloat, height h: CGFloat) -> CGRect {
    CGRect(x: x, y: height - top - h, width: width, height: h)
  }
}

/// Turns theme pixels into CGImages: tinted masks, ink layers, and the composed icons.
enum ThemeArt {
  /// An alpha mask filled with one colour (premultiplied), optionally scaled by `alpha`.
  static func tinted(_ mask: PixelImage, _ color: NSColor, alpha: CGFloat = 1) -> CGImage? {
    let (r, g, b, a) = color.rgba8
    var out = [UInt8](repeating: 0, count: mask.rgba.count)
    for i in stride(from: 0, to: mask.rgba.count, by: 4) {
      let m = CGFloat(mask.rgba[i + 3]) / 255 * (CGFloat(a) / 255) * alpha
      guard m > 0 else { continue }
      out[i] = UInt8((CGFloat(r) * m).rounded())
      out[i + 1] = UInt8((CGFloat(g) * m).rounded())
      out[i + 2] = UInt8((CGFloat(b) * m).rounded())
      out[i + 3] = UInt8((255 * m).rounded())
    }
    return PixelImage(width: mask.width, height: mask.height, rgba: out).toCGImage()
  }

  static func maskImage(from bits: [Bool], width: Int, height: Int) -> PixelImage {
    PixelImage(width: width, height: height, rgba: bits.flatMap { $0 ? [255, 255, 255, 255] : [0, 0, 0, 0] })
  }

  /// Draws a pixel image at 1 px per point with nearest-neighbour scaling; `origin` is the top-left corner.
  static func draw(_ image: CGImage?, at origin: CGPoint, scale: CGFloat = 1, alpha: CGFloat = 1, in canvas: PixelCanvas) {
    guard let image else { return }
    let ctx = canvas.ctx
    ctx.saveGState()
    ctx.interpolationQuality = .none
    ctx.setAlpha(alpha)
    ctx.draw(image, in: canvas.rect(x: origin.x, top: origin.y, width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale))
    ctx.restoreGState()
  }

  /// Icon = tint mask, then the untinted detail. With Increase Contrast, a 1 pt outline in the menu bar colour first.
  static func drawIcon(mask: PixelImage, detail: PixelImage?, tint: NSColor, ink: NSColor, outline: Bool, at origin: CGPoint, scale: CGFloat = 1, in canvas: PixelCanvas) {
    if outline, let edge = tinted(mask, ink) {
      for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
        draw(edge, at: CGPoint(x: origin.x + CGFloat(dx) * scale, y: origin.y + CGFloat(dy) * scale), scale: scale, in: canvas)
      }
    }
    draw(tinted(mask, tint), at: origin, scale: scale, in: canvas)
    if let detail { draw(detail.toCGImage(), at: origin, scale: scale, in: canvas) }
  }

  /// Scene frame = colour art (dark variant on a dark bar), then the ink layer in the menu bar colour.
  static func drawScene(theme: Theme, frame: Int, dark: Bool, ink: NSColor, at origin: CGPoint, scale: CGFloat = 1, alpha: CGFloat = 1, in canvas: PixelCanvas) {
    draw(theme.sceneFrame(frame, dark: dark).toCGImage(), at: origin, scale: scale, alpha: alpha, in: canvas)
    if let inkFrame = theme.sceneInkFrame(frame) { draw(tinted(inkFrame, ink), at: origin, scale: scale, alpha: alpha, in: canvas) }
  }

  /// The idle silhouette in one colour.
  static func drawIdle(theme: Theme, ink: NSColor, alpha: CGFloat, at origin: CGPoint, scale: CGFloat = 1, in canvas: PixelCanvas) {
    let mask = maskImage(from: theme.idleMask, width: Theme.sceneWidth, height: Theme.sceneHeight)
    draw(tinted(mask, ink, alpha: alpha), at: origin, scale: scale, in: canvas)
  }

  static func drawThemeIcon(theme: Theme, ink: NSColor, at origin: CGPoint, scale: CGFloat = 1, in canvas: PixelCanvas) {
    draw(theme.icon.toCGImage(), at: origin, scale: scale, in: canvas)
    if let inkMask = theme.iconInk { draw(tinted(inkMask, ink), at: origin, scale: scale, in: canvas) }
  }

  /// Panel glyphs and picker tiles are plain NSImages built from the same drawing calls.
  /// Rendered once into a bitmap (not a lazy drawing handler), so the result draws the same everywhere.
  @MainActor
  static func image(size: CGSize, isTemplate: Bool = false, _ body: (PixelCanvas) -> Void) -> NSImage {
    let scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2
    let image = NSImage(size: size)
    guard let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale), bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    else { return image }
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    if let gc = NSGraphicsContext(bitmapImageRep: rep) {
      NSGraphicsContext.current = gc
      gc.cgContext.interpolationQuality = .none
      body(PixelCanvas(ctx: gc.cgContext, height: size.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    image.addRepresentation(rep)
    image.isTemplate = isTemplate
    return image
  }

  @MainActor private static var glyphCache: [String: NSImage] = [:]
  @MainActor private static var tileCache: [String: NSImage] = [:]

  @MainActor
  static func glyph(theme: Theme, kind: StateGroup, tints: Tints, ink: NSColor) -> NSImage {
    let key = "\(theme.id)|\(kind)|\(tints.need.rgba8)|\(ink.rgba8)"
    if let hit = glyphCache[key] { return hit }
    let s = CGFloat(Theme.iconSize)
    let img = image(size: CGSize(width: s, height: s)) { canvas in
      switch kind {
      case .needsYou: drawIcon(mask: theme.need, detail: theme.needDetail, tint: tints.need, ink: ink, outline: false, at: .zero, in: canvas)
      case .done: drawIcon(mask: theme.done, detail: theme.doneDetail, tint: tints.done, ink: ink, outline: false, at: .zero, in: canvas)
      case .working: drawThemeIcon(theme: theme, ink: ink, at: .zero, in: canvas)
      case .idle:
        canvas.ctx.setFillColor(NSColor.tertiaryLabelColor.cgColor)
        canvas.ctx.fillEllipse(in: CGRect(x: 4.4, y: 4.4, width: 5.2, height: 5.2))
      }
    }
    glyphCache[key] = img
    return img
  }

  /// 88 × 56 picker tile: the scene at 2× on #05060f with ink #f2f4ff, like the spec's gallery.
  @MainActor
  static func tile(theme: Theme, frame: Int) -> NSImage {
    let key = "\(theme.id)|\(frame % theme.frameCount)"
    if let hit = tileCache[key] { return hit }
    let img = image(size: CGSize(width: 88, height: 56)) { canvas in
      canvas.ctx.setFillColor(NSColor(hex: 0x05060f).cgColor)
      canvas.ctx.fill(CGRect(x: 0, y: 0, width: 88, height: 56))
      drawScene(theme: theme, frame: frame, dark: true, ink: NSColor(hex: 0xf2f4ff), at: CGPoint(x: 0, y: 12), scale: 2, in: canvas)
    }
    tileCache[key] = img
    return img
  }
}
