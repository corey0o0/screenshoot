import SwiftData
import SwiftUI

struct ScreenshotListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Screenshot.createdAt, order: .reverse) private var screenshots: [Screenshot]
    @Binding var showUnclassifiedOnly: Bool
    @State private var isScanning = false
    @State private var showSettings = false

    private var unclassified: [Screenshot] { screenshots.filter { $0.status == .unclassified } }
    private var others: [Screenshot] { screenshots.filter { $0.status != .unclassified } }

    var body: some View {
        List {
            if !unclassified.isEmpty {
                Section("미분류 (\(unclassified.count))") {
                    ForEach(unclassified) { screenshot in
                        NavigationLink(value: screenshot) {
                            ScreenshotRowView(screenshot: screenshot)
                        }
                    }
                }
            }
            if !showUnclassifiedOnly {
                Section("전체") {
                    ForEach(others) { screenshot in
                        NavigationLink(value: screenshot) {
                            ScreenshotRowView(screenshot: screenshot)
                        }
                    }
                }
            }
        }
        .navigationTitle(showUnclassifiedOnly ? "미분류" : "순간")
        .navigationDestination(for: Screenshot.self) { screenshot in
            ScreenshotDetailView(screenshot: screenshot)
        }
        .toolbar {
            if showUnclassifiedOnly {
                ToolbarItem(placement: .topBarLeading) {
                    Button("전체보기") { showUnclassifiedOnly = false }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .overlay {
            if screenshots.isEmpty && !isScanning {
                ContentUnavailableView(
                    "스크린샷이 없어요",
                    systemImage: "photo.on.rectangle",
                    description: Text("스크린샷을 찍고 앱을 열면 자동으로 정리돼요.")
                )
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .task {
            await scan()
        }
        .refreshable {
            await scan()
        }
    }

    private func scan() async {
        guard !isScanning else { return }
        isScanning = true
        await ScreenshotScanner().scan(context: modelContext)
        isScanning = false
    }
}
