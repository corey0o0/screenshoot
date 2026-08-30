import Photos
import SwiftUI

struct ScreenshotRowView: View {
    let screenshot: Screenshot
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.secondary.opacity(0.15)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(screenshot.category.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                    if screenshot.isSensitive {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Text(screenshot.ocrText.isEmpty ? "텍스트 없음" : screenshot.ocrText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard thumbnail == nil else { return }
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [screenshot.assetIdentifier], options: nil)
        guard let asset = results.firstObject else { return }
        thumbnail = await PhotoLibraryService().requestImage(for: asset, targetSize: CGSize(width: 112, height: 112))
    }
}
