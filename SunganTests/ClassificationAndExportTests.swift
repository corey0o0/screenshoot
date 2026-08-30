import XCTest
@testable import Sungan

final class ScreenshotCategoryTests: XCTestCase {
    /// 저장값(rawValue)과 화면 라벨(displayName)이 분리되어 있어야
    /// 라벨 문구를 바꿔도 이미 저장된 데이터가 깨지지 않는다.
    func testRawValueIsStableASCIIAndSeparateFromDisplayName() {
        XCTAssertEqual(ScreenshotCategory.socialMedia.rawValue, "socialMedia")
        XCTAssertEqual(ScreenshotCategory.socialMedia.displayName, "SNS")
        XCTAssertEqual(ScreenshotStatus.unclassified.rawValue, "unclassified")
        XCTAssertEqual(ScreenshotStatus.unclassified.displayName, "미분류")
    }

    /// 온디바이스 LLM은 한글 라벨로 답하므로 그 값이 다시 case로 매핑되어야 한다.
    func testDisplayNameRoundTripsForEveryCase() {
        for category in ScreenshotCategory.allCases {
            XCTAssertEqual(ScreenshotCategory(displayName: category.displayName), category)
        }
    }

    func testDisplayNameInitToleratesSurroundingWhitespace() {
        XCTAssertEqual(ScreenshotCategory(displayName: " 지도/장소 "), .map)
    }

    func testUnknownDisplayNameReturnsNil() {
        XCTAssertNil(ScreenshotCategory(displayName: "알 수 없는 카테고리"))
    }
}

final class KeywordFallbackClassifierTests: XCTestCase {
    private let classifier = KeywordFallbackClassifier()

    func testClassifiesChatScreenshot() async {
        let result = await classifier.classify(ocrText: "카카오톡 단톡방에서 온 메시지 읽음 3")
        XCTAssertEqual(result.category, .chat)
        XCTAssertTrue(result.isTextType)
    }

    func testClassifiesShoppingScreenshot() async {
        let result = await classifier.classify(ocrText: "주문이 완료되었습니다. 배송 예정일 안내 결제 금액")
        XCTAssertEqual(result.category, .shopping)
    }

    /// 텍스트가 거의 없으면 이미지형으로 떨어져야 한다.
    func testTreatsTextLessScreenshotAsImageType() async {
        let result = await classifier.classify(ocrText: "")
        XCTAssertFalse(result.isTextType)
        XCTAssertEqual(result.category, .imageOrPhoto)
    }

    func testPropagatesSensitiveDetection() async {
        let result = await classifier.classify(ocrText: "비밀번호: sup3rSecret")
        XCTAssertTrue(result.isSensitive)
    }
}

final class ObsidianExporterTests: XCTestCase {
    func testSanitizesPathSeparatorsAndControlCharacters() {
        let sanitized = ObsidianExporter.sanitizedFileName("2025-08-30 폴더/이름\n두번째줄")
        XCTAssertFalse(sanitized.contains("/"))
        XCTAssertFalse(sanitized.contains("\n"))
    }

    func testFallsBackWhenNameBecomesEmpty() {
        XCTAssertEqual(ObsidianExporter.sanitizedFileName("///"), "___")
        XCTAssertEqual(ObsidianExporter.sanitizedFileName("   "), "순간-메모")
    }

    func testLimitsLength() {
        let sanitized = ObsidianExporter.sanitizedFileName(String(repeating: "가", count: 300))
        XCTAssertLessThanOrEqual(sanitized.count, 80)
    }

    /// vault를 고르지 않은 상태에서 저장하면 "폴더를 선택하라"는 안내가 나와야 한다.
    func testExportWithoutVaultThrowsNoVaultConfigured() {
        let defaults = UserDefaults(suiteName: "ObsidianExporterTests")!
        defaults.removePersistentDomain(forName: "ObsidianExporterTests")
        let exporter = ObsidianExporter(defaults: defaults)

        XCTAssertFalse(exporter.hasVault)
        XCTAssertThrowsError(try exporter.export(markdown: "# 제목", fileName: "테스트")) { error in
            // writeFailed가 Error를 물고 있어 Equatable을 붙일 수 없으므로 패턴으로 확인한다.
            guard case ObsidianExporterError.noVaultConfigured = error else {
                return XCTFail("expected .noVaultConfigured, got \(error)")
            }
        }
    }
}
