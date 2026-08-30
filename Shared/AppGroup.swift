import Foundation

/// 앱과 위젯 익스텐션이 공유하는 상수.
///
/// App Group은 개발자 계정마다 다시 설정해야 하고 번들 ID를 바꾸면 쉽게 어긋난다.
/// 설정이 어긋났을 때 앱이 즉시 크래시하는 대신 로컬 저장소로 물러나도록 옵셔널로 노출한다.
/// (공유가 끊기면 위젯 숫자만 갱신되지 않고, 앱 본체 기능은 정상 동작한다.)
enum AppGroup {
    static let identifier = "group.com.corey0o0.sungan"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    enum Key {
        static let unclassifiedCount = "unclassifiedCount"
    }
}

/// 위젯 kind 문자열. 앱에서 reloadTimelines를 호출할 때와 위젯 정의가 반드시 같은
/// 값을 써야 해서 공유 타깃에 둔다.
enum SunganWidgetKind {
    static let unclassified = "SunganUnclassifiedWidget"
}

/// 위젯 탭 시 앱을 미분류 리스트로 여는 딥링크.
enum SunganDeepLink {
    static let scheme = "sungan"
    static let unclassifiedHost = "unclassified"

    static var unclassified: URL? {
        URL(string: "\(scheme)://\(unclassifiedHost)")
    }
}
