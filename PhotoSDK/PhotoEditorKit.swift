//
//  PhotoEditorKit.swift
//  PhotoEditorKit SDK — Core Entry Point
//
//  A modern, AI-powered photo editing SDK for iOS 17+
//  Features agentic AI, batch processing, and liquid glass UI
//

import SwiftUI
import Photos
import CoreImage
import Vision

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PhotoEditorKit Main Class
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
public class PhotoEditorKit: ObservableObject {
    
    // ── State ─────────────────────────────────────────────────────────────────
    @Published public var images: [EditableImage] = []
    @Published public var selectedIndices: Set<Int> = []
    @Published public var isProcessing = false
    @Published public var progress: ProcessingProgress?
    
    // ── Core systems ──────────────────────────────────────────────────────────
    public let agent: EditorAgent
    public let batchProcessor: BatchProcessor
    public let analyzer: ImageAnalyzer
    
    // ── Configuration ─────────────────────────────────────────────────────────
    public var config: EditorConfig
    
    // ── Callbacks ─────────────────────────────────────────────────────────────
    public var onProgress: ((ProcessingProgress) -> Void)?
    public var onComplete: (([ProcessingResult]) -> Void)?
    public var onError: ((Error) -> Void)?
    
    // ──────────────────────────────────────────────────────────────────────────
    // MARK: - Initialization
    // ──────────────────────────────────────────────────────────────────────────
    
    public init(config: EditorConfig = .default) {
        self.config = config
        self.agent = EditorAgent(config: config)
        self.batchProcessor = BatchProcessor()
        self.analyzer = ImageAnalyzer()
        
        // Configure subsystems
        agent.editor = self
        batchProcessor.onProgress = { [weak self] progress in
            self?.progress = progress
            self?.onProgress?(progress)
        }
    }
    
    // ──────────────────────────────────────────────────────────────────────────
    // MARK: - Image Management
    // ──────────────────────────────────────────────────────────────────────────
    
    /// Add a single image to the editor
    public func addImage(_ image: UIImage, metadata: ImageMetadata? = nil) {
        let editable = EditableImage(
            id: UUID(),
            original: image,
            current: image,
            metadata: metadata ?? .default
        )
        images.append(editable)
    }
    
    /// Load multiple images at once
    public func loadImages(_ images: [UIImage]) {
        for image in images {
            addImage(image)
        }
    }
    
    /// Remove images at indices
    public func removeImages(at indices: Set<Int>) {
        images = images.enumerated()
            .filter { !indices.contains($0.offset) }
            .map { $0.element }
        selectedIndices.subtract(indices)
    }
    
    /// Clear all images
    public func clear() {
        images.removeAll()
        selectedIndices.removeAll()
        progress = nil
    }
    
    /// Get selected images
    public var selectedImages: [EditableImage] {
        selectedIndices.sorted().compactMap { images[safe: $0] }
    }
    
    // ──────────────────────────────────────────────────────────────────────────
    // MARK: - AI Agent Commands
    // ──────────────────────────────────────────────────────────────────────────
    
    /// Process natural language editing command
    public func processCommand(_ command: String) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        let targetImages = selectedImages.isEmpty ? images : selectedImages
        let results = try await agent.processCommand(command, images: targetImages)
        
        // Apply results
        for (index, result) in results.enumerated() {
            if let imageIndex = images.firstIndex(where: { $0.id == targetImages[index].id }) {
                images[imageIndex].current = result.image
                images[imageIndex].history.append(result)
            }
        }
        
        onComplete?(results)
    }
    
    // ──────────────────────────────────────────────────────────────────────────
    // MARK: - Batch Processing
    // ──────────────────────────────────────────────────────────────────────────
    
    /// Process batch operations
    public func processBatch(_ job: BatchJob? = nil) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        let targetImages = selectedImages.isEmpty ? images : selectedImages
        let actualJob = job ?? BatchJob(
            images: targetImages.map { $0.current },
            operations: config.defaultOperations
        )
        
        let results = try await batchProcessor.process(actualJob)
        
        // Apply results
        for (index, result) in results.enumerated() {
            if result.success, let imageIndex = images.firstIndex(where: { $0.id == targetImages[index].id }) {
                images[imageIndex].current = result.image
                images[imageIndex].history.append(result)
            }
        }
        
        onComplete?(results)
    }
    
    /// Apply single operation to selected/all images
    public func applyOperation(_ operation: EditOperation) async throws {
        let job = BatchJob(
            images: (selectedImages.isEmpty ? images : selectedImages).map { $0.current },
            operations: [operation]
        )
        try await processBatch(job)
    }
    
    // ──────────────────────────────────────────────────────────────────────────
    // MARK: - Smart Processing
    // ──────────────────────────────────────────────────────────────────────────
    
    /// AI analyzes and processes each image optimally
    public func smartProcess(targetStyle: String? = nil) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        let targetImages = selectedImages.isEmpty ? images : selectedImages
        
        // Analyze each image
        progress = ProcessingProgress(
            total: targetImages.count,
            completed: 0,
            currentOperation: "Analyzing images..."
        )
        
        var analyses: [ImageAnalysis] = []
        for (i, img) in targetImages.enumerated() {
            let analysis = try await analyzer.analyze(img.current)
            analyses.append(analysis)
            progress?.completed = i + 1
        }
        
        // Generate optimal operations per image
        let operations = try await agent.generateOperations(
            analyses: analyses,
            targetStyle: targetStyle
        )
        
        // Process each image with its specific operations
        var results: [ProcessingResult] = []
        for (i, (image, ops)) in zip(targetImages, operations).enumerated() {
            progress?.currentOperation = "Processing image \(i+1)/\(targetImages.count)"
            progress?.completed = i
            
            let job = BatchJob(images: [image.current], operations: ops)
            let batchResults = try await batchProcessor.process(job)
            if let result = batchResults.first {
                results.append(result)
                
                // Apply immediately
                if let imageIndex = images.firstIndex(where: { $0.id == image.id }) {
                    images[imageIndex].current = result.image
                    images[imageIndex].history.append(result)
                    images[imageIndex].analysis = analyses[i]
                }
            }
        }
        
        progress?.completed = targetImages.count
        onComplete?(results)
    }
    
    // ──────────────────────────────────────────────────────────────────────────
    // MARK: - History & Undo
    // ──────────────────────────────────────────────────────────────────────────
    
    /// Undo last edit on selected images
    public func undo() {
        for index in selectedIndices {
            guard index < images.count else { continue }
            if images[index].history.count > 1 {
                images[index].history.removeLast()
                if let previous = images[index].history.last {
                    images[index].current = previous.image
                }
            }
        }
    }
    
    /// Reset selected images to original
    public func reset() {
        for index in selectedIndices {
            guard index < images.count else { continue }
            images[index].current = images[index].original
            images[index].history.removeAll()
        }
    }
    
    // ──────────────────────────────────────────────────────────────────────────
    // MARK: - Export
    // ──────────────────────────────────────────────────────────────────────────
    
    /// Export edited images
    public func export(
        format: ImageFormat = .png,
        quality: CGFloat = 1.0,
        naming: NamingScheme = .sequential("edited-")
    ) async throws -> [URL] {
        let targetImages = selectedImages.isEmpty ? images : selectedImages
        var urls: [URL] = []
        
        for (i, img) in targetImages.enumerated() {
            let filename = naming.generate(index: i, original: img.metadata.filename)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            
            if let data = img.current.pngData() {
                try data.write(to: url)
                urls.append(url)
            }
        }
        
        return urls
    }
    
    /// Save to Photos library
    public func saveToPhotos() async throws {
        let targetImages = selectedImages.isEmpty ? images : selectedImages
        
        for img in targetImages {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: img.current)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Configuration
// ─────────────────────────────────────────────────────────────────────────────

public struct EditorConfig {
    public var theme: Theme = .dark
    public var accentColor: Color = .blue
    public var glassIntensity: CGFloat = 0.8
    public var defaultOperations: [EditOperation] = []
    public var maxConcurrentOperations: Int = 4
    public var enableAI: Bool = true
    public var learnFromEdits: Bool = true
    
    public static let `default` = EditorConfig()
    
    public enum Theme {
        case light, dark, auto
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Models
// ─────────────────────────────────────────────────────────────────────────────

public struct EditableImage: Identifiable {
    public let id: UUID
    public let original: UIImage
    public var current: UIImage
    public var metadata: ImageMetadata
    public var history: [ProcessingResult] = []
    public var analysis: ImageAnalysis?
}

public struct ImageMetadata {
    public var filename: String
    public var creationDate: Date?
    public var location: String?
    public var camera: String?
    public var tags: [String]
    
    public static let `default` = ImageMetadata(
        filename: "untitled",
        creationDate: Date(),
        location: nil,
        camera: nil,
        tags: []
    )
}

public struct ProcessingProgress {
    public var total: Int
    public var completed: Int
    public var currentOperation: String
    
    public var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

public struct ProcessingResult {
    public let image: UIImage
    public let operations: [EditOperation]
    public let success: Bool
    public let error: Error?
    public let processingTime: TimeInterval
    public let metadata: [String: Any]
    
    public init(image: UIImage, operations: [EditOperation] = [], 
                success: Bool = true, error: Error? = nil,
                processingTime: TimeInterval = 0, metadata: [String: Any] = [:]) {
        self.image = image
        self.operations = operations
        self.success = success
        self.error = error
        self.processingTime = processingTime
        self.metadata = metadata
    }
}

public enum ImageFormat {
    case png, jpeg, heic
}

public enum NamingScheme {
    case sequential(String)  // "prefix-001.png"
    case timestamp(String)   // "prefix-2026-02-18.png"
    case original            // Keep original names
    case custom((Int, String) -> String)
    
    func generate(index: Int, original: String) -> String {
        switch self {
        case .sequential(let prefix):
            return "\(prefix)\(String(format: "%03d", index + 1)).png"
        case .timestamp(let prefix):
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmmss"
            return "\(prefix)\(formatter.string(from: Date())).png"
        case .original:
            return original
        case .custom(let generator):
            return generator(index, original)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Helpers
// ─────────────────────────────────────────────────────────────────────────────

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
