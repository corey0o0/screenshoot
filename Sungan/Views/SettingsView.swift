import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    // body가 평가될 때마다 fetch/insert를 반복하지 않도록 @Query로 한 번만 읽는다.
    @Query private var allSettings: [UserSettings]
    @State private var isPickingVault = false
    @State private var vaultError: String?

    private let obsidianExporter = ObsidianExporter()

    var body: some View {
        NavigationStack {
            Form {
                if let settings = allSettings.first {
                    obsidianSection(settings)
                }

                Section("프라이버시") {
                    Label("모든 분류는 기기 안에서만 처리돼요", systemImage: "iphone.gen3")
                        .font(.subheadline)
                    Text("v1은 OCR과 분류를 전부 온디바이스로 실행하며, 어떤 내용도 외부로 보내지 않아요. 카드번호·주민등록번호 같은 민감정보가 감지된 스크린샷은 별도로 표시돼요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("설정")
            .task {
                // 스캔 전에 설정 화면을 먼저 열어도 편집할 대상이 있도록 보장한다.
                _ = UserSettings.fetchOrCreate(in: modelContext)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .fileImporter(isPresented: $isPickingVault, allowedContentTypes: [.folder]) { result in
                handleVaultSelection(result)
            }
            .alert("폴더를 사용할 수 없어요", isPresented: .constant(vaultError != nil)) {
                Button("확인", role: .cancel) { vaultError = nil }
            } message: {
                Text(vaultError ?? "")
            }
        }
    }

    @ViewBuilder
    private func obsidianSection(_ settings: UserSettings) -> some View {
        Section {
            Button(settings.obsidianVaultPath == nil ? "Vault 폴더 선택" : "Vault 폴더 변경") {
                isPickingVault = true
            }
            if let path = settings.obsidianVaultPath {
                Text(path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.head)
            }
        } header: {
            Text("Obsidian")
        } footer: {
            Text("선택한 vault 폴더에 마크다운 파일이 바로 저장돼요. 다른 앱으로 보낼 때는 표준 공유 시트를 사용해요.")
        }
    }

    private func handleVaultSelection(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            vaultError = "폴더를 선택하지 못했어요."
            return
        }
        guard obsidianExporter.saveVaultBookmark(for: url) else {
            vaultError = "이 폴더에 접근할 권한을 얻지 못했어요. iCloud Drive 안의 vault 폴더를 선택해주세요."
            return
        }
        allSettings.first?.obsidianVaultPath = url.path
    }
}
