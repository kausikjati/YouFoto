//
//  DemoApp.swift
//  Example integration of PhotoEditorKit
//

import SwiftUI

@main
struct PhotoEditorDemoApp: App {
    @StateObject private var editor = PhotoEditorKit(config: .default)
    
    var body: some Scene {
        WindowGroup {
            ContentView(editor: editor)
        }
    }
}

struct ContentView: View {
    @ObservedObject var editor: PhotoEditorKit
    
    var body: some View {
        PhotoEditorView(editor: editor)
            .onAppear {
                configureEditor()
            }
    }
    
    private func configureEditor() {
        // Configure AI agent
        editor.agent.style = .professional
        editor.agent.aggressiveness = 0.7
        editor.agent.maintainConsistency = true
        
        // Set up callbacks
        editor.onProgress = { progress in
            print("Progress: \(Int(progress.percentage * 100))%")
            print("Current: \(progress.currentOperation)")
        }
        
        editor.onComplete = { results in
            print("Completed: \(results.count) images processed")
            let successful = results.filter { $0.success }.count
            print("Success rate: \(successful)/\(results.count)")
        }
        
        editor.onError = { error in
            print("Error: \(error.localizedDescription)")
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Example Usage Scenarios
// ─────────────────────────────────────────────────────────────────────────────

struct Examples {
    
    // EXAMPLE 1: Basic Batch Processing
    static func example1(editor: PhotoEditorKit) async {
        // Load images
        let images: [UIImage] = [] // Your images
        editor.loadImages(images)
        
        // Create batch job
        let job = BatchJob(
            images: images,
            operations: [
                .removeBackground,
                .adjustBrightness(0.2),
                .sharpen(intensity: 0.5)
            ]
        )
        
        // Process
        try? await editor.processBatch(job)
        
        // Export
        let files = try? await editor.export(
            format: .png,
            naming: .sequential("product-")
        )
        print("Exported to: \(files?.map { $0.path } ?? [])")
    }
    
    // EXAMPLE 2: AI-Powered Editing
    static func example2(editor: PhotoEditorKit) async {
        // Natural language command
        try? await editor.processCommand("Make these look professional and remove backgrounds")
        
        // Smart processing with AI analysis
        try? await editor.smartProcess(targetStyle: "vibrant product photos")
        
        // AI learns from your edits
        editor.agent.learnFromEdits = true
    }
    
    // EXAMPLE 3: Custom Workflow
    static func example3(editor: PhotoEditorKit) async {
        // Load images
        editor.loadImages([]) // Your images
        
        // Select specific images
        editor.selectedIndices = [0, 2, 4]
        
        // Apply operations only to selected
        try? await editor.applyOperation(.removeBackground)
        
        // Different operation to all
        editor.selectedIndices = []
        try? await editor.applyOperation(.adjustBrightness(0.15))
        
        // Undo last operation
        editor.undo()
        
        // Reset to original
        editor.reset()
    }
    
    // EXAMPLE 4: Advanced Features
    static func example4(editor: PhotoEditorKit) async {
        // Configure agent style
        editor.agent.configure(
            style: .vibrant,
            aggressiveness: 0.8,
            maintainConsistency: true,
            learnFromEdits: true
        )
        
        // Generate operations based on analysis
        let analyses = try? await withThrowingTaskGroup(of: ImageAnalysis.self) { group in
            var results: [ImageAnalysis] = []
            for img in editor.images {
                group.addTask {
                    try await editor.analyzer.analyze(img.current)
                }
            }
            for try await analysis in group {
                results.append(analysis)
            }
            return results
        }
        
        if let analyses = analyses {
            let operations = try? await editor.agent.generateOperations(
                analyses: analyses,
                targetStyle: "consistent magazine style"
            )
            print("Generated \(operations?.count ?? 0) operation sets")
        }
    }
    
    // EXAMPLE 5: Integration with Photos Picker
    struct PhotoPickerIntegration: View {
        @StateObject private var editor = PhotoEditorKit()
        @State private var selectedItems: [PhotosPickerItem] = []
        
        var body: some View {
            NavigationStack {
                VStack {
                    if editor.images.isEmpty {
                        PhotosPicker(
                            selection: $selectedItems,
                            maxSelectionCount: 50,
                            matching: .images
                        ) {
                            Text("Select Photos")
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        PhotoEditorView(editor: editor)
                    }
                }
                .onChange(of: selectedItems) { _, items in
                    Task {
                        for item in items {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                editor.addImage(image)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView(editor: PhotoEditorKit())
}
