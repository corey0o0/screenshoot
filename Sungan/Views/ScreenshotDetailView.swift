import Photos
import SwiftData
import SwiftUI

struct ScreenshotDetailView: View {
    @Bindable var screenshot: Screenshot
    @State private var image: UIImage?
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
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
                        Text(category.rawValue).tag(category)
                    }
                }
                Toggle("텍스트형", isOn: $screenshot.isTextType)
                Toggle("민감정보 포함", isOn: $screenshot.isSensitive)
                Picker("상태", selection: $screenshot.status) {
                    Text(ScreenshotStatus.unclassified.rawValue).tag(ScreenshotStatus.unclassified)
                    Text(ScreenshotStatus.classified.rawValue).tag(ScreenshotStatus.classified)
                    Text(ScreenshotStatus.onHold.rawValue).tag(ScreenshotStatus.onHold)
                }
            }

            Section("추출된 텍스트") {
                TextEditor(text: $screenshot.ocrText)
                    .frame(minHeight: 120)
            }

            if screenshot.isSensitive {
                Section {
                    Label("민감정보가 감지되어 외부 전송 대상에서 제외됩니다.", systemImage: "exclamationmark.shield")
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
            }
        }
        .navigationTitle("스크린샷")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFullImage()
        }
        .alert("저장 실패", isPresented: $showExportError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
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
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [screenshot.assetIdentifier], options: nil)
        guard let asset = results.firstObject else { return }
        image = await PhotoLibraryService().requestImage(for: asset, targetSize: PHImageManagerMaximumSize)
    }

    private func markShared(destination: String) {
        screenshot.sharedTo.append(destination)
        screenshot.status = .classified
        screenshot.processedAt = Date()
    }

    private func exportToObsidian() {
        let markdown = shareTextBuilder.markdown(for: screenshot)
        let fileName = screenshot.assetIdentifier.replacingOccurrences(of: "/", with: "_")
        do {
            try obsidianExporter.export(markdown: markdown, fileName: fileName)
            markShared(destination: "Obsidian")
        } catch {
            exportErrorMessage = "설정 화면에서 Obsidian vault 폴더를 먼저 선택해주세요."
            showExportError = true
        }
    }
}
