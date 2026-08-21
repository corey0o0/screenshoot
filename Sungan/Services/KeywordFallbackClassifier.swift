import Foundation

/// Apple Foundation Models를 지원하지 않는 기기(A17 Pro 미만)를 위한 키워드 매칭 폴백.
struct KeywordFallbackClassifier: ClassificationEngine {
    private let sensitiveDetector = SensitiveInfoDetector()

    private let categoryKeywords: [ScreenshotCategory: [String]] = [
        .chat: ["카톡", "카카오톡", "메시지", "채팅", "읽음", "안읽음", "문자"],
        .shopping: ["주문", "배송", "결제", "장바구니", "쿠팡", "네이버페이", "할인", "구매"],
        .map: ["지도", "길찾기", "도보", "분 소요", "카카오맵", "네이버지도", "출발", "도착"],
        .document: ["회의", "보고서", "계약", "일정", "공지", "안내문"],
        .socialMedia: ["좋아요", "팔로우", "댓글", "인스타그램", "instagram", "리트윗", "리그램", "스토리"]
    ]

    func classify(ocrText: String) async -> ScreenshotClassification {
        let trimmed = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isTextType = trimmed.count >= 8

        var bestCategory: ScreenshotCategory = .etc
        var bestScore = 0
        for (category, keywords) in categoryKeywords {
            let score = keywords.reduce(0) { trimmed.contains($1) ? $0 + 1 : $0 }
            if score > bestScore {
                bestScore = score
                bestCategory = category
            }
        }
        if bestScore == 0 {
            bestCategory = isTextType ? .document : .imageOrPhoto
        }

        return ScreenshotClassification(
            category: bestCategory,
            isTextType: isTextType,
            isSensitive: sensitiveDetector.containsSensitiveInfo(in: trimmed)
        )
    }
}
