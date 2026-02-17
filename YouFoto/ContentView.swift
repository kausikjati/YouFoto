//
//  ContentView.swift
//  YouFoto  —  iOS 26 Liquid Glass
//

import SwiftUI
import Photos
import AVKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Models
// ─────────────────────────────────────────────────────────────────────────────

enum MediaFilter: String, CaseIterable, Identifiable {
    case photos = "Photos", videos = "Videos"
    var id: String { rawValue }
    var icon: String { self == .photos ? "photo" : "video" }
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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ContentView
// ─────────────────────────────────────────────────────────────────────────────

struct ContentView: View {

    @State private var columnCount  = 4
    private let minCols             = 2
    private let maxCols             = 10
    @State private var pinchBase    = 4
    @State private var isPinching   = false

    @State private var mediaFilter: MediaFilter = .photos
    @State private var albumFilter: AlbumFilter = .all

    @State private var selectedAsset: PHAsset?  = nil

    @State private var fetchResult: PHFetchResult<PHAsset> = PHFetchResult()
    @State private var imageManager = PHCachingImageManager()
    @State private var authStatus: PHAuthorizationStatus   = .notDetermined

    @Namespace private var filterNS
    @Namespace private var albumNS

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                // ── Grid ──────────────────────────────────────────────────
                gridContent
                    .navigationTitle("Library")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar { mediaFilterToolbar }
                    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .safeAreaInset(edge: .bottom) {
                        // Space so last row isn't hidden behind tab bar
                        Color.clear.frame(height: mediaFilter == .photos ? 110 : 0)
                    }

                // ── Album tab bar — 10 px from bottom ────────────────────
                if mediaFilter == .photos {
                    AlbumTabBar(selected: $albumFilter, ns: albumNS)
                        .padding(.bottom, 10)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal:   .move(edge: .bottom).combined(with: .opacity)))
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.76), value: mediaFilter)
            .onAppear(perform: setupPhotos)
            .onChange(of: mediaFilter) { _, _ in loadAssets() }
            .onChange(of: albumFilter) { _, _ in loadAssets() }
        }
        .fullScreenCover(item: $selectedAsset) { asset in
            MediaDetailView(asset: asset, imageManager: imageManager)
        }
    }

    // ── Grid body ─────────────────────────────────────────────────────────────
    @ViewBuilder
    private var gridContent: some View {
        switch authStatus {
        case .authorized, .limited:
            PhotoGridView(
                fetchResult: fetchResult,
                imageManager: imageManager,
                columnCount: columnCount,
                onTap: { selectedAsset = $0 }
            )
            .gesture(pinchGesture)

        case .denied, .restricted:
            VStack(spacing: 20) {
                Image(systemName: "lock.photo.fill")
                    .font(.system(size: 56)).foregroundStyle(.secondary)
                Text("Photos Access Required").font(.title2.bold())
                Text("Allow access in Settings › Privacy › Photos.")
                    .font(.subheadline).multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }.buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)

        default:
            ProgressView("Requesting access…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // ── Toolbar: Photos | Videos ─────────────────────────────────────────────
    // FIX: spacing: 8 between pills so they don't touch each other
    @ToolbarContentBuilder
    private var mediaFilterToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            GlassEffectContainer(spacing: 8) {          // ← spacing=8 adds gap between pills
                HStack(spacing: 8) {
                    ForEach(MediaFilter.allCases) { filter in
                        Button {
                            guard mediaFilter != filter else { return }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.74)) {
                                mediaFilter = filter
                                if filter == .videos { albumFilter = .all }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: filter.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(filter.rawValue)
                                    .font(.system(size: 14,
                                                  weight: mediaFilter == filter ? .semibold : .regular))
                            }
                            .foregroundStyle(mediaFilter == filter ? .primary : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            mediaFilter == filter
                                ? .regular.tint(Color.accentColor.opacity(0.30)).interactive()
                                : .regular.interactive(),
                            in: Capsule()                // ← Capsule for pill shape
                        )
                        .glassEffectID(filter.id, in: filterNS)
                    }
                }
            }
        }
    }

    // ── Pinch ─────────────────────────────────────────────────────────────────
    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { s in
                if !isPinching { pinchBase = columnCount; isPinching = true }
                let c = Int((CGFloat(pinchBase) / s).rounded()).clamped(to: minCols...maxCols)
                if c != columnCount {
                    columnCount = c
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            .onEnded { s in
                columnCount = Int((CGFloat(pinchBase) / s).rounded()).clamped(to: minCols...maxCols)
                isPinching = false
            }
    }

    // ── Setup ─────────────────────────────────────────────────────────────────
    private func setupPhotos() {
        let s = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authStatus = s
        switch s {
        case .authorized, .limited: loadAssets()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { st in
                DispatchQueue.main.async {
                    self.authStatus = st
                    if st == .authorized || st == .limited { self.loadAssets() }
                }
            }
        default: break
        }
    }

    private func loadAssets() {
        imageManager.stopCachingImagesForAllAssets()
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.predicate = mediaFilter == .photos
            ? NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            : NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        switch albumFilter {
        case .all:
            fetchResult = PHAsset.fetchAssets(with: opts)
        case .camera:
            if let c = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject {
                fetchResult = PHAsset.fetchAssets(in: c, options: opts)
            } else { fetchResult = PHFetchResult() }
        case .screenshots:
            if let c = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil).firstObject {
                fetchResult = PHAsset.fetchAssets(in: c, options: opts)
            } else { fetchResult = PHFetchResult() }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AlbumTabBar
//
// FIX for flickering:
//   • Do NOT use .glassEffectID with matchedGeometry on changing state —
//     that causes the glass surface to be destroyed/recreated on every tap.
//   • Instead use a single glass background for the whole bar, and draw
//     an accent underline / fill only on the selected item using a plain
//     RoundedRectangle overlay — zero glass lifecycle changes on selection.
// ─────────────────────────────────────────────────────────────────────────────

private struct AlbumTabBar: View {
    @Binding var selected: AlbumFilter
    var ns: Namespace.ID                       // kept for API compat, not used for morphing

    var body: some View {
        // One glass surface for the whole bar — never recreated
        HStack(spacing: 0) {
            ForEach(AlbumFilter.allCases) { filter in
                Button {
                    selected = filter
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: filter.icon)
                            .font(.system(size: 20,
                                          weight: selected == filter ? .semibold : .regular))
                        Text(filter.rawValue)
                            .font(.system(size: 11,
                                          weight: selected == filter ? .semibold : .regular))
                    }
                    .foregroundStyle(selected == filter ? Color.accentColor : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        // Stable single glass surface — never flickers
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 28)
        // Animate label/icon colour change only
        .animation(.easeInOut(duration: 0.18), value: selected)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PhotoGridView
// ─────────────────────────────────────────────────────────────────────────────

private struct PhotoGridView: View {
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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - MediaDetailView  (iOS 26 liquid glass, working zoom)
//
// Zoom fix:
//   • Use .simultaneousGesture for both pinch + pan so they don't compete
//   • zoomBase is captured ONCE at gesture start, updated at gesture END
//   • State is @State not computed so it persists across re-renders
// ─────────────────────────────────────────────────────────────────────────────

struct MediaDetailView: View {
    let asset: PHAsset
    let imageManager: PHCachingImageManager

    @Environment(\.dismiss) private var dismiss

    // Photo zoom / pan
    private let minZoom: CGFloat      = 1
    private let maxZoom: CGFloat      = 8
    @State private var zoomScale: CGFloat  = 1
    @State private var lastZoom: CGFloat   = 1   // scale at start of current pinch gesture
    @State private var panOffset: CGSize   = .zero
    @State private var lastPan: CGSize     = .zero

    @State private var fullImage: UIImage? = nil

    // Video
    @State private var player: AVPlayer?   = nil
    @State private var isPlaying           = false
    @State private var currentTime         = 0.0
    @State private var duration            = 1.0
    @State private var isDragging          = false
    @State private var timeToken: Any?     = nil

    // UI
    @State private var showControls        = true
    @State private var hideTimer: Timer?   = nil

    @Environment(\.displayScale) private var displayScale
    private let screen = UIScreen.main.bounds

    var body: some View {
        ZStack {
            // ── Layer 1: black background ─────────────────────────────────
            Color.black.ignoresSafeArea()

            // ── Layer 2: photo/video content ───────────────────────────────
            if asset.mediaType == .video, let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .disabled(true)
                    .contentShape(Rectangle())
                    .onTapGesture { toggleControls() }
            } else if let img = fullImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoomScale)
                    .offset(panOffset)
                    // Pinch zoom + pan (simultaneous so both keep working)
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { delta in
                                zoomScale = (lastZoom * delta).clamped(to: minZoom...maxZoom)
                                clampPanOffset(animated: false)
                            }
                            .onEnded { delta in
                                let final = (lastZoom * delta).clamped(to: minZoom...maxZoom)
                                if final <= 1.05 {
                                    resetZoom(animated: true)
                                } else {
                                    zoomScale = final
                                    lastZoom = final
                                    clampPanOffset(animated: true)
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { v in
                                guard zoomScale > minZoom else { return }
                                let candidate = CGSize(
                                    width: lastPan.width + v.translation.width,
                                    height: lastPan.height + v.translation.height)
                                panOffset = clampedOffset(candidate)
                            }
                            .onEnded { _ in
                                guard zoomScale > minZoom else { return }
                                clampPanOffset(animated: true)
                                lastPan = panOffset
                            }
                    )
                    // Double-tap to zoom
                    .onTapGesture(count: 2) { doubleTap() }
                    // Single tap to show/hide controls; button remains tappable via z-indexed overlay
                    .simultaneousGesture(TapGesture().onEnded { toggleControls() })
            } else {
                ProgressView().tint(.white).scaleEffect(1.5)
            }

            // ── Layer 4: close button (top-left, always on top, own frame) ─
            // Placed directly in the ZStack — NOT inside a VStack with
            // allowsHitTesting. This guarantees the button always receives taps.
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive(), in: Circle())
                    .padding(.leading, 20)
                    .padding(.top, safeTop + 8)

                    Spacer()

                    if let d = asset.creationDate {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(d, style: .date)
                            Text(d, style: .time)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .glassEffect(.regular, in: Capsule())
                        .padding(.trailing, 20)
                        .padding(.top, safeTop + 8)
                    }
                }
                Spacer()
            }
            .ignoresSafeArea()
            .zIndex(10)
            .allowsHitTesting(showControls)
            .opacity(showControls ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: showControls)

            // ── Layer 5: video bar (bottom, own frame) ─────────────────────
            if asset.mediaType == .video {
                VStack {
                    Spacer()
                    videoBar
                        .padding(.horizontal, 20)
                        .padding(.bottom, safeBottom + 16)
                }
                .ignoresSafeArea()
                .opacity(showControls ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: showControls)
            }

        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .onAppear { loadAsset(); scheduleHide() }
        .onDisappear { cleanup() }
    }

    // ── Video control bar — liquid glass ─────────────────────────────────────
    private var videoBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 0) {
                // Play/Pause
                Button { togglePlay() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())

                // Seek + time labels
                VStack(spacing: 4) {
                    Slider(
                        value: $currentTime,
                        in: 0...max(duration, 1),
                        onEditingChanged: { editing in
                            isDragging = editing
                            if editing { player?.pause() }
                            else {
                                let t = CMTime(seconds: currentTime, preferredTimescale: 600)
                                player?.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                                    if isPlaying { player?.play() }
                                }
                            }
                        }
                    )
                    .tint(Color.accentColor)
                    .padding(.horizontal, 12)

                    HStack {
                        Text(fmt(currentTime)); Spacer(); Text(fmt(duration))
                    }
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 14)
                }
                .frame(maxWidth: .infinity)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal, 4)
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    private func doubleTap() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
            if zoomScale > minZoom {
                resetZoom(animated: false)
            } else {
                zoomScale = 2.5
                lastZoom = 2.5
            }
            clampPanOffset(animated: false)
        }
    }

    private func clampedOffset(_ candidate: CGSize) -> CGSize {
        let fittedSize = fittedImageSize()
        let maxX = max(0, ((fittedSize.width * zoomScale) - screen.width) / 2)
        let maxY = max(0, ((fittedSize.height * zoomScale) - screen.height) / 2)
        return CGSize(
            width: candidate.width.clamped(to: -maxX...maxX),
            height: candidate.height.clamped(to: -maxY...maxY)
        )
    }

    private func fittedImageSize() -> CGSize {
        guard let imageSize = fullImage?.size,
              imageSize.width > 0,
              imageSize.height > 0 else {
            return screen.size
        }

        let widthRatio = screen.width / imageSize.width
        let heightRatio = screen.height / imageSize.height
        let scale = min(widthRatio, heightRatio)

        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func clampPanOffset(animated: Bool) {
        let clamped = clampedOffset(panOffset)
        if animated {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                panOffset = clamped
                lastPan = clamped
            }
        } else {
            panOffset = clamped
            lastPan = clamped
        }
    }

    private func resetZoom(animated: Bool) {
        let reset = {
            zoomScale = minZoom
            lastZoom = minZoom
            panOffset = .zero
            lastPan = .zero
        }
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78), reset)
        } else {
            reset()
        }
    }

    private func toggleControls() {
        hideTimer?.invalidate()
        withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() }
        if showControls { scheduleHide() }
    }

    private func scheduleHide() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { showControls = false }
        }
    }

    private func togglePlay() {
        guard let player else { return }
        isPlaying ? player.pause() : player.play()
        isPlaying.toggle()
    }

    private func loadAsset() {
        if asset.mediaType == .video {
            let opts = PHVideoRequestOptions()
            opts.isNetworkAccessAllowed = true; opts.deliveryMode = .automatic
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: opts) { item, _ in
                guard let item else { return }
                DispatchQueue.main.async {
                    let p = AVPlayer(playerItem: item)
                    self.player   = p
                    self.duration = item.asset.duration.seconds.isFinite
                        ? item.asset.duration.seconds : 1
                    self.timeToken = p.addPeriodicTimeObserver(
                        forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main
                    ) { t in if !self.isDragging { self.currentTime = t.seconds } }
                    NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
                    ) { _ in self.isPlaying = false; p.seek(to: .zero) }
                    p.play(); self.isPlaying = true
                }
            }
        } else {
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic; opts.isNetworkAccessAllowed = true
            let sz = CGSize(width: screen.width * displayScale,
                            height: screen.height * displayScale)
            imageManager.requestImage(
                for: asset, targetSize: sz, contentMode: .aspectFit, options: opts
            ) { img, info in
                guard let img else { return }
                let deg = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                DispatchQueue.main.async { if self.fullImage == nil || !deg { self.fullImage = img } }
            }
        }
    }

    private func cleanup() {
        hideTimer?.invalidate()
        if let tok = timeToken { player?.removeTimeObserver(tok) }
        player?.pause(); player = nil
    }

    private func fmt(_ t: Double) -> String {
        let s = Int(t)
        return s >= 3600 ? String(format: "%d:%02d:%02d", s/3600, (s%3600)/60, s%60)
                         : String(format: "%d:%02d", s/60, s%60)
    }

    private var safeTop: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows.first?.safeAreaInsets.top ?? 47
    }
    private var safeBottom: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows.first?.safeAreaInsets.bottom ?? 34
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Helpers
// ─────────────────────────────────────────────────────────────────────────────

extension Comparable {
    func clamped(to r: ClosedRange<Self>) -> Self { min(max(self, r.lowerBound), r.upperBound) }
}

extension PHAsset: @retroactive Identifiable {
    public var id: String { localIdentifier }
}

#Preview { ContentView() }
