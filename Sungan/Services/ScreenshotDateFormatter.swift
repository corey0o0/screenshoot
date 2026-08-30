import Foundation

/// 촬영 시각 표시용 포맷터.
///
/// DateFormatter 생성은 비싸서 리스트 셀마다 만들면 스크롤이 끊긴다.
/// 한 번 만들어 `shared`로 재사용하고, 테스트는 고정된 로케일·시간대로 자체 인스턴스를 만든다.
struct ScreenshotDateFormatter {
    private let calendar: Calendar
    private let timeOnly: DateFormatter
    private let monthDay: DateFormatter
    private let yearMonthDay: DateFormatter
    private let dateAndTime: DateFormatter

    static let shared = ScreenshotDateFormatter()

    init(
        locale: Locale = Locale(identifier: "ko_KR"),
        timeZone: TimeZone = .current
    ) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = timeZone
        self.calendar = calendar

        func makeFormatter(_ format: String) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timeZone
            formatter.dateFormat = format
            return formatter
        }

        self.timeOnly = makeFormatter("a h:mm")
        self.monthDay = makeFormatter("M월 d일")
        self.yearMonthDay = makeFormatter("yyyy년 M월 d일")
        self.dateAndTime = makeFormatter("yyyy년 M월 d일 a h:mm")
    }

    /// 리스트 셀용 짧은 표기. 오늘·어제는 시각까지, 그보다 이전은 날짜만 보여준다.
    func short(for date: Date, relativeTo now: Date = Date()) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "오늘 \(timeOnly.string(from: date))"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "어제 \(timeOnly.string(from: date))"
        }
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            return monthDay.string(from: date)
        }
        return yearMonthDay.string(from: date)
    }

    /// 상세 화면용 전체 표기.
    func detailed(for date: Date) -> String {
        dateAndTime.string(from: date)
    }
}
