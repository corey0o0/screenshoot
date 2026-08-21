import Foundation

struct ScreenshotClassification {
    var category: ScreenshotCategory
    var isTextType: Bool
    var isSensitive: Bool
}

protocol ClassificationEngine {
    func classify(ocrText: String) async -> ScreenshotClassification
}
