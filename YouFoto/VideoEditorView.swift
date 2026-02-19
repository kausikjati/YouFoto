import SwiftUI
import AVKit
import Photos

enum VideoExportQuality: String, CaseIterable, Identifiable {
    case p720 = "720p"
    case p1080 = "1080p"
    case p4k = "4K"

    var id: String { rawValue }
}

enum VideoAspectRatio: String, CaseIterable, Identifiable {
    case landscape = "16:9"
    case vertical = "9:16"
    case square = "1:1"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .landscape: return "YouTube"
        case .vertical: return "Reels, TikTok"
        case .square: return "Instagram"
        }
    }
}

enum OverlayMode: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case multiply = "Multiply"
    case screen = "Screen"
    case overlay = "Overlay"

    var id: String { rawValue }
}

private struct ClipSegment: Identifiable, Equatable {
    let id = UUID()
    var title: String
}

struct VideoEditorView: View {
    let asset: PHAsset
    let videoURL: URL
    let onClose: () -> Void

    @State private var player: AVPlayer?
    @State private var selectedExportQuality: VideoExportQuality = .p1080
    @State private var selectedAspectRatio: VideoAspectRatio = .landscape
    @State private var selectedOverlayMode: OverlayMode = .normal

    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 1
    @State private var timelineZoom: Double = 1

    @State private var brightness: Double = 0
    @State private var contrast: Double = 1
    @State private var saturation: Double = 1
    @State private var temperature: Double = 0

    @State private var audioTrimStart: Double = 0
    @State private var audioTrimEnd: Double = 1
    @State private var audioVolume: Double = 1
    @State private var audioFadeIn = true
    @State private var audioFadeOut = true

    @State private var speed: Double = 1
    @State private var reverseVideo = false

    @State private var enablePiP = false
    @State private var enableGreenScreen = false

    @State private var aiAutoVideoCreation = false
    @State private var aiAutoHighlightDetection = false
    @State private var aiSceneDetection = false
    @State private var aiTextToSpeech = false
    @State private var aiAutoSubtitleGeneration = false
    @State private var aiRemoveBackground = false
    @State private var aiBlurBackground = false

    @State private var clips: [ClipSegment] = [
        ClipSegment(title: "Clip 1"),
        ClipSegment(title: "Clip 2"),
        ClipSegment(title: "Clip 3")
    ]

    private var safeDuration: Double {
        max(asset.duration, 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    previewCard
                    exportCard
                    trimAndCutCard
                    timelineCard
                    filtersCard
                    audioCard
                    textAndTitlesCard
                    transitionsCard
                    speedCard
                    aspectRatioCard
                    overlayCard
                    aiCard
                }
                .padding(16)
            }
            .navigationTitle("Video Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { onClose() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Export") { }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            player = AVPlayer(url: videoURL)
        }
        .onDisappear {
            player?.pause()
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preview")
                .font(.headline)

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black)
                    .frame(height: 220)

                if let player {
                    VideoPlayer(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }

            HStack {
                Label("Duration: \(Int(asset.duration))s", systemImage: "clock")
                Spacer()
                Button("Play") { player?.play() }
                Button("Pause") { player?.pause() }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var exportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export video")
                .font(.headline)

            Picker("Quality", selection: $selectedExportQuality) {
                ForEach(VideoExportQuality.allCases) { quality in
                    Text(quality.rawValue).tag(quality)
                }
            }
            .pickerStyle(.segmented)

            Label("Share to social media", systemImage: "square.and.arrow.up")
                .font(.subheadline)
            Label("Save to gallery", systemImage: "photo.badge.plus")
                .font(.subheadline)
        }
        .cardStyle()
    }

    private var trimAndCutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("✂️ Trim & Cut")
                .font(.headline)

            sliderRow(title: "Trim start and end (start)", value: $trimStart, range: 0...safeDuration)
            sliderRow(title: "Trim start and end (end)", value: $trimEnd, range: trimStart...safeDuration)

            HStack(spacing: 10) {
                Button("Split video into parts") {
                    clips.append(ClipSegment(title: "Clip \(clips.count + 1)"))
                }
                .buttonStyle(.bordered)

                Button("Delete unwanted clips") {
                    if !clips.isEmpty {
                        clips.removeLast()
                    }
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline)
        }
        .cardStyle()
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📌 Timeline Editor")
                .font(.headline)

            Text("Simple horizontal timeline")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.22))
                            .frame(width: 90 * timelineZoom, height: 56)
                            .overlay {
                                Text(clip.title)
                                    .font(.caption)
                            }
                            .onTapGesture {
                                if index + 1 < clips.count {
                                    clips.swapAt(index, index + 1)
                                }
                            }
                    }
                }
                .padding(6)
            }
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text("Drag & drop clips (tap a clip to move it forward in this scaffold)")
                .font(.caption)
                .foregroundStyle(.secondary)

            sliderRow(title: "Zoom timeline", value: $timelineZoom, range: 1...2.2)
        }
        .cardStyle()
    }

    private var filtersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters & Effects")
                .font(.headline)

            Text("Basic filters")
                .font(.subheadline.weight(.semibold))
            chipRow(["Vintage", "Black & white", "Cinematic"])

            Text("Color adjustments")
                .font(.subheadline.weight(.semibold))
            sliderRow(title: "Brightness", value: $brightness, range: -1...1)
            sliderRow(title: "Contrast", value: $contrast, range: 0...2)
            sliderRow(title: "Saturation", value: $saturation, range: 0...2)
            sliderRow(title: "Temperature", value: $temperature, range: -1...1)
        }
        .cardStyle()
    }

    private var audioCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🎵 Audio Editing")
                .font(.headline)

            featureRows([
                "Add music from library",
                "Voice-over recording"
            ])

            sliderRow(title: "Audio trimming (start)", value: $audioTrimStart, range: 0...safeDuration)
            sliderRow(title: "Audio trimming (end)", value: $audioTrimEnd, range: audioTrimStart...safeDuration)
            sliderRow(title: "Volume control", value: $audioVolume, range: 0...2)

            Toggle("Fade in", isOn: $audioFadeIn)
            Toggle("Fade out", isOn: $audioFadeOut)
        }
        .cardStyle()
    }

    private var textAndTitlesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📝 Text & Titles")
                .font(.headline)

            featureRows([
                "Add text overlays",
                "Animated titles",
                "Fonts and colors",
                "Stickers and emojis"
            ])
        }
        .cardStyle()
    }

    private var transitionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transitions")
                .font(.headline)

            chipRow(["Fade", "Slide", "Zoom", "3D transitions"])
        }
        .cardStyle()
    }

    private var speedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⏩ Speed Control")
                .font(.headline)

            featureRows([
                "Slow motion",
                "Fast motion"
            ])
            sliderRow(title: "Speed", value: $speed, range: 0.25...2)
            Toggle("Reverse video", isOn: $reverseVideo)
        }
        .cardStyle()
    }

    private var aspectRatioCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📱 Aspect Ratio")
                .font(.headline)

            Picker("Ratio", selection: $selectedAspectRatio) {
                ForEach(VideoAspectRatio.allCases) { ratio in
                    Text("\(ratio.rawValue) (\(ratio.label))").tag(ratio)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardStyle()
    }

    private var overlayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🖼️ Overlay & Picture in Picture")
                .font(.headline)

            Toggle("Add video over video", isOn: $enablePiP)

            Picker("Blend modes", selection: $selectedOverlayMode) {
                ForEach(OverlayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Green screen (chroma key)", isOn: $enableGreenScreen)
        }
        .cardStyle()
    }

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🤖 AI Features")
                .font(.headline)

            Toggle("AI Editing · Auto video creation", isOn: $aiAutoVideoCreation)
            Toggle("Auto highlight detection", isOn: $aiAutoHighlightDetection)
            Toggle("AI scene detection", isOn: $aiSceneDetection)

            Text("AI Voice")
                .font(.subheadline.weight(.semibold))
            Toggle("Text to speech", isOn: $aiTextToSpeech)
            Toggle("Auto subtitle generation", isOn: $aiAutoSubtitleGeneration)

            Text("AI Background")
                .font(.subheadline.weight(.semibold))
            Toggle("Remove background", isOn: $aiRemoveBackground)
            Toggle("Blur background", isOn: $aiBlurBackground)
        }
        .cardStyle()
    }

    private func featureRows(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(items, id: \.self) { item in
                Label(item, systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func chipRow(_ items: [String]) -> some View {
        FlexibleChipRow(items: items)
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            Slider(value: value, in: range)
        }
    }
}

private struct FlexibleChipRow: View {
    let items: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.14), in: Capsule())
                }
            }
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
