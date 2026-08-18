# 한끼로그 iOS

남아서 버리는 식재료를, 다음 한 끼로.

첫 자취생이 한 번 산 식재료를 끝까지 쓰도록 레시피 선택부터 식단 계획·장보기·조리·남은 재료 활용까지 연결하는 SwiftUI iPhone 앱입니다.

## 구성

```
ios/OneLog/       SwiftUI iPhone 앱과 Xcode 프로젝트
ios/tools/        식약처 레시피·판매 단위 빌드 타임 임포터와 검증 도구
ios/firestore.rules  Firebase Firestore 보안 규칙
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

## Firebase 기능

동네 나눔·채팅·약속 기능은 Firebase Anonymous Auth와 Firestore를 사용합니다. Firebase 설정이 없는 빌드에서도 기본 식단 기능은 동작하고, 나눔 화면과 계정 연결만 미연결 안내를 표시합니다.

```sh
firebase deploy --only firestore:rules
python3 ios/tools/check_firestore_rules.py
```

Google 로그인은 FirebaseAuth의 OAuth 흐름을 사용하며, 실제 OAuth 콜백과 GPS 권한·Firebase 실시간 동작은 실기기 확인이 필요합니다.

레시피를 다시 가져오려면 `ios/tools/.api_key`에 식품안전나라 API 키를 넣습니다. 해당 파일은 커밋하지 않습니다.

기능별 상태와 남은 작업은 [AGENTS.md](AGENTS.md)에 기록합니다.
