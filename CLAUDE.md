# CLAUDE.md

This file provides repository-specific guidance to Claude Code when working with PasteClean.

## 먼저 읽을 것

작업 전에 [AGENTS.md](AGENTS.md)를 읽고 그대로 따르세요. 제품 정의, 계층별
책임과 의존 방향, SOLID 설계 원칙, 반드시 보존할 동작, UI·다국어 규칙,
검증 명령과 Git/PR 규칙의 단일 출처입니다.

설계 규칙을 바꿔야 하면 이 파일에 복제하지 말고 `AGENTS.md`를 수정하세요.
이 파일에는 Claude Code가 작업할 때 놓치기 쉬운 저장소 특성만 기록합니다.

## 테스트

테스트는 XCTest가 아니라 Swift Testing(`@Suite`, `@Test`, `#expect`)을
사용합니다. 전체 테스트 명령은 다음과 같습니다.

```bash
xcodebuild test -quiet \
  -project PasteClean.xcodeproj \
  -scheme PasteCleanTests \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

스위트 하나만 실행할 때 `-only-testing:`에는 `@Suite("줄바꿈")` 같은 표시
이름이 아니라 Swift 타입 이름을 사용하세요.

```bash
xcodebuild test -quiet \
  -project PasteClean.xcodeproj \
  -scheme PasteCleanTests \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:PasteCleanTests/CodeCleanerTests/LineEndings
```

표시 이름을 넣으면 오류 없이 스위트만 시작되고 테스트가 하나도 실행되지
않을 수 있으므로 실제 실행된 테스트 목록을 확인하세요.

## 타깃 구성

공용 프레임워크는 없습니다. 같은 소스 파일을 여러 타깃이 직접 컴파일합니다.

- `CodeCleaner.swift`: 앱, Xcode 확장 프로그램, 테스트 타깃
- `CleanPastedCodePlanner.swift`: Xcode 확장 프로그램, 테스트 타깃
- `ContentView.swift`, `CodeTextView.swift`: 앱 타깃
- `GuideView.swift`, `HelpMenu.swift`: 앱과 테스트 타깃
- `CleanPastedCodeCommand.swift`, `SourceEditorExtension.swift`: Xcode 확장
  프로그램 타깃

파일의 디렉터리만 보고 사용 타깃을 추정하지 말고 `project.pbxproj`의 Sources
Build Phase를 확인하세요.

## 저장소 특성 및 함정

- `PasteClean`과 `PasteCleanTests` 스킴은
  `PasteClean.xcodeproj/xcshareddata/xcschemes/`에서 저장소와 함께 관리합니다.
  `PasteClean` 스킴은 호스트 앱만 Release Archive 대상으로 유지해야 다른
  Mac에서도 내장 Xcode 확장 프로그램을 포함한 App Store Archive를 만듭니다.
- Xcode 확장 프로그램은 연결한 `XcodeKit.framework`를 `Embed & Sign`으로
  포함해야 합니다. 링크만 하면 빌드가 성공해도 설치 후 확장을 불러오지 못할
  수 있습니다. Archive와 내보낸 앱의 확인 경로는 [README.md](README.md)의
  배포 안내를 따르세요.
- `HelpMenu`는 SwiftUI가 메인 메뉴를 재구성하는 동작을 보완합니다. 표준
  도움말 항목과 메뉴 delegate가 사라지지 않도록 앱 시작 직후 재부착하고,
  메뉴 tracking 시점에도 다시 연결합니다. 실제 메뉴 검증 없이 단순한
  `.commands` 구현으로 교체하지 마세요.
- 가이드 시트는 모든 단계를 보이지 않게 배치해 가장 큰 단계의 높이를
  유지합니다. 시트 높이를 고정 숫자로 바꾸지 마세요.
- 앱 가이드 자동 표시는 `UserDefaults`에 최초 실제 표시 여부를 기록합니다.
  자동 표시는 한 번뿐이지만 도움말 메뉴를 통한 수동 표시는 계속 가능해야
  합니다.
- 편집기 두 패널의 헤더는 공용 `headerHeight`를 사용합니다. 한쪽만 수정해
  헤더 아래 구분선이 어긋나지 않게 하세요.
- 에디터 밖 공용 하단 푸터의 왼쪽에는 Input의 붙여넣기·정리 버튼을,
  오른쪽에는 Output의 `Indent Using`, `Widths`, `Tab`, `Indent` 설정을
  한 줄로 표시합니다. 최소 창 너비 980pt에서 잘리지 않아야 합니다.
- 들여쓰기 설정은 `@AppStorage`로 저장됩니다. 기본값과 달라지기 전에는
  preferences plist에 키가 없을 수 있습니다.
- `⌘V`는 포커스된 편집기의 기본 붙여넣기와 실행 취소를 보존합니다.
  Input 전체를 교체하고 정리하는 Paste 버튼에는 `⇧⌘V`를 사용하세요.
- Output은 사용자가 직접 편집할 수 있습니다. 설정만 변경했을 때 `clean()`을
  자동 실행해 편집 내용을 덮어쓰지 마세요.
- 편집기 패널 폭이 좁으면 긴 줄을 word wrap합니다. 긴 토큰이 다음 줄의
  0열로 내려가 들여쓰기가 사라진 것처럼 보여도 정리된 문자열 자체는 정상일
  수 있으므로, UI 표시와 실제 값을 구분해 확인하세요.

## 문서와 릴리스

- `VERSION.txt`는 모든 타깃의 `MARKETING_VERSION`과 일치시킵니다.
- 사용자 동작이 바뀌면 [CHANGELOG.md](CHANGELOG.md)와 필요한 경우
  [README.md](README.md)도 같은 변경에서 갱신합니다.
- 사용자에게 보이는 문자열은 `PasteClean/Localizable.xcstrings`에 영어와
  한국어 번역을 함께 추가하고 `jq empty`로 형식을 검증하세요.
