import Foundation

/// 스펙 섹션 5의 공유 마크다운 템플릿을 생성한다.
struct ShareTextBuilder {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter
    }()

    func markdown(for screenshot: Screenshot) -> String {
        let title = screenshot.ocrText
            .split(separator: "\n")
            .first.map(String.init)
            ?? dateFormatter.string(from: screenshot.createdAt)

        return """
        # \(title)
        태그: #\(screenshot.category.rawValue)

        \(screenshot.ocrText)

        ---
        원본: 순간 앱 · \(dateFormatter.string(from: screenshot.createdAt))
        """
    }
}
