# 한끼로그 iOS

SwiftUI iPhone 앱입니다. 외부 인증·AI·가격 API 없이 P0 식단/예산 흐름과 P1 장보기 실행·로컬 온보딩을 먼저 검증합니다.

## 실행

1. Xcode 26.1.1 이상에서 `ios/OneLog/OneLog.xcodeproj`를 엽니다.
2. `OneLog` scheme과 iPhone Simulator 또는 연결된 iPhone을 선택합니다.
3. 실행합니다.

첫 실행에는 제공된 온보딩 화면이 표시되며 화면을 탭하면 완료 상태를 로컬에 저장하고 앱으로 들어갑니다. 앱 아이콘은 `AppIcon` asset catalog에 등록했습니다. 로컬 계산·영속성 단위 테스트 15개는 `OneLogTests` target에 있고, 핵심 탭·식단 확정 흐름 UI 스모크 테스트 2개는 `OneLogUITests` target에 있습니다. 장보기 화면에서는 품목 체크, 실제 구매 포장 수 수정, 목록 복사·공유, 구매 이벤트 기록과 구매 멱등 반영을 지원합니다. CLI에서는 다음처럼 테스트 번들을 만들 수 있습니다.

```sh
xcodebuild -project ios/OneLog/OneLog.xcodeproj \
  -scheme OneLog \
  -sdk iphonesimulator \
  -derivedDataPath /private/tmp/onelog-deriveddata \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing
```

Personal Team 자동 서명을 설정한 뒤 `generic/platform=iOS` Debug 기기용 빌드와 서명된 앱 생성을 확인했습니다. 연결된 iPhone 14 Pro에 `devicectl`로 앱을 설치하고 실행하는 데 성공했습니다. Simulator용 도메인·UI 테스트와 온보딩 화면 상호작용은 현재 검증 기준에 포함됩니다.
