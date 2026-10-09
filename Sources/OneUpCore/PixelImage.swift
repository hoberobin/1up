import CoreGraphics
import Foundation
import ImageIO

/// A decoded PNG as premultiplied RGBA bytes, 1 px per point. Small enough to copy freely.
public struct PixelImage: Equatable, Sendable {
  public var width: Int
  public var height: Int
  public var rgba: [UInt8]

  public init(width: Int, height: Int, rgba: [UInt8]) {
    self.width = width
    self.height = height
    self.rgba = rgba
  }

  public init?(contentsOf url: URL) {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }
    self.init(cgImage: image)
  }

  public init?(cgImage image: CGImage) {
    let w = image.width, h = image.height
    var bytes = [UInt8](repeating: 0, count: w * h * 4)
    let ok = bytes.withUnsafeMutableBytes { buf -> Bool in
      guard let ctx = CGContext(
        data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      ctx.interpolationQuality = .none
      ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
      return true
    }
    guard ok else { return nil }
    self.init(width: w, height: h, rgba: bytes)
  }

  public func alpha(x: Int, y: Int) -> UInt8 {
    guard x >= 0, y >= 0, x < width, y < height else { return 0 }
    return rgba[(y * width + x) * 4 + 3]
  }

  public func color(x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    let o = (y * width + x) * 4
    return (rgba[o], rgba[o + 1], rgba[o + 2], rgba[o + 3])
  }

  /// Alpha channel as a bitmap, for shape comparisons.
  public var alphaMask: [Bool] { stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] > 0 } }

  public var isEmpty: Bool { !alphaMask.contains(true) }

  public func cropped(x: Int, y: Int, width w: Int, height h: Int) -> PixelImage {
    var out = [UInt8](repeating: 0, count: w * h * 4)
    for row in 0..<h where y + row < height {
      for col in 0..<w where x + col < width {
        let src = ((y + row) * width + (x + col)) * 4
        let dst = (row * w + col) * 4
        out[dst..<dst + 4] = rgba[src..<src + 4]
      }
    }
    return PixelImage(width: w, height: h, rgba: out)
  }

  /// Pixels where either image has alpha: the idle silhouette of a scene with its ink layer.
  public func unionAlpha(with other: PixelImage?) -> [Bool] {
    guard let other, other.width == width, other.height == height else { return alphaMask }
    return zip(alphaMask, other.alphaMask).map { $0 || $1 }
  }

  public func toCGImage() -> CGImage? {
    let data = Data(rgba)
    guard let provider = CGDataProvider(data: data as CFData) else { return nil }
    return CGImage(
      width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
  }
}
