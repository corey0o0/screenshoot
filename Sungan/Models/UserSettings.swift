import Foundation
import SwiftData

/// rawValue는 저장값, displayName은 화면 라벨 (ScreenshotCategory와 같은 원칙).
enum ShareFormat: String, Codable, CaseIterable, Identifiable {
    case textOnly
    case markdown
    case imageIncluded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .textOnly: "텍스트만"
        case .markdown: "마크다운"
        case .imageIncluded: "이미지포함"
        }
    }
}

@Model
final class UserSettings {
    // MARK: 로드맵 예약 필드
    // 아래 두 값은 아직 어떤 동작에도 연결되어 있지 않다. 동작하지 않는 스위치를
    // 설정 화면에 노출하면 사용자가 켰다고 착각하게 되므로(특히 프라이버시 항목),
    // 기능이 실제로 붙는 시점까지 UI에는 내보내지 않는다.
    //  - autoCleanupDays: 기간 경과 후 자동 정리 (v1.3)
    //  - shareFormatDefault: 공유 형식 선택 (현재는 항상 마크다운)
    //  - aiExternalSendEnabled: 외부 AI 전송 (v2). v1에는 전송 코드 자체가 없으므로
    //    항상 false이며, 스펙 섹션 4의 데이터 모델을 지키기 위해 필드만 남겨둔다.
    var autoCleanupDays: Int
    var shareFormatDefault: ShareFormat
    var aiExternalSendEnabled: Bool

    var obsidianVaultPath: String?
    var lastScanDate: Date?

    init(
        autoCleanupDays: Int = 3,
        shareFormatDefault: ShareFormat = .markdown,
        aiExternalSendEnabled: Bool = false,
        obsidianVaultPath: String? = nil,
        lastScanDate: Date? = nil
    ) {
        self.autoCleanupDays = autoCleanupDays
        self.shareFormatDefault = shareFormatDefault
        self.aiExternalSendEnabled = aiExternalSendEnabled
        self.obsidianVaultPath = obsidianVaultPath
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
