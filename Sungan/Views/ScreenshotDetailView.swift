import Photos
import SwiftData
import SwiftUI

struct ScreenshotDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var screenshot: Screenshot
    @State private var image: UIImage?
    @State private var exportErrorMessage: String?
    @State private var showShareSheet = false

    private let shareTextBuilder = ShareTextBuilder()
    private let obsidianExporter = ObsidianExporter()

    var body: some View {
        Form {
            if let image {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Section("분류") {
                Picker("카테고리", selection: $screenshot.category) {
                    ForEach(ScreenshotCategory.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                Toggle("텍스트형", isOn: $screenshot.isTextType)
                Toggle("민감정보 포함", isOn: $screenshot.isSensitive)
                Picker("상태", selection: $screenshot.status) {
                    ForEach(ScreenshotStatus.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
            }

            Section("추출된 텍스트") {
                TextEditor(text: $screenshot.ocrText)
                    .frame(minHeight: 120)
            }

            if screenshot.isSensitive {
                Section {
                    Label(
                        "민감정보가 감지됐어요. 공유하기 전에 내용을 한 번 확인해주세요.",
                        systemImage: "exclamationmark.shield"
                    )
                    .foregroundStyle(.orange)
                }
            }

            Section("공유") {
                Button {
                    showShareSheet = true
                } label: {
                    Label("공유 시트로 보내기", systemImage: "square.and.arrow.up")
                }

                Button {
                    exportToObsidian()
                } label: {
                    Label("Obsidian Vault에 저장", systemImage: "tray.and.arrow.down")
                }

                if !screenshot.sharedTo.isEmpty {
                    Text("공유함: \(screenshot.sharedTo.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("스크린샷")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFullImage()
        }
        // 상세 화면에서 상태를 바꾸면 위젯 숫자도 따라가야 리스트와 어긋나지 않는다.
        .onChange(of: screenshot.status) {
            UnclassifiedCountSync.refresh(context: modelContext)
        }
        .alert("저장 실패", isPresented: .constant(exportErrorMessage != nil)) {
            Button("확인", role: .cancel) { exportErrorMessage = nil }
        } message: {
            Text(exportErrorMessage ?? "")
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityShareSheet(items: [shareTextBuilder.markdown(for: screenshot)]) { completed in
                if completed {
                    markShared(destination: "공유 시트")
                }
            }
        }
    }

    private func loadFullImage() async {
        guard image == nil else { return }
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [screenshot.assetIdentifier], options: nil)
        guard let asset = results.firstObject else { return }
        image = await PhotoLibraryService().requestImage(for: asset, targetSize: PHImageManagerMaximumSize)
    }

    private func markShared(destination: String) {
        if !screenshot.sharedTo.contains(destination) {
            screenshot.sharedTo.append(destination)
        }
        screenshot.status = .classified
        screenshot.processedAt = Date()
        UnclassifiedCountSync.refresh(context: modelContext)
    }

    private func exportToObsidian() {
        do {
            try obsidianExporter.export(
                markdown: shareTextBuilder.markdown(for: screenshot),
                fileName: shareTextBuilder.fileName(for: screenshot)
            )
            markShared(destination: "Obsidian")
        } catch {
            exportErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }
}
