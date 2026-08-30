import Foundation

/// 스펙 섹션 5의 공유 마크다운 템플릿을 생성한다.
struct ShareTextBuilder {
    private let dateFormatter: DateFormatter

    init(locale: Locale = Locale(identifier: "ko_KR"), timeZone: TimeZone = .current) {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        self.dateFormatter = formatter
    }

    /// 첫 줄을 제목으로 쓰되, 비었거나 지나치게 길면 촬영일시로 대체/절단한다.
    func title(for screenshot: Screenshot) -> String {
        let firstLine = screenshot.ocrText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first(where: { !$0.isEmpty })

        guard let firstLine, !firstLine.isEmpty else {
            return dateFormatter.string(from: screenshot.createdAt)
        }
        return firstLine.count > 60 ? String(firstLine.prefix(60)) + "…" : firstLine
    }

    func markdown(for screenshot: Screenshot) -> String {
        """
        # \(title(for: screenshot))
        태그: #\(screenshot.category.displayName)

        \(screenshot.ocrText)

        ---
        원본: 순간 앱 · \(dateFormatter.string(from: screenshot.createdAt))
        """
    }

    /// Obsidian vault에 저장할 때 쓰는 파일명. assetIdentifier는 사람이 읽을 수 없어
    /// "날짜 제목" 형태로 만든다.
    func fileName(for screenshot: Screenshot) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd HHmm"
        return "\(dateFormatter.string(from: screenshot.createdAt)) \(title(for: screenshot))"
    }
}
