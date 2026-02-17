import SwiftUI
import Photos

struct PhotoEditorView: View {
    let assets: [PHAsset]
    let imageManager: PHCachingImageManager

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex = 0

    var body: some View {
        NavigationStack {
            Group {
                if assets.isEmpty {
                    ContentUnavailableView("No Photos", systemImage: "photo", description: Text("Select at least one photo to edit."))
                } else {
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                            EditorPreviewCell(asset: asset, imageManager: imageManager)
                                .tag(index)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 14)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Photo Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(assets.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .glassEffect(.regular, in: Capsule())
                }
            }
        }
    }
}

private struct EditorPreviewCell: View {
    let asset: PHAsset
    let imageManager: PHCachingImageManager

    @State private var image: UIImage?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.black)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                ProgressView().tint(.white)
            }
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                Text("SDK editor ready point")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: Capsule())
            .padding(.bottom, 16)
        }
        .task(id: asset.localIdentifier) {
            await loadImage()
        }
    }

    private func loadImage() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true

        let width = UIScreen.main.bounds.width * displayScale
        let height = UIScreen.main.bounds.height * displayScale
        let targetSize = CGSize(width: width, height: height)

        await withCheckedContinuation { continuation in
            var resumed = false
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { img, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if let img {
                    image = img
                }

                if !resumed, (!isDegraded || img != nil) {
                    resumed = true
                    continuation.resume()
                }
            }
        }
    }
}
