# PhotoEditorKit — Complete Implementation Guide

## 🎯 Overview

PhotoEditorKit is a modern, AI-powered photo editing SDK for iOS with:
- **Agentic AI** that intelligently analyzes and processes images
- **Batch processing** for 100+ images simultaneously  
- **iOS 26 liquid glass UI** with natural language commands
- **Context-aware adjustments** per image
- **Learning system** that adapts to your style

## 📦 What's Included

### Core SDK Files
- `PhotoEditorKit.swift` — Main SDK class
- `EditorAgent.swift` — AI agent system
- `BatchProcessor.swift` — High-performance batch engine
- `ImageAnalyzer.swift` — Context-aware analysis
- `EditOperations.swift` — All edit operation types

### UI Components
- `PhotoEditorUI.swift` — Complete UI with liquid glass
- Includes: PhotoEditorView, EffectsPanel, CommandBar
- Pre-built components ready to use

### Examples
- `DemoApp.swift` — Full demo application
- Integration examples for all features
- Photos Picker integration

## 🚀 Quick Start (5 minutes)

### 1. Add to Your Project

```swift
// In your Package.swift
dependencies: [
    .package(url: "path/to/PhotoEditorKit", from: "1.0.0")
]
```

### 2. Create Editor Instance

```swift
import SwiftUI
import PhotoEditorKit

@main
struct YourApp: App {
    @StateObject private var editor = PhotoEditorKit()
    
    var body: some Scene {
        WindowGroup {
            PhotoEditorView(editor: editor)
        }
    }
}
```

### 3. You're Done!

The SDK includes a complete UI. Just present `PhotoEditorView` and users can:
- Select photos via Photos Picker
- Type AI commands: "Remove all backgrounds"
- Apply effects with visual sliders
- Export results

## 🎨 UI Customization

### Use Pre-built Views

```swift
// Full editor
PhotoEditorView(editor: editor)

// Just the effects panel
EffectsPanel(editor: editor)

// Custom layout with built-in command bar
VStack {
    YourCustomGrid(images: editor.images)
    LiquidGlassCommandBar(editor: editor)
}
```

### Or Build Your Own

```swift
struct CustomEditor: View {
    @StateObject private var editor = PhotoEditorKit()
    
    var body: some View {
        VStack {
            // Your custom UI
            ForEach(editor.images) { image in
                Image(uiImage: image.current)
            }
            
            // Use SDK's processing
            Button("Auto Enhance All") {
                Task {
                    try? await editor.applyOperation(.autoEnhance)
                }
            }
        }
    }
}
```

## 🤖 AI Features

### Natural Language Commands

```swift
// Process commands in plain English
await editor.processCommand("Make brighter")
await editor.processCommand("Remove backgrounds and add watermark")
await editor.processCommand("Match colors to first image")
await editor.processCommand("Crop to Instagram format")
```

The AI understands:
- Brightness/contrast adjustments
- Background removal
- Color matching
- Cropping/resizing
- Enhancement operations
- Combinations of above

### Smart Processing

```swift
// AI analyzes each image and applies optimal adjustments
await editor.smartProcess(targetStyle: "professional product photos")

// Results vary per image based on:
// - Current brightness/contrast
// - Subject detection (faces, objects)
// - Background complexity
// - Scene classification
```

### Learning System

```swift
// Enable learning (on by default)
editor.agent.learnFromEdits = true

// SDK records:
// - Which operations you apply manually
// - On what types of images
// - The parameters you choose

// Then suggests similar edits for new images
```

## 🎬 Common Workflows

### Product Photography Pipeline

```swift
func processProductPhotos() async {
    // 1. Load images
    editor.loadImages(productPhotos)
    
    // 2. Remove backgrounds
    try? await editor.applyOperation(.removeBackground)
    
    // 3. Consistent brightness
    try? await editor.applyOperation(.adjustBrightness(0.15))
    
    // 4. Sharpen
    try? await editor.applyOperation(.sharpen(intensity: 0.6))
    
    // 5. Add watermark
    if let logo = UIImage(named: "logo") {
        try? await editor.applyOperation(
            .addWatermark(image: logo, position: .bottomRight)
        )
    }
    
    // 6. Export
    let files = try? await editor.export(
        format: .png,
        naming: .sequential("product-")
    )
}
```

### Social Media Content

```swift
func prepareSocialContent() async {
    editor.loadImages(photos)
    
    // AI command for quick processing
    try? await editor.processCommand(
        "Vibrant colors, crop to 1:1, add slight vignette"
    )
    
    // Export for Instagram
    let files = try? await editor.export(
        format: .jpeg,
        quality: 0.9,
        naming: .timestamp("post-")
    )
}
```

### Restore Old Photos

```swift
func restoreOldPhotos() async {
    editor.loadImages(oldPhotos)
    
    let job = BatchJob(
        images: oldPhotos,
        operations: [
            .aiRestore,           // Remove scratches, noise
            .aiColorize,          // Add color if B&W
            .adjustBrightness(0.1),
            .adjustContrast(0.15)
        ]
    )
    
    try? await editor.processBatch(job)
}
```

## 📊 Progress Tracking

```swift
// Set up progress callback
editor.onProgress = { progress in
    print("Processing: \(Int(progress.percentage * 100))%")
    print("Current: \(progress.currentOperation)")
    
    // Update UI
    ProgressView(value: progress.percentage) {
        Text(progress.currentOperation)
    }
}

// Completion callback
editor.onComplete = { results in
    let successful = results.filter { $0.success }.count
    print("Processed \(successful)/\(results.count) images")
    
    // Show results
    for result in results {
        if !result.success {
            print("Failed: \(result.error?.localizedDescription ?? "Unknown")")
        }
    }
}
```

## 🎛️ Advanced Configuration

### Agent Configuration

```swift
// Configure AI behavior
editor.agent.style = .professional  // or .natural, .vibrant, .moody
editor.agent.aggressiveness = 0.7   // 0 = subtle, 1 = strong
editor.agent.maintainConsistency = true
editor.agent.learnFromEdits = true

// Custom profile
let profile = EditorProfile(
    name: "My Brand Style",
    adjustments: [
        .adjustBrightness: 0.15,
        .adjustSaturation: 0.1,
        .adjustContrast: 0.05
    ],
    alwaysApply: [
        .sharpen(intensity: 0.5),
        .addWatermark(image: logo, position: .bottomRight)
    ]
)
editor.agent.loadProfile(profile)
```

### SDK Configuration

```swift
let config = EditorConfig(
    theme: .dark,
    accentColor: .blue,
    glassIntensity: 0.8,
    defaultOperations: [
        .adjustBrightness(0.1),
        .sharpen(intensity: 0.3)
    ],
    maxConcurrentOperations: 4,
    enableAI: true,
    learnFromEdits: true
)

let editor = PhotoEditorKit(config: config)
```

## 🔧 Custom Operations

### Register Custom Effect

```swift
// Define your effect
editor.registerOperation("vintage") { image in
    var result = image
    // Your custom processing
    // - Apply sepia tone
    // - Add vignette  
    // - Reduce saturation
    return result
}

// Use it
try? await editor.applyOperation(.custom("vintage"))
```

### Chain Operations

```swift
let operations: [EditOperation] = [
    .removeBackground,
    .adjustBrightness(0.2),
    .adjustContrast(0.1),
    .sharpen(intensity: 0.5),
    .addWatermark(image: logo, position: .bottomRight)
]

let job = BatchJob(images: photos, operations: operations)
try? await editor.processBatch(job)
```

## 💾 Export Options

### Basic Export

```swift
// Export all edited images
let files = try? await editor.export()

// Export selected only
editor.selectedIndices = [0, 2, 4]
let selected = try? await editor.export()
```

### Advanced Export

```swift
// Specific format and quality
let files = try? await editor.export(
    format: .jpeg,
    quality: 0.9,
    naming: .sequential("photo-")
)

// Custom naming
let files = try? await editor.export(
    naming: .custom { index, original in
        "batch_\(Date().timeIntervalSince1970)_\(index).png"
    }
)

// Preserve metadata
let files = try? await editor.export(
    preserveMetadata: true,
    embedProfile: true
)
```

### Save to Photos

```swift
// Requires Photos library permission
try? await editor.saveToPhotos()
```

## 🎯 Best Practices

### Memory Management

```swift
// For large batches (100+ images), process in chunks
let chunkSize = 20
for i in stride(from: 0, to: editor.images.count, by: chunkSize) {
    let end = min(i + chunkSize, editor.images.count)
    editor.selectedIndices = Set(i..<end)
    try? await editor.processBatch()
    editor.selectedIndices.removeAll()
}
```

### Error Handling

```swift
// Always handle errors
editor.onError = { error in
    // Log error
    print("Error: \(error)")
    
    // Show alert to user
    AlertManager.show(
        title: "Processing Failed",
        message: error.localizedDescription
    )
}
```

### Performance

```swift
// Adjust concurrent operations based on device
#if targetEnvironment(simulator)
config.maxConcurrentOperations = 2
#else
config.maxConcurrentOperations = 4  // Modern devices
#endif
```

## 🎨 UI Theming

### Dark/Light Theme

```swift
PhotoEditorKit.configure(theme: .auto)  // Follow system

// Or force
PhotoEditorKit.configure(theme: .dark)
```

### Custom Colors

```swift
PhotoEditorKit.configure(
    accentColor: .purple,
    glassIntensity: 0.9
)
```

### Custom Glass Styles

```swift
// Custom glass effect
let customGlass = GlassStyle(
    material: .ultraThin,
    tint: Color.blue.opacity(0.2),
    blur: 25,
    saturation: 1.3
)

Button("Action") { }
    .glassEffect(customGlass, in: Capsule())
```

## 📱 Requirements

- iOS 17.0+
- Swift 5.9+
- Xcode 15.0+

## 🐛 Troubleshooting

### Images not loading?
- Check Photos library permissions
- Verify image data is valid
- Try smaller batch size

### Slow processing?
- Reduce `maxConcurrentOperations`
- Process in smaller chunks
- Use `.opportunistic` quality for preview

### UI not updating?
- Ensure operations run on `@MainActor`
- Use `@Published` for state changes
- Check callbacks are called

## 📞 Support

- GitHub Issues: [link]
- Documentation: [link]
- Discord: [link]

## 📄 License

MIT License — See LICENSE file
