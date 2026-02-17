import SwiftUI
import Photos
import UIKit
import AVFoundation

struct ContentView: View {
    @State private var columnCount = 4
    private let minCols = 2
    private let maxCols = 10
    @State private var pinchBase = 4
    @State private var isPinching = false

    @State private var mediaFilter: MediaFilter = .photos
    @State private var albumFilter: AlbumFilter = .all

    @State private var selectedAsset: PHAsset? = nil
    @State private var isSelectionMode = false
    @State private var selectedAssetIDs: Set<String> = []

    @State private var fetchResult: PHFetchResult<PHAsset> = PHFetchResult()
    @State private var imageManager = PHCachingImageManager()
    @State private var authStatus: PHAuthorizationStatus = .notDetermined
    @State private var shareItems: [Any] = []
    @State private var isShareSheetPresented = false
    @State private var editorAssets: [PHAsset] = []
    @State private var isEditorPresented = false

    @Namespace private var filterNS
    @Namespace private var albumNS

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                gridContent
                    .navigationTitle("Library")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { mediaFilterToolbar }
                    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: bottomInsetHeight)
                    }

                if mediaFilter == .photos {
                    AlbumTabBar(selected: $albumFilter, ns: albumNS)
                        .padding(.bottom, 10)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }

                if isSelectionMode {
                    selectionBottomBar
                        .padding(.horizontal, 20)
                        .padding(.bottom, mediaFilter == .photos ? 78 : 14)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(2)
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.76), value: mediaFilter)
            .animation(.spring(response: 0.3, dampingFraction: 0.82), value: isSelectionMode)
            .onAppear(perform: setupPhotos)
            .onChange(of: mediaFilter) { _, _ in
                if isSelectionMode {
                    isSelectionMode = false
                    selectedAssetIDs.removeAll()
                }
                loadAssets()
            }
            .onChange(of: albumFilter) { _, _ in loadAssets() }
        }
        .fullScreenCover(item: $selectedAsset) { asset in
            MediaDetailView(asset: asset, imageManager: imageManager)
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ShareSheet(activityItems: shareItems)
        }
        .fullScreenCover(isPresented: $isEditorPresented) {
            PhotoEditorView(assets: editorAssets, imageManager: imageManager)
        }
    }

    @ViewBuilder
    private var gridContent: some View {
        switch authStatus {
        case .authorized, .limited:
            PhotoGridView(
                fetchResult: fetchResult,
                imageManager: imageManager,
                columnCount: columnCount,
                isSelectionMode: $isSelectionMode,
                selectedAssetIDs: $selectedAssetIDs,
                onTap: { selectedAsset = $0 }
            )
            .gesture(pinchGesture, including: isSelectionMode ? .none : .all)

        case .denied, .restricted:
            VStack(spacing: 20) {
                Image(systemName: "lock.photo.fill")
                    .font(.system(size: 56)).foregroundStyle(.secondary)
                Text("Photos Access Required").font(.title2.bold())
                Text("Allow access in Settings › Privacy › Photos.")
                    .font(.subheadline).multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)

        default:
            ProgressView("Requesting access…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ToolbarContentBuilder
    private var mediaFilterToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 8) {
                ForEach(MediaFilter.allCases) { filter in
                    let isSelected = mediaFilter == filter
                    Button {
                        mediaFilter = filter
                    } label: {
                        Image(systemName: filter.icon)
                            .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(
                        isSelected
                            ? .regular.tint(Color.accentColor.opacity(0.30)).interactive()
                            : .regular.interactive(),
                        in: Capsule()
                    )
                    .glassEffectID(filter.id, in: filterNS)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSelectionMode.toggle()
                        if !isSelectionMode {
                            selectedAssetIDs.removeAll()
                        }
                    }
                } label: {
                    Text(isSelectionMode ? "Done" : "Select")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelectionMode ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .glassEffect(
                    isSelectionMode
                        ? .regular.tint(Color.accentColor.opacity(0.45)).interactive()
                        : .regular.interactive(),
                    in: Capsule()
                )
            }
        }

    }

    private var bottomInsetHeight: CGFloat {
        let albumHeight = mediaFilter == .photos ? 110.0 : 0.0
        let selectionHeight = isSelectionMode ? 88.0 : 0.0
        return albumHeight + selectionHeight
    }

    private var selectionBottomBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                selectionCountChip

                Spacer(minLength: 0)

                if !selectedAssetIDs.isEmpty {
                    selectionIconButton(systemName: "square.and.arrow.up") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task { await presentShareSheet() }
                    }
                    .accessibilityLabel("Share")

                    if mediaFilter == .photos {
                        selectionIconButton(systemName: editActionIcon) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            presentEditor()
                        }
                        .accessibilityLabel(editActionLabel)
                    }
                }

                selectionIconButton(systemName: "xmark") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.88)) {
                        selectedAssetIDs.removeAll()
                    }
                }
                .accessibilityLabel("Clear selection")

            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .onTapGesture { }
        }
    }

    private var selectionCountChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))

            Text("\(selectedAssetIDs.count)")
                .font(.system(size: 17, weight: .bold).monospacedDigit())
                .contentTransition(.numericText())
                .animation(.spring(response: 0.22, dampingFraction: 0.9), value: selectedAssetIDs.count)

            Text("selected")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: Capsule())
    }

    private var editActionIcon: String {
        mediaFilter == .photos ? "slider.horizontal.3" : "film.stack"
    }

    private var editActionLabel: String {
        mediaFilter == .photos ? "Edit photos" : "Edit videos"
    }

    private func selectionIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .disabled(selectedAssetIDs.isEmpty)
        .opacity(selectedAssetIDs.isEmpty ? 0.45 : 1)
        .glassEffect(.regular.interactive(), in: Circle())
    }

    private func presentShareSheet() async {
        let assets = selectedAssetsInCurrentOrder()
        guard !assets.isEmpty else { return }

        var resolvedItems: [Any] = []
        for asset in assets {
            if let item = await shareItem(for: asset) {
                resolvedItems.append(item)
            }
        }

        guard !resolvedItems.isEmpty else { return }
        await MainActor.run {
            shareItems = resolvedItems
            isShareSheetPresented = true
        }
    }

    private func selectedAssetsInCurrentOrder() -> [PHAsset] {
        var assets: [PHAsset] = []
        for index in 0..<fetchResult.count {
            let asset = fetchResult.object(at: index)
            if selectedAssetIDs.contains(asset.localIdentifier) {
                assets.append(asset)
            }
        }
        return assets
    }

    private func shareItem(for asset: PHAsset) async -> Any? {
        if asset.mediaType == .video {
            return await videoShareURL(for: asset)
        }
        return await photoShareURL(for: asset)
    }

    private func photoShareURL(for asset: PHAsset) async -> URL? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .none
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                guard let data else {
                    continuation.resume(returning: nil)
                    return
                }

                let resource = PHAssetResource.assetResources(for: asset).first
                let filename = resource?.originalFilename ?? "photo_\(asset.localIdentifier).jpg"
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + "_" + filename)

                do {
                    try data.write(to: destination, options: .atomic)
                    continuation.resume(returning: destination)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func videoShareURL(for asset: PHAsset) async -> URL? {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    continuation.resume(returning: urlAsset.url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func presentEditor() {
        let photos = selectedAssetsInCurrentOrder().filter { $0.mediaType == .image }
        guard !photos.isEmpty else { return }
        editorAssets = photos
        isEditorPresented = true
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                if !isPinching { pinchBase = columnCount; isPinching = true }
                let updated = Int((CGFloat(pinchBase) / scale).rounded()).clamped(to: minCols...maxCols)
                if updated != columnCount {
                    columnCount = updated
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            .onEnded { scale in
                columnCount = Int((CGFloat(pinchBase) / scale).rounded()).clamped(to: minCols...maxCols)
                isPinching = false
            }
    }

    private func setupPhotos() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authStatus = status
        switch status {
        case .authorized, .limited:
            loadAssets()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { st in
                DispatchQueue.main.async {
                    self.authStatus = st
                    if st == .authorized || st == .limited { self.loadAssets() }
                }
            }
        default:
            break
        }
    }

    private func loadAssets() {
        imageManager.stopCachingImagesForAllAssets()

        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        opts.predicate = mediaFilter == .photos
            ? NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            : NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)

        switch albumFilter {
        case .all:
            fetchResult = PHAsset.fetchAssets(with: opts)
        case .camera:
            if let c = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil
            ).firstObject {
                fetchResult = PHAsset.fetchAssets(in: c, options: opts)
            } else {
                fetchResult = PHFetchResult()
            }
        case .screenshots:
            if let c = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil
            ).firstObject {
                fetchResult = PHAsset.fetchAssets(in: c, options: opts)
            } else {
                fetchResult = PHFetchResult()
            }
        }
    }
}

#Preview { ContentView() }

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

