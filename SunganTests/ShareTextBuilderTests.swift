import XCTest
@testable import Sungan

final class ShareTextBuilderTests: XCTestCase {
    private let builder = ShareTextBuilder(
        locale: Locale(identifier: "ko_KR"),
        timeZone: TimeZone(secondsFromGMT: 0)!
    )

    private func makeScreenshot(
        ocrText: String,
        category: ScreenshotCategory = .document
    ) -> Screenshot {
        Screenshot(
            assetIdentifier: "TEST/L0/001",
            ocrText: ocrText,
            category: category,
            createdAt: Date(timeIntervalSince1970: 1_756_512_000)
        )
    }

    func testMarkdownFollowsTemplate() {
        let markdown = builder.markdown(for: makeScreenshot(ocrText: "회의 요약\n다음 주 화요일 확정"))
        XCTAssertTrue(markdown.hasPrefix("# 회의 요약"))
        XCTAssertTrue(markdown.contains("태그: #문서/자료"))
        XCTAssertTrue(markdown.contains("다음 주 화요일 확정"))
        XCTAssertTrue(markdown.contains("원본: 순간 앱 · "))
    }

    /// OCR이 실패해 빈 텍스트가 오면 제목 자리가 비어버린다. 촬영일시로 대체돼야 한다.
    func testEmptyOCRFallsBackToTimestampTitle() {
        let title = builder.title(for: makeScreenshot(ocrText: ""))
        XCTAssertFalse(title.isEmpty)
        XCTAssertTrue(title.contains("2025") || title.contains("2026"))
    }

    func testBlankFirstLinesAreSkippedWhenPickingTitle() {
        let title = builder.title(for: makeScreenshot(ocrText: "\n   \n실제 제목"))
        XCTAssertEqual(title, "실제 제목")
    }

    func testOverlyLongTitleIsTruncated() {
        let title = builder.title(for: makeScreenshot(ocrText: String(repeating: "가", count: 200)))
        XCTAssertLessThanOrEqual(title.count, 61)
        XCTAssertTrue(title.hasSuffix("…"))
    }

    func testFileNameIsHumanReadableAndDatePrefixed() {
        let fileName = builder.fileName(for: makeScreenshot(ocrText: "영수증 정리"))
        XCTAssertTrue(fileName.contains("영수증 정리"))
        XCTAssertTrue(fileName.hasPrefix("2025-") || fileName.hasPrefix("2026-"))
    }
}
