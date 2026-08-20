# 한끼로그 iOS

남아서 버리는 식재료를, 다음 한 끼로.

첫 자취생이 한 번 산 식재료를 끝까지 쓰도록 레시피 선택부터 식단 계획·장보기·조리·남은 재료 활용까지 연결하는 SwiftUI iPhone 앱입니다. 식단 수정 대화는 OpenAI Platform을 Firebase callable function 뒤에서 사용합니다.

## 구성

```
ios/OneLog/       SwiftUI iPhone 앱과 Xcode 프로젝트
ios/tools/        식약처 레시피·판매 단위 빌드 타임 임포터와 검증 도구
ios/firestore.rules  Firebase Firestore 보안 규칙
functions/        OpenAI Responses API를 호출하는 Firebase callable function
AGENTS.md         기획 해석 순서, 기능 우선순위, 구현 현황
```

## 실행

1. Xcode 26.1.1 이상에서 `ios/OneLog/OneLog.xcodeproj`를 엽니다.
2. `OneLog` scheme과 iPhone Simulator 또는 연결된 iPhone을 선택합니다.
3. 실행합니다.

첫 실행에는 온보딩 화면이 표시됩니다. 앱은 외부 레시피 API를 호출하지 않고 번들 JSON을 사용하며, 식단·수량·예산·재고 계산은 결정론적 Swift 코드가 담당합니다.

## 테스트

```sh
xcodebuild test \
  -project ios/OneLog/OneLog.xcodeproj \
  -scheme OneLog \
  -destination 'platform=iOS Simulator,name=iPhone 16e'
```

테스트 대상은 `OneLogTests` 도메인 테스트와 `OneLogUITests` 핵심 화면·식단 흐름 UI 테스트입니다.

2026-08-20 기준 도메인 56개와 핵심 UI 9개 시나리오가 통과했습니다. Firebase 규칙 27개 서버 왕복과 실제 App Check·OpenAI 종단 검증 결과는 `ios/qa/2026-08-20-production-readiness/REPORT.md`에 기록합니다.

## Firebase 기능

동네 나눔·채팅·약속 기능과 식단 AI 채팅 프록시는 Firebase를 사용합니다. iOS 앱은 Firebase callable function `aiChat`만 호출하고 OpenAI API 키를 포함하지 않습니다. Firebase 설정이 없는 빌드에서도 기본 식단 기능은 동작하고, 나눔 화면·계정 연결·AI 채팅은 미연결 안내를 표시합니다.

```sh
firebase deploy --only firestore:rules
python3 ios/tools/check_firestore_rules.py
```

### 식단 AI 채팅 배포

사용자가 가진 OpenAI Platform 키는 저장소나 iOS 앱에 넣지 말고 Firebase Secret에 등록합니다. Firebase CLI 로그인 후 아래를 한 번 실행하면 됩니다.

```sh
cd functions
npm install
cd ..
firebase functions:secrets:set OPENAI_API_KEY
firebase deploy --only functions:aiChat
```

`functions/index.js`는 후보 레시피 ID만 받아 Responses API의 구조화 JSON 응답을 사용합니다. 수량·판매 단위·예산은 AI가 계산하지 않고 기존 Swift 결정론적 계산기가 계속 담당합니다.

Google 로그인은 FirebaseAuth의 OAuth 흐름을 사용하며, 실제 OAuth 콜백과 GPS 권한·서로 다른 두 기기의 Firebase 실시간 동작은 출시 전 수동 확인 항목입니다.

## Apple 배포

Release 빌드는 App Attest와 production APNs entitlement를 사용합니다. 이 capability는 무료 Personal Team에서 발급되지 않으므로 TestFlight/App Store archive에는 유료 Apple Developer Program 팀이 필요합니다. Debug는 로컬 기기 설치를 위해 `OneLogLocal.entitlements`와 App Check debug provider를 사용하며, Release 보안 설정과 분리되어 있습니다.

유료 팀 전환 후 App ID에서 App Attest·Push Notifications를 켜고 APNs 키를 Firebase에 등록한 다음 새 Distribution 프로파일로 archive합니다.

레시피를 다시 가져오려면 `ios/tools/.api_key`에 식품안전나라 API 키를 넣습니다. 해당 파일은 커밋하지 않습니다.

기능별 상태와 남은 작업은 [AGENTS.md](AGENTS.md)에 기록합니다.
