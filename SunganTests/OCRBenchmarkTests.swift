import UIKit
import XCTest
@testable import Sungan

/// OCR 설정을 바꿀 때 "좋아진 것 같다"가 아니라 숫자로 확인하기 위한 벤치마크.
///
/// 실제 스크린샷은 개인정보라 저장소에 커밋할 수 없으므로, 스크린샷과 비슷한 조건
/// (흰 배경·검은 본문·여러 줄)의 이미지를 코드로 렌더링해서 정답 텍스트와 비교한다.
/// 절대 수치보다 **설정 간 상대 비교**를 보는 용도다.
///
/// Vision의 출력은 OS 버전에 따라 달라질 수 있어 단정적인 임계값은 두지 않는다.
/// 회귀를 막는 딱딱한 검증은 OCRTextAssemblerTests가 담당하고,
/// 여기서는 수치를 로그로 남겨 튜닝 근거로 쓴다.
final class OCRBenchmarkTests: XCTestCase {

    private let sampleLines = [
        "주문이 정상적으로 결제되었습니다",
        "결제금액 24,800원",
        "배송 예정일 8월 30일 토요일",
        "Order confirmed - thank you",
        "문의는 고객센터로 연락주세요"
    ]

    private var groundTruth: String { sampleLines.joined(separator: "\n") }

    // MARK: - 렌더링

    /// 세로로 긴 스크린샷 비율(1179x2556)에 본문을 그린다.
    private func renderScreenshot(fontSize: CGFloat, scale: CGFloat = 1.0) -> UIImage {
        let size = CGSize(width: 1179 * scale, height: 2556 * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let font = UIFont.systemFont(ofSize: fontSize * scale)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black
            ]
            var y = 200 * scale
            for line in sampleLines {
                line.draw(at: CGPoint(x: 80 * scale, y: y), withAttributes: attributes)
                y += font.lineHeight * 1.8
            }
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

    /// 해상도를 줄이면 글자 높이가 그대로 줄어 인식률이 떨어진다는 점을 수치로 남긴다.
    /// ScreenshotScanner가 1024로 축소해서 넘기던 동작이 왜 문제였는지의 근거.
    func testResolutionEffectOnAccuracy() throws {
        let service = OCRService()
        let original = renderScreenshot(fontSize: 34)

        var report = "\n[해상도별 인식률]\n"
        for scale in [1.0, 0.6, 0.4] as [CGFloat] {
            let image = scale == 1.0 ? original : resize(original, scale: scale)
            let result = try service.recognize(in: image)
            let cer = characterErrorRate(recognized: result.text, expected: groundTruth)
            report += String(
                format: "  배율 %3.0f%% (%4.0fx%4.0f)  CER %5.1f%%  조각 %2d개  신뢰도 %.2f\n",
                scale * 100, image.size.width, image.size.height,
                cer * 100, result.fragmentCount, result.averageConfidence
            )
        }
        print(report)

        // OCR 파이프라인이 통째로 죽지 않았는지만 확인한다 (임계값 튜닝은 로그를 보고).
        let full = try service.recognize(in: original)
        XCTAssertGreaterThan(full.fragmentCount, 0, "원본 해상도에서 아무 텍스트도 인식하지 못했다")
    }

    /// minimumTextHeight 기본값(1/32)은 스크린샷 본문보다 크다.
    /// 값을 낮췄을 때 실제로 더 잡히는지 확인한다.
    func testMinimumTextHeightEffect() throws {
        let image = renderScreenshot(fontSize: 30)

        var report = "\n[minimumTextHeight별 인식률]\n"
        for minimumHeight in [Float(0.03125), 0.016, 0.008, 0.004] {
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
        let image = renderScreenshot(fontSize: 34)

        var report = "\n[언어 교정 on/off]\n"
        for correction in [true, false] {
            let service = OCRService(usesLanguageCorrection: correction)
            let result = try service.recognize(in: image)
            let cer = characterErrorRate(recognized: result.text, expected: groundTruth)
            report += String(format: "  usesLanguageCorrection=%@  CER %5.1f%%\n",
                             correction ? "true " : "false", cer * 100)
        }
        print(report)
    }

    private func resize(_ image: UIImage, scale: CGFloat) -> UIImage {
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
