import XCTest
@testable import Sungan

/// 민감정보 탐지는 프라이버시 원칙(스펙 섹션 7)의 마지막 방어선이라 양방향으로 검증한다.
/// - 놓치면(false negative) 민감정보가 그대로 노출된다.
/// - 과하게 잡으면(false positive) 멀쩡한 스크린샷이 전부 경고를 달고 나와 경고 자체가 무시된다.
final class SensitiveInfoDetectorTests: XCTestCase {
    private let detector = SensitiveInfoDetector()

    // MARK: - 탐지되어야 하는 것

    func testDetectsLuhnValidCardNumber() {
        XCTAssertTrue(detector.containsSensitiveInfo(in: "4111 1111 1111 1111"))
        XCTAssertTrue(detector.containsSensitiveInfo(in: "5500-0000-0000-0004 결제완료"))
    }

    func testDetectsResidentRegistrationNumber() {
        XCTAssertTrue(detector.findings(in: "주민등록번호 900101-1234567")
            .contains(.residentRegistrationNumber))
    }

    func testDetectsPasswordNearKeyword() {
        XCTAssertTrue(detector.findings(in: "비밀번호: hunter2!").contains(.password))
        XCTAssertTrue(detector.findings(in: "PW = a1b2c3d4").contains(.password))
    }

    func testDetectsPhoneNumber() {
        XCTAssertTrue(detector.findings(in: "연락처 010-1234-5678").contains(.phoneNumber))
    }

    func testDetectsAccountNumberOnlyWithContextKeyword() {
        XCTAssertTrue(detector.findings(in: "국민은행 123456-01-123456 로 입금해주세요")
            .contains(.bankAccount))
    }

    // MARK: - 탐지되면 안 되는 것 (오탐 방지)

    /// 날짜는 계좌번호와 형식이 겹친다. 문맥 키워드를 요구하지 않으면
    /// 날짜가 적힌 모든 스크린샷이 민감정보로 분류된다.
    func testDoesNotFlagPlainDates() {
        XCTAssertFalse(detector.containsSensitiveInfo(in: "회의는 2026-08-30 에 진행합니다"))
        XCTAssertFalse(detector.containsSensitiveInfo(in: "가입일 2024-01-05 / 만료 2025-12-31"))
    }

    func testDoesNotFlagAccountShapedNumberWithoutContext() {
        XCTAssertFalse(detector.containsSensitiveInfo(in: "코드 123456-01-123456"))
    }

    func testDoesNotFlagOrderNumberOrVersionString() {
        XCTAssertFalse(detector.containsSensitiveInfo(in: "주문번호 2026-0830-0001 배송중"))
        XCTAssertFalse(detector.containsSensitiveInfo(in: "v1.2.3 build 2026-08-30"))
    }

    /// Luhn 체크섬이 없으면 임의의 16자리 일련번호가 전부 카드번호로 잡힌다.
    func testDoesNotFlagRandomSixteenDigitSerial() {
        XCTAssertFalse(detector.containsSensitiveInfo(in: "일련번호 1234567890123456"))
    }

    func testDoesNotFlagOrdinaryConversationOrAmounts() {
        XCTAssertFalse(detector.containsSensitiveInfo(in: "내일 저녁 7시에 강남역에서 보자"))
        XCTAssertFalse(detector.containsSensitiveInfo(in: "총 결제금액 1,250,000원 입니다"))
    }

    func testEmptyTextIsNotSensitive() {
        XCTAssertFalse(detector.containsSensitiveInfo(in: ""))
    }

    // MARK: - Luhn

    func testLuhnValidation() {
        XCTAssertTrue(SensitiveInfoDetector.isLuhnValid("4111111111111111"))
        XCTAssertFalse(SensitiveInfoDetector.isLuhnValid("4111111111111112"))
    }
}
