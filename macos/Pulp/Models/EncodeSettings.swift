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
    case thumbnail
    case avatar
    case hd
    case fullHD
    case twoK
    case fourK
    case instagramSquare
    case instagramPortrait
    case instagramStory
    case twitterCard
    case twitterHeader
    case facebookCover
    case linkedInBanner
    case youTubeThumbnail
    case appleWatch

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .custom:             return "Custom"
        case .thumbnail:          return "Thumbnail (256)"
        case .avatar:             return "Avatar (512)"
        case .hd:                 return "720p (1280×720)"
        case .fullHD:             return "1080p (1920×1080)"
        case .twoK:               return "2K (2560×1440)"
        case .fourK:              return "4K (3840×2160)"
        case .instagramSquare:    return "Instagram Square"
        case .instagramPortrait:  return "Instagram Portrait"
        case .instagramStory:     return "Instagram Story"
        case .twitterCard:        return "Twitter Card"
        case .twitterHeader:      return "Twitter Header"
        case .facebookCover:      return "Facebook Cover"
        case .linkedInBanner:     return "LinkedIn Banner"
        case .youTubeThumbnail:   return "YouTube Thumbnail"
        case .appleWatch:         return "Apple Watch (Ultra)"
        }
    }

    /// `nil` means "use the explicit max width/height fields."
    var dimensions: (width: Int, height: Int)? {
        switch self {
        case .custom:             return nil
        case .thumbnail:          return (256, 256)
        case .avatar:             return (512, 512)
        case .hd:                 return (1280, 720)
        case .fullHD:             return (1920, 1080)
        case .twoK:               return (2560, 1440)
        case .fourK:              return (3840, 2160)
        case .instagramSquare:    return (1080, 1080)
        case .instagramPortrait:  return (1080, 1350)
        case .instagramStory:     return (1080, 1920)
        case .twitterCard:        return (1200, 675)
        case .twitterHeader:      return (1500, 500)
        case .facebookCover:      return (1200, 630)
        case .linkedInBanner:     return (1584, 396)
        case .youTubeThumbnail:   return (1280, 720)
        case .appleWatch:         return (502, 410)
        }
    }
}
