import CoreGraphics
import Foundation

/// Vision이 인식한 텍스트 조각 하나.
struct RecognizedFragment: Equatable {
    let text: String
    /// Vision 정규화 좌표 (원점 좌하단, y는 위로 증가).
    let boundingBox: CGRect
    let confidence: Float
}

/// 인식된 조각들을 사람이 읽는 순서로 재배열한다.
///
/// Vision은 관찰 결과의 순서를 보장하지 않는다. 받은 순서 그대로 이어붙이면
/// 표(2열), 카톡 좌우 말풍선, 영수증처럼 같은 높이에 여러 조각이 있는 화면에서
/// 문장이 뒤섞인다. 뒤섞인 텍스트는 사용자에게 그대로 보이는 데다,
/// 분류 LLM의 입력이기도 해서 카테고리 판정 품질까지 함께 떨어뜨린다.
enum OCRTextAssembler {

    /// - Parameter sameLineOverlapRatio: 두 조각을 같은 줄로 볼 세로 겹침 비율.
    ///   낮추면 살짝 어긋난 조각까지 한 줄로 묶고, 높이면 줄이 더 잘게 나뉜다.
    static func assemble(
        _ fragments: [RecognizedFragment],
        sameLineOverlapRatio: CGFloat = 0.3
    ) -> String {
        guard !fragments.isEmpty else { return "" }

        // 위에서 아래로. Vision 좌표는 y가 위로 증가하므로 midY 내림차순이 곧 위→아래다.
        let topToBottom = fragments.sorted { $0.boundingBox.midY > $1.boundingBox.midY }

        var lines: [[RecognizedFragment]] = []
        for fragment in topToBottom {
            if var lastLine = lines.last,
               let lineBox = boundingBox(of: lastLine),
               verticalOverlapRatio(lineBox, fragment.boundingBox) >= sameLineOverlapRatio {
                lastLine.append(fragment)
                lines[lines.count - 1] = lastLine
            } else {
                lines.append([fragment])
            }
        }

        return lines
            .map { line in
                line.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                    .map(\.text)
                    .joined(separator: " ")
            }
            .joined(separator: "\n")
    }

    private static func boundingBox(of fragments: [RecognizedFragment]) -> CGRect? {
        guard var union = fragments.first?.boundingBox else { return nil }
        for fragment in fragments.dropFirst() {
            union = union.union(fragment.boundingBox)
        }
        return union
    }

    /// 두 사각형의 세로 겹침을, 더 낮은 쪽 높이에 대한 비율로 돌려준다.
    private static func verticalOverlapRatio(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let overlap = min(lhs.maxY, rhs.maxY) - max(lhs.minY, rhs.minY)
        guard overlap > 0 else { return 0 }
        let shorter = min(lhs.height, rhs.height)
        guard shorter > 0 else { return 0 }
        return overlap / shorter
    }
}
