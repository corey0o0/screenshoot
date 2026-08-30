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

    /// OCR용 이미지는 원본 해상도로 받는다.
    ///
    /// 예전에는 1024x1024에 맞춰 넘겨서 1179x2556 스크린샷이 40%로 줄어들었다.
    /// OCRBenchmarkTests로 측정한 축소의 대가(합성 이미지, 본문 46px 기준):
    ///   100% → CER 0.0% / 60% → 0.0% / 40% → 0.6% / 25% → 2.5% (조각 1개 유실)
    /// 극적이진 않지만 분명히 손해이고, 스크린샷 한 장은 원본으로 처리해도
    /// 메모리·시간 부담이 크지 않아 원본을 쓴다.
    /// 실제 스크린샷은 합성 이미지보다 조건이 나쁘므로 격차는 더 클 수 있다.
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
