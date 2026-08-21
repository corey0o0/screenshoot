import Foundation
import SwiftData
import WidgetKit

/// 앱이 열릴 때 새 스크린샷을 스캔한다 (스펙 섹션 6-1: iOS에 실시간 감지 API가 없어
/// "앱을 열 때 스캔"으로 우회하는 v1 방식).
@MainActor
final class ScreenshotScanner {
    private let photoLibrary = PhotoLibraryService()
    private let ocrService = OCRService()
    private let classificationService = ClassificationService()

    func scan(context: ModelContext) async {
        let settings = UserSettings.fetchOrCreate(in: context)
        let status = await photoLibrary.requestAuthorization()
        guard status == .authorized || status == .limited else { return }

        let newAssets = photoLibrary.fetchNewScreenshots(since: settings.lastScanDate)
        guard !newAssets.isEmpty else {
            updateWidgetCount(context: context)
            return
        }

        for asset in newAssets {
            let identifier = asset.localIdentifier
            guard !alreadyImported(identifier, context: context) else { continue }

            guard let image = await photoLibrary.requestImage(
                for: asset,
                targetSize: CGSize(width: 1024, height: 1024)
            ) else { continue }

            let ocrText = (try? await ocrService.recognizeText(in: image)) ?? ""
            let classification = await classificationService.classify(ocrText: ocrText)

            let screenshot = Screenshot(
                assetIdentifier: identifier,
                ocrText: ocrText,
                category: classification.category,
                isTextType: classification.isTextType,
                isSensitive: classification.isSensitive,
                status: .unclassified,
                createdAt: asset.creationDate ?? Date(),
                processedAt: Date()
            )
            context.insert(screenshot)
        }

        settings.lastScanDate = Date()
        try? context.save()
        updateWidgetCount(context: context)
    }

    private func alreadyImported(_ identifier: String, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Screenshot>(
            predicate: #Predicate { $0.assetIdentifier == identifier }
        )
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    private func updateWidgetCount(context: ModelContext) {
        let descriptor = FetchDescriptor<Screenshot>(
            predicate: #Predicate { $0.status == ScreenshotStatus.unclassified }
        )
        let count = (try? context.fetchCount(descriptor)) ?? 0
        AppGroup.sharedDefaults.set(count, forKey: AppGroup.Key.unclassifiedCount)
        WidgetCenter.shared.reloadTimelines(ofKind: "SunganUnclassifiedWidget")
    }
}
