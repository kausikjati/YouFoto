//
//  VideoEditorUI.swift
//  Complete Video Editor Interface with iOS 26 Liquid Glass
//

import SwiftUI
import AVKit
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
    @State private var speed: Double = 1.0
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 0
    @State private var selectedBlendMode: BlendMode = .normal

    public init(videoURL: URL, onComplete: ((ExportResult) -> Void)? = nil) {
        _editor = StateObject(wrappedValue: VideoEditor(videoURL: videoURL))
        self.onComplete = onComplete
    }

    public init(asset: PHAsset, onComplete: ((ExportResult) -> Void)? = nil) {
        _editor = StateObject(wrappedValue: VideoEditor(asset: asset))
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.65), Color.cyan.opacity(0.6), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                topBar

                videoPreview
                    .frame(maxHeight: 360)

                timelineCard

                toolsPanel

                featureRows
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .onAppear {
            syncTrimValues()
        }
        .onChange(of: editor.timeline.clips.count) { _, _ in
            syncTrimValues()
        }
        .sheet(isPresented: $showEffects) {
            EffectsPanel(editor: editor)
        }
        .sheet(isPresented: $showText) {
            TextOverlayPanel(editor: editor)
        }
        .sheet(isPresented: $showAudio) {
            AudioPanel(editor: editor)
        }
        .sheet(isPresented: $showExport) {
            ExportSheet(editor: editor, onComplete: onComplete)
        }
    }

    // ── Top Bar ──────────────────────────────────────────────────────────────

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .glassEffect(.regular.interactive(), in: Capsule())

            Text("Project: Sunset Drive")
                .font(.system(size: 20, weight: .medium))
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
                HStack(spacing: 8) {
                    Text("Export")
                    Image(systemName: "chevron.down")
                }
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.black.opacity(0.85))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.8), in: Capsule())
            }
        }
    }

    // ── Video Preview ────────────────────────────────────────────────────────

    private var videoPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.24), Color.black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                }

            if !editor.isPlaying {
                Button {
                    editor.isPlaying = true
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 88, height: 88)
                }
                .glassEffect(.regular.interactive(), in: Circle())
            }

            VStack {
                Spacer()

                Text("\(timeString(editor.currentTime)) / \(timeString(editor.timeline.totalDuration))")
                    .font(.system(.title3, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.bottom, 18)
            }
        }
        .aspectRatio(editor.timeline.aspectRatio.size, contentMode: .fit)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
    }

    // ── Timeline ─────────────────────────────────────────────────────────────

    private var timelineCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    editor.isPlaying.toggle()
                } label: {
                    Image(systemName: editor.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12))

                Slider(value: $editor.currentTime, in: 0...max(editor.timeline.totalDuration, 1))
                    .tint(.cyan)

                zoomRow
            }

            TimelineView(timeline: editor.timeline)
                .frame(height: 88)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))

            Divider().overlay(Color.white.opacity(0.22))

            editorPanel
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
    }

    private var zoomRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "minus.magnifyingglass")
                .foregroundStyle(.white.opacity(0.75))
            Image(systemName: "plus.magnifyingglass")
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 8)
    }

    private var editorPanel: some View {
        VStack(spacing: 10) {
            switch selectedTool {
            case .trim:
                trimPanel
            case .filters:
                Button("Open Filters") { showEffects = true }
                    .buttonStyle(.borderedProminent)
            case .audio:
                Button("Open Audio") { showAudio = true }
                    .buttonStyle(.borderedProminent)
            case .text:
                Button("Add Text") { showText = true }
                    .buttonStyle(.borderedProminent)
            case .speed:
                speedPanel
            case .more:
                advancedPanel
            }
        }
    }

    private var trimPanel: some View {
        VStack(spacing: 8) {
            sliderRow(title: "Start", value: $trimStart, range: 0...max(trimEnd, 0.1)) {
                editor.timeline.trim(start: trimStart)
            }

            sliderRow(title: "End", value: $trimEnd, range: min(trimStart + 0.1, max(editor.timeline.totalDuration, 0.1))...max(editor.timeline.totalDuration, 0.1)) {
                editor.timeline.trim(end: trimEnd)
            }

            Button("Split at Current Time") {
                editor.timeline.split(at: editor.currentTime)
            }
            .buttonStyle(.bordered)
        }
    }

    private var speedPanel: some View {
        VStack(spacing: 10) {
            sliderRow(title: "Speed", value: $speed, range: 0.25...2.0) {
                if let firstClip = editor.timeline.clips.first {
                    editor.setSpeed(speed, for: firstClip)
                }
            }

            Button("Reverse Clip") {
                if let firstClip = editor.timeline.clips.first {
                    editor.reverse(firstClip)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var advancedPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Button("Add Fade Transition") {
                    if editor.timeline.clips.count > 1 {
                        editor.addTransition(.fade, between: editor.timeline.clips[0], and: editor.timeline.clips[1])
                    }
                }
                .buttonStyle(.bordered)

                Button("Smart Crop") {
                    Task {
                        await editor.smartCrop(to: editor.timeline.aspectRatio, focusOn: .faces)
                    }
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Picker("Blend", selection: $selectedBlendMode) {
                    ForEach(BlendMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                Button("Apply") {
                    if let firstClip = editor.timeline.clips.first {
                        editor.setBlendMode(selectedBlendMode, for: firstClip)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // ── Tool Rail ─────────────────────────────────────────────────────────────

    private var toolsPanel: some View {
        HStack(spacing: 12) {
            ToolButton(icon: "scissors", title: "Trim", isSelected: selectedTool == .trim) {
                selectedTool = .trim
            }
            ToolButton(icon: "camera.filters", title: "Filters", isSelected: selectedTool == .filters) {
                selectedTool = .filters
                showEffects = true
            }
            ToolButton(icon: "music.note", title: "Audio", isSelected: selectedTool == .audio) {
                selectedTool = .audio
                showAudio = true
            }
            ToolButton(icon: "textformat", title: "Text", isSelected: selectedTool == .text) {
                selectedTool = .text
                showText = true
            }
            ToolButton(icon: "gauge.with.dots.needle.50percent", title: "Speed", isSelected: selectedTool == .speed) {
                selectedTool = .speed
            }
            ToolButton(icon: "ellipsis", title: "More", isSelected: selectedTool == .more) {
                selectedTool = .more
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
    }

    private var featureRows: some View {
        VStack(spacing: 12) {
            featureRow(
                title: "AI Features",
                items: [
                    FeatureItem(title: "AI Editing", icon: "sparkles") {
                        Task { await editor.smartCrop(to: .horizontal, focusOn: .action) }
                    },
                    FeatureItem(title: "Auto Caption", icon: "captions.bubble") {
                        let caption = VideoOverlay(type: .text("Auto Caption"), position: .bottom)
                        editor.addOverlay(caption, at: editor.currentTime, duration: 4)
                    },
                    FeatureItem(title: "AI Remove BG", icon: "person.crop.rectangle") {
                        Task { await editor.smartCrop(to: .vertical, focusOn: .center) }
                    }
                ],
                overlayItems: [
                    FeatureItem(title: "PIP", icon: "rectangle.on.rectangle") {
                        if let firstClip = editor.timeline.clips.first {
                            editor.addPiP(videoURL: firstClip.url, at: editor.currentTime, duration: min(3, firstClip.duration), frame: CGRect(x: 40, y: 40, width: 140, height: 200))
                        }
                    },
                    FeatureItem(title: "Blend", icon: "circle.lefthalf.filled") {
                        if let firstClip = editor.timeline.clips.first {
                            editor.setBlendMode(.overlay, for: firstClip)
                        }
                    }
                ]
            )

            featureRow(
                title: "Aspect Ratio",
                items: [
                    FeatureItem(title: "16:9", icon: "rectangle") {
                        editor.setAspectRatio(.horizontal)
                    },
                    FeatureItem(title: "9:16", icon: "rectangle.portrait") {
                        editor.setAspectRatio(.vertical)
                    },
                    FeatureItem(title: "1:1", icon: "square") {
                        editor.setAspectRatio(.square)
                    }
                ],
                overlayItems: []
            )
        }
    }

    private func featureRow(title: String, items: [FeatureItem], overlayItems: [FeatureItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.95))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items) { item in
                        FeatureButton(item: item)
                    }
                    if !overlayItems.isEmpty {
                        Divider().frame(height: 48)
                        ForEach(overlayItems) { item in
                            FeatureButton(item: item)
                        }
                    }
                }
            }
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption.monospacedDigit())
            }
            Slider(value: value, in: range) { _ in
                action()
            }
        }
        .foregroundStyle(.white)
    }

    private func syncTrimValues() {
        guard let clip = editor.timeline.clips.first else { return }
        trimStart = clip.trimStart
        trimEnd = clip.trimEnd
        speed = clip.speed
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

struct TimelineView: View {
    @ObservedObject var timeline: Timeline
    @State private var zoomLevel: CGFloat = 1.0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(timeline.clips) { clip in
                    ClipThumbnail(clip: clip, width: 88 * zoomLevel)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
        }
    }
}

struct ClipThumbnail: View {
    @ObservedObject var clip: VideoClip
    let width: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.white.opacity(0.2))
            .frame(width: width, height: 62)
            .overlay {
                VStack(spacing: 2) {
                    Text(clip.url.lastPathComponent)
                        .font(.caption2)
                        .lineLimit(1)
                    Text(String(format: "%.1fs", clip.duration))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .foregroundStyle(.white)
                .padding(4)
            }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Effects Panel
// ─────────────────────────────────────────────────────────────────────────────

struct EffectsPanel: View {
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
                        FilterButton(
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
                AdjustmentSlider(title: "Brightness", value: $brightness, icon: "sun.max") {
                    editor.adjustBrightness(brightness)
                }
                AdjustmentSlider(title: "Contrast", value: $contrast, icon: "circle.lefthalf.filled") {
                    editor.adjustContrast(contrast)
                }
                AdjustmentSlider(title: "Saturation", value: $saturation, icon: "paintpalette") {
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

struct TextOverlayPanel: View {
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

struct AudioPanel: View {
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

struct ExportSheet: View {
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
                            PlatformButton(platform: platform) {
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

struct ToolButton: View {
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

struct FilterButton: View {
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

struct PlatformButton: View {
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

struct AdjustmentSlider: View {
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
