import XCTest
@testable import Sungan

final class ScreenshotDateFormatterTests: XCTestCase {
    // "오늘/어제" 판정이 실행 시점에 따라 흔들리지 않도록 기준 시각과 시간대를 고정한다.
    private let formatter = ScreenshotDateFormatter(
        locale: Locale(identifier: "ko_KR"),
        timeZone: TimeZone(identifier: "Asia/Seoul")!
    )
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    func testShowsTimeForToday() {
        let now = date(2026, 8, 30, 21, 0)
        let captured = date(2026, 8, 30, 15, 24)
        XCTAssertEqual(formatter.short(for: captured, relativeTo: now), "오늘 오후 3:24")
    }

    func testShowsTimeForYesterday() {
        let now = date(2026, 8, 30, 9, 0)
        let captured = date(2026, 8, 29, 23, 5)
        XCTAssertEqual(formatter.short(for: captured, relativeTo: now), "어제 오후 11:05")
    }

    /// 어제 판정은 "24시간 전"이 아니라 달력상 하루 전이어야 한다.
    /// 자정 직후에는 몇 시간 전 스크린샷도 전날에 속한다.
    func testYesterdayIsCalendarBasedNotElapsedHours() {
        let now = date(2026, 8, 30, 0, 30)
        let captured = date(2026, 8, 29, 22, 0)
        XCTAssertEqual(formatter.short(for: captured, relativeTo: now), "어제 오후 10:00")
    }

    func testOmitsYearWithinTheSameYear() {
        let now = date(2026, 8, 30, 12, 0)
        XCTAssertEqual(formatter.short(for: date(2026, 3, 5, 8, 0), relativeTo: now), "3월 5일")
    }

    func testIncludesYearForOlderScreenshots() {
        let now = date(2026, 8, 30, 12, 0)
        XCTAssertEqual(
            formatter.short(for: date(2025, 12, 31, 8, 0), relativeTo: now),
            "2025년 12월 31일"
        )
    }

    /// 해가 바뀌면 하루 전이라도 연도가 붙지 않고 "어제"로 나와야 한다.
    func testYesterdayWinsOverYearBoundary() {
        let now = date(2026, 1, 1, 10, 0)
        XCTAssertEqual(formatter.short(for: date(2025, 12, 31, 22, 0), relativeTo: now), "어제 오후 10:00")
    }

    func testDetailedFormatIncludesDateAndTime() {
        XCTAssertEqual(
            formatter.detailed(for: date(2026, 8, 30, 15, 24)),
            "2026년 8월 30일 오후 3:24"
        )
    }
}
