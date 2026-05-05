import AppKit
import Foundation
import ImageIO

@MainActor
final class ImageDocument: ObservableObject, Identifiable {
    let id = UUID()
    let sourceURL: URL?
    let sourceBytes: Data

    @Published private(set) var image: PulpImage
    @Published private(set) var thumbnail: NSImage?
    @Published private(set) var encoded: EncodedResult?
    @Published private(set) var isEncoding = false

    init(sourceURL: URL?, sourceBytes: Data, image: PulpImage) {
        self.sourceURL = sourceURL
        self.sourceBytes = sourceBytes
        self.image = image
        self.thumbnail = Self.makeThumbnail(from: sourceBytes)
    }

    var displayName: String {
        sourceURL?.deletingPathExtension().lastPathComponent ?? "Image"
    }

    var sourceByteCount: Int { sourceBytes.count }

    /// Re-encode using the supplied settings. Calls overlap safely — only the
    /// most recent result wins, since each call replaces `encoded` on
    /// completion.
    func encode(with settings: EncodeSettings) async {
        isEncoding = true
        let options = settings.toEncodeOptions()
        let image = self.image

        let data = await Task.detached(priority: .userInitiated) {
            image.encode(options)
        }.value

        isEncoding = false
        guard let data else { return }
        encoded = EncodedResult(data: data, format: settings.format)
    }

    /// Replace this document's working image with a cropped copy.
    ///
    /// `pixelRect` is in original-image pixel coordinates with origin
    /// top-left. The source bytes are intentionally left untouched so the
    /// "savings vs. original" stat keeps comparing against the file the
    /// user dropped in.
    func applyCrop(pixelRect: CGRect, settings: EncodeSettings) async {
        guard
            let source = CGImageSourceCreateWithData(sourceBytes as CFData, nil),
            let cg = CGImageSourceCreateImageAtIndex(source, 0, nil),
            let cropped = cg.cropping(to: pixelRect),
            let newImage = PulpImage.from(cgImage: cropped)
        else { return }

        image = newImage
        thumbnail = NSImage(cgImage: cropped, size: .zero)
        await encode(with: settings)
    }

    private static func makeThumbnail(from data: Data) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 512,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return NSImage(cgImage: cg, size: .zero)
    }
}

struct EncodedResult: Equatable {
    let data: Data
    let format: PulpFormat
    var byteCount: Int { data.count }
}
