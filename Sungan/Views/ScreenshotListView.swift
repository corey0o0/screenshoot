import SwiftData
import SwiftUI

struct ScreenshotListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Screenshot.createdAt, order: .reverse) private var screenshots: [Screenshot]
    @Binding var showUnclassifiedOnly: Bool

    @State private var isScanning = false
    @State private var lastOutcome: ScreenshotScanner.Outcome?
    @State private var showSettings = false

    private var unclassified: [Screenshot] { screenshots.filter { $0.status == .unclassified } }
    private var organized: [Screenshot] { screenshots.filter { $0.status != .unclassified } }

    var body: some View {
        List {
            if isScanning {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("스크린샷을 정리하는 중…")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if case .completed(_, let remaining) = lastOutcome, remaining > 0 {
                Section {
                    Label(
                        "\(remaining)장이 더 남아 있어요. 아래로 당기면 이어서 정리해요.",
                        systemImage: "clock.arrow.circlepath"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            if !unclassified.isEmpty {
                Section("미분류 (\(unclassified.count))") {
                    ForEach(unclassified) { screenshot in
                        NavigationLink(value: screenshot) {
                            ScreenshotRowView(screenshot: screenshot)
                        }
                    }
                }
            }

            if !showUnclassifiedOnly && !organized.isEmpty {
                Section("정리됨 (\(organized.count))") {
                    ForEach(organized) { screenshot in
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
                .accessibilityLabel("설정")
            }
        }
        .overlay {
            emptyStateView
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .task { await scan() }
        .refreshable { await scan() }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if screenshots.isEmpty && !isScanning {
            if lastOutcome == .notAuthorized {
                // 권한이 없을 때 "스크린샷을 찍어보세요"라고 안내하면 사용자가 원인을
                // 알 수 없어 계속 헤매게 된다. 실제 원인과 해결 경로를 보여준다.
                ContentUnavailableView {
                    Label("사진 접근 권한이 필요해요", systemImage: "lock.circle")
                } description: {
                    Text("스크린샷을 찾으려면 사진 보관함 접근을 허용해주세요.")
                } actions: {
                    Button("설정 열기") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                }
            } else {
                ContentUnavailableView(
                    "스크린샷이 없어요",
                    systemImage: "photo.on.rectangle",
                    description: Text("스크린샷을 찍고 앱을 열면 자동으로 정리돼요.")
                )
            }
        }
    }

    private func scan() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }
        lastOutcome = await ScreenshotScanner().scan(context: modelContext)
    }
}
