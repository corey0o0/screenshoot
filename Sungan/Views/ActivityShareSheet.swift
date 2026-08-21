import SwiftUI
import UIKit

/// UIActivityViewController를 감싼 래퍼. ShareLink는 완료/취소 여부를 알려주지 않아
/// 공유 이력(sharedTo)을 정확히 기록할 수 없으므로 이 래퍼를 사용한다.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
