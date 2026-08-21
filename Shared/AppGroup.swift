import Foundation

/// Constants shared between the main app and the widget extension.
enum AppGroup {
    static let identifier = "group.com.corey0o0.sungan"

    static var containerURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            fatalError("App Group container unavailable — check the '\(identifier)' entitlement on this target.")
        }
        return url
    }

    static var sharedDefaults: UserDefaults {
        guard let defaults = UserDefaults(suiteName: identifier) else {
            fatalError("Shared UserDefaults unavailable for app group '\(identifier)'.")
        }
        return defaults
    }

    enum Key {
        static let unclassifiedCount = "unclassifiedCount"
    }
}
