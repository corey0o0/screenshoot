import SwiftData
import SwiftUI

@main
struct SunganApp: App {
    @State private var showUnclassifiedOnly = false

    private let sharedModelContainer: ModelContainer = {
        let schema = Schema([Screenshot.self, UserSettings.self])

        // App Group 컨테이너에 저장해두면 이후 위젯/익스텐션에서도 같은 DB를 읽을 수 있다.
        // 다만 App Group 설정은 개발자 계정마다 다시 해야 하고 번들 ID를 바꾸면 쉽게
        // 어긋나므로, 사용할 수 없으면 앱을 크래시시키는 대신 기본 위치로 물러난다.
        let configuration: ModelConfiguration
        if let containerURL = AppGroup.containerURL {
            configuration = ModelConfiguration(
                schema: schema,
                url: containerURL.appendingPathComponent("Sungan.sqlite")
            )
        } else {
            configuration = ModelConfiguration(schema: schema)
        }

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
                    // 위젯을 탭하면 sungan://unclassified 로 열려 미확인 리스트로 이동한다.
                    if url.host == SunganDeepLink.unclassifiedHost {
                        showUnclassifiedOnly = true
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
