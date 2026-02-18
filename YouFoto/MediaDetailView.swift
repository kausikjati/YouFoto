import SwiftUI
import Photos
import AVKit

struct MediaDetailView: View {
    let asset: PHAsset
    let imageManager: PHCachingImageManager
    let onShare: (PHAsset) -> Void
    let onEdit: (PHAsset) -> Void
    let onDelete: (PHAsset) -> Void

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
    @State private var fittedContentSize: CGSize = .zero

    init(
        asset: PHAsset,
        imageManager: PHCachingImageManager,
        onShare: @escaping (PHAsset) -> Void = { _ in },
        onEdit: @escaping (PHAsset) -> Void = { _ in },
        onDelete: @escaping (PHAsset) -> Void = { _ in }
    ) {
        self.asset = asset
        self.imageManager = imageManager
        self.onShare = onShare
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

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
                                var transaction = Transaction(animation: nil)
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    zoomScale = (lastZoom * delta).clamped(to: minZoom...maxZoom)
                                    panOffset = clampedOffset(panOffset)
                                }
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

                                var transaction = Transaction(animation: nil)
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    panOffset = clampedOffset(candidate)
                                }
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

                    VStack(alignment: .trailing, spacing: 8) {
                        if let d = asset.creationDate {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(d, style: .date)
                                Text(d, style: .time)
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .glassEffect(.regular, in: Capsule())
                        }

                        if asset.mediaType == .video {
                            Label(fmt(duration), systemImage: "video.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.95))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .glassEffect(
                                    .regular.tint(Color.accentColor.opacity(0.35)),
                                    in: Capsule()
                                )
                        }

                        HStack(spacing: 8) {
                            detailActionButton(systemName: "square.and.arrow.up") { shareAsset() }
                            detailActionButton(systemName: asset.mediaType == .video ? "film.stack" : "slider.horizontal.3") { editAsset() }
                            detailActionButton(systemName: "trash") { deleteAsset() }
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.top, safeTop + 8)
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
            HStack(spacing: 10) {
                Button { seek(by: -10) } label: {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .glassEffect(.regular.interactive(), in: Circle())

                Button { togglePlay() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .glassEffect(.regular.tint(Color.accentColor.opacity(0.36)).interactive(), in: Circle())

                Button { seek(by: 10) } label: {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .glassEffect(.regular.interactive(), in: Circle())

                VStack(spacing: 5) {
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
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.horizontal, 14)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
        if fittedContentSize != .zero {
            return fittedContentSize
        }

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

    private func detailActionButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
    }

    private func shareAsset() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onShare(asset)
    }

    private func editAsset() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onEdit(asset)
    }

    private func deleteAsset() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onDelete(asset)
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


    private func seek(by seconds: Double) {
        guard let player else { return }
        let bounded = min(max(currentTime + seconds, 0), duration)
        currentTime = bounded
        let target = CMTime(seconds: bounded, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
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
                DispatchQueue.main.async {
                    if self.fullImage == nil || !deg {
                        self.fullImage = img
                        self.fittedContentSize = self.computeFittedSize(for: img.size)
                    }
                }
            }
        }
    }

    private func computeFittedSize(for imageSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return screen.size }
        let widthRatio = screen.width / imageSize.width
        let heightRatio = screen.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
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
