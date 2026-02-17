//
//  PhotoEditorUI.swift
//  Complete UI implementation with iOS 26 Liquid Glass
//

import SwiftUI
import Photos
import PhotosUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Main Photo Editor View
// ─────────────────────────────────────────────────────────────────────────────

public struct PhotoEditorView: View {
    @ObservedObject public var editor: PhotoEditorKit
    
    @State private var showCommandBar = false
    @State private var showEffectsPanel = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    @Namespace private var effectNS
    
    public init(editor: PhotoEditorKit) {
        self.editor = editor
    }
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Main content
                if editor.images.isEmpty {
                    emptyState
                } else {
                    mainEditor
                }
                
                // Floating command bar
                if !editor.images.isEmpty {
                    commandBar
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Photo Editor")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .sheet(isPresented: $showEffectsPanel) {
                EffectsPanel(editor: editor)
            }
        }
        .onChange(of: selectedPhotos) { _, items in
            loadImages(items)
        }
    }
    
    // ── Empty State ───────────────────────────────────────────────────────────
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.stack")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            
            Text("Start Editing")
                .font(.system(size: 32, weight: .bold))
            
            Text("Select photos or drag and drop to begin")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 100,
                matching: .images
            ) {
                Label("Select Photos", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(Color.accentColor.opacity(0.3)).interactive(),
                         in: Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // ── Main Editor ───────────────────────────────────────────────────────────
    
    private var mainEditor: some View {
        GeometryReader { geo in
            ScrollView {
                LazyVGrid(
                    columns: columns(for: geo.size.width),
                    spacing: 12
                ) {
                    ForEach(Array(editor.images.enumerated()), id: \.element.id) { index, img in
                        ImageTile(
                            image: img,
                            isSelected: editor.selectedIndices.contains(index),
                            onTap: { toggleSelection(index) }
                        )
                    }
                }
                .padding()
            }
        }
    }
    
    private func columns(for width: CGFloat) -> [GridItem] {
        let count = max(2, Int(width / 200))
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }
    
    // ── Command Bar (AI Prompt) ───────────────────────────────────────────────
    
    @State private var commandText = ""
    
    private var commandBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                // AI prompt input
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.accentColor)
                    
                    TextField("Tell me what to do...", text: $commandText)
                        .textFieldStyle(.plain)
                        .submitLabel(.send)
                        .onSubmit { processCommand() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: Capsule())
                
                // Send button
                Button {
                    processCommand()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(commandText.isEmpty)
                .glassEffect(.regular.interactive(), in: Circle())
                
                // Effects button
                Button {
                    showEffectsPanel = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
            }
            .padding(.horizontal, 12)
        }
        .padding(.horizontal, 20)
    }
    
    // ── Toolbar ───────────────────────────────────────────────────────────────
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if !editor.images.isEmpty {
                Button {
                    clearAll()
                } label: {
                    Text("Clear")
                        .font(.body)
                }
            }
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            if !editor.images.isEmpty {
                Menu {
                    Button("Export All") { exportAll() }
                    Button("Save to Photos") { saveToPhotos() }
                    Divider()
                    Button("Undo") { editor.undo() }
                    Button("Reset") { editor.reset() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            } else {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 100,
                    matching: .images
                ) {
                    Image(systemName: "plus.circle")
                }
            }
        }
    }
    
    // ── Actions ───────────────────────────────────────────────────────────────
    
    private func toggleSelection(_ index: Int) {
        if editor.selectedIndices.contains(index) {
            editor.selectedIndices.remove(index)
        } else {
            editor.selectedIndices.insert(index)
        }
    }
    
    private func processCommand() {
        guard !commandText.isEmpty else { return }
        Task {
            do {
                try await editor.processCommand(commandText)
                commandText = ""
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    private func loadImages(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    editor.addImage(image)
                }
            }
        }
    }
    
    private func clearAll() {
        editor.clear()
        selectedPhotos.removeAll()
    }
    
    private func exportAll() {
        Task {
            _ = try? await editor.export()
        }
    }
    
    private func saveToPhotos() {
        Task {
            try? await editor.saveToPhotos()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Image Tile
// ─────────────────────────────────────────────────────────────────────────────

struct ImageTile: View {
    let image: EditableImage
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image.current)
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.clear,
                            lineWidth: 3
                        )
                }
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.accentColor))
                    .padding(8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Effects Panel
// ─────────────────────────────────────────────────────────────────────────────

struct EffectsPanel: View {
    @ObservedObject var editor: PhotoEditorKit
    @Environment(\.dismiss) private var dismiss
    
    @State private var brightness: CGFloat = 0
    @State private var contrast: CGFloat = 0
    @State private var saturation: CGFloat = 0
    @State private var sharpness: CGFloat = 0
    
    @Namespace private var tabNS
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Quick Actions
                    quickActions
                    
                    // Adjustments
                    adjustmentsSection
                }
                .padding()
            }
            .navigationTitle("Effects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") { applyEffects() }
                        .fontWeight(.semibold)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
    }
    
    // ── Quick Actions ─────────────────────────────────────────────────────────
    
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionButton(
                    title: "Auto Enhance",
                    icon: "wand.and.stars",
                    action: { applyOperation(.autoEnhance) }
                )
                
                QuickActionButton(
                    title: "Remove BG",
                    icon: "person.crop.circle.badge.minus",
                    action: { applyOperation(.removeBackground) }
                )
                
                QuickActionButton(
                    title: "Sharpen",
                    icon: "triangle",
                    action: { applyOperation(.sharpen(intensity: 0.5)) }
                )
                
                QuickActionButton(
                    title: "Denoise",
                    icon: "camera.filters",
                    action: { applyOperation(.denoise(strength: 0.5)) }
                )
            }
        }
    }
    
    // ── Adjustments ───────────────────────────────────────────────────────────
    
    private var adjustmentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Adjustments")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 20) {
                AdjustmentSlider(
                    title: "Brightness",
                    icon: "sun.max",
                    value: $brightness,
                    range: -1...1
                )
                
                AdjustmentSlider(
                    title: "Contrast",
                    icon: "circle.lefthalf.filled",
                    value: $contrast,
                    range: -1...1
                )
                
                AdjustmentSlider(
                    title: "Saturation",
                    icon: "paintpalette",
                    value: $saturation,
                    range: -1...1
                )
                
                AdjustmentSlider(
                    title: "Sharpness",
                    icon: "triangle",
                    value: $sharpness,
                    range: 0...1
                )
            }
        }
    }
    
    private func applyOperation(_ operation: EditOperation) {
        Task {
            try? await editor.applyOperation(operation)
            dismiss()
        }
    }
    
    private func applyEffects() {
        Task {
            var operations: [EditOperation] = []
            if brightness != 0 { operations.append(.adjustBrightness(brightness)) }
            if contrast != 0 { operations.append(.adjustContrast(contrast)) }
            if saturation != 0 { operations.append(.adjustSaturation(saturation)) }
            if sharpness != 0 { operations.append(.sharpen(intensity: sharpness)) }
            
            if !operations.isEmpty {
                try? await editor.processBatch(
                    BatchJob(
                        images: editor.selectedImages.map { $0.current },
                        operations: operations
                    )
                )
            }
            dismiss()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - UI Components
// ─────────────────────────────────────────────────────────────────────────────

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct AdjustmentSlider: View {
    let title: String
    let icon: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            
            Slider(value: $value, in: range)
                .tint(Color.accentColor)
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }
}
