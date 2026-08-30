import Photos
import UIKit
import os

struct PhotoLibraryService {
    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    /// PHAsset.mediaSubtypes로 스크린샷만 필터링 (스펙 섹션 3).
    func fetchNewScreenshots(since date: Date?) -> [PHAsset] {
        var predicates = [NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )]
        if let date {
            predicates.append(NSPredicate(format: "creationDate > %@", date as NSDate))
        }

        let options = PHFetchOptions()
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        var assets: [PHAsset] = []
        PHAsset.fetchAssets(with: .image, options: options).enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    /// OCR용 이미지. 축소하면 글자 높이가 그대로 줄어 인식률이 급격히 떨어지므로
    /// 원본 해상도를 그대로 받는다. (1179x2556 스크린샷을 1024에 맞춰 넣으면
    /// 40% 크기가 되어 32px 본문이 13px이 된다.)
    func requestImageForOCR(for asset: PHAsset) async -> UIImage? {
        await requestImage(for: asset, targetSize: PHImageManagerMaximumSize)
    }

    func requestImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let resumeLock = OSAllocatedUnfairLock(initialState: false)
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                // requestImage's handler can fire more than once (degraded + final image);
                // guard against resuming the continuation twice, which would crash.
                let shouldResume = resumeLock.withLock { resumed -> Bool in
                    guard !resumed else { return false }
                    resumed = true
                    return true
                }
                if shouldResume {
                    continuation.resume(returning: image)
                }
            }
        }
    }
}
