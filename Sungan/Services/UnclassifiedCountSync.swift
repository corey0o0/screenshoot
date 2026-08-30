import Foundation
import SwiftData
import WidgetKit

/// 미분류 개수를 App Group에 기록하고 위젯 타임라인을 갱신한다.
///
/// 스캔이 끝났을 때뿐 아니라 사용자가 상세 화면에서 상태를 바꿨을 때도 호출해야
/// 위젯 숫자가 실제 리스트와 어긋나지 않는다.
@MainActor
enum UnclassifiedCountSync {
    static func refresh(context: ModelContext) {
        // #Predicate 안에서는 enum case를 직접 참조할 수 없어(키패스로 해석됨)
        // 비교 대상을 지역 상수로 캡처해서 넘긴다.
        let unclassified = ScreenshotStatus.unclassified
        let descriptor = FetchDescriptor<Screenshot>(
            predicate: #Predicate { $0.status == unclassified }
        )
        let count = (try? context.fetchCount(descriptor)) ?? 0

        AppGroup.sharedDefaults?.set(count, forKey: AppGroup.Key.unclassifiedCount)
        WidgetCenter.shared.reloadTimelines(ofKind: SunganWidgetKind.unclassified)
    }
}
