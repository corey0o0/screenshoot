import SwiftUI
import WidgetKit

struct UnclassifiedEntry: TimelineEntry {
    let date: Date
    let count: Int
}

/// v1 위젯은 정적 표시만 지원한다 (인터랙티브 App Intent 버튼은 v1.2로 이연 — 스펙 섹션 8).
struct UnclassifiedProvider: TimelineProvider {
    func placeholder(in context: Context) -> UnclassifiedEntry {
        UnclassifiedEntry(date: Date(), count: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (UnclassifiedEntry) -> Void) {
        completion(UnclassifiedEntry(date: Date(), count: currentCount()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UnclassifiedEntry>) -> Void) {
        let entry = UnclassifiedEntry(date: Date(), count: currentCount())
        // 앱이 스캔을 마치거나 사용자가 상태를 바꿀 때마다 WidgetCenter.reloadTimelines를
        // 호출해 값을 갱신하므로, 여기서 주기적으로 다시 깨울 필요가 없다.
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func currentCount() -> Int {
        AppGroup.sharedDefaults?.integer(forKey: AppGroup.Key.unclassifiedCount) ?? 0
    }
}

struct SunganUnclassifiedWidgetView: View {
    let entry: UnclassifiedEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "photo.stack")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(entry.count == 0 ? "다 정리했어요" : "\(entry.count)장")
                .font(entry.count == 0 ? .headline : .title.bold())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(entry.count == 0 ? "미분류 없음" : "미분류 스크린샷")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(SunganDeepLink.unclassified)
    }
}

struct SunganUnclassifiedWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SunganWidgetKind.unclassified, provider: UnclassifiedProvider()) { entry in
            SunganUnclassifiedWidgetView(entry: entry)
        }
        .configurationDisplayName("미분류 스크린샷")
        .description("아직 정리하지 않은 스크린샷 개수를 보여줘요. 탭하면 미분류 리스트로 이동해요.")
        .supportedFamilies([.systemSmall])
    }
}
