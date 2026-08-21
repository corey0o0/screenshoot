import Foundation

enum ObsidianExporterError: Error {
    case noVaultConfigured
    case bookmarkResolutionFailed
    case writeFailed
}

/// iCloud Drive의 Obsidian vault 폴더에 마크다운 파일을 직접 써서 자동 저장한다 (스펙 섹션 2, 9-4).
/// App Sandbox 하에서는 경로 문자열만으로는 재실행 후 접근이 보장되지 않으므로,
/// UIDocumentPicker로 받은 폴더 URL의 security-scoped bookmark를 별도로 저장해 둔다.
struct ObsidianExporter {
    private let bookmarkKey = "obsidianVaultBookmark"

    func saveVaultBookmark(for folderURL: URL) {
        guard let bookmark = try? folderURL.bookmarkData() else { return }
        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
    }

    func export(markdown: String, fileName: String) throws {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else {
            throw ObsidianExporterError.noVaultConfigured
        }

        var isStale = false
        guard let vaultURL = try? URL(
            resolvingBookmarkData: bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            throw ObsidianExporterError.bookmarkResolutionFailed
        }

        guard vaultURL.startAccessingSecurityScopedResource() else {
            throw ObsidianExporterError.bookmarkResolutionFailed
        }
        defer { vaultURL.stopAccessingSecurityScopedResource() }

        let fileURL = vaultURL.appendingPathComponent(fileName).appendingPathExtension("md")
        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw ObsidianExporterError.writeFailed
        }
    }
}
