# PasteClean App Store 출시 체크리스트

이 문서는 App Store Connect 제출 직전에 확인할 항목을 정리한 내부 체크리스트입니다.
Apple의 요구 사항과 라이선스 해석은 변경될 수 있으므로 제출 시점의 공식 안내와
필요한 경우 전문가의 검토를 함께 확인합니다.

## 공개 URL

- 개인정보처리방침: https://github.com/swift-man/PasteClean/blob/main/PRIVACY.md
- 지원 및 문의: https://github.com/swift-man/PasteClean/blob/main/SUPPORT.md
- 제품 및 소스 코드: https://github.com/swift-man/PasteClean
- LGPL 라이선스: https://github.com/swift-man/PasteClean/blob/main/LICENSE
- GPL 라이선스: https://github.com/swift-man/PasteClean/blob/main/COPYING

위 URL은 로그아웃 상태의 브라우저에서도 열리는지 확인합니다. 출시 태그를 만든
뒤에는 해당 버전의 소스를 가리키는 영구 링크도 릴리스 설명에 추가합니다.
Support URL은 위 지원 페이지를 사용하고, 공개 연락처가 실제로 수신 가능한지 제출
전에 확인합니다. 연락처가 바뀌면 `SUPPORT.md`와 App Store Connect의 URL 또는
메타데이터를 함께 갱신합니다.

## 앱 정보와 가격

- [ ] 앱 이름, 부제, 설명, 키워드가 독립 실행형 에디터와 Xcode 확장 프로그램을
      모두 정확히 설명한다.
- [ ] 기본 카테고리는 **Developer Tools**로 설정한다.
- [ ] 가격은 **무료**로 설정하고, 앱 내 구입이나 구독이 없음을 확인한다.
- [ ] 앱 기능과 배포 지역에 맞는 tax category를 선택한다.
- [ ] 판매 가능 국가·지역(Availability)을 확인하고 의도하지 않은 지역이 없는지
      검토한다.
- [ ] 조직 계정으로 대한민국 App Store에 배포한다면 **Availability in the
      Republic of Korea** 정보를 완료한다.
- [ ] 저작권의 권리자명과 연도가 앱 빌드 설정 및 App Store Connect에서 일치한다.
- [ ] Privacy Policy URL에는 위 개인정보처리방침 URL을 등록하고, Support URL에는
      연락 가능한 정보가 있는 공개 지원 URL을 등록한다.
- [ ] 앱 설명과 스크린샷에 지원하지 않는 기능 또는 자동 붙여넣기 동작을 암시하는
      문구가 없다.

## 개인정보와 법적 고지

- [ ] 실제 동작을 다시 확인한 뒤 App Privacy에서 **데이터를 수집하지 않음**으로
      답한다. 분석 SDK, 네트워크 전송 또는 새 데이터 수집 기능을 추가했다면 답변과
      `PRIVACY.md`를 함께 갱신한다.
- [ ] `LICENSE`, `COPYING`, `PRIVACY.md`가 아카이브된 앱의
      `Contents/Resources`에 포함되어 있다.
- [ ] `PrivacyInfo.xcprivacy`가 앱에 포함되고 `UserDefaults` 사용 사유
      `CA92.1`, 데이터 미수집 및 추적 안 함 선언이 실제 동작과 일치한다.
- [ ] LGPL 유지에 필요한 소스 제공과 고지 방식이 현재 배포 형태에 적합한지
      확인한다. Apple 표준 사용권 계약과 별도의 고지가 충돌하지 않는지 검토하고,
      필요하면 App Store Connect의 Custom EULA를 사용한다.
- [ ] 콘텐츠 권리 질문에 앱 아이콘, 스크린샷, 소스 코드 및 포함 구성요소의 권리를
      기준으로 정확하게 답한다.
- [ ] 연령 등급 설문을 실제 앱 콘텐츠에 맞게 완료한다.
- [ ] EU 배포 여부에 맞춰 DSA trader 상태와 연락처 표시 요구 사항을 완료한다.
- [ ] 무료 앱 계약을 포함한 최신 계약에 동의하고, Apple이 요구하는 세금 및 금융
      정보를 완료한다.

## 빌드와 제출

- [ ] `VERSION.txt`, 앱, 확장 프로그램, 테스트 타깃의 마케팅 버전이 일치한다.
- [ ] 앱과 확장 프로그램의 빌드 번호가 모두 일치하고 이전 업로드보다 높다.
- [ ] Release 아카이브의 주 제품이 `PasteClean.app`이며
      `Contents/PlugIns/PasteCleanExtension.appex`가 포함되어 있다.
- [ ] 앱과 확장 프로그램의 서명, Sandbox, Hardened Runtime 및 배포 프로파일이
      유효하다.
- [ ] `ITSAppUsesNonExemptEncryption` 값과 App Store Connect의 수출 규정 답변이
      실제 암호화 사용에 맞는다.
- [ ] 현재 macOS App Store가 허용하는 규격으로 한국어와 영어 스크린샷, 앱 아이콘,
      설명 및 프로모션 문구를 준비한다.
- [ ] App Review 담당자의 이름, 이메일과 검토 중 연락 가능한 전화번호를 입력한다.
      전화번호는 `+국가번호`를 포함한 국제 형식으로 작성한다.
- [ ] 자동 출시, 수동 출시 또는 단계적 출시 중 원하는 방식을 확인한다.

## App Review Notes

검토 메모에는 다음 내용을 간결하게 적습니다.

1. PasteClean은 자체 macOS 에디터로 바로 사용할 수 있습니다.
2. Xcode 확장 프로그램은 앱에 포함되어 있으며 별도 다운로드나 단축키가 필요하지
   않습니다.
3. 확장을 확인하려면 앱을 한 번 실행하고, macOS 시스템 설정에서 Xcode Source
   Editor 확장 프로그램의 PasteClean을 활성화한 다음 Xcode를 완전히 재시작합니다.
4. Swift 파일을 연 뒤 **Editor ▸ PasteClean ▸ Clean Pasted Code**를 선택합니다.
   선택 영역이 없으면 전체 파일을, 선택 영역이 있으면 해당 영역을 정리합니다.
5. 로그인, 계정, 테스트 자격 증명 및 네트워크 연결은 필요하지 않습니다.

## 최종 실제 기기 확인

- [ ] TestFlight 빌드를 개발에 사용하지 않은 Mac에 설치한다.
- [ ] 앱의 Input, Output, Paste, Clean, Copy, 들여쓰기 및 줄 번호 기능을 확인한다.
- [ ] 확장을 활성화하고 Xcode를 재시작한 뒤 단축키 없이 Editor 메뉴가 표시되는지
      확인한다.
- [ ] 선택 영역 정리, 선택 영역 없는 전체 파일 정리, 여러 선택 영역, `⌘Z`와 Xcode
      들여쓰기 설정 반영을 확인한다.
- [ ] 한국어와 영어, 최소 창 크기, 키보드 탐색 및 VoiceOver 레이블을 확인한다.
- [ ] About와 Help에서 개인정보처리방침, 라이선스와 지원 경로가 접근 가능한지
      확인한다.

## Apple 공식 참고 자료

- [App Privacy 관리](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [플랫폼 버전 정보와 Support URL](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
- [Privacy Manifest와 Required Reason API](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [필수·현지화·편집 가능 속성](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/)
- [App Review 제출 개요](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review/)
