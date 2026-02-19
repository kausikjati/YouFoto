# VideoEditorKit — Professional Video Editor SDK for iOS

A modern, AI-powered video editing SDK with timeline editor, effects, transitions, and advanced features.

## 🎬 Features

### ✂️ Core Editing
- **Trim & Cut**: Precise start/end trimming, split into parts, delete clips
- **Timeline Editor**: Drag & drop, zoom controls, multi-track support
- **Aspect Ratios**: 16:9 (YouTube), 9:16 (Reels/TikTok), 1:1 (Instagram)
- **Speed Control**: 0.25x-4x speed, reverse playback

### 🎨 Visual Effects
- **Filters**: Vintage, B&W, Cinematic, and 20+ more
- **Color Adjustments**: Brightness, Contrast, Saturation, Temperature
- **Transitions**: Fade, Slide, Zoom, 3D effects
- **Overlays**: Picture-in-Picture, blend modes, green screen

### 🎵 Audio Editing
- **Music**: Add from library, trim, volume control
- **Voice-over**: Record directly in-app
- **Audio Effects**: Fade in/out, speed adjustment
- **Multi-track**: Background music + voice-over + original audio

### 📝 Text & Titles
- **Text Overlays**: Animated titles, fonts, colors
- **Stickers & Emojis**: Built-in library
- **Animated Presets**: Fade in/out, slide, bounce
- **Custom Positioning**: Drag anywhere on video

### 🤖 AI Features
- **Auto Creation**: AI generates highlights automatically
- **Scene Detection**: Identifies key moments
- **Background Removal**: AI-powered chroma key
- **Auto Subtitles**: Speech-to-text with timing
- **Text-to-Speech**: AI voice narration

### 📤 Export & Share
- **Quality Options**: 720p, 1080p, 4K
- **Direct Sharing**: Instagram, TikTok, YouTube
- **Save to Gallery**: With metadata
- **Background Export**: Continue using app while exporting

## 🚀 Quick Start

### Basic Integration

```swift
import VideoEditorKit
import SwiftUI

struct MyApp: View {
    @State private var videoURL: URL?
    
    var body: some View {
        if let url = videoURL {
            VideoEditorView(videoURL: url) { result in
                // Handle export
                print("Exported: \(result.outputURL)")
            }
        }
    }
}
```

### From Photo App (Your Existing App)

```swift
// In your existing photo/video grid
if asset.mediaType == .video {
    Button("Edit") {
        exportAssetForEditing(asset)
    }
}

func exportAssetForEditing(_ asset: PHAsset) {
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = true
    
    PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
        if let urlAsset = avAsset as? AVURLAsset {
            DispatchQueue.main.async {
                showVideoEditor(url: urlAsset.url)
            }
        }
    }
}
```

## 📦 Architecture

```
VideoEditorKit/
├── Core/
│   ├── VideoEditorKit.swift        # Main SDK
│   ├── TimelineManager.swift       # Timeline logic
│   ├── ExportManager.swift         # Export & share
│   └── AIEngine.swift               # AI features
├── UI/
│   ├── VideoEditorView.swift       # Main editor UI
│   ├── TimelineView.swift          # Timeline editor
│   ├── EffectsPanel.swift          # Filters & effects
│   └── TextOverlayEditor.swift     # Text & stickers
├── Effects/
│   ├── FilterEngine.swift          # Video filters
│   ├── TransitionEngine.swift      # Transitions
│   └── ColorAdjustments.swift      # Color grading
└── Audio/
    ├── AudioMixer.swift            # Multi-track audio
    ├── VoiceRecorder.swift         # Voice-over
    └── AudioEffects.swift          # Fade, volume
```

## 🎯 Key Features in Detail

### Timeline Editor

```swift
let editor = VideoEditor(videoURL: url)

// Add clips
editor.timeline.addClip(url: clip1)
editor.timeline.addClip(url: clip2)

// Trim
editor.timeline.clips[0].trim(start: 2.0, end: 10.0)

// Split
editor.timeline.split(at: 5.0)

// Drag & drop (UI handles this automatically)
TimelineView(timeline: editor.timeline)
```

### Filters & Effects

```swift
// Apply filter
editor.apply(filter: .vintage)
editor.apply(filter: .blackAndWhite)

// Color adjustments
editor.adjustBrightness(0.2)
editor.adjustContrast(0.1)
editor.adjustSaturation(0.3)

// Transitions
editor.addTransition(.fade, between: clip1, and: clip2, duration: 1.0)
```

### Audio Editing

```swift
// Add music
editor.audio.addMusic(url: musicURL)
editor.audio.setVolume(0.7, for: .music)

// Record voice-over
await editor.audio.recordVoiceOver { recording in
    editor.audio.addVoiceOver(recording)
}

// Fade effects
editor.audio.addFadeIn(duration: 2.0, for: .music)
editor.audio.addFadeOut(duration: 2.0, for: .music)
```

### Text & Titles

```swift
// Add text
let text = TextOverlay(
    text: "Hello World",
    font: .headline,
    color: .white,
    position: .center
)
editor.addOverlay(text, at: 2.0, duration: 5.0)

// Animated title
let title = AnimatedTitle.fadeIn(
    text: "My Video",
    duration: 2.0
)
editor.addTitle(title, at: 0.0)
```

### AI Features

```swift
// Auto highlights
let highlights = await editor.ai.detectHighlights()
let autoVideo = await editor.ai.createHighlightReel(from: highlights)

// Auto subtitles
let subtitles = await editor.ai.generateSubtitles()
editor.addSubtitles(subtitles)

// Background removal
await editor.ai.removeBackground(from: clip)

// Text-to-speech
let narration = await editor.ai.textToSpeech("Welcome to my video")
editor.audio.addNarration(narration)
```

### Export

```swift
// Export with options
let options = ExportOptions(
    quality: .hd1080p,
    format: .mp4,
    aspectRatio: .vertical  // 9:16 for Reels
)

let result = await editor.export(options: options) { progress in
    print("Progress: \(progress)%")
}

// Direct share
await editor.share(to: .instagram, quality: .hd1080p)
await editor.share(to: .tiktok, quality: .hd1080p)

// Save to gallery
await editor.saveToGallery(quality: .uhd4k)
```

## 📱 UI Components

### Complete Pre-built Editor

```swift
// Full-featured editor
VideoEditorView(videoURL: url) { result in
    // Handle completion
}
```

### Custom UI with SDK Processing

```swift
struct CustomEditor: View {
    @StateObject private var editor = VideoEditor(videoURL: url)
    
    var body: some View {
        VStack {
            // Video preview
            VideoPreviewView(editor: editor)
            
            // Your custom timeline
            CustomTimeline(clips: editor.timeline.clips)
            
            // Use SDK's processing
            Button("Apply Filter") {
                editor.apply(filter: .vintage)
            }
        }
    }
}
```

## 🎨 Customization

### Themes

```swift
VideoEditorKit.configure(
    theme: .dark,
    accentColor: .blue,
    glassIntensity: 0.8
)
```

### Custom Filters

```swift
// Register custom filter
editor.registerFilter("myFilter") { frame in
    // Your custom processing
    return processedFrame
}

// Use it
editor.apply(filter: .custom("myFilter"))
```

### Custom Transitions

```swift
editor.registerTransition("myTransition") { progress, fromFrame, toFrame in
    // Your custom transition logic
    return blendedFrame
}
```

## 🎯 Advanced Features

### Picture-in-Picture

```swift
// Add overlay video
editor.addPiP(
    videoURL: overlayURL,
    at: 5.0,
    duration: 10.0,
    frame: CGRect(x: 0.7, y: 0.1, width: 0.25, height: 0.25)
)

// Blend modes
editor.setBlendMode(.screen, for: pipLayer)
```

### Green Screen

```swift
// Chroma key
await editor.chromaKey(
    video: greenScreenURL,
    keyColor: .green,
    tolerance: 0.3,
    background: backgroundURL
)
```

### Speed Control

```swift
// Slow motion
editor.setSpeed(0.5, for: clip)  // Half speed

// Fast forward
editor.setSpeed(2.0, for: clip)  // 2x speed

// Reverse
editor.reverse(clip)
```

### Aspect Ratio Conversion

```swift
// Convert for social media
editor.setAspectRatio(.vertical)   // 9:16 (Reels/TikTok)
editor.setAspectRatio(.square)     // 1:1 (Instagram)
editor.setAspectRatio(.horizontal) // 16:9 (YouTube)

// Auto-crop to focal point
editor.smartCrop(to: .vertical, focusOn: .faces)
```

## 🤖 AI Engine Details

### Auto Video Creation

```swift
// AI analyzes video and creates highlights
let result = await editor.ai.autoCreate(
    style: .energetic,
    duration: 60.0,  // Target 60 seconds
    includeMusic: true
)
```

### Scene Detection

```swift
// Detect scene changes
let scenes = await editor.ai.detectScenes()
for scene in scenes {
    print("Scene at \(scene.timestamp): \(scene.type)")
}

// Auto-split at scenes
editor.splitAtScenes(scenes)
```

### Smart Subtitles

```swift
// Generate with timing
let subtitles = await editor.ai.generateSubtitles(
    language: "en",
    style: .modern
)

// Customize appearance
subtitles.font = .headline
subtitles.backgroundColor = .black.opacity(0.7)
subtitles.position = .bottom
```

## 📤 Export Options

### Quality Settings

```swift
enum ExportQuality {
    case sd480p      // 854×480
    case hd720p      // 1280×720
    case hd1080p     // 1920×1080
    case uhd4k       // 3840×2160
    case custom(CGSize)
}
```

### Format Options

```swift
enum ExportFormat {
    case mp4         // H.264
    case mov         // ProRes
    case hevc        // H.265 (smaller file)
}
```

### Social Media Presets

```swift
// Pre-configured for each platform
editor.exportFor(.instagram) { result in
    // Optimized: 1080×1350, H.264, 30fps
}

editor.exportFor(.tiktok) { result in
    // Optimized: 1080×1920, H.264, 30fps
}

editor.exportFor(.youtube) { result in
    // Optimized: 1920×1080, H.264, 60fps
}
```

## 🎓 Common Workflows

### Instagram Reel

```swift
// 1. Load video
let editor = VideoEditor(videoURL: url)

// 2. Set aspect ratio
editor.setAspectRatio(.vertical)  // 9:16

// 3. Trim to 60s
editor.timeline.trim(end: 60.0)

// 4. Add music
editor.audio.addMusic(url: trendingMusic)

// 5. Add text
let text = TextOverlay(text: "Check this out!", position: .top)
editor.addOverlay(text, at: 0, duration: 3)

// 6. Export
await editor.exportFor(.instagram)
```

### YouTube Video

```swift
// 1. Load clips
editor.timeline.addClips([intro, mainContent, outro])

// 2. Add transitions
editor.addTransition(.fade, between: intro, and: mainContent)

// 3. Add background music
editor.audio.addMusic(url: bgMusic, volume: 0.3)

// 4. Generate auto-subtitles
let subs = await editor.ai.generateSubtitles()
editor.addSubtitles(subs)

// 5. Export 1080p
await editor.export(quality: .hd1080p)
```

## 📱 Requirements

- iOS 17.0+
- Swift 5.9+
- Storage: ~500MB for effects library
- Recommended: iPhone 12 or newer for 4K

## 🎬 Performance

- **Real-time Preview**: 30fps preview while editing
- **Background Export**: Continue using app during export
- **Hardware Acceleration**: Uses Metal for effects
- **Memory Efficient**: Streams video, doesn't load all in RAM

## 📄 License

MIT License — See LICENSE file

## 🤝 Integration with PhotoEditorKit

```swift
// Seamless integration
struct MediaApp: View {
    @State private var selectedMedia: PHAsset?
    
    var body: some View {
        if let asset = selectedMedia {
            if asset.mediaType == .image {
                PhotoEditorView(asset: asset)  // Your existing photo editor
            } else if asset.mediaType == .video {
                VideoEditorView(asset: asset)  // New video editor
            }
        }
    }
}
```

## 📞 Support

- Documentation: Included
- Examples: DemoApp.swift
- Integration Guide: INTEGRATION_GUIDE.md
