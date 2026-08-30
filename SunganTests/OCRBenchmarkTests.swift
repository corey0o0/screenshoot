import UIKit
import XCTest
@testable import Sungan

/// OCR 설정을 바꿀 때 "좋아진 것 같다"가 아니라 숫자로 확인하기 위한 벤치마크.
///
/// 실제 스크린샷은 개인정보라 커밋할 수 없으므로 비슷한 조건의 화면을 렌더링해서
/// 정답 텍스트와 비교한다. 절대 수치보다 **설정 간 상대 비교**를 보는 용도다.
///
/// 주의: 여기서 재는 것은 합성 이미지이고 시뮬레이터의 Vision이다.
/// 실기기·실제 스크린샷(인스타 캡처, 웹툰, 표 등)의 인식률과는 다를 수 있다.
///
/// 초기 버전은 흰 배경에 큰 글씨 5줄이라 모든 설정에서 CER 0%가 나와
/// 아무 것도 구별하지 못했다. 지금은 실제 스크린샷에 가깝게
/// (촘촘한 목록, 회색 보조 텍스트, 낮은 대비) 그려 변별력을 준다.
final class OCRBenchmarkTests: XCTestCase {

    /// (본문, 보조설명) 목록 — iOS 설정앱·알림함 같은 촘촘한 화면을 흉내낸다.
    private let rows: [(title: String, subtitle: String)] = [
        ("주문이 정상적으로 결제되었습니다", "8월 30일 오후 3시 24분"),
        ("배송이 시작되었어요", "송장번호 조회하기"),
        ("장바구니에 담은 상품이 품절되었습니다", "대체 상품 보기"),
        ("이번 주 무료배송 쿠폰 도착", "9월 5일까지 사용 가능"),
        ("리뷰를 작성하면 적립금을 드려요", "최대 2,000원"),
        ("고객센터 상담이 종료되었습니다", "만족도를 평가해주세요"),
        ("결제 수단이 변경되었습니다", "국민카드 1234"),
        ("관심 상품의 가격이 내렸어요", "24,800원에서 19,900원으로"),
        ("포인트가 곧 소멸됩니다", "잔여 1,250점"),
        ("새로운 기기에서 로그인되었습니다", "본인이 아니라면 확인하세요"),
        ("정기결제가 갱신되었습니다", "다음 결제일 9월 30일"),
        ("문의하신 내용에 답변이 등록되었어요", "답변 확인하기"),
        ("Order confirmed", "Thank you for your purchase"),
        ("Your package is on the way", "Track shipment"),
        ("주소지가 업데이트되었습니다", "서울시 강남구"),
        ("교환 신청이 접수되었습니다", "처리까지 2~3일 소요"),
        ("이벤트 응모가 완료되었습니다", "당첨자 발표 9월 10일"),
        ("비밀번호가 변경되었습니다", "변경하지 않았다면 문의해주세요"),
        ("월간 리포트가 도착했어요", "8월 지출 요약 보기"),
        ("친구가 회원가입했습니다", "추천 보상 지급 완료")
    ]

    private var groundTruth: String {
        rows.flatMap { [$0.title, $0.subtitle] }.joined(separator: "\n")
    }

    // MARK: - 렌더링

    /// 세로로 긴 스크린샷 비율(1179x2556)에 촘촘한 목록을 그린다.
    /// 글자 크기는 실제 iOS 기기 기준(3x): 본문 17pt≈51px, 보조 11pt≈33px.
    private func renderScreenshot(scale: CGFloat = 1.0) -> UIImage {
        let size = CGSize(width: 1179 * scale, height: 2556 * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            // 순백/순흑이 아닌 실제 iOS 톤. 대비가 낮아 더 현실적인 난이도가 된다.
            UIColor(white: 0.95, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let titleFont = UIFont.systemFont(ofSize: 46 * scale)
            let subtitleFont = UIFont.systemFont(ofSize: 33 * scale)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor(white: 0.11, alpha: 1)
            ]
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor(white: 0.56, alpha: 1)
            ]

            var y = 120 * scale
            for row in rows {
                row.title.draw(at: CGPoint(x: 60 * scale, y: y), withAttributes: titleAttributes)
                y += titleFont.lineHeight
                row.subtitle.draw(at: CGPoint(x: 60 * scale, y: y), withAttributes: subtitleAttributes)
                y += subtitleFont.lineHeight + 22 * scale
            }
        }
    }

    private func resize(_ image: UIImage, scale: CGFloat) -> UIImage {
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - 측정

    private func characterErrorRate(recognized: String, expected: String) -> Double {
        let normalize: (String) -> [Character] = { text in
            Array(text.replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\n", with: ""))
        }
        let lhs = normalize(recognized)
        let rhs = normalize(expected)
        guard !rhs.isEmpty else { return lhs.isEmpty ? 0 : 1 }
        return Double(Self.levenshtein(lhs, rhs)) / Double(rhs.count)
    }

    static func levenshtein(_ lhs: [Character], _ rhs: [Character]) -> Int {
        guard !lhs.isEmpty else { return rhs.count }
        guard !rhs.isEmpty else { return lhs.count }

        var previous = Array(0...rhs.count)
        var current = [Int](repeating: 0, count: rhs.count + 1)

        for i in 1...lhs.count {
            current[0] = i
            for j in 1...rhs.count {
                let substitution = previous[j - 1] + (lhs[i - 1] == rhs[j - 1] ? 0 : 1)
                current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
            }
            swap(&previous, &current)
        }
        return previous[rhs.count]
    }

    func testLevenshteinIsCorrect() {
        XCTAssertEqual(Self.levenshtein(Array("kitten"), Array("sitting")), 3)
        XCTAssertEqual(Self.levenshtein(Array("가나다"), Array("가나다")), 0)
        XCTAssertEqual(Self.levenshtein(Array(""), Array("abc")), 3)
    }

    // MARK: - 벤치마크

    /// 해상도를 줄이면 글자의 절대 픽셀 크기가 줄어든다.
    /// ScreenshotScanner가 1024로 축소해 넘기던 동작이 실제로 손해였는지 확인한다.
    func testResolutionEffectOnAccuracy() throws {
        let service = OCRService()
        let original = renderScreenshot()

        var report = "\n[해상도별 인식률] 본문 46px / 보조 33px, 40줄\n"
        for scale in [1.0, 0.6, 0.4, 0.25] as [CGFloat] {
            let image = scale == 1.0 ? original : resize(original, scale: scale)
            let result = try service.recognize(in: image)
            let cer = characterErrorRate(recognized: result.text, expected: groundTruth)
            report += String(
                format: "  배율 %3.0f%% (%4.0fx%4.0f, 본문 %4.1fpx)  CER %5.1f%%  조각 %2d개  신뢰도 %.2f\n",
                scale * 100, image.size.width, image.size.height, 46 * scale,
                cer * 100, result.fragmentCount, result.averageConfidence
            )
        }
        print(report)

        let full = try service.recognize(in: original)
        XCTAssertGreaterThan(full.fragmentCount, 0, "원본 해상도에서 아무 텍스트도 인식하지 못했다")
    }

    /// minimumTextHeight는 '이미지 높이 대비 비율'이라 균일 축소로는 변하지 않는다.
    /// 기본값 0.03125는 실제 본문 비율(약 0.018~0.020)보다 크다. 정말 영향이 있는지 잰다.
    func testMinimumTextHeightEffect() throws {
        let image = renderScreenshot()

        var report = "\n[minimumTextHeight별 인식률] 본문 비율 ≈ \(String(format: "%.5f", 46.0 / 2556.0))\n"
        for minimumHeight in [Float(0.03125), 0.02, 0.016, 0.008, 0.004] {
            let service = OCRService(minimumTextHeight: minimumHeight)
            let result = try service.recognize(in: image)
            let cer = characterErrorRate(recognized: result.text, expected: groundTruth)
            report += String(
                format: "  minimumTextHeight %.5f  CER %5.1f%%  조각 %2d개\n",
                minimumHeight, cer * 100, result.fragmentCount
            )
        }
        print(report)
    }

    /// 한국어에서 언어 교정이 도움이 되는지 해가 되는지는 단정할 수 없다. 재보고 정한다.
    func testLanguageCorrectionEffect() throws {
        let image = renderScreenshot()

        var report = "\n[언어 교정 on/off]\n"
        for correction in [true, false] {
            let service = OCRService(usesLanguageCorrection: correction)
            let result = try service.recognize(in: image)
            let cer = characterErrorRate(recognized: result.text, expected: groundTruth)
            report += String(format: "  usesLanguageCorrection=%@  CER %5.1f%%  조각 %2d개\n",
                             correction ? "true " : "false", cer * 100, result.fragmentCount)
        }
        print(report)
    }
}
