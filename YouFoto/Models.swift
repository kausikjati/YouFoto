import SwiftUI
import Photos

enum MediaFilter: String, CaseIterable, Identifiable, Hashable {
    case photos = "Photos"
    case videos = "Videos"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .photos: return "photo"
        case .videos: return "video"
        }
    }

    var mediaType: PHAssetMediaType {
        switch self {
        case .photos: return .image
        case .videos: return .video
        }
    }
}

enum AlbumFilter: String, CaseIterable, Identifiable {
    case all = "All", camera = "Camera", screenshots = "Screenshots"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .all:          return "photo.stack.fill"
        case .camera:       return "camera.fill"
        case .screenshots:  return "iphone"
        }
    }
}
