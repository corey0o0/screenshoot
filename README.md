# 순간 — 스크린샷 자동 분류 & 정리 앱 (v1 MVP)

아이폰 스크린샷을 자동으로 감지·분류하고, 텍스트를 추출해 공유 시트나 Obsidian으로
쉽게 보낼 수 있게 해주는 iOS 앱입니다. 이 저장소는 스펙 문서(섹션 1~9)에 정의된
v1 MVP 스코프를 SwiftUI + SwiftData + WidgetKit으로 구현한 소스입니다.

이 프로젝트는 macOS/Xcode가 없는 Linux 컨테이너에서 작성되었기 때문에
**실제 빌드 검증(컴파일/시뮬레이터 실행)은 되어 있지 않습니다.** 아래 순서대로
macOS + Xcode에서 여는 것을 전제로 합니다.

## 빌드 방법

Xcode 프로젝트 파일(`.xcodeproj`)은 저장소에 커밋하지 않고, [XcodeGen](https://github.com/yonaskolb/XcodeGen)
스펙(`project.yml`)으로부터 생성합니다.

```bash
brew install xcodegen
xcodegen generate
open Sungan.xcodeproj
```

Xcode에서 두 타겟(`Sungan`, `SunganWidgetExtension`) 모두 본인의 개발자 팀(Signing & Capabilities)을
지정해야 합니다. App Group ID(`group.com.corey0o0.sungan`)와 번들 ID(`com.corey0o0.sungan*`)는
`project.yml` 및 각 `.entitlements` 파일에서 필요에 맞게 바꿔주세요.

- 최소 배포 타깃: iOS 18.0 (SwiftData, WidgetKit `containerBackground` 사용)
- Foundation Models 기반 분류는 Apple Intelligence 지원 기기(A17 Pro/M-series 이상)에서만 동작하며,
  그 외 기기는 키워드 매칭 폴백으로 자동 전환됩니다.
- `AppIcon`/`AccentColor`는 빈 플레이스홀더입니다. 실제 아이콘 이미지를 추가해주세요.

## 폴더 구조

```
project.yml                        XcodeGen 프로젝트 정의
Shared/                            앱 · 위젯 공용 코드 (App Group 상수)
Sungan/
  App/                             App 진입점, Info.plist, entitlements, privacy manifest
  Models/                          SwiftData 모델 (Screenshot, UserSettings)
  Services/                        PhotoKit/Vision/분류/공유/Obsidian 로직
  Views/                           SwiftUI 화면
  Resources/Assets.xcassets/       앱 아이콘 · 강조색 플레이스홀더
SunganWidget/                      정적 위젯 익스텐션 (미분류 개수 표시)
```

## 스펙 대비 구현 메모

- **스캔 트리거**: iOS에는 백그라운드에서 "스크린샷 촬영 순간"을 감지하는 공식 API가 없어(스펙 섹션 6-1),
  `ScreenshotListView`가 나타날 때(`ScreenshotScanner.scan`)마다 `lastScanDate` 이후의 새 스크린샷만
  증분 스캔합니다. Shortcuts Automation 온보딩은 의도적으로 v1.1로 미뤘습니다.
- **분류 엔진**: `ClassificationService`가 기기 지원 여부(`SystemLanguageModel.default.availability`)를
  런타임에 확인해 Foundation Models 또는 키워드 폴백(`KeywordFallbackClassifier`)을 선택합니다.
  `FoundationModelsClassifier.swift` 상단에 남긴 것처럼, 실제 Foundation Models 프레임워크의
  최소 OS 버전은 사용 중인 Xcode/SDK에 따라 스펙의 "iOS 18.1"과 다를 수 있어 확인이 필요합니다.
- **민감정보 판단**: LLM/키워드 분류 결과와 무관하게 `SensitiveInfoDetector`(정규식 기반)가 항상
  추가로 실행되어 OR 조건으로 반영됩니다. 이렇게 하면 모델이 놓친 카드번호/비밀번호 등이
  외부 공유 대상에서 새어나갈 위험을 낮출 수 있습니다.
- **AI 외부 전송**: v1에는 실제로 외부로 전송하는 코드가 없습니다. `UserSettings.aiExternalSendEnabled`는
  기본 OFF이며 v1.1+ 연동을 위한 예약 필드로만 존재합니다(스펙 섹션 7).
- **Obsidian 연동**: 앱이 샌드박스 상태이므로 vault 폴더 경로 문자열만으로는 재실행 후 접근이
  보장되지 않습니다. `SettingsView`에서 `fileImporter`로 폴더를 선택하면 security-scoped bookmark를
  저장해두고, `ObsidianExporter`가 매 저장 시 이 bookmark를 다시 resolve해서 `.md` 파일을 씁니다.
- **위젯**: v1은 정적 표시만 지원합니다(스펙 섹션 2, 8). 앱이 스캔을 마칠 때마다 App Group의
  공유 `UserDefaults`에 미분류 개수를 쓰고 `WidgetCenter.reloadTimelines`를 호출해 갱신하며,
  위젯 탭 시 `sungan://unclassified` URL로 앱을 열어 미분류 리스트만 보여주는 화면으로 이동합니다.
- **공유 이력 정확도**: `ShareLink`는 사용자가 실제로 공유를 완료했는지 알려주지 않으므로,
  `ActivityShareSheet`(`UIActivityViewController` 래퍼)로 완료 콜백을 받아야만 `sharedTo`에 기록합니다.

## 알려진 제약 (스펙 섹션 6 그대로)

1. 스크린샷 촬영 실시간 감지 불가 → 앱을 열 때 스캔으로 우회
2. Notes 앱은 공식 저장 API가 없어 표준 공유 시트를 통한 수동 전달만 가능
3. Foundation Models는 A17 Pro 이상 + 지원 OS에서만 동작, 구형 기기는 폴백 품질 차이 발생
4. 인스타그램/카톡/표·그래프/웹툰 캡처 등에서 OCR·분류 정확도 추가 검증 필요
