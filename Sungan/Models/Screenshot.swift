import Foundation
import SwiftData

enum ScreenshotCategory: String, Codable, CaseIterable, Identifiable {
    case chat = "대화"
    case shopping = "쇼핑"
    case map = "지도/장소"
    case document = "문서/자료"
    case socialMedia = "SNS"
    case imageOrPhoto = "이미지/사진"
    case etc = "기타"

    var id: String { rawValue }
}

enum ScreenshotStatus: String, Codable {
    case unclassified = "미분류"
    case classified = "분류완료"
    case onHold = "보류"
}

@Model
final class Screenshot {
    // PHAsset.localIdentifier — the stable link back to the photo in Photos.
    @Attribute(.unique) var assetIdentifier: String
    var ocrText: String
    var category: ScreenshotCategory
    var isTextType: Bool
    var isSensitive: Bool
    var status: ScreenshotStatus
    var createdAt: Date
    var processedAt: Date?
    var sharedTo: [String]

    init(
        assetIdentifier: String,
        ocrText: String = "",
        category: ScreenshotCategory = .etc,
        isTextType: Bool = false,
        isSensitive: Bool = false,
        status: ScreenshotStatus = .unclassified,
        createdAt: Date,
        processedAt: Date? = nil,
        sharedTo: [String] = []
    ) {
        self.assetIdentifier = assetIdentifier
        self.ocrText = ocrText
        self.category = category
        self.isTextType = isTextType
        self.isSensitive = isSensitive
        self.status = status
        self.createdAt = createdAt
        self.processedAt = processedAt
        self.sharedTo = sharedTo
    }
}
