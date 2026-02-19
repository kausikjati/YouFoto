# Complete Integration Guide — Adding Video Editor to Your Photo App

## 🎯 Overview

This guide shows you how to add professional video editing to your existing photo app. The `VideoEditorKit` is designed to work seamlessly alongside `PhotoEditorKit`.

## ⚡ Quick Integration (5 Minutes)

### Step 1: Add VideoEditorKit

```swift
// Add to your project (Swift Package or drag files)
import VideoEditorKit
```

### Step 2: Update Your Media Grid

```swift
// BEFORE (Photo only)
if asset.mediaType == .image {
    PhotoEditorView(asset: asset)
}

// AFTER (Photo + Video)
if asset.mediaType == .image {
    PhotoEditorView(asset: asset)
} else if asset.mediaType == .video {
    VideoEditorView(asset: asset)  // ← Add this line!
}
```

### Step 3: Done!

That's it! Your app now supports video editing with:
- ✅ Trim & cut
- ✅ Filters & effects
- ✅ Transitions
- ✅ Text overlays
- ✅ Audio editing
- ✅ Export to social media

## 📱 Integration Patterns

### Pattern 1: Unified Media Editor (Recommended)

```swift
struct MediaEditorView: View {
    let asset: PHAsset
    
    var body: some View {
        if asset.mediaType == .image {
            PhotoEditorView(asset: asset)
        } else {
            VideoEditorView(asset: asset)
        }
    }
}
```

**When to use:** When you want seamless experience for users

### Pattern 2: Separate Buttons

```swift
struct MediaThumbnail: View {
    let asset: PHAsset
    
    var body: some View {
        ZStack {
            Image(...)
            
            if asset.mediaType == .video {
                Button("Edit Video") {
                    showVideoEditor = true
                }
            } else {
                Button("Edit Photo") {
                    showPhotoEditor = true
                }
            }
        }
    }
}
```

**When to use:** When you want explicit distinction

### Pattern 3: Custom Integration

```swift
struct CustomEditor: View {
    @StateObject private var editor: VideoEditor
    
    var body: some View {
        VStack {
            // Your custom UI
            MyCustomTimeline(editor: editor)
            MyCustomControls(editor: editor)
            
            // Use SDK processing
            Button("Apply Effect") {
                editor.apply(filter: .cinematic)
            }
        }
    }
}
```

**When to use:** When you need full control over UI

## 🔧 Feature-by-Feature Integration

### Basic Editing

```swift
// Your existing photo editing button
Button("Edit") {
    if asset.mediaType == .image {
        // Existing photo editor
        showPhotoEditor = true
    } else if asset.mediaType == .video {
        // NEW: Video editor
        showVideoEditor = true
    }
}
```

### Export & Share

```swift
// Both editors support same export pattern
let result = await editor.export()

// Or direct share
await editor.share(to: .instagram, quality: .hd1080p)
await editor.saveToGallery()
```

### AI Features

```swift
// Photos
await photoEditor.processCommand("Remove background")

// Videos (NEW - same pattern!)
await videoEditor.processCommand("Add subtitles and enhance")
await videoEditor.ai.generateSubtitles()
```

## 🎨 UI Consistency

### Shared Theme

```swift
// Configure both editors with same theme
func configureEditors() {
    let theme = .dark
    let accent = Color.blue
    
    PhotoEditorKit.configure(theme: theme, accentColor: accent)
    VideoEditorKit.configure(theme: theme, accentColor: accent)
}
```

### Matching Components

Both editors use:
- ✅ Same liquid glass design
- ✅ Same toolbar style
- ✅ Same export flow
- ✅ Same gesture patterns

## 📊 Handling Different Media Types

### Loading Media

```swift
func loadMediaForEditing(_ asset: PHAsset) {
    if asset.mediaType == .image {
        // Load image
        let options = PHImageRequestOptions()
        PHImageManager.default().requestImage(for: asset...) { image, _ in
            photoEditor.addImage(image)
        }
    } else if asset.mediaType == .video {
        // Load video
        let options = PHVideoRequestOptions()
        PHImageManager.default().requestAVAsset(forVideo: asset...) { avAsset, _, _ in
            if let urlAsset = avAsset as? AVURLAsset {
                showVideoEditor(url: urlAsset.url)
            }
        }
    }
}
```

### Saving Results

```swift
// Both editors support Photos library
await photoEditor.saveToPhotos()
await videoEditor.saveToGallery()
```

## 🚀 Advanced Features

### Batch Operations

```swift
// Photos (existing)
let photoJob = BatchJob(
    images: photos,
    operations: [.removeBackground, .adjustBrightness(0.2)]
)
await photoEditor.processBatch(photoJob)

// Videos (NEW - same pattern!)
for video in videos {
    let editor = VideoEditor(videoURL: video)
    editor.apply(filter: .cinematic)
    await editor.export()
}
```

### AI Processing

```swift
// Unified AI command interface
if asset.mediaType == .image {
    await photoEditor.processCommand("make professional")
} else {
    await videoEditor.processCommand("create highlight reel")
}
```

### Custom Effects

```swift
// Register custom effects for both
photoEditor.registerOperation("myEffect") { image in
    // Process image
}

videoEditor.registerFilter("myEffect") { frame in
    // Process video frame
}
```

## 🎯 Migration Guide

### From Photo-Only App

1. **Update grid to show videos**
   ```swift
   // Add video support to fetch
   let fetchOptions = PHFetchOptions()
   // Remove: fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
   // Fetch all media types now
   ```

2. **Add video indicator**
   ```swift
   if asset.mediaType == .video {
       Image(systemName: "play.fill")
       Text(formatDuration(asset.duration))
   }
   ```

3. **Route to correct editor**
   ```swift
   .fullScreenCover(item: $selectedAsset) { asset in
       if asset.mediaType == .image {
           PhotoEditorView(asset: asset)
       } else {
           VideoEditorView(asset: asset)
       }
   }
   ```

### Maintaining Feature Parity

| Photo Feature | Video Equivalent | Status |
|--------------|------------------|---------|
| Filters | ✅ Same filters | Ready |
| Adjustments | ✅ Same adjustments | Ready |
| Text overlay | ✅ Animated text | Enhanced |
| Background removal | ✅ Chroma key | Ready |
| AI processing | ✅ AI features | Enhanced |
| Export/Share | ✅ Same flow | Ready |

## 🐛 Troubleshooting

### Video Not Loading

```swift
// Ensure video request has proper options
let options = PHVideoRequestOptions()
options.isNetworkAccessAllowed = true  // ← Important for iCloud videos
options.deliveryMode = .automatic
```

### Preview Not Showing

```swift
// Check video asset is valid
if let urlAsset = avAsset as? AVURLAsset {
    let editor = VideoEditor(videoURL: urlAsset.url)
} else {
    print("Invalid video asset")
}
```

### Export Failing

```swift
// Handle export errors
do {
    let result = try await editor.export()
} catch {
    print("Export failed: \(error)")
    // Show error to user
}
```

## 📖 Example: Complete Integration

```swift
// Your existing photo app structure
struct YourApp: View {
    @StateObject private var photoEditor = PhotoEditorKit()
    @State private var selectedMedia: PHAsset?
    
    var body: some View {
        NavigationStack {
            // Your existing grid
            MediaGrid(onSelect: { asset in
                selectedMedia = asset
            })
        }
        // NEW: Just add this sheet
        .fullScreenCover(item: $selectedMedia) { asset in
            if asset.mediaType == .image {
                // Your existing photo editor
                PhotoEditorView(asset: asset)
            } else if asset.mediaType == .video {
                // NEW: Video editor (1 line!)
                VideoEditorView(asset: asset) { result in
                    print("Video edited: \(result.outputURL)")
                }
            }
        }
    }
}
```

## ✅ Checklist

Before launching video editing:

- [ ] Test with different video sizes (1080p, 4K)
- [ ] Test with iCloud videos
- [ ] Test export to different qualities
- [ ] Test share to social platforms
- [ ] Test on older devices (iPhone 12+)
- [ ] Test memory usage with long videos
- [ ] Add loading indicators
- [ ] Handle permission requests
- [ ] Add error handling
- [ ] Test offline mode

## 🎓 Next Steps

1. **Try the Demo App**: See complete integration example
2. **Read API Docs**: Check README.md for all features
3. **Customize UI**: Make it match your brand
4. **Add AI Features**: Enable smart editing

## 📞 Support

- Full API docs: README.md
- Integration examples: IntegrationWithPhotoApp.swift
- Code samples: All files include comments
