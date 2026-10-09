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

  /// Draws a pixel image at 1 px per point with nearest-neighbour scaling.
  static func draw(_ image: CGImage?, at origin: CGPoint, scale: CGFloat = 1, alpha: CGFloat = 1, in ctx: CGContext) {
    guard let image else { return }
    ctx.saveGState()
    ctx.interpolationQuality = .none
    ctx.setAlpha(alpha)
    ctx.draw(image, in: CGRect(x: origin.x, y: origin.y, width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale))
    ctx.restoreGState()
  }

  /// Icon = tint mask, then the untinted detail. With Increase Contrast, a 1 pt outline in the menu bar colour first.
  static func drawIcon(mask: PixelImage, detail: PixelImage?, tint: NSColor, ink: NSColor, outline: Bool, at origin: CGPoint, scale: CGFloat = 1, in ctx: CGContext) {
    if outline, let edge = tinted(mask, ink) {
      for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
        draw(edge, at: CGPoint(x: origin.x + CGFloat(dx) * scale, y: origin.y + CGFloat(dy) * scale), scale: scale, in: ctx)
      }
    }
    draw(tinted(mask, tint), at: origin, scale: scale, in: ctx)
    if let detail { draw(detail.toCGImage(), at: origin, scale: scale, in: ctx) }
  }

  /// Scene frame = colour art (dark variant on a dark bar), then the ink layer in the menu bar colour.
  static func drawScene(theme: Theme, frame: Int, dark: Bool, ink: NSColor, at origin: CGPoint, scale: CGFloat = 1, alpha: CGFloat = 1, in ctx: CGContext) {
    draw(theme.sceneFrame(frame, dark: dark).toCGImage(), at: origin, scale: scale, alpha: alpha, in: ctx)
    if let inkFrame = theme.sceneInkFrame(frame) { draw(tinted(inkFrame, ink), at: origin, scale: scale, alpha: alpha, in: ctx) }
  }

  /// The idle silhouette in one colour.
  static func drawIdle(theme: Theme, ink: NSColor, alpha: CGFloat, at origin: CGPoint, scale: CGFloat = 1, in ctx: CGContext) {
    let mask = maskImage(from: theme.idleMask, width: Theme.sceneWidth, height: Theme.sceneHeight)
    draw(tinted(mask, ink, alpha: alpha), at: origin, scale: scale, in: ctx)
  }

  static func drawThemeIcon(theme: Theme, ink: NSColor, at origin: CGPoint, scale: CGFloat = 1, in ctx: CGContext) {
    draw(theme.icon.toCGImage(), at: origin, scale: scale, in: ctx)
    if let inkMask = theme.iconInk { draw(tinted(inkMask, ink), at: origin, scale: scale, in: ctx) }
  }

  /// Panel glyphs and picker tiles are plain NSImages built from the same drawing calls.
  @MainActor
  static func image(size: CGSize, scale: CGFloat = 1, isTemplate: Bool = false, _ body: @escaping (CGContext) -> Void) -> NSImage {
    let image = NSImage(size: size, flipped: true) { _ in
      guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
      body(ctx)
      return true
    }
    image.isTemplate = isTemplate
    return image
  }

  @MainActor
  static func glyph(theme: Theme, kind: StateGroup, tints: Tints, ink: NSColor) -> NSImage {
    let s = CGFloat(Theme.iconSize)
    return image(size: CGSize(width: s, height: s)) { ctx in
      switch kind {
      case .needsYou: drawIcon(mask: theme.need, detail: theme.needDetail, tint: tints.need, ink: ink, outline: false, at: .zero, in: ctx)
      case .done: drawIcon(mask: theme.done, detail: theme.doneDetail, tint: tints.done, ink: ink, outline: false, at: .zero, in: ctx)
      case .working: drawThemeIcon(theme: theme, ink: ink, at: .zero, in: ctx)
      case .idle:
        ctx.setFillColor(NSColor.tertiaryLabelColor.cgColor)
        ctx.fillEllipse(in: CGRect(x: 4.4, y: 4.4, width: 5.2, height: 5.2))
      }
    }
  }

  /// 88 × 56 picker tile: the scene at 2× on #05060f with ink #f2f4ff, like the spec's gallery.
  @MainActor
  static func tile(theme: Theme, frame: Int) -> NSImage {
    image(size: CGSize(width: 88, height: 56)) { ctx in
      ctx.setFillColor(NSColor(hex: 0x05060f).cgColor)
      ctx.fill(CGRect(x: 0, y: 0, width: 88, height: 56))
      drawScene(theme: theme, frame: frame, dark: true, ink: NSColor(hex: 0xf2f4ff), at: CGPoint(x: 0, y: 12), scale: 2, in: ctx)
    }
  }
}
