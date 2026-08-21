import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isPickingVault = false

    private let obsidianExporter = ObsidianExporter()

    private var settings: UserSettings {
        UserSettings.fetchOrCreate(in: modelContext)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("AI 처리") {
                    Toggle("AI 외부 전송 허용", isOn: Binding(
                        get: { settings.aiExternalSendEnabled },
                        set: { settings.aiExternalSendEnabled = $0 }
                    ))
                    Text("v1의 모든 분류는 기기 안에서만 처리돼요. 이 설정은 향후 외부 AI 연동을 위해 예약된 항목이며, 켜져 있어도 민감정보가 감지된 스크린샷은 자동으로 제외돼요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("공유") {
                    Picker("기본 공유 형식", selection: Binding(
                        get: { settings.shareFormatDefault },
                        set: { settings.shareFormatDefault = $0 }
                    )) {
                        ForEach(ShareFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                }

                Section("Obsidian") {
                    if let path = settings.obsidianVaultPath {
                        Text(path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Button("Vault 폴더 선택") {
                        isPickingVault = true
                    }
                }

                Section("정리") {
                    Stepper(
                        "자동 정리: \(settings.autoCleanupDays)일 후",
                        value: Binding(
                            get: { settings.autoCleanupDays },
                            set: { settings.autoCleanupDays = $0 }
                        ),
                        in: 1...30
                    )
                }
            }
            .navigationTitle("설정")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .fileImporter(isPresented: $isPickingVault, allowedContentTypes: [.folder]) { result in
                guard case .success(let url) = result else { return }
                obsidianExporter.saveVaultBookmark(for: url)
                settings.obsidianVaultPath = url.path
            }
        }
    }
}
