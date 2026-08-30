import CoreGraphics
import UIKit
import Vision

struct OCRResult {
    let text: String
    /// 인식 신뢰도 평균. 낮으면 사용자에게 "인식 품질 낮음"을 알리거나
    /// 분류 결과를 덜 신뢰하는 근거로 쓸 수 있다.
    let averageConfidence: Float
    let fragmentCount: Int

    static let empty = OCRResult(text: "", averageConfidence: 0, fragmentCount: 0)
}

struct OCRService {
    /// 인식할 글자의 최소 높이(이미지 높이 대비 비율).
    ///
    /// Vision 기본값은 1/32(≈0.031)로, 이미지 높이가 2556px이면 80px 이상인 글자만
    /// 대상으로 삼는다. 스크린샷 본문은 보통 30px 안팎이라 기본값으로는 본문이
    /// 통째로 빠질 수 있다. 값을 낮추면 처리 시간이 늘어나므로,
    /// OCRBenchmarkTests로 실제 수치를 보고 조정할 것.
    var minimumTextHeight: Float

    /// 한국어에서는 언어 교정이 고유명사·아이디·상품명을 엉뚱하게 "고쳐" 놓는
    /// 경우가 있다. 벤치마크로 켠 쪽/끈 쪽을 비교해 결정할 수 있게 열어둔다.
    var usesLanguageCorrection: Bool

    /// 교정 사전에 없는 도메인 단어(앱 이름, 브랜드 등)를 보강한다.
    var customWords: [String]

    /// 이 값보다 신뢰도가 낮은 조각은 버린다. 아주 낮은 신뢰도의 결과는
    /// 대개 UI 아이콘이나 노이즈를 글자로 오인한 것이다.
    var minimumConfidence: Float

    init(
        minimumTextHeight: Float = 0.008,
        usesLanguageCorrection: Bool = true,
        customWords: [String] = [],
        minimumConfidence: Float = 0.3
    ) {
        self.minimumTextHeight = minimumTextHeight
        self.usesLanguageCorrection = usesLanguageCorrection
        self.customWords = customWords
        self.minimumConfidence = minimumConfidence
    }

    func recognize(in cgImage: CGImage) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = usesLanguageCorrection
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.minimumTextHeight = minimumTextHeight
        if !customWords.isEmpty {
            request.customWords = customWords
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let fragments = (request.results ?? []).compactMap { observation -> RecognizedFragment? in
            guard let candidate = observation.topCandidates(1).first,
                  candidate.confidence >= minimumConfidence else { return nil }
            return RecognizedFragment(
                text: candidate.string,
                boundingBox: observation.boundingBox,
                confidence: candidate.confidence
            )
        }

        guard !fragments.isEmpty else { return .empty }

        let total = fragments.reduce(Float.zero) { $0 + $1.confidence }
        return OCRResult(
            text: OCRTextAssembler.assemble(fragments),
            averageConfidence: total / Float(fragments.count),
            fragmentCount: fragments.count
        )
    }

    func recognize(in image: UIImage) throws -> OCRResult {
        guard let cgImage = image.cgImage else { return .empty }
        return try recognize(in: cgImage)
    }

    /// async를 유지하는 이유: 호출부(ScreenshotScanner)가 @MainActor다.
    /// nonisolated async 함수는 호출자의 액터를 물려받지 않고 글로벌 실행기에서 도므로,
    /// 무거운 Vision 작업이 메인 스레드를 막지 않는다. 동기 함수로 바꾸면
    /// 스캔 도는 동안 UI가 그대로 멈춘다.
    func recognizeText(in image: UIImage) async throws -> String {
        try recognize(in: image).text
    }
}
