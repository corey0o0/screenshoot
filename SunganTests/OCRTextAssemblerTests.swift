import XCTest
@testable import Sungan

/// 읽기 순서 재배열은 Vision 없이 순수 기하 계산이라 결정적으로 검증할 수 있다.
/// (Vision 자체의 인식률은 OCRBenchmarkTests에서 측정한다.)
final class OCRTextAssemblerTests: XCTestCase {

    /// Vision 정규화 좌표는 원점이 좌하단이고 y가 위로 증가한다.
    private func fragment(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat = 0.2,
        height: CGFloat = 0.04
    ) -> RecognizedFragment {
        RecognizedFragment(
            text: text,
            boundingBox: CGRect(x: x, y: y, width: width, height: height),
            confidence: 0.9
        )
    }

    func testEmptyInputProducesEmptyString() {
        XCTAssertEqual(OCRTextAssembler.assemble([]), "")
    }

    /// Vision은 관찰 순서를 보장하지 않는다. 입력이 뒤섞여 들어와도
    /// 위→아래, 왼쪽→오른쪽으로 복원돼야 한다.
    func testRestoresReadingOrderFromShuffledInput() {
        let text = OCRTextAssembler.assemble([
            fragment("2,000원", x: 0.6, y: 0.70),
            fragment("항목", x: 0.1, y: 0.80),
            fragment("금액", x: 0.6, y: 0.80),
            fragment("커피", x: 0.1, y: 0.70)
        ])
        XCTAssertEqual(text, "항목 금액\n커피 2,000원")
    }

    /// 세로 위치가 다른 좌우 말풍선은 각각 다른 줄로 남아야 한다.
    func testKeepsVerticallySeparatedBubblesOnSeparateLines() {
        let text = OCRTextAssembler.assemble([
            fragment("내일 보자", x: 0.55, y: 0.60, width: 0.3),
            fragment("응 좋아", x: 0.10, y: 0.70, width: 0.3),
            fragment("몇 시에?", x: 0.10, y: 0.50, width: 0.3)
        ])
        XCTAssertEqual(text, "응 좋아\n내일 보자\n몇 시에?")
    }

    /// 한 줄이 여러 조각으로 쪼개져 인식돼도 한 줄로 합쳐져야 한다.
    func testMergesFragmentsOfTheSameLine() {
        let text = OCRTextAssembler.assemble([
            fragment("결제되었습니다", x: 0.45, y: 0.900, width: 0.3, height: 0.035),
            fragment("주문이", x: 0.10, y: 0.902, width: 0.2, height: 0.035)
        ])
        XCTAssertEqual(text, "주문이 결제되었습니다")
    }

    func testHigherOverlapThresholdSplitsLinesMoreAggressively() {
        let fragments = [
            fragment("왼쪽", x: 0.1, y: 0.50, height: 0.04),
            // 겹치긴 하지만 절반 정도만 겹치는 조각
            fragment("오른쪽", x: 0.6, y: 0.52, height: 0.04)
        ]
        XCTAssertEqual(OCRTextAssembler.assemble(fragments, sameLineOverlapRatio: 0.3), "왼쪽 오른쪽")
        XCTAssertEqual(OCRTextAssembler.assemble(fragments, sameLineOverlapRatio: 0.9), "오른쪽\n왼쪽")
    }

    func testSingleFragmentPassesThrough() {
        XCTAssertEqual(OCRTextAssembler.assemble([fragment("안녕하세요", x: 0.1, y: 0.5)]), "안녕하세요")
    }
}
