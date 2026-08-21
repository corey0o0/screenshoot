import Foundation
import SwiftData

enum ShareFormat: String, Codable, CaseIterable, Identifiable {
    case textOnly = "텍스트만"
    case markdown = "마크다운"
    case imageIncluded = "이미지포함"

    var id: String { rawValue }
}

@Model
final class UserSettings {
    var autoCleanupDays: Int
    var shareFormatDefault: ShareFormat
    var obsidianVaultPath: String?
    // v1에는 외부 AI 전송 기능이 없다. 이 플래그는 v1.1+ 연동을 위해 미리 마련해둔 것이며
    // 기본값은 항상 OFF, 켜져 있어도 민감정보가 감지된 스크린샷은 자동 제외된다 (섹션 7 참고).
    var aiExternalSendEnabled: Bool
    var lastScanDate: Date?

    init(
        autoCleanupDays: Int = 3,
        shareFormatDefault: ShareFormat = .markdown,
        obsidianVaultPath: String? = nil,
        aiExternalSendEnabled: Bool = false,
        lastScanDate: Date? = nil
    ) {
        self.autoCleanupDays = autoCleanupDays
        self.shareFormatDefault = shareFormatDefault
        self.obsidianVaultPath = obsidianVaultPath
        self.aiExternalSendEnabled = aiExternalSendEnabled
        self.lastScanDate = lastScanDate
    }

    @MainActor
    static func fetchOrCreate(in context: ModelContext) -> UserSettings {
        if let existing = try? context.fetch(FetchDescriptor<UserSettings>()).first {
            return existing
        }
        let settings = UserSettings()
        context.insert(settings)
        return settings
    }
}
