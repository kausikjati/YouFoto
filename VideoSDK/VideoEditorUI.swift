//
//  VideoEditorUI.swift
//  Complete Video Editor Interface with iOS 26 Liquid Glass
//

import SwiftUI
import AVKit
import AVFoundation
import PhotosUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Video Editor View (Main Interface)
// ─────────────────────────────────────────────────────────────────────────────

public struct VideoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var editor: VideoEditor
    let onComplete: ((ExportResult) -> Void)?

    @State private var showEffects = false
    @State private var showText = false
    @State private var showAudio = false
    @State private var showExport = false
    @State private var selectedTool: EditTool = .trim
    @State private var selectedQuality: ExportQuality = .hd1080p
    @State private var previewPlayer: AVPlayer?
    @State private var selectedClipID: UUID?

    public init(videoURL: URL, onComplete: ((ExportResult) -> Void)? = nil) {
        _editor = StateObject(wrappedValue: VideoEditor(videoURL: videoURL))
        self.onComplete = onComplete
    }

    public init(asset: PHAsset, onComplete: ((ExportResult) -> Void)? = nil) {
        _editor = StateObject(wrappedValue: VideoEditor(asset: asset))
        self.onComplete = onComplete
    }

    public init(assets: [PHAsset], onComplete: ((ExportResult) -> Void)? = nil) {
        _editor = StateObject(wrappedValue: VideoEditor(assets: assets))
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    topBar

                    videoPreview
                        .frame(maxWidth: .infinity)

                    timelineCard

                    toolsPanel
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .onAppear {
            configurePreviewPlayer()
        }
        .onChange(of: editor.timeline.clips.count) { _, _ in
            configurePreviewPlayer()
        }
        .onChange(of: selectedClipID) { _, _ in
            configurePreviewPlayer()
        }
        .onChange(of: editor.isPlaying) { _, isPlaying in
            if isPlaying {
                previewPlayer?.play()
            } else {
                previewPlayer?.pause()
            }
        }
        .sheet(isPresented: $showEffects) {
            VideoEffectsPanel(editor: editor)
        }
        .sheet(isPresented: $showText) {
            VideoTextOverlayPanel(editor: editor)
        }
        .sheet(isPresented: $showAudio) {
            VideoAudioPanel(editor: editor)
        }
        .sheet(isPresented: $showExport) {
            VideoExportSheet(editor: editor, onComplete: onComplete)
        }
    }

    // ── Top Bar ──────────────────────────────────────────────────────────────

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .glassEffect(.regular.interactive(), in: Circle())

            Text("Project")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .glassEffect(.regular, in: Capsule())

            Menu {
                ForEach(ExportQuality.allCases, id: \.self) { quality in
                    Button {
                        selectedQuality = quality
                    } label: {
                        if selectedQuality == quality {
                            Label(quality.rawValue, systemImage: "checkmark")
                        } else {
                            Text(quality.rawValue)
                        }
                    }
                }

                Divider()

                Button("Export") {
                    exportQuickly()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
        }
    }

    // ── Video Preview ────────────────────────────────────────────────────────

    private var videoPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.black)
                .overlay {
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                }

            if let previewPlayer {
                VideoPreviewLayerView(player: previewPlayer)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(6)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
    }

    // ── Timeline ─────────────────────────────────────────────────────────────

    private var timelineCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    editor.isPlaying.toggle()
                } label: {
                    Image(systemName: editor.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive(), in: Circle())

                Spacer()

                Text("\(editor.timeline.clips.count) clips")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }

            VideoTimelineView(timeline: editor.timeline, selectedClipID: $selectedClipID)
                .frame(height: 96)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
    }

    // ── Tool Rail ─────────────────────────────────────────────────────────────

    private var toolsPanel: some View {
        HStack(spacing: 12) {
            VideoToolButton(icon: "scissors", title: "Trim", isSelected: selectedTool == .trim) {
                selectedTool = .trim
            }
            VideoToolButton(icon: "camera.filters", title: "Filters", isSelected: selectedTool == .filters) {
                selectedTool = .filters
                showEffects = true
            }
            VideoToolButton(icon: "music.note", title: "Audio", isSelected: selectedTool == .audio) {
                selectedTool = .audio
                showAudio = true
            }
            VideoToolButton(icon: "textformat", title: "Text", isSelected: selectedTool == .text) {
                selectedTool = .text
                showText = true
            }
            VideoToolButton(icon: "gauge.with.dots.needle.50percent", title: "Speed", isSelected: selectedTool == .speed) {
                selectedTool = .speed
            }
            VideoToolButton(icon: "ellipsis", title: "More", isSelected: selectedTool == .more) {
                selectedTool = .more
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
    }

    private func configurePreviewPlayer() {
        let fallbackClip = editor.timeline.clips.first
        let selectedClip = editor.timeline.clips.first(where: { $0.id == selectedClipID })
        guard let clip = selectedClip ?? fallbackClip else {
            previewPlayer = nil
            return
        }

        if selectedClipID == nil {
            selectedClipID = clip.id
        }

        previewPlayer = AVPlayer(url: clip.url)
        previewPlayer?.pause()
        if editor.isPlaying {
            previewPlayer?.play()
        }
    }

    private func exportQuickly() {
        Task {
            let result = try? await editor.export(options: ExportOptions(quality: selectedQuality, format: .mp4))
            if let result {
                onComplete?(result)
            } else {
                showExport = true
            }
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let safe = max(0, Int(seconds))
        let minutes = safe / 60
        let secs = safe % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Timeline View
// ─────────────────────────────────────────────────────────────────────────────

struct VideoTimelineView: View {
    @ObservedObject var timeline: Timeline
    @Binding var selectedClipID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(timeline.clips) { clip in
                    ClipThumbnail(clip: clip, isSelected: selectedClipID == clip.id)
                        .onTapGesture {
                            selectedClipID = clip.id
                        }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.86), value: selectedClipID)
    }
}

struct ClipThumbnail: View {
    @ObservedObject var clip: VideoClip
    let isSelected: Bool

    @State private var thumbnailImage: UIImage?
    @State private var trimStartRatio: CGFloat = 0
    @State private var trimEndRatio: CGFloat = 1

    private var tileWidth: CGFloat { isSelected ? 220 : 104 }
    private var fullDuration: Double { max(clip.trimEnd, clip.duration + clip.trimStart, 0.1) }
    private var trimmedDuration: Double {
        max(0.05, Double(trimEndRatio - trimStartRatio) * fullDuration)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isSelected ? .white.opacity(0.28) : .white.opacity(0.16))
            .frame(width: tileWidth, height: 72)
            .overlay {
                GeometryReader { geo in
                    ZStack {
                        Group {
                            if let thumbnailImage {
                                Image(uiImage: thumbnailImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                ZStack {
                                    Color.white.opacity(0.08)
                                    Image(systemName: "film")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.75))
                                }
                            }
                        }

                        if isSelected {
                            let lead = trimStartRatio * geo.size.width
                            let trail = (1 - trimEndRatio) * geo.size.width

                            HStack(spacing: 0) {
                                Color.black.opacity(0.50).frame(width: max(0, lead))
                                Color.clear
                                Color.black.opacity(0.50).frame(width: max(0, trail))
                            }

                            Circle()
                                .fill(Color.white.opacity(0.95))
                                .frame(width: 10, height: 10)
                                .position(x: lead, y: geo.size.height / 2)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let next = min(max(0, value.location.x / geo.size.width), trimEndRatio - 0.05)
                                            trimStartRatio = next
                                            applyTrim()
                                        }
                                )

                            Circle()
                                .fill(Color.white.opacity(0.95))
                                .frame(width: 10, height: 10)
                                .position(x: trimEndRatio * geo.size.width, y: geo.size.height / 2)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let next = max(min(1, value.location.x / geo.size.width), trimStartRatio + 0.05)
                                            trimEndRatio = next
                                            applyTrim()
                                        }
                                )
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(4)
            }
            .overlay(alignment: .bottomTrailing) {
                Text(String(format: "%.1fs", trimmedDuration))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.55), in: Capsule())
                    .padding(8)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.white.opacity(0.85) : Color.clear, lineWidth: 1.5)
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.84), value: isSelected)
            .onAppear {
                loadThumbnail()
                syncRatiosFromClip()
            }
            .onChange(of: isSelected) { _, selected in
                if selected {
                    syncRatiosFromClip()
                }
            }
    }

    private func syncRatiosFromClip() {
        let duration = fullDuration
        guard duration > 0 else { return }
        trimStartRatio = CGFloat(max(0, min(1, clip.trimStart / duration)))
        trimEndRatio = CGFloat(max(trimStartRatio + 0.05, min(1, clip.trimEnd / duration)))
    }

    private func applyTrim() {
        let duration = fullDuration
        clip.trimStart = Double(trimStartRatio) * duration
        clip.trimEnd = Double(trimEndRatio) * duration
        clip.duration = max(0.05, clip.trimEnd - clip.trimStart)
    }

    private func loadThumbnail() {
        guard thumbnailImage == nil else { return }

        let asset = AVAsset(url: clip.url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 420, height: 280)

        Task.detached {
            let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil)
            guard let cgImage else { return }
            let image = UIImage(cgImage: cgImage)
            await MainActor.run {
                thumbnailImage = image
            }
        }
    }
}

private struct VideoPreviewLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Effects Panel
// ─────────────────────────────────────────────────────────────────────────────

struct VideoEffectsPanel: View {
    @ObservedObject var editor: VideoEditor
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFilter: VideoFilter = .none
    @State private var brightness: CGFloat = 0
    @State private var contrast: CGFloat = 0
    @State private var saturation: CGFloat = 0
    @State private var selectedTransition: TransitionType = .fade

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    filtersSection
                    adjustmentsSection
                    transitionsSection
                }
                .padding()
            }
            .navigationTitle("Effects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var filtersSection: some View {
        VStack(alignment: .leading) {
            Text("Filters")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(VideoFilter.allCases, id: \.self) { filter in
                        VideoFilterButton(
                            filter: filter,
                            isSelected: selectedFilter == filter
                        ) {
                            selectedFilter = filter
                            editor.apply(filter: filter)
                        }
                    }
                }
            }
        }
    }

    private var adjustmentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Adjustments")
                .font(.headline)

            VStack(spacing: 12) {
                VideoAdjustmentSlider(title: "Brightness", value: $brightness, icon: "sun.max") {
                    editor.adjustBrightness(brightness)
                }
                VideoAdjustmentSlider(title: "Contrast", value: $contrast, icon: "circle.lefthalf.filled") {
                    editor.adjustContrast(contrast)
                }
                VideoAdjustmentSlider(title: "Saturation", value: $saturation, icon: "paintpalette") {
                    editor.adjustSaturation(saturation)
                }
            }
        }
    }

    private var transitionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Transitions")
                .font(.headline)

            Picker("Transition", selection: $selectedTransition) {
                ForEach(TransitionType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }

            Button("Apply Between First Two Clips") {
                if editor.timeline.clips.count > 1 {
                    editor.addTransition(selectedTransition, between: editor.timeline.clips[0], and: editor.timeline.clips[1])
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(editor.timeline.clips.count < 2)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Text Overlay Panel
// ─────────────────────────────────────────────────────────────────────────────

struct VideoTextOverlayPanel: View {
    @ObservedObject var editor: VideoEditor
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var position: VideoOverlay.OverlayPosition = .center

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TextField("Enter text", text: $text)
                    .textFieldStyle(.roundedBorder)

                Picker("Position", selection: $position) {
                    Text("Top").tag(VideoOverlay.OverlayPosition.top)
                    Text("Center").tag(VideoOverlay.OverlayPosition.center)
                    Text("Bottom").tag(VideoOverlay.OverlayPosition.bottom)
                }
                .pickerStyle(.segmented)

                Button("Add Text") {
                    let overlay = VideoOverlay(
                        type: .text(text),
                        position: position
                    )
                    editor.addOverlay(overlay, at: editor.currentTime, duration: 5.0)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("Add Text")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Audio Panel
// ─────────────────────────────────────────────────────────────────────────────

struct VideoAudioPanel: View {
    @ObservedObject var editor: VideoEditor
    @Environment(\.dismiss) private var dismiss
    @State private var volume: Double = 0.7

    var body: some View {
        NavigationStack {
            List {
                Section("Music") {
                    Button {
                        // Placeholder for media picker integration
                    } label: {
                        Label("Add Music", systemImage: "music.note")
                    }
                }

                Section("Voice-over") {
                    Button {
                        // Placeholder for voice-over recorder integration
                    } label: {
                        Label("Record Voice-over", systemImage: "mic")
                    }
                }

                Section("Volume") {
                    VStack {
                        Slider(value: $volume, in: 0...1)
                        HStack {
                            Text("Original Audio")
                            Spacer()
                            Text("\(Int(volume * 100))%")
                        }
                        .font(.caption)
                    }
                }
            }
            .navigationTitle("Audio")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Export Sheet
// ─────────────────────────────────────────────────────────────────────────────

struct VideoExportSheet: View {
    @ObservedObject var editor: VideoEditor
    let onComplete: ((ExportResult) -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var selectedQuality: ExportQuality = .hd1080p

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("Quality")
                        .font(.headline)

                    Picker("Quality", selection: $selectedQuality) {
                        ForEach(ExportQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading) {
                    Text("Export For")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(SocialPlatform.allCases, id: \.self) { platform in
                            VideoPlatformButton(platform: platform) {
                                exportFor(platform)
                            }
                        }
                    }
                }

                Spacer()

                Button {
                    export()
                } label: {
                    if editor.isExporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Export Video")
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .padding()
            .navigationTitle("Export")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func export() {
        Task {
            let result = try? await editor.export(options: ExportOptions(quality: selectedQuality, format: .mp4))
            if let result {
                onComplete?(result)
                dismiss()
            }
        }
    }

    private func exportFor(_ platform: SocialPlatform) {
        Task {
            try? await editor.share(to: platform, quality: selectedQuality)
            dismiss()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - UI Components
// ─────────────────────────────────────────────────────────────────────────────

struct VideoToolButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(isSelected ? Color.cyan : .white)
            .frame(maxWidth: .infinity)
        }
    }
}

struct VideoFilterButton: View {
    let filter: VideoFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.gray)
                    .frame(width: 80, height: 80)
                Text(filter.rawValue)
                    .font(.caption)
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
        }
    }
}

struct VideoPlatformButton: View {
    let platform: SocialPlatform
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: iconForPlatform)
                    .font(.system(size: 30))
                Text(platform.rawValue)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
        }
        .buttonStyle(.bordered)
    }

    private var iconForPlatform: String {
        switch platform {
        case .instagram, .reels: return "camera.circle.fill"
        case .tiktok: return "music.note"
        case .youtube: return "play.rectangle.fill"
        }
    }
}

struct VideoAdjustmentSlider: View {
    let title: String
    @Binding var value: CGFloat
    let icon: String
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption.monospacedDigit())
            }
            Slider(value: $value, in: -1...1, onEditingChanged: { _ in onChange() })
        }
    }
}

struct FeatureItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let action: () -> Void
}

struct FeatureButton: View {
    let item: FeatureItem

    var body: some View {
        Button(action: item.action) {
            VStack(spacing: 8) {
                Image(systemName: item.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                Text(item.title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
            }
            .frame(width: 86)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Edit Tool
// ─────────────────────────────────────────────────────────────────────────────

enum EditTool {
    case trim, filters, text, audio, speed, more
}

extension BlendMode: CaseIterable {
    public static var allCases: [BlendMode] {
        [.normal, .multiply, .screen, .overlay, .softLight]
    }

    var title: String {
        switch self {
        case .normal: return "Normal"
        case .multiply: return "Multiply"
        case .screen: return "Screen"
        case .overlay: return "Overlay"
        case .softLight: return "Soft Light"
        }
    }
}
