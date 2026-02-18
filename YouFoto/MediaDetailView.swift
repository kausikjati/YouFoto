import SwiftUI
import Photos
import AVKit

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
            // ── Layer 1: background ───────────────────────────────────────
            (asset.mediaType == .video ? Color.black : Color(red: 0.91, green: 0.91, blue: 0.92))
                .ignoresSafeArea()

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

            // ── Layer 4: top/bottom chrome overlays ──────────────────────────
            VStack(spacing: 0) {
                topChrome
                Spacer(minLength: 0)

                if asset.mediaType == .video {
                    videoBar
                        .padding(.horizontal, 20)
                        .padding(.bottom, safeBottom + 16)
                } else {
                    photoBottomChrome
                        .padding(.bottom, safeBottom + 16)
                }
            }
            .ignoresSafeArea()
            .zIndex(10)
            .allowsHitTesting(showControls)
            .opacity(showControls ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: showControls)

        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .onAppear { loadAsset(); scheduleHide() }
        .onDisappear { cleanup() }
    }

    private var topChrome: some View {
        HStack(alignment: .top) {
            chromeCircleButton(systemName: "chevron.left") { dismiss() }

            Spacer(minLength: 12)

            if let d = asset.creationDate {
                VStack(spacing: 2) {
                    Text(d.formatted(.dateTime.day().month(.wide).year()))
                        .font(.system(size: 22, weight: .bold))
                    Text(d.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundStyle(chromeForeground)
                .padding(.horizontal, 22)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.6), lineWidth: 1.4)
                }
            }

            Spacer(minLength: 12)

            chromeCircleButton(systemName: "ellipsis") { }
        }
        .padding(.horizontal, 20)
        .padding(.top, safeTop + 12)
    }

    private var photoBottomChrome: some View {
        VStack(spacing: 14) {
            photoThumbStrip

            HStack(spacing: 18) {
                chromeCircleButton(systemName: "square.and.arrow.up") { }

                HStack(spacing: 30) {
                    Image(systemName: "heart")
                    Image(systemName: "info.circle")
                    Image(systemName: "slider.horizontal.3")
                }
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(chromeForeground)
                .padding(.horizontal, 36)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.55), lineWidth: 1.2)
                }

                chromeCircleButton(systemName: "trash") { }
            }
            .padding(.horizontal, 20)
        }
    }

    private var photoThumbStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<10, id: \.self) { _ in
                    Group {
                        if let img = fullImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.35))
                        }
                    }
                    .frame(width: 40, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .opacity(0.8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.48), lineWidth: 1)
        }
        .padding(.horizontal, 20)
    }

    private func chromeCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(chromeForeground)
                .frame(width: 74, height: 74)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.58), lineWidth: 1.3)
                }
        }
        .buttonStyle(.plain)
    }

    private var chromeForeground: Color {
        asset.mediaType == .video ? .white : .black.opacity(0.88)
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
