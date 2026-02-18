import SwiftUI
import Photos
import AVKit

struct PhotoGridView: View {
    let fetchResult: PHFetchResult<PHAsset>
    let imageManager: PHCachingImageManager
    let columnCount: Int
    @Binding var isSelectionMode: Bool
    @Binding var selectedAssetIDs: Set<String>
    let onTap: (PHAsset) -> Void
    let onShare: (PHAsset) -> Void
    let onEdit: (PHAsset) -> Void
    let onDelete: (PHAsset) -> Void

    private let gap: CGFloat = 3
    @State private var scrollContentMinY: CGFloat = 0
    @State private var dragVisitedIndices: Set<Int> = []
    @State private var dragShouldSelect: Bool?
    @State private var dragLocation: CGPoint? = nil
    @State private var autoScrollTimer: Timer? = nil
    @State private var isDragSelecting = false

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: gap), count: columnCount)
    }

    var body: some View {
        GeometryReader { geo in
            let side = (geo.size.width - CGFloat(columnCount - 1) * gap) / CGFloat(columnCount)
            ScrollViewReader { proxy in
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
                        VStack(spacing: 0) {
                            GeometryReader { marker in
                                Color.clear
                                    .preference(
                                        key: GridScrollOffsetPreferenceKey.self,
                                        value: marker.frame(in: .named("gridScroll")).minY
                                    )
                            }
                            .frame(height: 0)

                            LazyVGrid(columns: columns, spacing: gap) {
                                ForEach(0..<fetchResult.count, id: \.self) { i in
                                    GridCell(
                                        asset: fetchResult.object(at: i),
                                        imageManager: imageManager,
                                        side: side,
                                        isSelectionMode: isSelectionMode,
                                        isSelected: selectedAssetIDs.contains(fetchResult.object(at: i).localIdentifier),
                                        onTap: onTap,
                                        onShare: onShare,
                                        onEdit: onEdit,
                                        onDelete: onDelete,
                                        onSelectToggle: { toggleSelection(at: i) }
                                    )
                                    .id(i)
                                }
                            }
                        }
                        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: columnCount)
                        .animation(.easeInOut(duration: 0.2), value: fetchResult.count)
                    }
                }
                .coordinateSpace(name: "gridScroll")
                .simultaneousGesture(dragSelectionGesture(side: side, viewportHeight: geo.size.height, proxy: proxy))
                .onPreferenceChange(GridScrollOffsetPreferenceKey.self) { scrollContentMinY = $0 }
                .onChange(of: isSelectionMode) { _, active in
                    if !active {
                        resetDragSelectionState()
                    }
                }
                .onDisappear(perform: stopAutoScroll)
            }
        }
    }

    private func dragSelectionGesture(side: CGFloat, viewportHeight: CGFloat, proxy: ScrollViewProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.18)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard isSelectionMode else { return }

                switch value {
                case .first(true):
                    if !isDragSelecting {
                        isDragSelecting = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                case .second(true, let dragValue?):
                    guard isDragSelecting else { return }
                    dragLocation = dragValue.location
                    selectAtDragLocation(dragValue.location, side: side)
                    startAutoScrollIfNeeded(side: side, viewportHeight: viewportHeight, proxy: proxy)
                default:
                    break
                }
            }
            .onEnded { _ in
                resetDragSelectionState()
            }
    }

    private func resetDragSelectionState() {
        dragVisitedIndices.removeAll()
        dragShouldSelect = nil
        dragLocation = nil
        isDragSelecting = false
        stopAutoScroll()
    }

    private func selectAtDragLocation(_ location: CGPoint, side: CGFloat) {
        guard let index = index(at: location, side: side),
              dragVisitedIndices.insert(index).inserted else { return }

        let assetID = fetchResult.object(at: index).localIdentifier
        if dragShouldSelect == nil {
            dragShouldSelect = !selectedAssetIDs.contains(assetID)
        }
        applySelection(assetID: assetID)
    }

    private func startAutoScrollIfNeeded(side: CGFloat, viewportHeight: CGFloat, proxy: ScrollViewProxy) {
        guard autoScrollTimer == nil else { return }

        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { _ in
            guard isSelectionMode,
                  let dragLocation,
                  fetchResult.count > 0 else {
                stopAutoScroll()
                return
            }

            let edgeThreshold: CGFloat = 72
            var direction = 0
            if dragLocation.y > viewportHeight - edgeThreshold {
                direction = 1
            } else if dragLocation.y < edgeThreshold {
                direction = -1
            }

            guard direction != 0 else { return }

            let cellPlusGap = side + gap
            let currentRow = max(0, Int((dragLocation.y - scrollContentMinY) / cellPlusGap))
            let targetRow = max(0, currentRow + direction)
            let targetIndex = min(max(targetRow * columnCount, 0), fetchResult.count - 1)

            withAnimation(.linear(duration: 0.06)) {
                proxy.scrollTo(targetIndex, anchor: direction > 0 ? .bottom : .top)
            }

            DispatchQueue.main.async {
                selectAtDragLocation(dragLocation, side: side)
            }
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    private func index(at location: CGPoint, side: CGFloat) -> Int? {
        let cellPlusGap = side + gap
        let contentY = location.y - scrollContentMinY
        guard location.x >= 0, location.x < (CGFloat(columnCount) * side + CGFloat(columnCount - 1) * gap),
              contentY >= 0 else { return nil }

        let col = Int(location.x / cellPlusGap)
        let row = Int(contentY / cellPlusGap)
        guard col >= 0, col < columnCount, row >= 0 else { return nil }

        let xRemainder = location.x.truncatingRemainder(dividingBy: cellPlusGap)
        let yRemainder = contentY.truncatingRemainder(dividingBy: cellPlusGap)
        guard xRemainder <= side, yRemainder <= side else { return nil }

        let index = row * columnCount + col
        return index < fetchResult.count ? index : nil
    }

    private func toggleSelection(at index: Int) {
        let id = fetchResult.object(at: index).localIdentifier
        if selectedAssetIDs.contains(id) {
            selectedAssetIDs.remove(id)
        } else {
            selectedAssetIDs.insert(id)
        }
    }

    private func applySelection(assetID: String) {
        guard let shouldSelect = dragShouldSelect else { return }
        if shouldSelect {
            selectedAssetIDs.insert(assetID)
        } else {
            selectedAssetIDs.remove(assetID)
        }
    }
}

private struct GridScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - GridCell  (corner radius = 8)
// ─────────────────────────────────────────────────────────────────────────────

private struct GridCell: View {
    let asset: PHAsset
    let imageManager: PHCachingImageManager
    let side: CGFloat
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: (PHAsset) -> Void
    let onShare: (PHAsset) -> Void
    let onEdit: (PHAsset) -> Void
    let onDelete: (PHAsset) -> Void
    let onSelectToggle: () -> Void

    @State private var image: UIImage? = nil
    @State private var imageRequestID: PHImageRequestID? = nil
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
        .overlay(alignment: .topTrailing) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.95))
                    .shadow(radius: 2)
                    .padding(6)
            }
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
        .onDisappear(perform: cancelImageRequest)
        .contextMenu {
            Button {
                onShare(asset)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button {
                onEdit(asset)
            } label: {
                Label("Edit", systemImage: asset.mediaType == .video ? "film.stack" : "slider.horizontal.3")
            }

            Button(role: .destructive) {
                onDelete(asset)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } preview: {
            GridCellContextPreview(asset: asset, imageManager: imageManager, thumbnail: image)
        }
        .task(id: asset.localIdentifier + "_\(Int(side))") { await loadThumb() }
    }

    private func handleTap() {
        if isSelectionMode {
            onSelectToggle()
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }

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
        opts.deliveryMode = .opportunistic
        opts.resizeMode = .fast
        opts.isNetworkAccessAllowed = true

        let px = CGSize(width: side * displayScale, height: side * displayScale)
        cancelImageRequest()

        imageRequestID = imageManager.requestImage(
            for: asset,
            targetSize: px,
            contentMode: .aspectFill,
            options: opts
        ) { img, info in
            if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                return
            }

            guard let img else { return }
            Task { @MainActor in
                self.image = img
            }

            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if !isDegraded {
                self.imageRequestID = nil
            }
        }
    }

    private func cancelImageRequest() {
        guard let imageRequestID else { return }
        imageManager.cancelImageRequest(imageRequestID)
        self.imageRequestID = nil
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
                    Task { @MainActor in
                        previewImage = img
                    }
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
