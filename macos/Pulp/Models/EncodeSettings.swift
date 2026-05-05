import Foundation

struct EncodeSettings: Equatable {
    var format: PulpFormat = .jpeg
    /// 1–100. Effective only for formats that support quality (everything but PNG).
    var quality: Int = 80
    /// 0 means no constraint on this axis. Ignored when a non-`.custom` preset is set.
    var maxWidth: Int = 0
    var maxHeight: Int = 0
    var preset: SizePreset = .custom

    func toEncodeOptions() -> EncodeOptions {
        let (w, h) = preset.dimensions ?? (maxWidth, maxHeight)
        return EncodeOptions(
            format: format,
            quality: quality,
            maxWidth: w,
            maxHeight: h
        )
    }
}

enum SizePreset: String, CaseIterable, Identifiable {
    case custom
    case fullHD
    case fourK
    case hd
    case instagramSquare
    case instagramPortrait
    case twitter
    case thumbnail

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .custom:             return "Custom"
        case .fullHD:             return "1080p (1920×1080)"
        case .fourK:              return "4K (3840×2160)"
        case .hd:                 return "720p (1280×720)"
        case .instagramSquare:    return "Instagram Square"
        case .instagramPortrait:  return "Instagram Portrait"
        case .twitter:            return "Twitter Card"
        case .thumbnail:          return "Thumbnail (256)"
        }
    }

    /// `nil` means "use the explicit max width/height fields."
    var dimensions: (width: Int, height: Int)? {
        switch self {
        case .custom:             return nil
        case .fullHD:             return (1920, 1080)
        case .fourK:              return (3840, 2160)
        case .hd:                 return (1280, 720)
        case .instagramSquare:    return (1080, 1080)
        case .instagramPortrait:  return (1080, 1350)
        case .twitter:            return (1200, 675)
        case .thumbnail:          return (256, 256)
        }
    }
}
