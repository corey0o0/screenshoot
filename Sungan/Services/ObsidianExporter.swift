import Foundation

enum ObsidianExporterError: LocalizedError {
    case noVaultConfigured
    case vaultUnavailable
    case writeFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noVaultConfigured:
            "설정에서 Obsidian vault 폴더를 먼저 선택해주세요."
        case .vaultUnavailable:
            "vault 폴더에 접근할 수 없어요. 설정에서 폴더를 다시 선택해주세요."
        case .writeFailed(let underlying):
            "파일을 저장하지 못했어요: \(underlying.localizedDescription)"
        }
    }
}

/// iCloud Drive의 Obsidian vault 폴더에 마크다운 파일을 직접 써서 자동 저장한다 (스펙 섹션 2, 9-4).
///
/// 앱 샌드박스에서는 경로 문자열만으로는 다음 실행 때 접근이 보장되지 않으므로,
/// 문서 선택기로 받은 폴더 URL의 security-scoped bookmark를 저장해두고 매번 resolve한다.
struct ObsidianExporter {
    private let bookmarkKey = "obsidianVaultBookmark"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// fileImporter가 돌려준 URL은 security scope를 연 상태여야 bookmark를 만들 수 있다.
    /// 열지 않고 bookmarkData()를 호출하면 권한이 없는 bookmark가 저장되어,
    /// 나중에 resolve는 되지만 쓰기에서 실패한다.
    @discardableResult
    func saveVaultBookmark(for folderURL: URL) -> Bool {
        let didStartAccess = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess { folderURL.stopAccessingSecurityScopedResource() }
        }

        guard let bookmark = try? folderURL.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return false
        }
        defaults.set(bookmark, forKey: bookmarkKey)
        return true
    }

    var hasVault: Bool {
        defaults.data(forKey: bookmarkKey) != nil
    }

    func export(markdown: String, fileName: String) throws {
        guard let bookmark = defaults.data(forKey: bookmarkKey) else {
            throw ObsidianExporterError.noVaultConfigured
        }

        var isStale = false
        guard let vaultURL = try? URL(
            resolvingBookmarkData: bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            throw ObsidianExporterError.vaultUnavailable
        }

        guard vaultURL.startAccessingSecurityScopedResource() else {
            throw ObsidianExporterError.vaultUnavailable
        }
        defer { vaultURL.stopAccessingSecurityScopedResource() }

        // bookmark가 낡았으면(폴더 이동/이름 변경 등) 지금 갱신해둔다.
        // 그대로 두면 다음 실행에서 resolve 자체가 실패할 수 있다.
        if isStale, let refreshed = try? vaultURL.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            defaults.set(refreshed, forKey: bookmarkKey)
        }

        let fileURL = vaultURL
            .appendingPathComponent(Self.sanitizedFileName(fileName))
            .appendingPathExtension("md")
        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw ObsidianExporterError.writeFailed(underlying: error)
        }
    }

    /// 파일명에 쓸 수 없는 문자를 정리하고 길이를 제한한다.
    /// 제목을 그대로 파일명에 쓰기 때문에 OCR 텍스트의 어떤 문자가 와도 안전해야 한다.
    static func sanitizedFileName(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        let cleaned = raw
            .components(separatedBy: invalid)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = cleaned.isEmpty ? "순간-메모" : cleaned
        return String(fallback.prefix(80))
    }
}
