# 한끼로그 iOS

SwiftUI iPhone 앱입니다. P0 식단/예산 흐름과 P1 장보기 실행·로컬 온보딩을 유지하면서, 식단 수정 AI 채팅은 Firebase callable function을 통해 OpenAI Platform과 연결합니다.

## 실행

1. Xcode 26.1.1 이상에서 `ios/OneLog/OneLog.xcodeproj`를 엽니다.
2. `OneLog` scheme과 iPhone Simulator 또는 연결된 iPhone을 선택합니다.
3. 실행합니다.

첫 실행에는 제공된 온보딩 화면이 표시되며 화면을 탭하면 완료 상태를 로컬에 저장하고 앱으로 들어갑니다. 앱 아이콘은 `AppIcon` asset catalog에 등록했습니다. 로컬 계산·영속성 단위 테스트는 `OneLogTests` target에 있고, 핵심 탭·식단 확정 흐름·AI 채팅 fixture UI 스모크 테스트는 `OneLogUITests` target에 있습니다. 장보기 화면에서는 품목 체크, 실제 구매 포장 수 수정, 목록 복사·공유, 구매 이벤트 기록과 구매 멱등 반영을 지원합니다. CLI에서는 다음처럼 테스트 번들을 만들 수 있습니다.

```sh
xcodebuild -project ios/OneLog/OneLog.xcodeproj \
  -scheme OneLog \
  -sdk iphonesimulator \
  -derivedDataPath /private/tmp/onelog-deriveddata \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing
```

위 `CODE_SIGNING_ALLOWED=NO`는 테스트 번들 컴파일 명령에만 한정한다. 앱 타깃 설정에는 저장하지 않는다. Simulator에서 FirebaseAuth를 실행할 때도 Xcode의 `Sign to Run Locally`가 만들어 주는 키체인 entitlement가 필요하다.

Personal Team 자동 서명을 설정한 뒤 `generic/platform=iOS` Debug 기기용 빌드와 서명된 앱 생성을 확인했습니다. 연결된 iPhone 14 Pro에 `devicectl`로 앱을 설치했습니다. Simulator 도메인 56개·핵심 UI 9개 시나리오와 나눔 화면 캡처 5장을 현재 검증 기준에 포함합니다.

Debug는 무료 Personal Team 설치를 위해 `OneLogLocal.entitlements`와 Firebase App Check debug provider를 사용합니다. Release는 `OneLogRelease.entitlements`의 production App Attest·APNs를 유지합니다. 무료 팀은 두 capability를 발급하지 않으므로 App Store/TestFlight archive는 유료 Apple Developer Program 팀으로 서명해야 합니다.

## 식단 AI 채팅

식단 만들기 6단계의 `식단 수정 AI 채팅` 카드에서 대화를 시작합니다. 앱은 현재 식단·선호·보유 재료와 로컬 후보 레시피를 Firebase callable function `aiChat`에 보내고, 함수가 OpenAI Responses API를 호출합니다. API 키는 앱에 저장하지 않습니다.

저장소 루트에서 Firebase CLI로 Secret을 등록하고 함수를 배포합니다.

```sh
cd functions
npm install
cd ..
firebase functions:secrets:set OPENAI_API_KEY
firebase deploy --only functions:aiChat
```

키 입력은 CLI의 비대화형 프롬프트에서만 하고 저장소 파일·`Info.plist`·UserDefaults에는 기록하지 않습니다. 배포 전에는 `node --check functions/index.js`로 함수 문법을 확인할 수 있습니다. 시뮬레이터 UI 테스트는 `-uiTestAIChat` fixture를 사용하므로 OpenAI 호출 없이 진입·제안·적용을 검증합니다.

실제 배포 왕복은 임시 App Check debug token을 등록해 `python3 ios/tools/check_backend_e2e.py`로 검증하고, 완료 즉시 토큰을 삭제합니다. 스크립트는 익명 인증·소분 요청 승인·OpenAI 실응답·재귀 삭제·계정 완전삭제까지 확인합니다.
