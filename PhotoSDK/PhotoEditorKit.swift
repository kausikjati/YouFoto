//
//  PhotoEditorKit.swift
//  PhotoEditorKit SDK — Core Entry Point
//
//  A modern, AI-powered photo editing SDK for iOS 17+
//  Features agentic AI, batch processing, and liquid glass UI
//

import SwiftUI
import Combine
import Photos
import CoreImage
import Vision
import ImageIO
import UniformTypeIdentifiers

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PhotoEditorKit Main Class
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
public class PhotoEditorKit: ObservableObject {
    public nonisolated let objectWillChange = ObservableObjectPublisher()

    
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
            let generatedName = naming.generate(index: i, original: img.metadata.filename)
            let filename = generatedName.replacingOccurrences(of: ".png", with: "") + format.fileExtension
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

            guard let data = img.current.data(for: format, quality: quality) else { continue }
            try data.write(to: url)
            urls.append(url)
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
// MARK: - Core SDK Types
// ─────────────────────────────────────────────────────────────────────────────

public struct BatchJob {
    public let images: [UIImage]
    public let operations: [EditOperation]

    public init(images: [UIImage], operations: [EditOperation]) {
        self.images = images
        self.operations = operations
    }
}

public struct ImageAnalysis {
    public var averageBrightness: CGFloat
    public var averageContrast: CGFloat
    public var hasFaces: Bool

    public init(averageBrightness: CGFloat, averageContrast: CGFloat, hasFaces: Bool) {
        self.averageBrightness = averageBrightness
        self.averageContrast = averageContrast
        self.hasFaces = hasFaces
    }
}

public enum EditOperation {
    case removeBackground
    case adjustBrightness(CGFloat)
    case adjustContrast(CGFloat)
    case adjustSaturation(CGFloat)
    case sharpen(intensity: CGFloat)
    case denoise(strength: CGFloat)
    case autoEnhance
}

@MainActor
public final class EditorAgent {
    public enum Style {
        case professional, natural, vibrant, moody
    }

    public weak var editor: PhotoEditorKit?
    public var style: Style = .natural
    public var aggressiveness: CGFloat = 0.5
    public var maintainConsistency = true
    public var learnFromEdits = true

    public init(config: EditorConfig) {
        self.learnFromEdits = config.learnFromEdits
    }

    public func configure(style: Style, aggressiveness: CGFloat, maintainConsistency: Bool, learnFromEdits: Bool) {
        self.style = style
        self.aggressiveness = aggressiveness
        self.maintainConsistency = maintainConsistency
        self.learnFromEdits = learnFromEdits
    }

    public func processCommand(_ command: String, images: [EditableImage]) async throws -> [ProcessingResult] {
        let lowered = command.lowercased()
        var operations: [EditOperation] = []

        if lowered.contains("bright") { operations.append(.adjustBrightness(0.12 + (aggressiveness * 0.08))) }
        if lowered.contains("contrast") { operations.append(.adjustContrast(0.1 + (aggressiveness * 0.1))) }
        if lowered.contains("saturat") || lowered.contains("vibrant") { operations.append(.adjustSaturation(0.1)) }
        if lowered.contains("sharpen") { operations.append(.sharpen(intensity: 0.5)) }
        if lowered.contains("denoise") || lowered.contains("noise") { operations.append(.denoise(strength: 0.5)) }
        if lowered.contains("background") { operations.append(.removeBackground) }

        if operations.isEmpty {
            operations = [.autoEnhance]
        }

        let processor = BatchProcessor()
        let job = BatchJob(images: images.map { $0.current }, operations: operations)
        return try await processor.process(job)
    }

    public func generateOperations(analyses: [ImageAnalysis], targetStyle: String?) async throws -> [[EditOperation]] {
        analyses.map { analysis in
            var operations: [EditOperation] = [.autoEnhance]
            if analysis.averageBrightness < 0.45 { operations.append(.adjustBrightness(0.12)) }
            if analysis.averageContrast < 0.45 { operations.append(.adjustContrast(0.1)) }
            if let targetStyle, targetStyle.lowercased().contains("vibrant") {
                operations.append(.adjustSaturation(0.12))
            }
            if analysis.hasFaces { operations.append(.sharpen(intensity: 0.25)) }
            return operations
        }
    }
}

public final class BatchProcessor {
    public var onProgress: ((ProcessingProgress) -> Void)?

    public init() {}

    public func process(_ job: BatchJob) async throws -> [ProcessingResult] {
        guard !job.images.isEmpty else { return [] }

        var results: [ProcessingResult] = []
        results.reserveCapacity(job.images.count)

        for (index, image) in job.images.enumerated() {
            let start = Date()
            do {
                let output = try Self.apply(operations: job.operations, to: image)
                results.append(ProcessingResult(
                    image: output,
                    operations: job.operations,
                    success: true,
                    processingTime: Date().timeIntervalSince(start)
                ))
            } catch {
                results.append(ProcessingResult(
                    image: image,
                    operations: job.operations,
                    success: false,
                    error: error,
                    processingTime: Date().timeIntervalSince(start)
                ))
            }

            onProgress?(ProcessingProgress(total: job.images.count, completed: index + 1, currentOperation: "Editing photos"))
        }

        return results
    }

    private static func apply(operations: [EditOperation], to image: UIImage) throws -> UIImage {
        var output = image
        for operation in operations {
            switch operation {
            case .adjustBrightness(let value):
                output = output.adjusted(brightness: value, contrast: 1, saturation: 1)
            case .adjustContrast(let value):
                output = output.adjusted(brightness: 0, contrast: 1 + value, saturation: 1)
            case .adjustSaturation(let value):
                output = output.adjusted(brightness: 0, contrast: 1, saturation: 1 + value)
            case .sharpen(let intensity):
                output = output.sharpened(intensity: intensity)
            case .denoise(let strength):
                output = output.noiseReduced(strength: strength)
            case .autoEnhance:
                output = output.autoEnhanced()
            case .removeBackground:
                continue
            }
        }
        return output
    }
}

public final class ImageAnalyzer {
    public init() {}

    public func analyze(_ image: UIImage) async throws -> ImageAnalysis {
        guard let ciImage = CIImage(image: image) else {
            return ImageAnalysis(averageBrightness: 0.5, averageContrast: 0.5, hasFaces: false)
        }

        let extent = ciImage.extent
        guard !extent.isEmpty else {
            return ImageAnalysis(averageBrightness: 0.5, averageContrast: 0.5, hasFaces: false)
        }

        let context = CIContext(options: nil)
        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = extent

        guard let output = filter.outputImage else {
            return ImageAnalysis(averageBrightness: 0.5, averageContrast: 0.5, hasFaces: false)
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        let brightness = (CGFloat(bitmap[0]) + CGFloat(bitmap[1]) + CGFloat(bitmap[2])) / (3 * 255)
        return ImageAnalysis(averageBrightness: brightness, averageContrast: 0.5, hasFaces: false)
    }
}

private extension ImageFormat {
    var fileExtension: String {
        switch self {
        case .png: return ".png"
        case .jpeg: return ".jpg"
        case .heic: return ".heic"
        }
    }
}

private extension UIImage {
    func data(for format: ImageFormat, quality: CGFloat) -> Data? {
        switch format {
        case .png:
            return pngData()
        case .jpeg:
            return jpegData(compressionQuality: quality)
        case .heic:
            if #available(iOS 11.0, *), let cg = cgImage {
                let data = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(data, UTType.heic.identifier as CFString, 1, nil) else {
                    return jpegData(compressionQuality: quality)
                }
                CGImageDestinationAddImage(destination, cg, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
                guard CGImageDestinationFinalize(destination) else { return nil }
                return data as Data
            }
            return jpegData(compressionQuality: quality)
        }
    }

    func adjusted(brightness: CGFloat, contrast: CGFloat, saturation: CGFloat) -> UIImage {
        guard let ci = CIImage(image: self) else { return self }
        let filter = CIFilter.colorControls()
        filter.inputImage = ci
        filter.brightness = Float(brightness)
        filter.contrast = Float(contrast)
        filter.saturation = Float(saturation)
        return Self.render(filter.outputImage) ?? self
    }

    func sharpened(intensity: CGFloat) -> UIImage {
        guard let ci = CIImage(image: self) else { return self }
        let filter = CIFilter.sharpenLuminance()
        filter.inputImage = ci
        filter.sharpness = Float(max(0, intensity * 2))
        return Self.render(filter.outputImage) ?? self
    }

    func noiseReduced(strength: CGFloat) -> UIImage {
        guard let ci = CIImage(image: self) else { return self }
        let filter = CIFilter.noiseReduction()
        filter.inputImage = ci
        filter.noiseLevel = Float(max(0, min(0.1, strength * 0.1)))
        filter.sharpness = 0.4
        return Self.render(filter.outputImage) ?? self
    }

    func autoEnhanced() -> UIImage {
        guard let ci = CIImage(image: self) else { return self }
        let adjusted = ci.autoAdjustmentFilters().reduce(ci) { current, filter in
            filter.setValue(current, forKey: kCIInputImageKey)
            return filter.outputImage ?? current
        }
        return Self.render(adjusted) ?? self
    }

    private static func render(_ ciImage: CIImage?) -> UIImage? {
        guard let ciImage else { return nil }
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
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
