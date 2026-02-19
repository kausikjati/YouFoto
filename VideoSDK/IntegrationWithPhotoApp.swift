//
//  IntegrationWithPhotoApp.swift
//  How to integrate video editor with your existing photo app
//

import SwiftUI
import Photos
import PhotoEditorKit  // Your existing photo SDK
import VideoEditorKit  // New video SDK

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Unified Media Editor
// Handles both photos and videos seamlessly
// ─────────────────────────────────────────────────────────────────────────────

struct UnifiedMediaApp: View {
    @State private var selectedAsset: PHAsset?
    @State private var showEditor = false
    
    var body: some View {
        NavigationStack {
            MediaGridView(onSelect: { asset in
                selectedAsset = asset
                showEditor = true
            })
            .navigationTitle("Media Library")
        }
        .fullScreenCover(isPresented: $showEditor) {
            if let asset = selectedAsset {
                MediaEditorView(asset: asset)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Media Editor (Routes to Photo or Video)
// ─────────────────────────────────────────────────────────────────────────────

struct MediaEditorView: View {
    let asset: PHAsset
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if asset.mediaType == .image {
                // Use your existing photo editor
                PhotoEditorView(asset: asset) { result in
                    // Handle photo edit completion
                    dismiss()
                }
            } else if asset.mediaType == .video {
                // Use new video editor
                VideoEditorView(asset: asset) { result in
                    // Handle video edit completion
                    print("Video exported to: \(result.outputURL)")
                    dismiss()
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Enhanced Grid with Edit Button
// Your existing grid, now with video support
// ─────────────────────────────────────────────────────────────────────────────

struct EnhancedMediaGrid: View {
    let assets: [PHAsset]
    @State private var selectedAsset: PHAsset?
    @State private var showEditor = false
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
            ForEach(assets, id: \.localIdentifier) { asset in
                MediaThumbnail(asset: asset) {
                    selectedAsset = asset
                    showEditor = true
                }
            }
        }
        .fullScreenCover(isPresented: $showEditor) {
            if let asset = selectedAsset {
                MediaEditorView(asset: asset)
            }
        }
    }
}

struct MediaThumbnail: View {
    let asset: PHAsset
    let onTap: () -> Void
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Edit button
            Button {
                onTap()
            } label: {
                Text("Edit")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(8)
            
            // Video indicator
            if asset.mediaType == .video {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                    Text(formatDuration(asset.duration))
                        .font(.caption2)
                }
                .padding(4)
                .background(.black.opacity(0.6), in: Capsule())
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 300, height: 300),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            self.thumbnail = image
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Example: Adding Video Editing to Existing Photo App
// ─────────────────────────────────────────────────────────────────────────────

// BEFORE (Your existing app):
/*
struct ContentView: View {
    var body: some View {
        NavigationStack {
            PhotoGridView()  // Only handles photos
        }
    }
}
*/

// AFTER (With video support):
struct ContentView: View {
    @StateObject private var photoEditor = PhotoEditorKit()
    
    var body: some View {
        NavigationStack {
            UnifiedMediaGridView()  // Handles photos AND videos
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Import Photos") { /* ... */ }
                            Button("Import Videos") { /* ... */ }  // NEW
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Quick Integration Example
// ─────────────────────────────────────────────────────────────────────────────

struct QuickIntegrationExample: View {
    @State private var asset: PHAsset?
    
    var body: some View {
        Button("Edit Media") {
            // Your existing code to select asset
            // ...
            // Then just add this:
        }
        .fullScreenCover(item: $asset) { asset in
            // Automatically routes to correct editor
            if asset.mediaType == .image {
                PhotoEditorView(asset: asset)
            } else {
                VideoEditorView(asset: asset)  // NEW - 1 line integration!
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Advanced: Custom Integration
// ─────────────────────────────────────────────────────────────────────────────

struct CustomIntegration: View {
    @StateObject private var photoEditor = PhotoEditorKit()
    @StateObject private var videoEditor: VideoEditor
    
    init(asset: PHAsset) {
        if asset.mediaType == .video {
            _videoEditor = StateObject(wrappedValue: VideoEditor(asset: asset))
        } else {
            // Handle photo
            _videoEditor = StateObject(wrappedValue: VideoEditor(videoURL: URL(fileURLWithPath: "")))
        }
    }
    
    var body: some View {
        VStack {
            // Your custom UI
            CustomPreview()
            CustomControls()
            
            // Use SDK processing
            Button("Apply Effect") {
                Task {
                    videoEditor.apply(filter: .cinematic)
                }
            }
        }
    }
    
    private func CustomPreview() -> some View {
        // Your custom video preview
        Text("Video Preview")
    }
    
    private func CustomControls() -> some View {
        // Your custom controls
        Text("Controls")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Shared Settings Between Photo & Video Editor
// ─────────────────────────────────────────────────────────────────────────────

class MediaEditorSettings: ObservableObject {
    @Published var theme: Theme = .dark
    @Published var accentColor: Color = .blue
    
    static let shared = MediaEditorSettings()
    
    enum Theme {
        case light, dark
    }
}

// Configure both editors
extension View {
    func configureMediaEditors() -> some View {
        self.onAppear {
            let settings = MediaEditorSettings.shared
            
            // Configure photo editor
            PhotoEditorKit.configure(
                theme: settings.theme == .dark ? .dark : .light,
                accentColor: settings.accentColor
            )
            
            // Configure video editor
            VideoEditorKit.configure(
                theme: settings.theme == .dark ? .dark : .light,
                accentColor: settings.accentColor
            )
        }
    }
}

#Preview {
    UnifiedMediaApp()
}
