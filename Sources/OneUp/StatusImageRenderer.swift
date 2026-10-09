import AppKit
import OneUpCore

/// Draws the menu bar item from the UI reference layout:
/// 6 · 44×16 scene · 4 · working count · 8 · 14×14 need icon · 3 · count · 8 · 14×14 done icon · 3 · count · 6.
@MainActor
struct StatusImageRenderer {
  static let height: CGFloat = 22
  static let pad: CGFloat = 6
  static let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)

  struct Input {
    var theme: Theme
    var counts: Counts
    var cannotTell: Bool
    var frame: Int
    var dark: Bool
    var ink: NSColor
    var increaseContrast: Bool
    var reduceMotion: Bool
  }

  static func countText(_ n: Int) -> String { n > 99 ? "99+" : String(n) }

  /// Two digits are reserved per count so 9 → 10 never shifts the item.
  static func countWidth(_ text: String) -> CGFloat {
    let attrs: [NSAttributedString.Key: Any] = [.font: font]
    let w = (text as NSString).size(withAttributes: attrs).width
    let two = ("00" as NSString).size(withAttributes: attrs).width
    return ceil(max(w, two))
  }

  private static var cache: [String: NSImage] = [:]
  private static var cacheKeyPrefix = ""

  static func render(_ input: Input) -> NSImage {
    let c = input.counts
    let prefix = "\(input.theme.id)|\(c.working)|\(c.needsYou)|\(c.needsYouWaited)|\(c.done)|\(input.cannotTell)|\(input.dark)|\(input.ink.rgba8)|\(input.increaseContrast)|\(input.reduceMotion)"
    if prefix != cacheKeyPrefix {
      cache.removeAll(keepingCapacity: true)
      cacheKeyPrefix = prefix
    }
    let frame = input.reduceMotion ? input.theme.idleFrame : ((input.frame % input.theme.frameCount) + input.theme.frameCount) % input.theme.frameCount
    let key = "\(prefix)|\(c.working > 0 && !input.cannotTell ? frame : 0)"
    if let hit = cache[key] { return hit }
    let image = draw(input, frame: frame)
    cache[key] = image
    return image
  }

  private static func draw(_ input: Input, frame: Int) -> NSImage {
    let tints = Tints.forAppearance(dark: input.dark)
    let sceneW = CGFloat(Theme.sceneWidth), icon = CGFloat(Theme.iconSize)
    let sceneY = (height - CGFloat(Theme.sceneHeight)) / 2, iconY = (height - icon) / 2
    let c = input.counts
    let idleOnly = !input.cannotTell && c.isEmpty

    struct Part { var kind: Kind; var x: CGFloat; var width: CGFloat; var text: String; var color: NSColor }
    enum Kind { case count, needIcon, doneIcon }
    var parts: [Part] = []
    var x = pad + sceneW
    if input.cannotTell {
      x += 4
      let w = countWidth("?")
      parts.append(Part(kind: .count, x: x, width: w, text: "?", color: tints.fail))
      x += w
    } else {
      if c.working > 0 {
        x += 4
        let t = countText(c.working), w = countWidth(t)
        parts.append(Part(kind: .count, x: x, width: w, text: t, color: input.ink))
        x += w
      }
      if c.needsYou > 0 {
        let tint = c.needsYouWaited ? tints.needWaited : tints.need
        x += 8
        parts.append(Part(kind: .needIcon, x: x, width: icon, text: "", color: tint))
        x += icon + 3
        let t = countText(c.needsYou), w = countWidth(t)
        parts.append(Part(kind: .count, x: x, width: w, text: t, color: tint))
        x += w
      }
      if c.done > 0 {
        x += 8
        parts.append(Part(kind: .doneIcon, x: x, width: icon, text: "", color: tints.done))
        x += icon + 3
        let t = countText(c.done), w = countWidth(t)
        parts.append(Part(kind: .count, x: x, width: w, text: t, color: tints.done))
        x += w
      }
    }
    let width = ceil(x + pad)
    let theme = input.theme

    // Pure-ink states are template images so macOS tints them on every menu bar.
    return ThemeArt.image(size: CGSize(width: width, height: height), isTemplate: idleOnly) { canvas in
      let origin = CGPoint(x: pad, y: sceneY)
      if input.cannotTell {
        ThemeArt.drawIdle(theme: theme, ink: input.ink, alpha: 0.4, at: origin, in: canvas)
      } else if c.working > 0 {
        ThemeArt.drawScene(theme: theme, frame: frame, dark: input.dark, ink: input.ink, at: origin, in: canvas)
      } else {
        ThemeArt.drawIdle(theme: theme, ink: input.ink, alpha: 0.5, at: origin, in: canvas)
      }
      for p in parts {
        switch p.kind {
        case .needIcon:
          ThemeArt.drawIcon(mask: theme.need, detail: theme.needDetail, tint: p.color, ink: input.ink, outline: input.increaseContrast, at: CGPoint(x: p.x, y: iconY), in: canvas)
        case .doneIcon:
          ThemeArt.drawIcon(mask: theme.done, detail: theme.doneDetail, tint: p.color, ink: input.ink, outline: input.increaseContrast, at: CGPoint(x: p.x, y: iconY), in: canvas)
        case .count:
          let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: p.color]
          let size = (p.text as NSString).size(withAttributes: attrs)
          // Counts sit on the same optical centre as the page's preview (cy + 1).
          (p.text as NSString).draw(at: CGPoint(x: p.x, y: (height - size.height) / 2 - 0.5), withAttributes: attrs)
        }
      }
    }
  }
}
