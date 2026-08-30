import Foundation

#if canImport(FoundationModels)
import FoundationModels

// NOTE: Apple's on-device Foundation Models framework requires an Apple
// Intelligence–enabled device (A17 Pro/M-series or newer). The `iOS 18.1`
// gate below follows the spec's stated target; confirm the actual minimum
// OS version for `import FoundationModels` on your Xcode/SDK version and
// adjust this availability annotation (and the project deployment target)
// accordingly before shipping.
@available(iOS 18.1, *)
@Generable
struct FoundationModelsClassificationResult {
    @Guide(description: "스크린샷이 텍스트 위주(대화, 문서, 캡션)인지 여부. 사진/그림 위주면 false.")
    var isTextType: Bool

    @Guide(description: "다음 중 하나를 정확히 그대로 선택: 대화, 쇼핑, 지도/장소, 문서/자료, SNS, 이미지/사진, 기타")
    var category: String

    @Guide(description: "카드번호, 계좌번호, 비밀번호, 주민등록번호 등 민감정보가 포함되어 있는지 여부")
    var isSensitive: Bool
}

@available(iOS 18.1, *)
struct FoundationModelsClassifier: ClassificationEngine {
    static var isAvailable: Bool {
        switch SystemLanguageModel.default.availability {
        case .available:
            return true
        default:
            return false
        }
    }

    func classify(ocrText: String) async -> ScreenshotClassification {
        let fallback = KeywordFallbackClassifier()

        let trimmed = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ScreenshotClassification(category: .imageOrPhoto, isTextType: false, isSensitive: false)
        }
        guard Self.isAvailable else {
            return await fallback.classify(ocrText: ocrText)
        }

        do {
            let session = LanguageModelSession(instructions: """
            너는 사용자의 아이폰 스크린샷을 정리해주는 어시스턴트야.
            주어진 OCR 텍스트만 보고 스크린샷을 분류해. 텍스트가 거의 없으면 이미지형으로 판단해.
            카테고리는 반드시 다음 중 하나로만 답해: 대화, 쇼핑, 지도/장소, 문서/자료, SNS, 이미지/사진, 기타.
            """)
            let response = try await session.respond(
                to: "OCR 텍스트:\n\(trimmed)",
                generating: FoundationModelsClassificationResult.self
            )
            let category = ScreenshotCategory(displayName: response.content.category) ?? .etc
            return ScreenshotClassification(
                category: category,
                isTextType: response.content.isTextType,
                isSensitive: response.content.isSensitive
            )
        } catch {
            return await fallback.classify(ocrText: ocrText)
        }
    }
}
#endif
