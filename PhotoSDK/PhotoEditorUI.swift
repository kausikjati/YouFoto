//
//  PhotoEditorUI.swift
//  PhotoEditorKit UI — iOS 26 glass-style editor experience
//

import SwiftUI
import PhotosUI
import UIKit

public struct PhotoEditorView: View {
    @ObservedObject public var editor: PhotoEditorKit

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var activeIndex: Int = 0
    @State private var selectedTool: EditorTool = .adjust
    @State private var showEffectsPanel = false
    @State private var isSaving = false

    public init(editor: PhotoEditorKit) {
        self.editor = editor
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if editor.images.isEmpty {
                emptyState
            } else {
                editorCanvas
            }
        }
        .sheet(isPresented: $showEffectsPanel) {
            EffectsPanel(editor: editor)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedPhotos) { _, items in
            loadImages(items)
        }
        .onChange(of: editor.images.count) { _, count in
            activeIndex = min(activeIndex, max(0, count - 1))
            syncSelectionWithActiveIndex()
        }
        .task(id: editor.images.count) {
            if !editor.images.isEmpty {
                syncSelectionWithActiveIndex()
            }
        }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 22) {
            Image(systemName: "photo.stack")
                .font(.system(size: 72))
                .foregroundStyle(.white.opacity(0.85))

            Text("Start editing")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("Pick photos to open the new glass photo editor")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 100, matching: .images) {
                Label("Select Photos", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(Color.accentColor.opacity(0.35)).interactive(), in: Capsule())

            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Capsule())
        }
        .padding(24)
    }

    // MARK: Main editor

    private var editorCanvas: some View {
        VStack(spacing: 14) {
            topBar

            selectedImagesHeader

            imageStage
                .padding(.horizontal, 14)

            middleActionBar

            bottomToolBar
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        .foregroundStyle(.white)
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            iconButton(systemName: "chevron.left") { dismiss() }

            iconButton(systemName: "arrow.uturn.backward") {
                editor.undo()
            }

            Spacer(minLength: 6)

            Button("Revert") {
                guard !editor.images.isEmpty else { return }
                editor.selectedIndices = [activeIndex]
                editor.reset()
                syncSelectionWithActiveIndex()
            }
            .foregroundStyle(.white)
            .font(.title3.weight(.semibold))
            .buttonStyle(.plain)

            Button(isSaving ? "Saving…" : "Save") {
                saveCurrentEdits()
            }
            .disabled(isSaving)
            .foregroundStyle(.white)
            .font(.title3.weight(.bold))
            .buttonStyle(.plain)

            Menu {
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 100, matching: .images) {
                    Label("Add photos", systemImage: "plus")
                }
                Button("Save to Photos") { saveCurrentEdits() }
                Button("Export files") { exportAll() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private var selectedImagesHeader: some View {
        VStack(spacing: 10) {
            Text("selected images")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.red.opacity(0.85))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.red.opacity(0.85), lineWidth: 1)
                }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(editor.images.enumerated()), id: \.element.id) { idx, item in
                        Button {
                            activeIndex = idx
                            syncSelectionWithActiveIndex()
                        } label: {
                            Image(uiImage: item.current)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(activeIndex == idx ? Color.yellow : Color.white.opacity(0.2), lineWidth: 2)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
            }
        }
    }

    private var imageStage: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))

                if let image = editor.images[safe: activeIndex]?.current {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size - 8, height: size - 8)
                }

                GridOverlay(lineColor: .black.opacity(0.22), columns: 3, rows: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .frame(width: size, height: size)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: 470)
    }

    private var middleActionBar: some View {
        HStack(spacing: 18) {
            floatingActionIcon("chevron.left.slash.chevron.right") { }
            floatingActionIcon("doc.on.doc") { }
            floatingActionIcon("arrow.up.left.and.arrow.down.right") { }
            floatingActionIcon("rotate.3d") { }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: Capsule())
    }

    private var bottomToolBar: some View {
        HStack(spacing: 24) {
            ForEach(EditorTool.allCases) { tool in
                Button {
                    selectedTool = tool
                    if tool == .effects {
                        showEffectsPanel = true
                    } else if tool == .adjust {
                        editor.selectedIndices = [activeIndex]
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tool.icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(selectedTool == tool ? .yellow : .white.opacity(0.92))
                        Text(tool.title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(selectedTool == tool ? .yellow : .white.opacity(0.7))
                    }
                    .frame(width: 54)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: Actions

    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }

    private func floatingActionIcon(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
    }

    private func syncSelectionWithActiveIndex() {
        guard editor.images.indices.contains(activeIndex) else { return }
        editor.selectedIndices = [activeIndex]
    }

    private func saveCurrentEdits() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            try? await editor.saveToPhotos()
            await MainActor.run {
                isSaving = false
            }
        }
    }

    private func exportAll() {
        Task {
            _ = try? await editor.export(format: .jpeg, quality: 0.95, naming: .timestamp("photoedit-"))
        }
    }

    private func loadImages(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run { editor.addImage(image) }
                }
            }
        }
    }
}

private enum EditorTool: String, CaseIterable, Identifiable {
    case crop
    case effects
    case adjust
    case retouch
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .crop: return "Crop"
        case .effects: return "Effects"
        case .adjust: return "Light"
        case .retouch: return "Retouch"
        case .more: return "More"
        }
    }

    var icon: String {
        switch self {
        case .crop: return "crop"
        case .effects: return "camera.filters"
        case .adjust: return "sun.max"
        case .retouch: return "face.smiling"
        case .more: return "circle.grid.2x2"
        }
    }
}

private struct GridOverlay: View {
    let lineColor: Color
    let columns: Int
    let rows: Int

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let width = geo.size.width
                let height = geo.size.height

                guard columns > 0, rows > 0 else { return }

                for column in 1..<columns {
                    let x = width * CGFloat(column) / CGFloat(columns)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }

                for row in 1..<rows {
                    let y = height * CGFloat(row) / CGFloat(rows)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(lineColor, lineWidth: 0.7)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Effects Panel

struct EffectsPanel: View {
    @ObservedObject var editor: PhotoEditorKit
    @Environment(\.dismiss) private var dismiss

    @State private var brightness: CGFloat = 0
    @State private var contrast: CGFloat = 0
    @State private var saturation: CGFloat = 0
    @State private var sharpness: CGFloat = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    quickActions
                    adjustmentsSection
                }
                .padding(16)
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
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickActionButton(title: "Auto Enhance", icon: "wand.and.stars") { applyOperation(.autoEnhance) }
                QuickActionButton(title: "Remove BG", icon: "person.crop.circle.badge.minus") { applyOperation(.removeBackground) }
                QuickActionButton(title: "Sharpen", icon: "triangle") { applyOperation(.sharpen(intensity: 0.5)) }
                QuickActionButton(title: "Denoise", icon: "camera.filters") { applyOperation(.denoise(strength: 0.5)) }
            }
        }
    }

    private var adjustmentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Adjustments")
                .font(.headline)
                .foregroundStyle(.secondary)

            AdjustmentSlider(title: "Brightness", icon: "sun.max", value: $brightness, range: -1...1)
            AdjustmentSlider(title: "Contrast", icon: "circle.lefthalf.filled", value: $contrast, range: -1...1)
            AdjustmentSlider(title: "Saturation", icon: "paintpalette", value: $saturation, range: -1...1)
            AdjustmentSlider(title: "Sharpness", icon: "triangle", value: $sharpness, range: 0...1)
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
                let targetImages = editor.selectedImages.isEmpty
                    ? editor.images.map { $0.current }
                    : editor.selectedImages.map { $0.current }
                try? await editor.processBatch(BatchJob(images: targetImages, operations: operations))
            }
            dismiss()
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: range)
                .tint(.accentColor)
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
