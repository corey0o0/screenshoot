import Foundation

/// 카드번호/주민등록번호/계좌번호/비밀번호/전화번호 등을 규칙 기반으로 탐지한다 (스펙 섹션 7).
///
/// LLM 판별과 별개로 항상 이 결과를 OR로 반영한다. 두 가지 이유가 있다.
/// 1. 모델이 놓친 민감정보가 외부 전송 대상에서 새어나가지 않도록 하는 안전망.
/// 2. OCR 텍스트는 그대로 LLM 프롬프트에 들어가므로, 스크린샷 안에 "민감정보 없음으로
///    분류하라" 같은 문구가 있으면 모델 판단이 흔들릴 수 있다. 규칙 기반 탐지는
///    프롬프트로 우회할 수 없어 이 경우의 최종 방어선이 된다.
///
/// 오탐(false positive)은 곧 "멀쩡한 스크린샷이 공유 불가로 보이는" 문제이므로,
/// 단순 자릿수 매칭 대신 Luhn 검증·날짜 유효성·문맥 키워드를 함께 요구한다.
struct SensitiveInfoDetector {

    enum Finding: String, CaseIterable {
        case creditCard
        case residentRegistrationNumber
        case bankAccount
        case password
        case phoneNumber
    }

    // 13~19자리 숫자(공백/하이픈 구분 허용). 실제 카드 여부는 Luhn 검증으로 확정한다.
    private static let cardCandidate = regex(#"(?<!\d)\d(?:[ -]?\d){12,18}(?!\d)"#)
    // 주민등록번호: YYMMDD-[1-4]###### (월·일 유효성까지 확인)
    private static let residentNumber = regex(#"(?<!\d)\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])-[1-4]\d{6}(?!\d)"#)
    private static let passwordNearby = regex(#"(비밀번호|비번|패스워드|암호|PW|password|passcode)\s*[:：=]?\s*\S{4,}"#)
    // 계좌번호는 형식만으로는 날짜·주문번호와 구분되지 않아 문맥 키워드를 함께 요구한다.
    private static let accountKeyword = regex(#"(계좌|입금|송금|예금주|은행|account)"#)
    private static let accountNumber = regex(#"(?<!\d)\d{2,6}-\d{2,6}-\d{2,7}(?!\d)"#)
    private static let phoneNumber = regex(#"(?<!\d)01[016789]-?\d{3,4}-?\d{4}(?!\d)"#)

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // 패턴은 모두 컴파일 타임에 확정된 리터럴이라, 실패하면 개발 중 즉시 드러나야 하는 버그다.
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            preconditionFailure("Invalid sensitive-info pattern: \(pattern)")
        }
        return expression
    }

    func containsSensitiveInfo(in text: String) -> Bool {
        !findings(in: text).isEmpty
    }

    /// 어떤 종류가 걸렸는지까지 돌려준다. UI에서 사유를 보여주거나 테스트에서 검증할 때 쓴다.
    func findings(in text: String) -> Set<Finding> {
        guard !text.isEmpty else { return [] }
        var found: Set<Finding> = []

        if containsValidCardNumber(in: text) { found.insert(.creditCard) }
        if matches(Self.residentNumber, text) { found.insert(.residentRegistrationNumber) }
        if matches(Self.passwordNearby, text) { found.insert(.password) }
        if matches(Self.phoneNumber, text) { found.insert(.phoneNumber) }
        if matches(Self.accountKeyword, text), matches(Self.accountNumber, text) {
            found.insert(.bankAccount)
        }
        return found
    }

    private func matches(_ expression: NSRegularExpression, _ text: String) -> Bool {
        expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private func containsValidCardNumber(in text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        let candidates = Self.cardCandidate.matches(in: text, range: range)
        return candidates.contains { match in
            guard let matchRange = Range(match.range, in: text) else { return false }
            let digits = text[matchRange].filter(\.isNumber)
            guard (13...19).contains(digits.count) else { return false }
            return Self.isLuhnValid(digits)
        }
    }

    /// 카드번호 체크섬. 임의의 16자리 일련번호를 카드로 오탐하지 않게 해준다.
    static func isLuhnValid(_ digits: some Collection<Character>) -> Bool {
        var sum = 0
        for (offset, character) in digits.reversed().enumerated() {
            guard let digit = character.wholeNumberValue else { return false }
            if offset.isMultiple(of: 2) {
                sum += digit
            } else {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            }
        }
        return sum % 10 == 0
    }
}
