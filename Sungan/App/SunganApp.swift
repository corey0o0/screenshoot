import SwiftData
import SwiftUI

@main
struct SunganApp: App {
    @State private var showUnclassifiedOnly = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Screenshot.self, UserSettings.self])
        let configuration = ModelConfiguration(
            schema: schema,
            url: AppGroup.containerURL.appendingPathComponent("Sungan.sqlite")
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("SwiftData 컨테이너 생성 실패: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(showUnclassifiedOnly: $showUnclassifiedOnly)
                .onOpenURL { url in
                    // 위젯 탭 시 "sungan://unclassified"로 열려 미확인 리스트로 이동한다.
                    if url.host == "unclassified" {
                        showUnclassifiedOnly = true
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
