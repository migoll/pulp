import AppKit
import Foundation

@MainActor
final class ImageDocument: ObservableObject, Identifiable {
    let id = UUID()
    let sourceURL: URL?
    let sourceBytes: Data
    let image: PulpImage
    let thumbnail: NSImage?

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

    var sourceDimensions: (width: Int, height: Int) {
        (image.width, image.height)
    }

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
