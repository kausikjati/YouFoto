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

struct VideoEditorView: View {
    let asset: PHAsset
    let videoURL: URL
    let onClose: () -> Void

    @State private var player: AVPlayer?
    @State private var selectedExportQuality: VideoExportQuality = .p1080
    @State private var selectedAspectRatio: VideoAspectRatio = .landscape
    @State private var brightness: Double = 0
    @State private var contrast: Double = 1
    @State private var saturation: Double = 1
    @State private var temperature: Double = 0
    @State private var audioVolume: Double = 1
    @State private var speed: Double = 1

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    playerCard
                    exportAndShareCard
                    trimAndTimelineCard
                    filtersCard
                    audioCard
                    textCard
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

    private var playerCard: some View {
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

    private var exportAndShareCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export video")
                .font(.headline)

            Picker("Quality", selection: $selectedExportQuality) {
                ForEach(VideoExportQuality.allCases) { quality in
                    Text(quality.rawValue).tag(quality)
                }
            }
            .pickerStyle(.segmented)

            featureRows([
                "Share to social media",
                "Save to gallery"
            ])
        }
        .cardStyle()
    }

    private var trimAndTimelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trim, Cut & Timeline")
                .font(.headline)

            featureRows([
                "Trim start and end",
                "Split video into parts",
                "Delete unwanted clips",
                "Simple horizontal timeline",
                "Drag & drop clips",
                "Zoom timeline"
            ])

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 70)
                .overlay(alignment: .leading) {
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.5))
                                .frame(width: 42, height: 52)
                        }
                    }
                    .padding(.horizontal, 10)
                }
        }
        .cardStyle()
    }

    private var filtersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters & Effects")
                .font(.headline)

            featureRows([
                "Vintage",
                "Black & white",
                "Cinematic"
            ])

            Group {
                sliderRow(title: "Brightness", value: $brightness, range: -1...1)
                sliderRow(title: "Contrast", value: $contrast, range: 0...2)
                sliderRow(title: "Saturation", value: $saturation, range: 0...2)
                sliderRow(title: "Temperature", value: $temperature, range: -1...1)
            }
        }
        .cardStyle()
    }

    private var audioCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio Editing")
                .font(.headline)

            featureRows([
                "Add music from library",
                "Voice-over recording",
                "Audio trimming",
                "Fade in / fade out"
            ])

            sliderRow(title: "Volume", value: $audioVolume, range: 0...2)
        }
        .cardStyle()
    }

    private var textCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Text & Titles")
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

            featureRows([
                "Fade",
                "Slide",
                "Zoom",
                "3D transitions"
            ])
        }
        .cardStyle()
    }

    private var speedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Speed Control")
                .font(.headline)

            featureRows([
                "Slow motion",
                "Fast motion",
                "Reverse video"
            ])

            sliderRow(title: "Playback speed", value: $speed, range: 0.25...2)
        }
        .cardStyle()
    }

    private var aspectRatioCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aspect Ratio")
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
            Text("Overlay & Picture in Picture")
                .font(.headline)

            featureRows([
                "Add video over video",
                "Blend modes",
                "Green screen (chroma key)"
            ])
        }
        .cardStyle()
    }

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Features")
                .font(.headline)

            featureRows([
                "Auto video creation",
                "Auto highlight detection",
                "AI scene detection",
                "Text to speech",
                "Auto subtitle generation",
                "Remove background",
                "Blur background"
            ])
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

private extension View {
    func cardStyle() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
