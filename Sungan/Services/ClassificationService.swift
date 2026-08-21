import Foundation

/// 기기 지원 여부에 따라 온디바이스 LLM 또는 키워드 폴백을 선택하고,
/// 민감정보 판단은 규칙 기반 탐지 결과와 항상 OR로 합쳐 누락 위험을 줄인다.
struct ClassificationService {
    private let sensitiveDetector = SensitiveInfoDetector()

    private var engine: ClassificationEngine {
        #if canImport(FoundationModels)
        if #available(iOS 18.1, *), FoundationModelsClassifier.isAvailable {
            return FoundationModelsClassifier()
        }
        #endif
        return KeywordFallbackClassifier()
    }

    func classify(ocrText: String) async -> ScreenshotClassification {
        var result = await engine.classify(ocrText: ocrText)
        result.isSensitive = result.isSensitive || sensitiveDetector.containsSensitiveInfo(in: ocrText)
        return result
    }
}
