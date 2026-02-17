import SwiftUI
import Photos
import AVKit

struct PhotoGridView: View {
    let fetchResult: PHFetchResult<PHAsset>
    let imageManager: PHCachingImageManager
    let columnCount: Int
    let onTap: (PHAsset) -> Void

    private let gap: CGFloat = 3

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: gap), count: columnCount)
    }

    var body: some View {
        GeometryReader { geo in
            let side = (geo.size.width - CGFloat(columnCount - 1) * gap) / CGFloat(columnCount)
            ScrollView(showsIndicators: false) {
                if fetchResult.count == 0 {
                    ContentUnavailableView(
                        "No Media",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Nothing matches this filter.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    LazyVGrid(columns: columns, spacing: gap) {
                        ForEach(0..<fetchResult.count, id: \.self) { i in
                            GridCell(
                                asset: fetchResult.object(at: i),
                                imageManager: imageManager,
                                side: side,
                                onTap: onTap
                            )
                        }
                    }
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: columnCount)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - GridCell  (corner radius = 8)
// ─────────────────────────────────────────────────────────────────────────────

private struct GridCell: View {
    let asset: PHAsset
    let imageManager: PHCachingImageManager
    let side: CGFloat
    let onTap: (PHAsset) -> Void

    @State private var image: UIImage? = nil
    @State private var tapHighlight = false
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ZStack {
            Color(.systemGray5)
            if let img = image {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ProgressView().tint(.secondary)
            }
        }
        .frame(width: side, height: side)
        .scaleEffect(tapHighlight ? 0.96 : 1)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))   // ← corner radius
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(tapHighlight ? 0.18 : 0))
        }
        .overlay(alignment: .bottomLeading) {
            if asset.mediaType == .video {
                HStack(spacing: 3) {
                    Image(systemName: "play.fill").font(.system(size: 8, weight: .bold))
                    Text(durStr(asset.duration)).font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 5).padding(.vertical, 3)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 5))
                .padding(4)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .animation(.easeOut(duration: 0.12), value: tapHighlight)
        .onTapGesture { handleTap() }
        .contextMenu {
            Button {
                onTap(asset)
            } label: {
                Label("Open", systemImage: "arrow.up.forward.app")
            }

            Label(asset.mediaType == .video ? "Video" : "Photo",
                  systemImage: asset.mediaType == .video ? "video" : "photo")
        } preview: {
            GridCellContextPreview(asset: asset, imageManager: imageManager, thumbnail: image)
        }
        .task(id: asset.localIdentifier + "_\(Int(side))") { await loadThumb() }
    }

    private func handleTap() {
        tapHighlight = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            onTap(asset)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            tapHighlight = false
        }
    }

    private func durStr(_ s: TimeInterval) -> String {
        let t = Int(s)
        return t >= 3600
            ? String(format: "%d:%02d:%02d", t/3600, (t%3600)/60, t%60)
            : String(format: "%d:%02d", t/60, t%60)
    }

    private func loadThumb() async {
        let opts = PHImageRequestOptions()
        opts.isSynchronous = false
        opts.deliveryMode  = .opportunistic
        opts.resizeMode    = .fast
        opts.isNetworkAccessAllowed = true
        let px = CGSize(width: side * displayScale, height: side * displayScale)
        await withCheckedContinuation { cont in
            var resumed = false
            imageManager.requestImage(
                for: asset, targetSize: px, contentMode: .aspectFill, options: opts
            ) { img, info in
                let deg = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !resumed { image = img; resumed = true; cont.resume() }
                else if !deg, let img { Task { @MainActor in image = img } }
            }
        }
    }
}

private struct GridCellContextPreview: View {
    let asset: PHAsset
    let imageManager: PHCachingImageManager
    let thumbnail: UIImage?

    var body: some View {
        Group {
            if asset.mediaType == .video {
                GridVideoPreview(asset: asset)
            } else {
                GridPhotoPreview(asset: asset, imageManager: imageManager, thumbnail: thumbnail)
            }
        }
        .frame(width: 240, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct GridPhotoPreview: View {
    let asset: PHAsset
    let imageManager: PHCachingImageManager
    let thumbnail: UIImage?

    @State private var previewImage: UIImage? = nil

    var body: some View {
        ZStack {
            Color.black

            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
            } else if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .blur(radius: 1.5)
            } else {
                ProgressView().tint(.white)
            }
        }
        .task { await loadPreview() }
    }

    private func loadPreview() async {
        let opts = PHImageRequestOptions()
        opts.isSynchronous = false
        opts.deliveryMode = .highQualityFormat
        opts.resizeMode = .exact
        opts.isNetworkAccessAllowed = true

        let size = CGSize(width: 900, height: 1200)
        await withCheckedContinuation { cont in
            var resumed = false
            imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFit,
                options: opts
            ) { img, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if let img {
                    previewImage = img
                }
                if !resumed, (!isDegraded || img != nil) {
                    resumed = true
                    cont.resume()
                }
            }
        }
    }
}

private struct GridVideoPreview: View {
    let asset: PHAsset

    @State private var player: AVPlayer? = nil

    var body: some View {
        ZStack {
            Color.black

            if let player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.isMuted = true
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                ProgressView().tint(.white)
            }
        }
        .task { await loadPlayer() }
    }

    private func loadPlayer() async {
        let opts = PHVideoRequestOptions()
        opts.deliveryMode = .automatic
        opts.isNetworkAccessAllowed = true

        await withCheckedContinuation { cont in
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: opts) { item, _ in
                DispatchQueue.main.async {
                    if let item {
                        player = AVPlayer(playerItem: item)
                    }
                    cont.resume()
                }
            }
        }
    }
}
