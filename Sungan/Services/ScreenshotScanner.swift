import Foundation
import Photos
import SwiftData

/// 앱이 열릴 때 새 스크린샷을 스캔한다 (스펙 섹션 6-1: iOS에 실시간 감지 API가 없어
/// "앱을 열 때 스캔"으로 우회하는 v1 방식).
@MainActor
final class ScreenshotScanner {
    /// 한 번의 스캔에서 처리할 최대 장수.
    ///
    /// 첫 실행 때는 `lastScanDate`가 없어 보관함의 모든 스크린샷이 대상이 된다.
    /// 스크린샷이 수천 장인 사용자는 장당 (iCloud 다운로드 + OCR + 온디바이스 추론)이
    /// 누적되어 앱이 한참 멈춘 것처럼 보이고 배터리도 크게 소모된다.
    /// 최신 것부터 잘라서 처리하고 나머지는 다음 스캔으로 넘긴다.
    static let maxAssetsPerScan = 50

    enum Outcome: Equatable {
        case notAuthorized
        case completed(processed: Int, remaining: Int)
    }

    private let photoLibrary = PhotoLibraryService()
    private let ocrService = OCRService()
    private let classificationService = ClassificationService()

    @discardableResult
    func scan(context: ModelContext) async -> Outcome {
        let settings = UserSettings.fetchOrCreate(in: context)
        let status = await photoLibrary.requestAuthorization()
        guard status == .authorized || status == .limited else { return .notAuthorized }

        // 스캔 "시작" 시각을 기준으로 삼는다. 종료 시각을 쓰면 스캔이 도는 동안 찍힌
        // 스크린샷의 creationDate가 기준보다 앞서게 되어 영영 스캔되지 않는다.
        let scanStartedAt = Date()

        // 이미 담은 asset을 미리 걸러낸 뒤에 batch를 자른다. 걸러내지 않고 자르면
        // 백로그가 남았을 때 매번 같은 최신 50장만 다시 집어 진행이 멈춘다.
        let imported = importedIdentifiers(context: context)
        let pending = photoLibrary
            .fetchNewScreenshots(since: settings.lastScanDate)
            .filter { !imported.contains($0.localIdentifier) }

        // creationDate 오름차순이므로 suffix가 "가장 최근" 묶음이다.
        let batch = pending.suffix(Self.maxAssetsPerScan)
        let remaining = pending.count - batch.count

        var processed = 0
        for asset in batch {
            if Task.isCancelled { break }

            guard let image = await photoLibrary.requestImage(
                for: asset,
                targetSize: CGSize(width: 1024, height: 1024)
            ) else { continue }

            let ocrText = (try? await ocrService.recognizeText(in: image)) ?? ""
            let classification = await classificationService.classify(ocrText: ocrText)

            context.insert(Screenshot(
                assetIdentifier: asset.localIdentifier,
                ocrText: ocrText,
                category: classification.category,
                isTextType: classification.isTextType,
                isSensitive: classification.isSensitive,
                status: .unclassified,
                createdAt: asset.creationDate ?? Date(),
                processedAt: Date()
            ))
            processed += 1
        }

        // 백로그가 남아 있으면 기준 시각을 올리지 않는다. 올려버리면 아직 처리하지
        // 못한 과거 스크린샷이 통째로 건너뛰어진다. 다음 스캔이 위 필터를 통해
        // 그 다음 묶음을 집어간다.
        if remaining == 0 {
            settings.lastScanDate = scanStartedAt
        }

        try? context.save()
        UnclassifiedCountSync.refresh(context: context)
        return .completed(processed: processed, remaining: remaining)
    }

    /// 이미 저장된 assetIdentifier 집합. asset마다 fetchCount를 도는 것보다
    /// 한 번에 읽어 Set으로 비교하는 편이 훨씬 저렴하다.
    private func importedIdentifiers(context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<Screenshot>()
        let stored = (try? context.fetch(descriptor)) ?? []
        return Set(stored.map(\.assetIdentifier))
    }
}
