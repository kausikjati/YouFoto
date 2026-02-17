import SwiftUI
import Photos

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
        let selectionHeight = isSelectionMode ? 84.0 : 0.0
        return albumHeight + selectionHeight
    }

    private var selectionBottomBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Label("\(selectedAssetIDs.count) selected", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: Capsule())

                Spacer(minLength: 0)

                Button("Clear") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.88)) {
                        selectedAssetIDs.removeAll()
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive(), in: Capsule())

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.88)) {
                        isSelectionMode = false
                        selectedAssetIDs.removeAll()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(Color.accentColor.opacity(0.34)).interactive(), in: Circle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
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
