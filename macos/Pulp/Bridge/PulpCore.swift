import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A decoded image whose pixels live in Rust-owned memory. Re-encoding is
/// cheap; the source bytes are decoded once and reused for every encode call.
///
/// `@unchecked Sendable`: the handle and dimensions are immutable after init,
/// and the Rust core treats the underlying buffer as read-only during encode,
/// so concurrent encodes from multiple threads are safe.
final class PulpImage: @unchecked Sendable {
    private let handle: OpaquePointer

    let width: Int
    let height: Int

    private init(handle: OpaquePointer) {
        self.handle = handle
        self.width = Int(pulp_image_width(handle))
        self.height = Int(pulp_image_height(handle))
    }

    deinit {
        pulp_image_free(handle)
    }

    /// Decode a file's bytes. Falls back to ImageIO for formats the Rust core
    /// doesn't handle directly (HEIC, AVIF, RAW).
    static func decode(_ data: Data) -> PulpImage? {
        if let handle = data.withUnsafeBytes({ buffer -> OpaquePointer? in
            guard let base = buffer.baseAddress else { return nil }
            return pulp_decode(base.assumingMemoryBound(to: UInt8.self), buffer.count)
        }) {
            return PulpImage(handle: handle)
        }
        return decodeViaImageIO(data)
    }

    func encode(_ options: EncodeOptions) -> Data? {
        var raw = options.toRaw()
        guard let buffer = pulp_encode(handle, &raw) else { return nil }
        defer { pulp_buffer_free(buffer) }
        return Data(bytes: buffer.pointee.data, count: buffer.pointee.len)
    }

    private static func decodeViaImageIO(_ data: Data) -> PulpImage? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let cg = CGImageSourceCreateImageAtIndex(source, 0, nil),
            let rgba = cg.rgba8Bytes()
        else { return nil }

        return rgba.pixels.withUnsafeBufferPointer { buffer -> PulpImage? in
            guard let base = buffer.baseAddress,
                  let handle = pulp_image_from_rgba(
                    base, buffer.count,
                    UInt32(rgba.width), UInt32(rgba.height)
                  )
            else { return nil }
            return PulpImage(handle: handle)
        }
    }
}

struct EncodeOptions: Equatable {
    var format: PulpFormat = .jpeg
    /// 1–100. Ignored for PNG.
    var quality: Int = 80
    /// 0 means no limit on this axis.
    var maxWidth: Int = 0
    var maxHeight: Int = 0

    fileprivate func toRaw() -> PulpEncodeOptions {
        PulpEncodeOptions(
            format: format.rawValue,
            quality: UInt8(quality.clamped(to: 1...100)),
            max_width: UInt32(max(maxWidth, 0)),
            max_height: UInt32(max(maxHeight, 0))
        )
    }
}

enum PulpFormat: UInt8, CaseIterable, Identifiable {
    case jpeg = 0
    case png = 1
    case webp = 2
    case avif = 3

    var id: UInt8 { rawValue }

    var displayName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .png:  return "PNG"
        case .webp: return "WebP"
        case .avif: return "AVIF"
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png:  return "png"
        case .webp: return "webp"
        case .avif: return "avif"
        }
    }

    var contentType: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .png:  return .png
        case .webp: return .webP
        case .avif: return UTType("public.avif") ?? .image
        }
    }

    /// Whether the quality slider has any effect on this format.
    var supportsQuality: Bool {
        self != .png
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension CGImage {
    /// Repaint the image into a known RGBA8 layout so the Rust side can take
    /// the buffer at face value. ImageIO will hand us all sorts of pixel
    /// formats otherwise (premultiplied, BGRA, 16-bit float…).
    func rgba8Bytes() -> (pixels: [UInt8], width: Int, height: Int)? {
        let w = self.width
        let h = self.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)

        guard
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let ctx = pixels.withUnsafeMutableBytes({ buffer -> CGContext? in
                CGContext(
                    data: buffer.baseAddress,
                    width: w,
                    height: h,
                    bitsPerComponent: 8,
                    bytesPerRow: w * 4,
                    space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                              | CGBitmapInfo.byteOrder32Big.rawValue
                )
            })
        else { return nil }

        ctx.draw(self, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (pixels, w, h)
    }
}
