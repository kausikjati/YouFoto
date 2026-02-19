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
    @StateObject private var editor: VideoEditor
    let onComplete: ((ExportResult) -> Void)?
    
    @State private var showEffects = false
    @State private var showText = false
    @State private var showAudio = false
    @State private var showExport = false
    @State private var selectedTool: EditTool = .trim
    
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
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar
                topBar
                
                // Video preview
                videoPreview
                
                // Timeline editor
                TimelineView(timeline: editor.timeline)
                    .frame(height: 120)
                    .background(.ultraThinMaterial)
                
                // Tool controls
                toolsPanel
                    .frame(height: 80)
                    .background(.ultraThinMaterial)
            }
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
        HStack {
            Button {
                // Close
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .glassEffect(.regular.interactive(), in: Circle())
            
            Spacer()
            
            Text("Video Editor")
                .font(.headline)
                .foregroundStyle(.white)
            
            Spacer()
            
            Button {
                showExport = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .glassEffect(.regular.interactive(), in: Circle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
    
    // ── Video Preview ────────────────────────────────────────────────────────
    
    private var videoPreview: some View {
        ZStack {
            // Video player
            Color.black
            
            // Play button
            if !editor.isPlaying {
                Button {
                    editor.isPlaying.toggle()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                }
                .glassEffect(.regular.interactive(), in: Circle())
            }
        }
    }
    
    // ── Tools Panel ──────────────────────────────────────────────────────────
    
    private var toolsPanel: some View {
        HStack(spacing: 20) {
            ToolButton(icon: "scissors", title: "Trim", isSelected: selectedTool == .trim) {
                selectedTool = .trim
            }
            
            ToolButton(icon: "wand.and.stars", title: "Effects", isSelected: selectedTool == .effects) {
                showEffects = true
            }
            
            ToolButton(icon: "textformat", title: "Text", isSelected: selectedTool == .text) {
                showText = true
            }
            
            ToolButton(icon: "music.note", title: "Audio", isSelected: selectedTool == .audio) {
                showAudio = true
            }
            
            ToolButton(icon: "speedometer", title: "Speed", isSelected: selectedTool == .speed) {
                selectedTool = .speed
            }
        }
        .padding(.horizontal)
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
            HStack(spacing: 4) {
                ForEach(timeline.clips) { clip in
                    ClipThumbnail(clip: clip, width: 100 * zoomLevel)
                }
            }
            .padding()
        }
        .overlay(alignment: .bottom) {
            zoomControls
        }
    }
    
    private var zoomControls: some View {
        HStack {
            Button {
                zoomLevel = max(0.5, zoomLevel - 0.25)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 16))
            }
            
            Slider(value: $zoomLevel, in: 0.5...3.0)
                .frame(width: 100)
            
            Button {
                zoomLevel = min(3.0, zoomLevel + 0.25)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 16))
            }
        }
        .padding(8)
        .glassEffect(.regular, in: Capsule())
        .padding(.bottom, 8)
    }
}

struct ClipThumbnail: View {
    @ObservedObject var clip: VideoClip
    let width: CGFloat
    
    var body: some View {
        Rectangle()
            .fill(.gray.opacity(0.3))
            .frame(width: width, height: 60)
            .overlay {
                VStack {
                    Text(clip.url.lastPathComponent)
                        .font(.caption2)
                        .lineLimit(1)
                    Text(String(format: "%.1fs", clip.duration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(4)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
        VStack(alignment: .leading) {
            Text("Transitions")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TransitionType.allCases, id: \.self) { type in
                        TransitionButton(type: type) {
                            // Add transition
                        }
                    }
                }
            }
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
    
    var body: some View {
        NavigationStack {
            List {
                Section("Music") {
                    Button {
                        // Add music
                    } label: {
                        Label("Add Music", systemImage: "music.note")
                    }
                }
                
                Section("Voice-over") {
                    Button {
                        // Record voice-over
                    } label: {
                        Label("Record Voice-over", systemImage: "mic")
                    }
                }
                
                Section("Volume") {
                    VStack {
                        Slider(value: .constant(0.7), in: 0...1)
                        HStack {
                            Text("Original Audio")
                            Spacer()
                            Text("70%")
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
    @State private var selectedPlatform: SocialPlatform?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Quality
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
                
                // Social media presets
                VStack(alignment: .leading) {
                    Text("Export For")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(SocialPlatform.allCases, id: \.self) { platform in
                            PlatformButton(platform: platform) {
                                selectedPlatform = platform
                                exportFor(platform)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Export button
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
            if let result = result {
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
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(isSelected ? Color.accentColor : .white)
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
                Rectangle()
                    .fill(.gray)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(filter.rawValue)
                    .font(.caption)
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
        }
    }
}

struct TransitionButton: View {
    let type: TransitionType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: "arrow.right")
                    .font(.system(size: 30))
                    .frame(width: 60, height: 60)
                    .background(.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(type.rawValue)
                    .font(.caption)
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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Edit Tool
// ─────────────────────────────────────────────────────────────────────────────

enum EditTool {
    case trim, effects, text, audio, speed
}
