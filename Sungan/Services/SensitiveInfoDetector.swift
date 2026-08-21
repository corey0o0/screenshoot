import Foundation

/// 카드번호/계좌번호/비밀번호 근접 텍스트 등을 규칙 기반으로 탐지한다 (스펙 섹션 7).
/// LLM 판별과 별개로 항상 이 결과를 OR로 반영해, 모델이 놓친 민감정보가 외부 공유
/// 대상에서 새어나가지 않도록 한다.
struct SensitiveInfoDetector {
    private let patterns: [NSRegularExpression]

    init() {
        let rawPatterns = [
            #"\b(?:\d[ -]?){13,16}\b"#,
            #"(비밀번호|비번|패스워드|PW|password)\s*[:：]?\s*\S+"#,
            #"\b\d{2,6}-\d{2,6}-\d{2,6}\b"#,
            #"\b(?:19|20)\d{2}[01]\d[0-3]\d-[1-4]\d{6}\b"#
        ]
        self.patterns = rawPatterns.compactMap {
            try? NSRegularExpression(pattern: $0, options: [.caseInsensitive])
        }
    }

    func containsSensitiveInfo(in text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return patterns.contains { $0.firstMatch(in: text, range: range) != nil }
    }
}
