import Foundation
import SwiftData

/// rawValue는 DB에 저장되는 값이므로 화면에 보이는 한글 라벨과 분리한다.
/// 둘을 겸하게 두면 라벨 문구를 다듬거나 다국어를 추가하는 순간
/// 이미 저장된 데이터가 전부 매칭되지 않는다.
enum ScreenshotCategory: String, Codable, CaseIterable, Identifiable {
    case chat
    case shopping
    case map
    case document
    case socialMedia
    case imageOrPhoto
    case etc

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chat: "대화"
        case .shopping: "쇼핑"
        case .map: "지도/장소"
        case .document: "문서/자료"
        case .socialMedia: "SNS"
        case .imageOrPhoto: "이미지/사진"
        case .etc: "기타"
        }
    }

    /// 온디바이스 LLM은 한글 라벨로 답하므로 그 값을 다시 case로 되돌린다.
    init?(displayName: String) {
        let normalized = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = Self.allCases.first(where: { $0.displayName == normalized }) else {
            return nil
        }
        self = match
    }
}

enum ScreenshotStatus: String, Codable, CaseIterable, Identifiable {
    case unclassified
    case classified
    case onHold

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unclassified: "미분류"
        case .classified: "분류완료"
        case .onHold: "보류"
        }
    }
}

@Model
final class Screenshot {
    // PHAsset.localIdentifier — 사진 보관함의 원본을 가리키는 안정적인 참조.
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
