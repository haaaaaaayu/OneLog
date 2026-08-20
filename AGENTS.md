# AGENTS.md

이 문서는 한끼로그 저장소에서 작업하는 모든 AI 코딩 에이전트의 최상위 지침이다. 하위 디렉터리에 더 구체적인 `AGENTS.md`가 있으면 그 범위에서는 하위 문서가 우선한다.

## 1. 기획 기준과 해석 순서

- 최상위 기획 원문: [한끼로그 통합기획서](https://app.notion.com/p/3bb192b603dc80eb8557f60e1597a783)
- 상위 Notion 페이지: [멋쟁이사자처럼 14기](https://app.notion.com/p/3b8192b603dc804d8bfcce0461b9acaf)
- 이 문서가 대조한 원문 시점: **2026-08-13 23:51 KST**
- UI·화면 상태·사용자 흐름 참고: [Figma 최종본](https://www.figma.com/design/BVikfm03WAbz6hGlDLqcxx/%EC%A0%9C%EB%AA%A9-%EC%97%86%EC%9D%8C?node-id=707-570). Figma는 Notion의 제품 원칙과 사용자가 확정한 공급자·데이터 경계를 바꾸지 않으며, `미사용 / 구버전`, `원본`, `비교` 프레임은 구현 요구사항으로 사용하지 않는다. 이 기준은 **2026-08-19 Figma 대조 후** 추가했다.

Notion 원문과 이 문서 또는 코드가 충돌하면 다음 순서로 판단한다.

1. Notion에서 `예산 기능 추가 버전`으로 표시된 최신 핵심 흐름
2. Notion의 서비스 개요, 문제 정의, 목표, 타깃, JTBD, 핵심 시나리오
3. 이 문서의 구현 원칙과 완료 조건
4. 현재 코드의 기존 동작

Notion의 `기존 시나리오 백업 (이 섹션은 참고하지 말것)` 블록은 요구사항 근거로 사용하지 않는다. 위치는 아래의 F25 사용자 확정 경계만 따른다.

### Figma 대조 메모

- 구현 기준 화면은 홈(713:884·713:1044), 온보딩(707:571·707:576·707:590·707:658·707:702·707:744·707:796), 동네 인증(789:26·790:26), 레시피(707:881·713:1562·713:1689·772:90·804:125·805:17), 식단 만들기(719:581·719:638·719:682·719:730·713:1880·713:1966·713:2036·713:2072·713:2088·713:2162·713:2262·713:2454·713:2492), 식단 관리(723:558·723:777·723:964·707:1667·723:1134), 재료소분(744:35·723:160·723:221·723:263·795:26), 설정·알림(792:26·798:26·799:26), 마이페이지(713:1214·713:1276·713:1307·713:1322·713:1339·713:1361) 그룹이다.
- Figma의 프레임명과 실제 화면 순서가 일부 어긋난다. 화면에서 확인되는 식단 만들기 1~11단계와 사용자 흐름을 우선하고, `원본`, `비교` 및 중복 프레임은 상태·기능 근거로 사용하지 않는다. 단, 713:2088·713:2162처럼 이름에 `미사용 / 구버전`이 붙어도 실제 화면 내용이 현재 10~11단계와 일치하면 프레임 이름이 아니라 화면 내용을 참고한다.
- 하단 탭 문구도 일부 프레임에서 `남은재료`로 보이지만, 앱의 기준 명칭은 `식단관리`이며 남은 재료는 식단 관리의 진입 화면으로 둔다. 네 번째 탭은 `재료소분`으로 표준화한다.

공동구매·소분(F26)과 채팅(F27)은 **2026-08-16 사용자 확정 요청**으로 구현에 들어갔다. 이때 함께 확정된 경계는 다음과 같다.

- 백엔드 공급자: **Firebase**(Firestore + Anonymous Auth). 다른 공급자로 바꾸려면 다시 확정을 받는다.
- 식단 수정 AI 채팅은 **OpenAI Platform**을 사용한다. OpenAI 키는 iOS 앱이나 웹 브라우저에 넣지 않는다. iOS는 Firebase callable function의 Secret, 웹은 2026-08-20 사용자 승인에 따라 같은 키를 Vercel Production의 민감 서버 환경변수로 보관한다. AI는 후보 레시피 선택과 대화만 담당하며 수량·판매 단위·가격·예산 계산은 결정론적 코드가 계속 담당한다.
- 위치: **2026-08-18 사용자 확정으로 GPS를 쓴다(F25 착수)**. 경계는 다음과 같다. ① `WhenInUse` 권한으로 필요할 때 1회만 읽고 추적하지 않는다. ② 서버에 올리는 값은 약 100m 격자로 반올림한 좌표뿐이다(`ShareCoordinate.rounded`). ③ 쓰임새는 이웃과의 **도보 시간 표시** 하나뿐이고, 직선 거리 ÷ 75m/분 가정이라 `도보 약 n분`으로 적는다. ④ 권한을 거부해도 동네 이름만으로 나눔 기능은 그대로 쓴다.

기획 원문이 모호하거나 서로 충돌하면 조용히 확정하지 않는다. 사용자 데이터, 금액 계산, 인증, 외부 연동, 위치 정보처럼 되돌리기 어려운 결정은 선택지와 영향을 먼저 제시한다.

## 2. 제품 정의

- 제품명: **한끼로그**
- 비전: **남아서 버리는 식재료를, 다음 한 끼로.**
- 정의: 첫 자취생이 한 번 산 식재료를 버리지 않고 끝까지 활용해 식비를 아끼도록 레시피 선택, 식단 계획, 장보기, 조리, 남은 재료 활용을 연결하는 AI 식사 플래너
- 주요 사용자: 요리가 익숙하지 않은 첫 자취 대학생과 사회초년생
- 핵심 JTBD: **“먹고 싶은 요리는 내가 고를게. 뭘 얼마나 사고, 남은 재료로 다음에 뭘 먹을지는 대신 계획해줘.”**
- Primary Goal: 사용자의 목표 식비 안에서 식단을 계획해 버리는 음식과 돈을 줄인다.
- Secondary Goals: 집밥 계획 부담, 중복 구매, 배달 의존을 낮추고 남은 식재료 활용과 꾸준한 집밥 습관을 높인다.
- 작업용 North Star Metric: 구매한 식재료 중 실제 식사에 사용된 비율. 실제 계측 정의가 확정되기 전에는 가정임을 표시한다.

한끼로그의 핵심 문제는 레시피 부족이 아니다. 한 끼에 필요한 양과 마트 판매 단위가 달라 재료가 남고, 남은 재료의 다음 사용 계획이 없어 식비와 식재료가 함께 낭비되는 문제다.

## 3. 제품 원칙

1. 사용자가 먹고 싶은 메뉴를 먼저 고른다. 추천은 선택지이며 AI가 식단을 일방적으로 확정하지 않는다.
2. 예산은 식단 생성의 필수 입력이다. 단, 가격 근거가 없는 금액을 임의로 만들어 예산 충족처럼 표시하지 않는다.
3. 식비 절약은 산 재료를 끝까지 활용하는 것이다.
4. 찜, 보유 재료, 재료 재사용, 불호 재료, 보유 조리도구, 끼니 특성을 함께 고려한다.
5. 아침 후보는 가벼운 메뉴라는 기획 조건을 반영하되, `가벼움`의 데이터 기준이 먼저 정의되어야 한다.
6. 냉장고 전체 입력을 강요하지 않는다. 현재 식단에 필요한 재료부터 확인한다.
7. 수량·단위·판매 단위·가격·예산·재고 차감은 결정론적 코드로 계산한다. 생성형 AI의 추측을 계산 결과로 사용하지 않는다.
8. 예상값, 대표값, 사용자 확인값을 구분하고 출처와 갱신 시점을 보존한다.
9. 식단이나 재고가 바뀌면 필요량, 구매량, 예상 지출, 잔여 예산, 예상 잔여량, 사용 예정일을 함께 다시 계산한다.
10. 불호와 알레르기·못 먹는 재료를 분리한다. 불호는 자동 추천에서 제외하되 직접 고른 레시피는 경고하고, 알레르기·못 먹는 재료는 자동 추천에서 완전히 제외한다.
11. 닉네임·생년월일·요리 숙련도·선호 조리 시간·보유 조리도구·거주지·계정 정보는 목적에 필요한 최소 범위만 수집하고 수정·삭제 경로를 둔다. 거주지·위치 인증은 확정된 F25 경계 안에서만 수집한다.
12. 홈·마이페이지의 절약 금액은 산정 정의가 확정된 경우에만 표시한다. `보유 재료로 아낀 구매 포장 금액`과 `외식 대비 절약액`을 혼용하지 않는다.

## 4. 기준 사용자 흐름

구현은 아래 퍼널을 기준으로 한다.

1. 첫 화면에서 Google 계정으로 가입하거나 기기 전용 계정으로 시작한다. 약관·개인정보 동의, 로그인 실패·재시도·대체 시작 경로를 제공한다.
2. 닉네임·생년월일·거주 동네·요리 숙련도·선호 조리 시간을 입력한다. 보유 조리도구, 불호 재료, 알레르기·못 먹는 재료를 별도로 선택하고, 위치 정보는 재료공유 흐름에서만 필요할 때 1회 사용한다.
3. 홈에서 오늘의 식단, 날짜별 식사 수, 예정·완료 상태, 식단 진행률, 장보기 진행률, 남은 재료 진입을 확인한다. 식단이 없으면 `새 식단 만들기`, 예정 식사가 있으면 요리 흐름으로 이동한다.
4. 레시피 탭에서 검색·조리 시간·난이도·요리 종류·끼니 필터로 탐색하고, 상세에서 재료·수량·조리 순서를 확인한다. 레시피를 찜하거나 날짜·끼니에 직접 담고, 찜 목록에서는 근거가 보이는 취향 요약을 제공한다.
5. `식단 만들기`에서 1~7일 기간과 날짜별 아침·점심·저녁, 목표 예산을 입력한다.
6. 시스템은 찜한 메뉴, 보유 재료, 재료 재사용, 예상 잔여량, 불호·알레르기, 조리도구, 끼니 특성, 확인 가능한 가격을 반영해 분석하고 3개의 식단안을 제안한다. 난이도는 명시적 메타데이터가 있을 때만 선택적 보조 기준으로 사용한다.
7. 사용자는 식단안을 비교하고 메뉴를 직접 교체·수정하거나 식단 수정 AI 채팅으로 후보를 확인한 뒤 하나를 선택한다. AI는 후보 ID와 설명만 반환하고 최종 선택·계산은 앱이 담당한다.
8. 확정 전 식단의 전체 재료를 정규화·합산하고, 냉장고 화면에서 현재 식단에 필요한 재료의 보유 여부·정확한 보유량·수량 미상을 추가·수정·삭제한다.
9. 보유량을 제외한 추가 필요량, 판매 단위 기준 구매량, 예상 잔여량을 계산한다. 판매 단위·가격이 없거나 단위가 충돌하면 사용자 확인으로 보낸다.
10. 가격 카탈로그에 근거가 있는 범위에서 예상 구매 비용, 제품이 채택한 정의에 따른 보유 재료 절감액, 확정 또는 미확정 잔여 예산을 보여준다. 사용자가 가격을 직접 입력하는 화면이나 Figma에 없는 독립 업그레이드 화면은 두지 않는다.
11. 최종 확정 후 장보기 리스트에서 필요량과 실제 구매량을 구분하고, 품목 체크·구매 포장 수 수정·복사·공유·장보기 완료를 지원한다. 구매 반영은 멱등 처리한다.
12. 식단 관리에서는 주간 식단, 날짜별 식사, 완료율, 장보기 진행률을 제공한다. 계획한 식사를 먹지 않았다면 다른 날짜·끼니로 미루기, 다른 메뉴로 교체, 오늘만 비활성화, 식단에서 삭제를 선택하고 관련 계산을 갱신한다.
13. 사용자는 레시피를 보며 요리하고, 완료 시 계획 수량을 멱등 차감한다. Figma에 없는 사용량 입력·토글 중간 화면은 두지 않는다. 요리 완료 후 사용한 재료와 남은 재료를 보여주고, 근거가 있는 보관 정보와 추가 구매 필요 여부를 반영해 다음 레시피를 추천한다.
14. 재료공유에서는 남은 재료를 소분·공동구매 글로 만들고, 동네 글 목록·도보 시간·분량·표시 금액·참여 인원을 확인한다. 요청 취소·정원 마감·상태 변경·멤버 전용 실시간 채팅·날짜·시간·장소 메모를 지원한다.

예산 계산은 가격 정보가 충분하지 않아도 식단·재료·재고 데이터를 손상시키지 않아야 한다. 사용자는 식단 제안을 모두 버리고 직접 구성할 수도 있어야 한다.

## 5. 기능 범위와 우선순위

### P0 — Figma 핵심 사용자 흐름

| ID | 기능 | 필수 결과 |
| --- | --- | --- |
| F00 | 앱 셸·홈 대시보드 | 온보딩 시작 화면, 홈·레시피·식단관리·재료소분 내비게이션, 오늘의 식단, 날짜별 식사 수, 완료율, 장보기·남은 재료 진입, 식단 생성·요리 진입 |
| F01 | 레시피 탐색·상세 | 검색, 조리 시간·난이도·요리 종류·끼니 필터, 재료·수량·조리 순서·인분 기준 확인 |
| F02 | 찜·찜 목록·취향 노트 | 레시피 저장·해제, 찜 목록, 찜 데이터를 근거로 한 결정론적 취향 요약, 식단 추천 반영 |
| F03 | 직접 식사 선택 | 날짜·끼니에 레시피 추가, 수정, 삭제, 레시피에서 요리 시작 |
| F04 | 재료 통합 | 별칭 정규화, 같은 단위 합산, 단위 충돌·사용자 확인 |
| F05 | 보유 재료·냉장고 관리 | 냉장고 화면에서 재료 추가·수정·삭제, 정확한 보유량·수량 미상 기록, 현재 식단에 필요한 재료 확인 |
| F06 | 구매량 계산 | 보유량 차감, 판매 단위 올림, 판매 단위 덮어쓰기, 예상 잔여량 |
| F07 | 장보기 리스트 | 필요량과 실제 구매량을 구분한 최종 목록, 가격·예산 요약, 품목 체크 |
| F08 | 요리 완료 | 계획 수량 기준 완료, 사용 결과, 멱등 재고 차감. Figma에 없는 사용량 입력 UI는 두지 않음 |
| F09 | 남은 재료 활용 | 먼저 사용할 재료, 근거 있는 보관 정보, 추가 구매 필요 여부, 다음 메뉴 추천·식단 추가 |
| F10 | 지난 식단 기록·절약 요약 | 누적 완료 식사, 기간별 식단 기록, 홈·식단 관리·마이페이지의 절약 요약 |
| F13 | 11단계 식단 생성 | 기간·날짜별 끼니·예산, 로딩이 보이는 분석, 3개 식단안, 수정·AI 채팅, 최종 확인, 전체 재료, 보유량, 카탈로그 가격 요약, 장보기 생성 |
| F15 | 보관 안내·남은 재료 우선순위 | 재료에 등록된 보관 문구, 남은 양·수량 상태, 다음 메뉴 추천 |
| F19 | 찜 기반 취향 노트 | 찜 목록의 저장 데이터에서 취향을 결정론적으로 요약하고 식단 추천에 반영 |
| F20 | 예산 기반 계획 | 목표 예산, 근거 있는 예상 구매 비용, 절감액 정의, 확정·미확정 잔여 예산 |
| F21 | 잔여 예산 재계산 | 결정론적 재계산 로직을 유지하되 Figma에 없는 독립 업그레이드 선택 UI는 노출하지 않음 |
| F22 | 주간 식단·미취식 처리 | 주간 한눈에 보기, 날짜별 상태·진행률, 미루기·메뉴 교체·오늘만 비활성화·삭제와 관련 계산 갱신 |

### P1 — 확정된 계정·실행·재료공유 흐름

| ID | 기능 | 필수 결과 |
| --- | --- | --- |
| F14 | 장보기 실행 지원 | 실제 구매 포장 수 수정, 복사·공유, 구매 이벤트, 정확 품목만 재고 반영, 멱등 처리 |
| F23 | 계정·온보딩 | Google·기기 전용 시작, 닉네임·생년월일·동네·실패·재시도·탈퇴·데이터 경계 |
| F24 | 프로필·선호·조리도구 | 요리 숙련도, 선호 조리 시간, 불호와 알레르기 분리, 보유 도구, 추천 반영 |
| F25 | 거주지·위치 | WhenInUse 1회 GPS, 약 100m 격자 좌표, 동네 이름 fallback, 도보 시간 표시만 사용 |
| F26 | 공동구매·소분 | 남은 재료 기반 글 작성, 품목·분량·상대 선택, 요청·취소·참여·정원·모집 상태, 표시 금액과 동네 목록 |
| F27 | 채팅·약속 | 멤버 전용 실시간 채팅, 요청 상태, 날짜·시간·장소 메모, 약속 생성·수정·삭제 |

F26·F27은 2026-08-16 사용자 확정 범위이다. Google OAuth, GPS 실측, Firebase 실시간 동작, OpenAI 실응답은 실기기·배포 검증 전까지 `부분 구현`으로 표시한다.

## 6. 현재 구현 현황

> 이 절은 실제 저장소 상태와 항상 일치해야 한다. 기능을 구현·수정·삭제한 에이전트는 작업 종료 전에 마지막 갱신일, 기능 상태, 검증, 변경 이력을 갱신한다. 계획이나 기획 문구만으로 완료 처리하지 않는다.

마지막 갱신: **2026-08-20**

### 전체 상태

- 기술 스택: iOS는 SwiftUI·Swift·Xcode 26.1.1과 firebase-ios-sdk 12.17.0(FirebaseAuth, FirebaseFirestore, FirebaseFunctions)을 사용한다. 모바일 웹 미러는 `web/`의 Next.js 16.3.1·React 19·Tailwind CSS 4로 구성한다. iOS OpenAI 호출은 루트 `functions/`의 Firebase callable function, 웹 OpenAI 호출은 Vercel Route Handler가 맡는다
- Firebase 설정 절차: `GoogleService-Info.plist`(프로젝트 `onelog-21cb6`)는 저장소와 타깃 리소스에 있다. 익명 로그인·Google 제공업체, App Check API, 강화한 `ios/firestore.rules`, Functions 10개와 `OPENAI_API_KEY` Secret 배포를 완료했다. 현재 규칙 서버 왕복 27개와 임시 App Check debug token을 쓴 Firebase·OpenAI 종단 테스트가 모두 통과했고, 임시 토큰은 테스트 직후 삭제했다. iPhone 14 Pro와 `OneLog-Figma393` Simulator에는 각각 전용 Debug token을 등록·로컬 저장했으며 저장소에는 넣지 않았다. plist가 없으면 Firebase 기능에 미연결 안내를 띄우고 로컬 식단 흐름은 계속 동작한다
- Google 로그인 방식: `GoogleSignIn-iOS` SPM 9.2.0의 네이티브 `GIDSignIn` 흐름으로 Google 계정을 인증한 뒤, ID token·access token으로 Firebase `GoogleAuthProvider` credential을 만든다. 최신 Firebase 콘솔 plist의 `CLIENT_ID`·`REVERSED_CLIENT_ID`를 `OneLogApp/GoogleService-Info.plist`에 반영했고, `OneLogApp/Info.plist`에는 `REVERSED_CLIENT_ID`와 기존 `app-1-668539294331-ios-eecf800525f29b3e2b88de`(GOOGLE_APP_ID의 `:`를 `-`로 바꾼 값) 두 콜백 scheme을 등록했다. SwiftUI의 `.onOpenURL`와 명시적 `UIApplicationDelegate`에서 `GIDSignIn.sharedInstance.handle(url)`와 `Auth.auth().canHandle(url)`를 호출하며, `FirebaseAppDelegateProxyEnabled`를 끄고 delegate adaptor를 사용한다. 등록이 어긋나면 `AppStore.isGoogleSignInConfigured`가 호출 전에 막는다. 앱 타깃은 Simulator에서도 로컬 코드 서명을 유지해야 FirebaseAuth 키체인 entitlement가 들어간다
- 형태: `ios/OneLog`의 SwiftUI 앱은 UserDefaults와 Firebase를 사용한다. `web/`은 iOS 최종 UI와 핵심 상호작용을 393pt 모바일 캔버스로 미러링하며 브라우저 로컬 상태를 사용한다. 두 구현은 저장 데이터를 자동 동기화하지 않는다
- 구현 기준선: iOS 네이티브 앱을 원본 구현으로 유지하고, `web/` 모바일 웹 미러를 별도 배포한다. P0 현재 UI 흐름(F00~F10·F13·F15·F19~F22), P1 F14·F23~F27, 식단 수정 AI 채팅을 기준으로 한다.
- 남은 검증 공백: Google OAuth 실제 콜백, GPS 권한·좌표, 서로 다른 두 실기기의 Firebase 나눔·채팅 실시간 동작은 별도 수동 확인이 필요하다. 배포된 `aiChat`의 실제 OpenAI 응답은 서버 종단 테스트로 확인했다. App Store/TestFlight archive는 현재 Personal Team이 App Attest·Push Notifications capability를 발급하지 않아 유료 Apple Developer Program 팀 전환이 필요하다
- 레시피 데이터: `ios/tools/import_recipes.py`가 식품안전나라 `COOKRCP01`(1,156건)을 빌드 타임에 변환해 `Resources/imported_recipes.json`(950건)과 `Resources/imported_ingredients.json`(1,300종)으로 굽는다. 앱은 외부 API를 호출하지 않고 번들 JSON만 읽는다. 인증키는 `ios/tools/.api_key`(gitignore)에 두고 커밋하지 않는다. 공공누리 출처 표시는 마이페이지에 노출한다.
- 판매 단위 정책: 대표 판매 단위는 `ios/tools/sale_units.json`(마트 소포장 기준 **대표값** 658종)에서 온다. 임포터는 이름을 **뒤에서부터** 맞춘다(`빨강 파프리카` → `파프리카`, `표고버섯마른것` → `표고버섯`). 앞에서 맞추면 `현미유`가 `현미`가 되는 식으로 다른 재료가 되므로 접두 매칭은 쓰지 않는다. 한 글자 이름은 꼬리 매칭에서 뺀다. 여기 없는 재료는 `representativeSaleUnit`이 없고, 구매량을 계산하지 않고 `precision == .manual`로 사용자 확인을 요청하며 예산도 `확정 잔여 예산`으로 표시하지 않는다. 사용자는 장보기 화면에서 대표 판매 단위를 언제든 덮어쓸 수 있다(`packageOverrides`).
- 단위 환산: `CanonicalIngredient.unitGrams`에 **명시된 단위끼리만** 환산한다(예: 양파 `["개": 200, "g": 1]`). 근거가 없으면 환산하지 않고 수동 확인으로 보낸다. 식약처 데이터가 g 표기라 큐레이션 재료의 `개`·`큰술` 판매 단위와 맞물리려면 이 표가 필요하다.
- 계산 완결성: `fullyCalculableRecipeIDs`가 실제 장보기 계산기를 돌려 판정한다. 현재 **956개 중 719개**가 구매량까지 계산되며, 탐색 화면의 `구매량 계산 가능` 필터와 카드 배지로 구분한다.
- 검증 기준선: 2026-08-20 최종 재감사에서 Figma 활성 화면과 iOS 런타임 캡처 54장을 393×852로 나란히 대조했다. 동네 확인·장보기·재료소분의 Figma 비포함 UI를 제거한 뒤 변경 화면 집중 캡처 테스트 3/3과 최종 재캡처 2/2가 모두 통과했다. 웹은 공개 루트 최초 진입 누락을 추가로 발견해 노란 스플래시·로그인·온보딩 1/3~3/3을 재구현하고, 온보딩 6개와 핵심 8개 화면을 Figma와 393×852로 다시 대조했다. 후속 iPhone Safari 감사에서 실제 Firebase Web Auth, 기기 전용 시작, 짧은 높이 문서 스크롤, safe-area, 탭·라우트·식단 단계 스크롤 초기화, 소분 작성, 프로필 저장, 채팅 접근성을 보완했다. 같은 날 웹 최종본의 visible top-level frame 50개를 다시 인벤토리화해 공통 헤더·마이페이지 중앙 정렬, 동네 인증, 설정·알림, 소분 요청·채팅, 미취식 변경, 웹 식단 12/12 표시를 보정했다. 393×852·393×667 브라우저 조작, lint·production build, Production Google 인증 진입·실제 OpenAI 구조화 응답을 통과했고 `https://onelog-web.vercel.app`에 재배포했다. 전체 iOS 회귀는 사용자 요청에 따라 반복하지 않았다. 상세 결과는 `ios/qa/2026-08-20-final-audit/REPORT.md`, `ios/qa/2026-08-20-production-readiness/REPORT.md`, `web/qa/REPORT.md`, `web/qa/2026-08-20-ui-repair/REPORT.md`, `web/qa/2026-08-20-iphone-safari-audit/REPORT.md`에 있다

### 모바일 웹 구현 현황

`web/`은 iOS 화면을 수정하지 않고 별도 구현한 모바일 전용 Next.js 앱이다. 온보딩, 홈, 레시피 검색·필터·찜, 최종 웹 Figma 표시 기준 12단계 식단 생성, 로딩 상태, AI 채팅, 식단관리·요리·완료·남은 재료, 장보기, 재료소분 선택·요청·채팅, 동네 인증, 설정·알림, 편집 가능한 마이페이지 화면과 핵심 CTA를 제공한다. Production은 `https://onelog-web.vercel.app`이며, 기존 Firebase `OPENAI_API_KEY` Secret을 Vercel의 민감 환경변수로 재사용한다. 웹 로그인은 Firebase Web App `1:668539294331:web:55624cd797157a042b88de`의 Google OAuth와 Anonymous Auth를 사용하고 Production 도메인을 Auth 허용 도메인으로 등록했다. 세션이 없으면 브라우저 로컬 온보딩 플래그만으로 홈을 열지 않는다. 웹 Route Handler는 OpenAI Responses API의 JSON Schema 출력에서 카탈로그 후보 ID만 허용하고 장애 시 결정론적 후보로 복구한다. 웹 상태는 브라우저 로컬·화면 상태이며 iOS UserDefaults·Firebase 나눔 데이터와 자동 동기화하지 않는다. 검증 자료는 `web/qa/REPORT.md`와 `web/qa/2026-08-20-iphone-safari-audit/REPORT.md`에 있다.

### iOS 네이티브 구현 현황

`ios/OneLog`에 독립적인 SwiftUI iPhone 앱을 유지한다. 레시피 데이터는 번들 JSON으로 읽고, 식단 수정 AI는 Firebase callable function 뒤의 OpenAI Platform을 사용한다. 식단 생성에 쓰는 가격은 번들 가격 카탈로그에서 읽으며 사용자가 가격을 입력하는 화면은 노출하지 않는다. 식단·수량·예산·재고 계산은 `PlannerEngine.swift`의 결정론적 코드가 담당한다.

| 범위 | 상태 | 구현 위치 | 검증·미완료 |
| --- | --- | --- | --- |
| F00 앱 셸·홈 대시보드 | 완료 | `Views/RootView.swift`, `Views/HomeView.swift` | 4개 탭, 홈의 오늘 식단·날짜별 식사·요리 완료 수·식단 생성 진입을 구현했다. 홈·탭 접근성 UI 스모크 테스트를 통과했다. 절약 금액의 기간·정의 정합성은 F10에 남긴다 |
| F01~F09 P0 기본 흐름 | 완료 | `ios/OneLog/OneLogApp/Views`, `PlannerEngine.swift`, `AppStore.swift`, `OneLogUITests.swift` | 2026-08-19 iPhone 16e Simulator에서 도메인 41개·UI 7개·캡처 2개가 통과했다. 여러 단위 재고 합산·환산 차감, 중복 재료 조리 행 병합, 식단 실행 단위 장보기 멱등성을 회귀 테스트로 검증했다. 판매 단위 미확인 품목은 사용자 확인으로 보낸다 |
| F14 장보기 실행 지원 | 완료 | `Views/ShoppingView.swift`, `Models.swift`, `AppStore.swift`, `PlannerEngine.swift` | Figma 장보기 화면에는 품목 체크와 `장보기 완료`만 노출한다. 실제 구매 포장 수 수정, 구매·실행 이벤트와 멱등 재고 반영을 유지하며 복사·공유·냉장고 이동은 완료 버튼의 context menu·VoiceOver action으로 제공한다. 변경 화면 집중 Simulator 테스트를 통과했다 |
| F23 로컬 온보딩 | 완료 | `Views/OnboardingView.swift`, `Models.swift`, `AppStore.swift`, `Assets.xcassets` | 첫 실행 온보딩, 기기 전용 시작, 닉네임·생년월일·숙련도·선호 조리 시간·동네·불호·알레르기·조리도구 저장을 구현하고 시뮬레이터 UI 테스트·Personal Team 기기 설치를 확인했다. Google OAuth 실기기 콜백과 재료공유 GPS 실측은 기능별 F23·F25에 남긴다 |
| F13 다일 식단 제안 | 완료 | `Views/PlanView.swift`, `PlannerEngine.swift` | 피그마 식단 만들기 1~11단계(기간·끼니·예산·로딩이 보이는 분석·3안·수정·최종 확인·전체 재료·보유량·카탈로그 가격 요약·장보기)를 연결했다. 사용자 가격 입력과 별도 업그레이드 화면은 제거했고, 가격·판매 단위가 모두 있는 레시피만 자동 식단 후보로 사용한다. 제보 화면 전용 Simulator 캡처와 Figma 대조를 통과했다 |
| F13-AI: 식단 수정 AI 채팅 | 부분 구현 | iOS: `AIChat.swift`, `Views/AIChatView.swift`, `Views/PlanView.swift`; Firebase: `functions/index.js` | Secret 뒤의 Responses API 구조화 후보와 Swift 계산 경계를 유지한다. callable 지역을 명시하고 오류 코드를 사용자 메시지로 분류한다. 서버 종단 및 `OneLog-Figma393` 실제 대화에서 OpenAI 답변·후보 3개를 확인했다. 최종 Release 서명과 실기기 대화 화면 수동 확인이 남았다 |
| F10 지난 식단 기록·절약 요약 | 완료 | `Views/MealsView.swift`, `Views/HomeView.swift`, `Views/MyPageView.swift`, `AppStore.swift` | 현재 월에 완료한 식사의 완료 당시 사용자 확인 가격 기반 보유 재료 절감액만 합산한다. 계획 식사와 임의 외식 대비 금액은 포함하지 않는다 |
| F15 보관 안내·남은 재료 우선순위 | 완료 | `Models.swift`, `SeedData.swift`, `Views/FridgeView.swift`, `Views/MealsView.swift` | 근거 보관 문구와 사용자가 직접 확인한 구매·개봉·표시 기한을 저장하고, 임박 재료를 추천 우선순위와 이유에 반영한다. 안전 여부는 추정하지 않는다 |
| F19 찜 기반 취향 노트 | 완료 | `Views/RecipeHomeView.swift` | 찜 목록의 요리 종류·카테고리·조리 시간에서 결정론적으로 요약한다. 화면 문구가 `AI 취향 노트`여도 외부 AI·학습 모델을 호출하지 않는다 |
| F20 예산 기반 계획 | 완료 | `Views/PlanView.swift`, `PlannerEngine.swift`, `Models.swift`, `Resources/ingredient_prices.json` | 번들 가격 카탈로그·보유 재료 절감·잔여 예산을 결정론적으로 계산한다. 식단 생성 화면에는 사용자 가격 입력을 두지 않고 카탈로그 구매 요약만 표시한다 |
| F21 잔여 예산 업그레이드 | 완료 | `PlannerEngine.swift` | 재계산 로직은 유지하지만 Figma에 없는 독립 업그레이드 선택 UI는 노출하지 않는다 |
| F22 미취식 처리 | 완료 | `Views/MealsView.swift`, `AppStore.swift` | 피그마 일정 변경 화면에서 삭제·날짜/끼니 이동·메뉴 교체·오늘만 비활성화를 고르고, 건너뛴 끼니는 재료를 차감하지 않으며 완료한 끼니는 멱등 보호한다 |

`완료` 표시는 네이티브에서도 핵심 화면 흐름을 실제 iPhone Simulator 또는 기기에서 확인한 뒤로 미룬다.

### 기능별 상태

> 아래 표에는 현재 UI에 존재하는 기능만 기록한다. F14는 P1 실행 완성도 범위로 iOS 구현을 진행한다.

| ID | 기능 | 상태 | 구현 위치 | 검증·미완료 |
| --- | --- | --- | --- | --- |
| F00 | 앱 셸·홈 대시보드 | 완료 | `ios/OneLog/OneLogApp/Views/RootView.swift`, `Views/HomeView.swift` | 홈·레시피·식단관리·재료소분 4개 탭, 오늘 식단·요리 완료 수·식단 생성 진입을 구현했다. 홈·탭 UI 스모크 테스트를 통과했다. 절약 요약의 기간·정의 정합성은 F10에 남긴다 |
| F01 | 레시피 탐색 | 완료 | `ios/OneLog/OneLogApp/SeedData.swift`, `Resources/imported_recipes.json` | 큐레이션 6건 + 식약처 변환 950건 = 956건. 대표 판매 단위가 없는 재료는 구매량·예산을 만들지 않고 사용자 확인으로 보낸다. iPhone 16e Simulator 전체 화면 검증 통과 |
| F02 | 찜·찜 목록·취향 노트 | 완료 | `ios/OneLog/OneLogApp/Views/RecipeHomeView.swift`, `AppStore.swift` | UserDefaults 저장·해제, 찜 목록, 찜 데이터 기반 결정론적 취향 노트를 구현했다. `AI 취향 노트` 문구는 외부 AI 호출을 의미하지 않는다 |
| F03 | 직접 식사 선택 | 완료 | `ios/OneLog/OneLogApp/Views/RecipeHomeView.swift`, `MealsView.swift`, `AppStore.swift` | 날짜·끼니 지정, 수정·삭제, 중복 방지 |
| F04 | 재료 통합 | 완료 | `ios/OneLog/OneLogApp/PlannerEngine.swift` | 별칭·합산·단위 충돌 테스트 |
| F05 | 보유 재료·냉장고 관리 | 완료 | `ios/OneLog/OneLogApp/Views/FridgeView.swift`, `Views/ShoppingView.swift`, `Models.swift` | 냉장고 화면에서 재료 추가·수정·삭제, 정확 수량·수량 미상 기록, 장보기·남은 재료 추천 연결 |
| F06 | 구매량 계산 | 완료 | `ios/OneLog/OneLogApp/PlannerEngine.swift`, `AppStore.swift` | 판매 단위 올림, 잔여량, 사용자 수정값 검증 |
| F07 | 장보기 리스트 | 완료 | `ios/OneLog/OneLogApp/Views/ShoppingView.swift`, `PlannerEngine.swift` | 필요량·구매량 분리, 구매 재고 반영 |
| F08 | 요리 완료 | 완료 | `ios/OneLog/OneLogApp/Views/MealsView.swift`, `PlannerEngine.swift`, `AppStore.swift` | Figma에 없는 사용량 입력·토글 화면 없이 계획 수량으로 바로 완료하고, 결과 화면과 중복 완료 멱등 처리를 제공한다 |
| F09 | 남은 재료 추천 | 완료 | `ios/OneLog/OneLogApp/Views/MealsView.swift`, `PlannerEngine.swift` | 활용·추가 구매·이유·미니 장보기 |
| F10 | 지난 식단 기록·절약 요약 | 완료 | `ios/OneLog/OneLogApp/Views/MealsView.swift`, `Views/HomeView.swift`, `Views/MyPageView.swift`, `AppStore.swift` | 현재 월 완료 이력의 사용자 확인 가격 기반 보유 재료 절감액만 합산한다 |
| F13 | 다일 식단 제안 | 완료 | `ios/OneLog/OneLogApp/Views/PlanView.swift`, `PlannerEngine.swift` | 피그마 식단 만들기 1~11단계와 연결했다. 1~7일·날짜별 끼니·여러 안·예산·불호·알레르기·도구·가벼운 아침·재료 재사용을 구현했다. iPhone 16e Simulator 전체 흐름 통과 |
| F13-AI | 식단 수정 AI 채팅 | 부분 구현 | iOS: `ios/OneLog/OneLogApp/AIChat.swift`, `Views/AIChatView.swift`, `Views/PlanView.swift`; Firebase: `functions/index.js` | fixture UI·배포된 OpenAI 종단·`OneLog-Figma393` 실제 대화를 통과했다. Simulator 전용 App Check token은 로컬에만 저장하며, Release 배포와 실기기 대화 화면 수동 확인이 남았다 |
| F14 | 장보기 실행 지원 | 완료 | `ios/OneLog/OneLogApp/Views/ShoppingView.swift`, `AppStore.swift`, `PlannerEngine.swift` | Figma에는 체크·완료 CTA만 보이며 복사·공유·냉장고 이동은 완료 버튼의 context menu·VoiceOver action으로 제공한다. 실제 구매 포장 수 수정·이벤트 기록·정확 품목 재고 반영·멱등 처리를 구현했고 도메인 및 집중 시뮬레이터 검증을 통과했다 |
| F15 | 보관 안내·남은 재료 우선순위 | 완료 | `ios/OneLog/OneLogApp/Models.swift`, `SeedData.swift`, `Views/FridgeView.swift`, `Views/MealsView.swift` | 사용자 확인 구매·개봉·표시 기한과 근거 보관 문구를 보존하고 임박 재료를 우선 추천한다. 기존 저장 데이터 하위호환과 우선순위 테스트 통과 |
| F19 | 찜 기반 취향 노트 | 완료 | `ios/OneLog/OneLogApp/Views/RecipeHomeView.swift` | 찜한 레시피의 요리 종류·카테고리·조리 시간에서 결정론적으로 요약한다 |
| F20 | 예산 기반 계획 | 완료 | iOS: `Views/PlanView.swift`, `PlannerEngine.swift`, `Models.swift`, `Resources/ingredient_prices.json` | 목표 예산, 카탈로그 기반 예상 지출·보유 재료 절감·잔여 예산을 구현했다. 사용자 가격 입력 UI는 제거했다 |
| F21 | 잔여 예산 업그레이드 | 완료 | iOS: `PlannerEngine.swift` | 결정론적 재계산 로직만 유지하며 Figma에 없는 별도 업그레이드 화면은 노출하지 않는다 |
| F22 | 미취식 처리 | 완료 | iOS: `Views/MealsView.swift`(`MealChangeView`), `Models.swift`(`MealStatus.skipped`) | 미루기·메뉴 교체·오늘만 비활성화·삭제를 한 화면에서 고르고, 이동·교체 시 날짜·끼니 충돌과 계산 갱신을 막는다 |
| F23 | Google 계정·온보딩 | 부분 구현 | iOS: `Views/OnboardingView.swift`, `Views/PreferencesView.swift`, `Models.swift`, `AppStore.swift` | 시작 화면 → 계정 → 프로필 → 불호·알레르기·조리도구 온보딩, 기기 전용 계정, 닉네임·생년월일·숙련도·선호 조리 시간·동네 저장, 연결 해제(데이터 유지), 탈퇴(전체 삭제), 실패 안내·재시도 구현. 동네 온보딩은 현재 수동 입력이며 GPS는 F25 공유 흐름에서만 요청한다. Google 로그인은 `GoogleSignIn-iOS`의 ID/access token을 Firebase credential로 교환하고 익명 계정 위에 `link`한다. 콜백 스킴·Firebase 콘솔 제공업체·Simulator 키체인 entitlement를 반영했지만 **Google 계정 선택 뒤 Firebase 연결 완료와 실기기 로그인 확인이 남았다.** |
| F24 | 프로필·선호·조리도구 | 완료 | iOS: `Views/PreferencesView.swift`(`MyPageView`, `PreferenceSections`), `Models.swift`, `PlannerEngine.swift` | 닉네임·생년월일/나이·숙련도·선호 조리 시간·불호 재료·알레르기·불호 메뉴·조리도구 수정과 마이페이지 진입을 구현했다. `isRecommendable()`이 알레르기·불호·도구 자동 추천 필터를 단일 경로로 판정하고, 직접 고른 메뉴는 삭제하지 않고 경고한다. UI 테스트 통과 |
| F25 | 거주지·위치 | 부분 구현 | iOS: `LocationProvider.swift`, `Sharing.swift`(`ShareCoordinate`·`walkingMinutes`), `Views/NeighborhoodSheet.swift`, `Info.plist`, `ios/firestore.rules` | 최종본 789:26·790:26의 동네 검색→확인 2단계를 구현했다. 확인 화면은 Figma의 비식별 격자·반경·핀만 보여주지만 검색은 Apple 로컬 검색을 사용하며, `현재 위치로 찾기`를 누를 때만 WhenInUse 1회 측정 후 약 100m 격자로 반올림한다. 거부해도 동네 이름 검색으로 동작한다. 도보 시간·반올림·하위호환 도메인 테스트와 집중 UI 테스트 통과. 실기기 권한 팝업과 실제 좌표 확인은 미완료 |
| F26 | 공동구매·소분 | 부분 구현 | iOS: `Sharing.swift`, `ShareStore.swift`, `Views/ShareView.swift`, `ios/firestore.rules` | 참여 요청과 실제 멤버를 분리하고 callable 승인·정원·신고·차단·재귀 삭제를 구현했다. 강화 규칙 27개와 실제 서버 승인 종단 테스트가 통과했고 iPhone 14 Pro에서 재료소분 목록 진입을 확인했다. 서로 다른 두 실기기 왕복만 남았다 |
| F27 | 채팅·일정 | 부분 구현 | `Sharing.swift`, `ShareStore.swift`, `Views/ShareView.swift`, `ios/firestore.rules` | 멤버 전용 실시간 채팅·약속 CRUD·신고·푸시 trigger를 배포했다. 보안 규칙·UI·서버 종단 검증은 통과했고 서로 다른 두 실기기 실시간 송수신과 APNs 수신만 남았다 |

상태 값은 `미착수`, `진행 중`, `부분 구현`, `완료` 중 하나만 사용한다. `완료`는 요구사항, 관련 테스트, 사용자 흐름 검증이 모두 끝난 경우에만 사용한다.

### 최근 변경 이력

최신 항목을 위에 추가한다. 코드·스키마·설정·의존성·기능 범위·검증 결과가 달라진 작업은 반드시 기록한다.

| 날짜 | 변경 내용 | 관련 기능 | 검증 | 남은 작업 |
| --- | --- | --- | --- | --- |
| 2026-08-20 | 웹 최종 UI 제보를 반영해 Figma 최종 페이지의 visible top-level frame 50개를 다시 인벤토리화하고 공통 36px 뒤로가기·18px 제목, 마이페이지 중앙 아바타, Google 첫 화면, 동네 인증, 설정·알림, 소분 선택→요청→채팅, 미취식 변경, 식단 12/12 화면을 보정했다. Firebase 세션이 없으면 과거 로컬 플래그와 무관하게 로그인부터 시작하도록 인증 관찰 경계를 수정하고 달력 월·날짜, 프로필 사진, 재요청, 실제 계정 삭제까지 연결했다 | 모바일 웹 F00, F13, F22~F27 | lint·production build 통과. Codex 인앱 브라우저에서 393×852·393×667 로그인/스크롤/고정 CTA/탭/프로필/식단/동네/설정/소분 흐름과 콘솔 오류 0건을 확인했다. Production 프로필 중심 x=197px(화면 196.5px), Google 인증 iframe 진입, 실제 OpenAI `source: openai` 응답을 확인하고 `https://onelog-1pyl98n0c-bodleims-projects.vercel.app`를 `https://onelog-web.vercel.app`에 alias했다 | 실제 Google 계정 선택·OAuth 콜백 완료와 물리 iPhone 1회 수동 확인 |
| 2026-08-20 | 웹 iPhone Safari 감사를 바탕으로 Google 버튼을 실제 Firebase Web Auth에 연결하고 기기 전용 시작을 추가했다. 온보딩 고정 높이·스크롤 차단을 제거하고 safe-area·44pt 터치 대상·확대 허용을 적용했으며, 탭·라우트·식단 단계의 스크롤 위치를 초기화했다. 잘못 연결된 소분 CTA를 작성·완료 흐름으로 바꾸고 식단관리·소분 마이페이지, 프로필 편집 저장, 채팅 접근성 이름을 연결했다. 날짜·끼니 선택, 주간 식단, 제외 재료 직접 추가, 남은 재료 추천, 요청 거절의 무동작 버튼도 실제 상태·라우트로 연결했다 | 모바일 웹 F00, F13, F23~F27 | lint 오류 0, production build 통과, 393pt 모바일 캔버스에서 짧은 높이 온보딩 최대 스크롤·탭 `132→0`·식단 8→9단계 `132→0`·소분 작성/완료·프로필 저장·채팅 전송과 무동작 버튼 회귀 통과. Firebase Web App·Production 허용 도메인을 구성하고 Vercel deployment `dpl_GfRuZQQFLuy7S8FDkA75uVtKwXCr`를 `https://onelog-web.vercel.app`에 alias했다. Production Google 인증 진입·콘솔 오류 0과 iOS 26.1 Simulator Safari(WebKit) 로그인·온보딩 safe-area 렌더링을 확인했다 | 사용자 Google 계정 선택·OAuth 콜백 완료와 물리 iPhone 1회 수동 확인 |
| 2026-08-20 | 공개 웹 루트가 Figma에 없는 흰 배경 소개 화면으로 시작하던 문제를 교정했다. 최초 진입을 노란 스플래시→Google 로그인→1/3~3/3 온보딩으로 복원하고, 로고를 30px로 축소하던 selector·제목 굵기·AI 채팅 화면 순서를 수정했다. 웹폰트는 9.9MB→202KB subset, 레시피 초기 이미지는 약 13MB→828KB WebP로 최적화했다 | 모바일 웹 최초 진입, F00, F13-AI, F23 | 온보딩 6개·핵심 8개 393×852 Figma 병렬 비교, lint·production build, Production 스플래시·로그인·홈·AI 캡처, 실제 OpenAI `source: openai` 통과. `https://onelog-web.vercel.app`의 deployment `dpl_HRd1VuKRn3tS39j47gzoajf24K2b` 배포 | 웹 상태와 iOS/Firebase 데이터 자동 동기화는 기존 경계 유지 |
| 2026-08-20 | iOS 최종 UI를 유지한 채 `web/`에 Next.js 16·Tailwind CSS 4 모바일 웹 미러를 구현했다. Figma에 없는 가격 입력·조리 사용량·독립 약속 UI는 넣지 않고 11단계 식단, 식단 분석 로딩, 레시피, 식단관리, 장보기, 재료소분, 마이페이지와 AI 채팅을 연결했다. 기존 Firebase OpenAI Secret을 Vercel Production에 민감 환경변수로 재사용하고 구조화 후보 API를 배포했다 | F00~F10, F13~F15, F19~F27 모바일 웹 미러 | Figma 393×852 병렬 비교 15장, lint·production build, Production 화면 13개 HTTP 200, 실제 OpenAI `source: openai` 2건, iPhone Simulator Production 홈·AI 캡처 통과. `web/qa/REPORT.md` 생성, `https://onelog-web.vercel.app` 배포 | 웹과 iOS UserDefaults·Firebase 나눔 데이터 자동 동기화는 하지 않음. iOS 고유 실기기·App Store 항목은 기존 남은 작업 유지 |
| 2026-08-20 | Figma 최종본과 런타임 캡처 54장을 다시 비교해 동네 확인의 실제 지도 타일, 장보기 상세의 하단 탭·보조 버튼 묶음, 재료소분의 알림 아이콘·emoji·별도 모집 닫기·과도한 채팅 요약을 Figma 비포함 UI로 판정해 제거하거나 비가시 접근 경로로 옮겼다. 받은 요청 CTA와 상세 화면 하단 내비게이션도 원본에 맞췄다 | F14, F25~F27 | 393×852 병렬 비교 시트 7개 보존, 변경 화면 집중 테스트 3/3과 최종 재캡처 2/2 통과, `git diff --check` 통과. `ios/qa/2026-08-20-final-audit/REPORT.md` 생성 | Google OAuth·GPS·두 실기기 실시간·접근성 수동 QA, 유료 Apple Developer Program 전환 후 Release archive |
| 2026-08-20 | 사용자 제보에 맞춰 식단 분석 단계에 명확한 로딩 상태를 추가하고, 7단계 확정 화면의 Figma 원본 마스코트·문구·카드 좌표를 적용했다. 가격/판매 단위 입력 화면과 조리 사용량 입력·토글 화면, 독립 업그레이드 UI를 제거했다. 10단계는 번들 가격 카탈로그의 읽기 전용 구매 요약, 11단계는 Figma 장보기 목록으로 교체했다. AI 실패는 Simulator App Check 누락으로 확인해 전용 로컬 token을 설정하고 callable 지역·오류 분류를 보강했다 | F08, F13, F13-AI, F20, F21 | 제보 화면 전용 UI 1개(6개 캡처) 통과, 7·10·11단계 Figma 393×852 나란히 대조, Debug 기기·Simulator 빌드 통과, Firebase·App Check·OpenAI 실제 종단 통과, Simulator 실제 AI 답변·후보 3개 확인, 최신 Debug를 iPhone 14 Pro에 덮어 설치 | iPhone 잠금 해제 후 앱 실행·실제 AI 대화 1회 확인, Release App Attest·APNs archive |
| 2026-08-20 | 사용자 제보 4건의 UI와 실제 AI 실패를 보정했다. 식단 분석 단계를 11로 맞추고 제목 겹침, AI 진입 마스코트 클리핑, AI 오류 재시도를 고쳤다. Debug 컴파일 조건 누락으로 App Check debug provider가 제외되던 원인을 수정해 기기에서 App Check VALID·OpenAI 후보 3개 실응답을 확인했다. 레시피 707:881은 Figma MCP 원본과 393×852로 나란히 대조해 169.5×220pt 카드, 14pt 열 간격, 고정 상단/결과 스크롤, 사진·하트·마스코트 크롭을 다시 맞춰다 | F01, F13-AI | 레시피 픽셀 캡처 2회, AI/11단계 핵심 UI 2개, 도메인 56개, 실제 Firebase App Check·OpenAI 종단 통과. `node --check functions/index.js`, `git diff --check` 통과. 최신 Debug를 iPhone 14 Pro에 덧어설치·실행 | Release App Attest·APNs archive, Google OAuth·GPS·두 실기기 실시간·접근성 수동 QA |
| 2026-08-20 | 배포 준비 감사를 수행했다. 필수 약관·개인정보 manifest·지원 문의, MapKit 동네 검색과 명시적 GPS, 실제 알림 저장소, 참여 요청/승인 분리, 신고·차단·금칙어, 재귀 삭제·계정 완전삭제, App Check·rate limit·만료 정리, Google 개인 백업, 완료 이력 기반 절감액, 사용자 확인 보관 날짜를 구현했다. Functions 10개와 강화한 Firestore 규칙을 배포하고 Debug/Release 서명 경계를 분리했다 | F10, F13-AI, F15, F23~F27 | 규칙 27/27, 실제 Firebase·App Check·OpenAI 종단, npm 취약점 0, 도메인 56/56, 핵심 UI 9/9, 나눔 캡처 5장, Debug 1.0.0 iPhone 14 Pro 설치·일반 실행·홈/재료소분 진입 통과. 기기 전용 Debug App Check도 등록·저장했다. `ios/qa/2026-08-20-production-readiness/REPORT.md` 생성 | Personal Team 제한 때문에 Release App Attest·APNs archive 불가. 유료 Apple Developer Program 팀 전환, APNs 키 등록, Google OAuth·GPS·두 실기기 실시간·접근성 수동 QA |
| 2026-08-20 | Figma MCP로 `최종본` 페이지의 활성 48개 프레임을 전수 재대조했다. 레시피 상세에서 조리 진입 시 상세 화면을 먼저 보이게 하고, 식단 변경·요리 완료·남은 재료 활용을 전체 화면 흐름으로 정리했다. AI 채팅의 안전영역·제안 카드·입력 독, 식단 변경의 간격과 선택 카드, 요리 완료의 Figma 원본 마스코트·재료 결과 카드·버튼을 기준 좌표에 맞췄다. 캡처 테스트에는 기간 선택, 실제 AI 입력 fixture, 일정 변경, 레시피 상세, 요리 완료, 남은 재료와 마이페이지 조리 시간·도구 시트를 추가했다 | F01, F08~F09, F13-AI, F22, F24 | 활성 Figma 원본 48장과 앱 런타임 캡처 52장 보존, 캡처 스위트 3/3·도메인 52/52 통과. `node --check functions/index.js`, `git diff --check` 통과. 최신 Debug 기기 빌드를 iPhone `나는 박범준이다.`에 설치했다. `ios/qa/2026-08-20-figma-final/REPORT.md` 생성 | 기기에서 개발자 프로필을 신뢰한 뒤 첫 실행, 기본 글자 크기·라이트 모드 외 접근성 QA, Google OAuth·GPS·Firebase·OpenAI 실제 네트워크 확인, 강화한 Firestore 규칙 재배포 |
| 2026-08-19 | 393×852 전용 시뮬레이터에서 Figma 최종본 UI를 화면 단위로 QA했다. 온보딩·홈·레시피·마이페이지·식단 만들기·식단관리·재료소분의 승인 캡처 44장을 저장하고 대표 6개 화면을 Figma 원본과 나란히 대조했다. 재료소분 채팅 메시지·약속의 날짜와 시간이 영어 로캘로 표시되던 문제를 한국어로 고쳤고, 마이페이지 불호·알레르기 시트 캡처의 오래된 식별자도 수정했다 | F00, F01, F13, F22~F27 | iPhone 16 Simulator(iOS 26.1) UI 9개·도메인 52개·수정 재캡처 2개 전부 통과. `ios/qa/2026-08-19-final-ui/REPORT.md`와 승인 캡처 44장 생성 | Dynamic Type 큰 글자·VoiceOver·다크 모드 별도 접근성 QA, Google OAuth·GPS·Firebase·OpenAI 실기기 확인 |
| 2026-08-19 | Figma MCP로 `최종본` 페이지(707:570)의 최상위 50개 프레임을 전수 대조하고 `미사용 / 구버전` 2개를 제외한 활성 48개만 구현 기준으로 확정했다. 기존 화면에 없던 동네 인증 검색·지도 확인(789:26·790:26), 레시피 검색 결과·빈 결과(804:125·805:17), 설정·알림함·알림 설정(792:26·798:26·799:26), 받은 소분 요청·약속(795:26·796:26)을 SwiftUI로 연결했다. 빈 검색 마스코트는 Figma 원본 asset을 사용하고, 받은 요청 거절은 해당 참여자 한 명만 제거하도록 Firestore 쓰기 범위를 보강했다 | F01, F23~F27 | `generic/platform=iOS` 빌드 성공, 393×852 전용 시뮬레이터 주요 화면 21장 캡처 및 시각 대조, 도메인 XCTest 52개 통과, 동네 인증·설정·알림/요청/약속 UI 테스트 각각 통과, `git diff --check` 통과 | 강화된 `ios/firestore.rules` 재배포·서버 왕복 재검증, GPS·Google OAuth·Firebase 실시간 채팅/약속·OpenAI 응답의 실기기 확인 |
| 2026-08-19 | 정적 코드 감사에서 발견한 계산·상태 버그를 수정했다. 분류형 알레르기와 직접 입력 불호를 자동 추천·AI 후보에 반영하고, 여러 단위 재고를 명시적 환산표로 합산·차감하며, 같은 재료가 여러 번 등장하는 레시피의 조리 입력을 합쳤다. 장보기 멱등 키를 식단 실행 세션·포장 크기까지 포함하도록 바꾸고 식단 변경 시 체크·수량 수정값을 초기화했다. 완료 식사 삭제 우회, 건너뛴 홈 상태, 구매 단위 잔여량 괄호, 손상 저장 필드의 전체 초기화도 보완했다. AI 적용 실패를 성공으로 표시하지 않고 서버의 끼니 자동 변경과 Google 취소 오인을 막았으며 Firestore 작성자·참여자·메시지 쓰기 규칙을 강화했다 | F04~F08, F13-AI, F14, F22~F24, F26~F27 | iPhone 16e Simulator 도메인 41개·UI 7개·캡처 2개(총 50개) 통과. 전체 스킴에서 48개 통과 뒤 Xcode 러너 종료 정체가 발생해 남은 UI 2개를 분리 실행하여 통과. `node --check functions/index.js`, `git diff --check` 통과 | 강화한 `ios/firestore.rules` 재배포와 서버 왕복 검증. 실제 Google OAuth·OpenAI·GPS·나눔/채팅 실기기 확인 |
| 2026-08-19 | 앱 타깃에 고정돼 있던 `CODE_SIGNING_ALLOWED=NO`·`CODE_SIGNING_REQUIRED=NO`를 제거했다. 서명되지 않은 Simulator 앱에서 FirebaseAuth가 키체인 entitlement 부족으로 `SecItemCopyMatching(-34018)`을 내며 Google 토큰 교환 뒤 실패하던 문제를 수정했다 | F23, F26, F27 | iPhone 17 Simulator Debug 빌드·설치·재실행 성공. 빌드 로그에서 `Sign to Run Locally`와 simulated application identifier entitlement 생성을 확인했고 재실행 Firebase 로그에서 기존 키체인 오류가 사라짐 | Simulator에서 Google 계정 선택 뒤 Firebase 계정 연결 완료 확인, 이어서 실기기 로그인 확인 |
| 2026-08-19 | Firebase의 모바일 웹 OAuth 흐름 대신 `GoogleSignIn-iOS` SPM 9.2.0 네이티브 로그인으로 교체했다. Google SDK가 반환한 ID/access token을 Firebase `GoogleAuthProvider` credential로 교환하고, AppDelegate·SwiftUI `.onOpenURL`에서 Google 콜백을 명시적으로 처리하도록 연결했다 | F23 | `xcodebuild -resolvePackageDependencies`, 시뮬레이터 Debug 빌드, `generic/platform=iOS` 서명 Debug 빌드 모두 **성공**. 최신 `OneLog.app`을 iPhone 14 Pro에 설치 완료 | 실기기에서 Google 계정 선택·콜백·Firebase 계정 연결 1회 확인 |
| 2026-08-19 | Firebase Blaze 업그레이드 후 `OPENAI_API_KEY` Secret 등록과 `aiChat` Cloud Function 배포를 완료했다. Firebase Functions Node.js 20 deprecation 경고를 반영해 runtime과 functions engine을 Node.js 22로 올리고, 의존성 설치·문법 검사 경로를 `functions/` 폴더 기준으로 정리했다 | F13-AI | 사용자 터미널에서 `firebase deploy --only functions:aiChat` 완료, `node --check functions/index.js`, `git diff --check` 통과 | 실제 OpenAI 응답과 실기기 AI 채팅 확인 |
| 2026-08-19 | SwiftUI에서 Firebase Auth의 Google OAuth 콜백 URL을 `.onOpenURL`와 명시적 `UIApplicationDelegate`에서 `Auth.auth().canHandle(url)`에 전달하도록 보완하고, Firebase delegate swizzling을 끈 뒤 delegate adaptor를 연결했다. 사용자가 다운로드한 최신 `GoogleService-Info.plist`의 OAuth 설정을 프로젝트에 교체 반영하고 `REVERSED_CLIENT_ID` URL scheme도 등록했다 | F23 | plist의 `CLIENT_ID`·`REVERSED_CLIENT_ID` 존재 확인, 빌드 산출물 URL scheme·delegate 설정 확인, iPhone Simulator `xcodebuild build` **BUILD SUCCEEDED**, `git diff --check` 통과 | 새 빌드를 실기기에 설치해 Google OAuth 콜백 1회 확인 |
| 2026-08-19 | Figma 최종본과 실제 SwiftUI 화면을 다시 대조해 현재 화면에 존재하는 홈·레시피·식단 만들기 1~11단계·식단 관리·냉장고·재료공유·마이페이지 흐름만 기준으로 재정의했다. 냉장고 재료 관리, 지난 식단 기록·절약 요약, 보관 문구·남은 재료 우선순위, 찜 기반 취향 노트도 현재 UI 기능으로 문서에 반영했다. F25~F27은 사용자 확정 P1로 유지하고, 알레르기·AI callable·GPS fallback·탭 명칭도 문서에 반영했다 | F00, F02, F05, F09, F10, F13, F15, F19, F23~F27 | 코드·모델·테스트·Figma 프레임 메타데이터 대조, `git diff --check` 통과 | F10의 월별 절약 정의·Google OAuth/GPS/Firebase 실기기·OpenAI Secret 배포 검증 |
| 2026-08-19 | 피그마 `식단 만들기 / AI 채팅`(713:2454) 진입 카드를 식단안 확인 단계에 추가하고, 전체 화면 대화에서 현재 식단·선호·보유 재료를 바탕으로 후보 레시피를 제안·상세 확인·교체/추가하도록 연결했다. iOS는 Firebase callable function `aiChat`만 호출하고, 함수는 OpenAI Responses API의 구조화 JSON 응답을 후보 레시피 ID로 검증한다. API 키는 앱에 넣지 않고 `OPENAI_API_KEY` Firebase Secret을 사용한다 | F13-AI | `node --check functions/index.js`, `generic/platform=iOS` `xcodebuild build-for-testing`, iPhone 16e Simulator `xcodebuild test` 도메인 36개·UI 7개·캡처 2개 **전부 통과** | Firebase CLI에서 Secret 등록·`firebase deploy --only functions:aiChat`, 실제 OpenAI 응답·기기 확인 |
| 2026-08-18 | 부분 구현 공백을 제품 흐름까지 연결했다. 레시피 상세에서 날짜·끼니를 골라 식사에 담고, 식단 확정은 마지막 완료에서 한 번만 반영하도록 정리했다. 예산은 수량 미상·판매 단위 미확인 품목을 확정 금액에서 제외하고, 가격·판매 단위 확인 뒤에만 잔여 예산과 업그레이드를 계산한다. 장보기 완료는 정확 품목만 멱등 반영하며, 요리 완료 입력 검증·건너뛴 끼니 보호·날짜/끼니 충돌·GPS 대기 타임아웃·나눔 가격 근거 검증도 추가했다 | F01, F03, F06~F09, F13, F14, F20~F27 | iPhone 16e Simulator `xcodebuild test` 도메인 35개·UI 6개·캡처 2개 **전부 통과**. 후속 경계 조건 수정 후 도메인 35개와 식단 확정 UI 1개 재실행, 시뮬레이터 빌드 성공, `git diff --check` 통과 | Google OAuth 실제 콜백, GPS 권한·좌표, Firebase 공동구매·채팅 실기기 실시간 송수신은 사용자 기기에서 확인 필요 |
| 2026-08-18 | 남은 시안을 마저 적용했다. `식단 관리 4 / 일정 변경`(467:117)은 네 갈래(미루기·메뉴 교체·오늘만 비활성화·삭제) 화면으로, `5 / 요리 완료`(467:161)는 조리 후 재고 결과 화면으로, `6 / 남은 재료 활용`(467:205)은 먼저 쓸 재료 + 다음 한 끼 추천(레시피 보기·식단에 추가)으로, `7 / 지난 식단 기록`(467:249)은 누적 완료·절약과 기간별 기록으로 만들었다. `식단 만들기 11 / 계란 구매 단위 선택`(430:23)은 예산 확인 단계에서 품목을 누르면 대표 단위와 부족분만 채우는 단위를 비교하는 화면으로 연결했다. `식단 관리 3 / 레시피 상세`는 레시피 탭 상세 화면을 그대로 쓴다. F22를 위해 `MealStatus.skipped`(재료 차감 없이 건너뛰기)를 추가했다 | F03, F08, F09, F10, F22 | `xcodebuild test` 도메인 34개·UI 6개·캡처 2개 **전부 통과** | 실기기에서 위치 권한과 새 화면 흐름 확인은 미완료 |
| 2026-08-18 | F25 GPS 착수(사용자 확정)와 재료공유 3화면 시안 적용. `LocationProvider`(WhenInUse·1회 측정)를 추가하고 좌표는 약 100m 격자로 반올림해 프로필과 나눔 글에 저장한다. 이웃 글에 `도보 약 n분`(직선거리 ÷ 75m/분)을 표시한다. 피그마 `재료공유 1 / 공동구매·소분`(350:1267), `2 / 소분 요청`(350:1327), `4 / 채팅`(350:1440)을 옮겨 나눌 재료 선택·하단 고정 요약·CTA, 채팅 헤더·말풍선·약속 카드·입력 독을 시안대로 만들었다. `firestore.rules`에 좌표 범위 검증 추가 | F25, F26, F27 | 도메인 34개 통과(도보 시간·좌표 반올림·좌표 없는 예전 글 디코딩 3개 추가). 시뮬레이터 캡처 `share-1-main`으로 시안 대조 | 실기기에서 위치 권한 팝업·실제 도보 시간 확인, 규칙 재배포(`firebase deploy --only firestore:rules`)와 `check_firestore_rules.py` 재실행. 당시 남은 시안 화면은 다음 변경에서 연결했다 |
| 2026-08-18 | 식단관리와 장보기를 피그마 `식단 관리 1 / 메인`(454:29)·`식단 관리 2 / 장보기 리스트`(467:29) 시안으로 다시 만들었다. 메인은 기간 헤더·날짜 선택·완료율/남은 예산 요약·장보기 진입·오늘/다음 식단·지난 식단 기록·마스코트 배너 순서이고, 장보기는 체크 목록·예산 2카드·`장보기 완료` 버튼이다. 시안에 없는 실행 보조(실제 구매량·판매 단위 수정, 목록 복사·공유, 냉장고·동네 나눔)는 항목 시트와 카드 아래 보조 버튼으로 옮겨 기능을 유지했다. 남은 예산을 보여주려고 `AppState.targetBudget`을 추가하고 식단 확정 시 저장한다(가격 미확인이면 금액을 만들지 않고 `확인 전`으로 둔다) | F03, F07, F08, F14, F20, F22 | `xcodebuild test`(iPhone 16e, `-parallel-testing-enabled NO`) 도메인 31개·UI 6개·캡처 2개 **전부 통과, TEST SUCCEEDED**. 캡처 하네스에 `care-1-main`·`care-2-shopping`를 추가해 시안과 대조 | 당시에는 `식단 관리 3~7` 화면이 옛 시트를 사용했고, 다음 변경에서 현재 화면과 지난 식단 기록을 연결했다. 메뉴 교체·삭제는 시안에 자리가 없어 카드 길게 누르기(+접근성 액션)로 남겼다 |
| 2026-08-18 | 식단 만들기를 피그마 `식단 만들기 1~8`(350:1551·1586·1645·1690·1729·1779·1832, 438:23) 좌표대로 다시 만들었다. 헤더(42)·프로그레스(94)·본문(116)·푸터(772) 골격을 `PlanFlowScaffold`로 두고 기간 → 끼니 → 예산 → 분석 → 식단안 → 확인·수정 → 최종 확인 → 재료 목록 8단계로 나눴다. 시안이 없는 9·10단계 자리에는 기존 가격·예산 확인 화면을 `9 / 11`로 이어 붙였다. 마스코트 4종과 후광 SVG는 피그마 원본을 그대로 받아 asset catalog에 넣었다(`PlanMascot*`, `PlanAiHalo`). 홈의 진입은 시트에서 전체 화면으로 바꿨다(시안은 자체 헤더를 가진 전체 화면) | F13, F20, F21, F22 | `xcodebuild test`(iPhone 16e, `-parallel-testing-enabled NO`) 도메인 31개·UI 6개·캡처 2개 **전부 통과, TEST SUCCEEDED**. 새 UI 테스트 `testPlanFlowFollowsFigmaSteps`가 1→9단계를 지나 식단이 `내 식사`에 담기는지 본다. 시뮬레이터 캡처로 8개 화면을 시안과 대조(`ScreenshotTests/testCapturePlanFlow`) | 당시 시점에는 시안의 9·10단계(보유 재료 확인·장보기 리스트)와 `식단 만들기 11 / 계란 구매 단위 선택`(430:23)이 남아 있었음. 2026-08-19 현재는 9~11단계까지 연결했다. Material Symbols 아이콘은 SF Symbols로 대체했다. 8단계 재료 분류(채소/단백질·유제품/곡물·양념)는 이름 휴리스틱이라 분류 데이터가 생기면 교체해야 한다. UI 테스트는 피그마 재작업으로 바뀐 진입 경로에 맞춰 모두 고쳤다(레시피 탭의 `구매량 계산 가능` 필터와 `식사에 담기`가 사라져, 장보기 검증은 식단 확정 흐름을 거치도록 바꿨다) |
| 2026-08-17 | 판매 단위 공백과 가격 입력 UX를 메웠다. ① 임포터가 재료 이름을 **뒤에서부터** 맞춰(`빨강 파프리카`→`파프리카`, `다진것`·`마른것` 등 손질 표기 제거, `재료`·`양념`·`육수` 같은 소제목 접두 제거) 표기 변형을 흡수한다. 같은 매칭을 상비 조미료 판정에도 써서 `고운 고춧가루`·`양념 후춧가루`가 상비로 잡힌다. ② `build_sale_units.py`에 대표 판매 단위 185종 → **658종**(육류·수산·채소·과일·곡류·면·가루·소스·주류와 `버섯`·`고기`·`나물` 같은 마지막 그물), `개`·`장`·`봉` 환산 대표값도 추가. ③ 예산 화면 `PriceEditorRow`를 판매 단위 확인 → 그 포장 가격 순서로 바꿔, 판매 단위 미확인 품목도 화면에서 바로 확정할 수 있게 하고 포장 크기와 가격이 어긋나 조용히 예산에 안 잡히던 문제를 없앴다 | F06, F07, F20, F21 | `xcodebuild test -only-testing:OneLogTests/OneLogDomainTests` **TEST SUCCEEDED**(31개). 완전 계산 레시피 **124건 → 719건**/956. `python3 ios/tools/import_recipes.py --self-check` 통과. 판매 단위 확인→가격 저장이 예산을 확정시키는 도메인 테스트 1개 추가 | UI 테스트는 이 환경에서 러너가 시뮬레이터에 뜨지 않아(`FBSOpenApplicationServiceErrorDomain`) 미실행. 남은 256종 재료 판매 단위, `큰술`·`ml` 같은 단위 환산 근거, 별칭 정규화(`다진 애호박`을 `애호박` canonical로 합치기)는 여전히 미착수 |
| 2026-08-17 | F27 약속 기능을 자유 메모에서 멤버 전용 구조화 정보로 확장. `ShareMeetup`에 날짜·시간·장소 메모·수정자·수정 시각을 저장하고, `meetup/details` 하위 문서와 SwiftUI 약속 잡기·수정·삭제 화면을 추가 | F27 | `xcodebuild build-for-testing` 성공, `xcodebuild test -only-testing:OneLogTests/OneLogDomainTests` **TEST SUCCEEDED**. Firestore 규칙 배포 후 `check_firestore_rules.py` 약속 권한 포함 **17개 모두 PASS**. Personal Team 서명 기기용 빌드와 iPhone 14 Pro 설치 성공 | 실기기 실행은 아이폰 잠금 상태로 `devicectl`이 거부해 미확인. 잠금 해제 후 약속 저장·수정·삭제와 채팅 실시간 송수신 확인 |
| 2026-08-17 | Firebase 콘솔에서 익명·Google 로그인 제공업체를 활성화하고 Firestore 규칙을 배포한 뒤 서버 왕복 검증을 완료 | F23, F26, F27 | `python3 ios/tools/check_firestore_rules.py` 실행. 비로그인 읽기 차단, 작성·참여, 정원 제한, 수정·삭제 차단, 채팅 멤버 경계·발신자 사칭 차단 등 **11개 항목 모두 PASS** | 실기기 Google 로그인 1회, F26·F27 실제 화면·실시간 송수신 확인 |
| 2026-08-17 | F23 Google 로그인 본체 구현과 F26·F27 서버 검증 수단 마련. 당시에는 GoogleSignIn SDK를 새로 붙이지 않고 FirebaseAuth의 웹 OAuth(`OAuthProvider(providerID: "google.com")`)로 처리했다. 익명 사용자로 쓰던 중이면 그 위에 `link`해서 나눔 글의 uid를 유지하고, 이미 다른 uid에 붙은 계정이면 그쪽으로 로그인한다. 이후 2026-08-19 네이티브 `GoogleSignIn-iOS` 흐름으로 교체했다. 콜백 URL 스킴 때문에 `OneLogApp/Info.plist`를 추가(`INFOPLIST_FILE` + 기존 `GENERATE_INFOPLIST_FILE` 병합)하고, 계정 해제·탈퇴 시 Firebase 세션도 끊고, `ShareStore.ensureSignedIn`은 캐시한 uid 대신 항상 `Auth.currentUser`를 본다. 서버 왕복 검증용 `ios/tools/check_firestore_rules.py`(REST, 시뮬레이터 불필요) 추가 | F23, F26, F27 | `xcodebuild build-for-testing`(iPhone 16e, iOS 26.1) `** TEST BUILD SUCCEEDED **`. 빌드 산출물 Info.plist에서 콜백 스킴과 생성 키 병합 확인. 검증 스크립트는 익명 로그인이 꺼져 있어 `CONFIGURATION_NOT_FOUND`에서 멈춤 | **Firebase 콘솔에서 익명·Google 제공업체 사용 설정**, `firebase deploy --only firestore:rules` 배포, 그 뒤 검증 스크립트와 실기기 Google 로그인 1회 확인 |
| 2026-08-16 | F26·F27 착수. firebase-ios-sdk 12.17.0(Auth·Firestore) SPM 추가, `Sharing.swift`(순수 도메인)·`ShareStore.swift`(Firestore)·`Views/ShareView.swift`(목록·작성·상세·채팅) 신설, `ios/firestore.rules` 추가. `UserProfile.neighborhood`(자기입력, GPS 없음) 추가. 진입점은 탭이 아니라 장보기 화면의 링크 | F26, F27 | `xcodebuild test`(iPhone 16e, iOS 26.1) 도메인 29개·UI 6개 총 35개 통과, `** TEST SUCCEEDED **`. 나눔 후보 추출·글 순위·참여 가능 판정·채팅 접근 권한·프로필 하위호환 도메인 테스트 5개와 진입점 UI 테스트 1개 추가 | `GoogleService-Info.plist` 투입 후 실제 서버 왕복 검증과 Firestore 규칙 배포 |
| 2026-08-15 | 구매량 계산을 실제로 되게 마무리. `CanonicalIngredient.unitGrams` 단위 환산(명시된 단위끼리만) 추가, 보유 재고도 환산해 차감. `ios/tools/build_sale_units.py`로 대표 판매 단위 185종 생성해 임포터에 연결. `fullyCalculableRecipeIDs`와 탐색 화면 필터·배지 추가 | F06, F07, F20 | `xcodebuild test` 29개 통과. 완전 계산 레시피 6건 → **124건**. 환산·재고 환산·계산 완결성 테스트 3개와 UI 테스트 1개 추가 | 나머지 1,272종 재료의 판매 단위(사용자 확인 또는 추가 대표값), 가격 입력 UX |
| 2026-08-15 | 식약처 `COOKRCP01` 1,156건을 변환해 iOS에 950건 추가. 미등록 재료는 판매 단위 없는 canonical로 자동 등록하고 구매량·예산 계산에서 제외(사용자 확인 품목). `Recipe.difficulty`·`cookTime`과 `CanonicalIngredient.representativeSaleUnit`·`storageNote`를 옵셔널로 전환 | F01, F13, F20 | `xcodebuild test` 25개 통과. 재료 참조 무결성·판매 단위 미확인 시 예산 미확정 테스트 추가 | 자동 등록 재료의 판매 단위·가격 확정, 별칭 정규화(`마늘다진것`↔`다진 마늘`), 반찬 단독 끼니 처리 |
| 2026-08-15 | 예산 계산 버그 수정: `precision == .manual` 품목이 `unknownCostIngredientIDs`에 잡히지 않아 잔여 예산이 `확정`으로 표시되던 문제 | F20, F21 | 도메인 테스트로 재현·검증 | 없음 |
| 2026-08-15 | F23 온보딩을 4단계(시작·계정·프로필·불호/조리도구)로 확장하고 F24 마이페이지 신설. 계정 연결/해제/탈퇴, 불호 메뉴, 닉네임·나이 추가 | F23, F24 | `xcodebuild test` 25개 통과(UI 3개 포함) | Google OAuth 실제 연동, 실기기 확인 |
| 2026-08-15 | 아이폰 탭 바 5개 제한으로 6번째 탭이 `More`에 숨는 문제를 발견해 마이페이지를 탐색 탭 툴바로 이동 | F24 | UI 테스트 3개 통과 | 없음 |
| 2026-08-14 | 연결된 iPhone 14 Pro에 Personal Team으로 서명한 `OneLog.app`을 설치하고 `com.onelog.native`를 실행 | F23 | `xcrun devicectl device install app` 및 `device process launch` 성공, 기기 상태 `connected` 확인 | 실제 온보딩 탭 상호작용과 전체 화면 흐름 검증 |
| 2026-08-14 | iOS에 제공된 앱 아이콘을 AppIcon asset catalog로 등록하고, `온보딩.png`를 첫 실행 온보딩 화면으로 연결. Xcode Personal Team 자동 서명도 프로젝트에 적용 | F23 | `generic/platform=iOS` Debug 기기용 빌드와 서명된 앱 생성 성공. Xcode Run은 기기에서 완료로 표시됐지만 CoreDevice가 `unavailable`로 전환되어 `devicectl` 설치·실제 화면 확인은 미확정 | iPhone 잠금 해제·케이블 연결·이 Mac 신뢰·Developer Mode 확인 후 설치 재시도 |
| 2026-08-14 | 사용자 요청에 따라 iOS P1 F14 장보기 실행 지원을 재개. 품목 체크, 실제 구매 포장 수 수정, 복사·공유, 구매·실행 이벤트 기록과 UserDefaults 하위 호환 디코딩을 추가 | F14 | `xcodebuild build-for-testing` 성공, 도메인 테스트 15개·UI 테스트 2개 컴파일 확인, 기기 SDK `build` 성공. CoreSimulator 장애로 XCTest·화면 조작은 미실행 | 실제 iPhone 화면에서 체크·수량 수정·복사·공유·구매 반영 확인 |
| 2026-08-14 | P0 경계 도메인 테스트 4개와 핵심 탭·식단 확정 UI 스모크 테스트 2개를 `OneLogUITests` 타깃으로 추가 | F01~F09, F13, F20~F22 | `xcodebuild build-for-testing` 성공, 도메인 테스트 13개·UI 테스트 2개 컴파일 확인 | CoreSimulator 복구 후 테스트 실행 및 화면 결과 확인 |
| 2026-08-14 | 웹은 그대로 두고 iOS만 P0 기준으로 정리. 재료 계산·예산·장보기 목록·구매 반영·요리 완료·미취식 이동·보관 안내·남은 재료 추천을 현재 흐름에 맞춰 유지하고 장보기 실행 보조를 이어갔다 | F05, F09, F10, F14, F15, F01~F04, F06~F08, F13, F20~F22 | `xcodebuild build-for-testing` 성공, 기기 SDK `build` 성공. CoreSimulator 서비스 연결 불가로 XCTest 실행 실패 | iPhone Simulator 복구 후 도메인 XCTest와 핵심 화면 E2E 재실행 |
| 2026-08-14 | 당시 최종 통합 기획서와 실제 화면을 재대조해 현재 UI 흐름과 후속 외부 연동을 구분했다. 이후 F26·F27은 2026-08-16 사용자 확정으로 P1에 편입했다 | 현재 UI 범위, F26, F27 | Notion 원문 fetch 및 `AGENTS.md` 대조 | 코드·화면 대조 후 기능 상태 갱신 |
| 2026-08-14 | iPhone 16e Simulator에서 네이티브 도메인 XCTest를 재실행하고 재고 절감액 테스트의 잘못된 기대값을 5,000원으로 수정 | F20, 네이티브 테스트 | iOS 26.0.1 Simulator `OneLogDomainTests` 9개 통과, 앱 설치·실행·홈 화면 스모크 캡처 확인 | 화면 상호작용 E2E 테스트 타깃은 후속 구성 |
| 2026-08-14 | 웹은 유지하고 `ios/OneLog`에 SwiftUI iPhone 프로젝트·UserDefaults 저장·P0 식단/예산 퍼널을 신규 구현. 레시피 탐색·찜·직접 식사 선택·재료/구매량 계산·장보기·요리 완료·남은 재료 추천·다일 식단안·예산 리뷰·업그레이드·미취식 이동/삭제 연결 | F01~F09, F13, F20~F22 | iOS `xcodebuild` Debug 시뮬레이터 빌드, 테스트 번들 빌드, Release 기기 SDK 빌드 성공. `npm test` 43개, `npm run lint`, `npm run build` 성공 | CoreSimulator 서비스 연결 복구 후 XCTest 실행과 핵심 화면 E2E, 실제 기기 확인 |
| 2026-08-14 | 기준 기획서를 `한끼로그 통합기획서`로 교체하고 예산형 최신 시나리오를 중심으로 기능 범위·우선순위·상태를 재정의. 백업 시나리오와 부가 기능을 분리 | 전체, F13, F20~F27 | Notion 원문 fetch, 저장소 파일 대조, `npm test` 43개 통과, `npm run lint`, `npm run build` 통과 | F20 예산 모델과 F13 확장 요구부터 설계·구현 |
| 2026-08-13 | 결정론적 다일 식단, 절약 요약, 장보기 실행 보조와 식단 관리 화면을 추가 | F10, F13~F15 | `npm test` 43개, `npm run lint`, `npm run build`, 로컬 HTTP 200 | 브라우저 E2E와 외부 연동 기능 |
| 2026-08-13 | KST 기본 날짜, completion 유실 시 재고 이중 차감, 추천 재료 중복 등 P0 버그 수정 | F03, F08, F09 | `npm test` 43개 | 없음 |
| 2026-08-12 | 수량 기반 추천, 미니 장보기, 재료 보관 문구, localStorage·판매 단위 검증, 통합 테스트 추가 | F03, F06, F09, F15 | `npm test` 15개, `npm run lint`, `npm run build` | 보관 문구의 재료 데이터 보강, 브라우저 E2E |
| 2026-08-11 | Next.js·Tailwind 프로젝트와 기존 P0 MVP 초기 구현 | F01~F09 | `npm test` 9개, `npx tsc --noEmit`, `npm run build`, 로컬 HTTP 200 | 백엔드·DB·실제 AI·E2E |

## 7. 핵심 화면 책임

1. **Onboarding / Account**: Google·기기 전용 시작, 약관·실패 복구, 닉네임·생년월일·동네·숙련도·선호 조리 시간, 불호·알레르기·조리도구
2. **Home**: 오늘 식단, 날짜별 식사 상태, 요리 완료 수, 식단 생성·요리·장보기·남은 재료 진입, 정의가 확인된 절약 요약
3. **Recipe Explore / Saved / Detail**: 검색·필터, 레시피 상세, 찜·찜 목록, 결정론적 취향 노트, 날짜·끼니에 담기·요리 시작
4. **Plan Setup / Analysis / Options**: 기간·날짜별 끼니·예산, 분석 조건, 여러 식단안과 추천 근거
5. **Plan Edit / AI Chat / Confirm**: 메뉴 직접 교체, AI 후보 대화·상세, 사용자 최종 선택, 11단계 진행 상태
6. **Fridge / Inventory**: 냉장고 재료 추가·수정·삭제, 정규화·통합 재료, 정확 수량·수량 미상 확인
7. **Budget / Package / Price**: 필요량·구매량·판매 단위·번들 가격 근거·잔여 예산과 전체 재계산. Figma에 없는 가격 입력·독립 업그레이드 화면은 두지 않는다.
8. **Weekly Meals / History / Change**: 주간 한눈에 보기, 완료율·장보기 진행률, 지난 식단 기록, 미루기·교체·오늘만 비활성화·삭제
9. **Shopping Execution**: 체크 목록, 실제 구매 포장 수 수정, 복사·공유, 구매 완료·멱등 재고 반영
10. **Cooking / Result**: 조리 순서, 계획 수량 기준 요리 완료, 남은 양 기록. Figma에 없는 사용량 입력·토글 중간 화면은 두지 않는다.
11. **Leftovers / Next Meal**: 먼저 사용할 재료, 근거 있는 보관 문구, 추가 구매 필요 여부, 레시피 보기·식단 추가
12. **Sharing / Request / Chat**: 공동구매·소분 글, 참여·취소·정원 상태, 멤버 전용 채팅, 날짜·시간·장소 약속
13. **My Page**: 프로필·선호·조리도구·알레르기 수정, 계정 연결·해제·탈퇴, 데이터 삭제 경로

프로토타입에서 화면을 합칠 수는 있지만 각 책임과 상태 전환을 잃지 않는다. 한 화면에 모든 설정·계산·실행을 몰아넣지 않는다.
하단 내비게이션은 `홈·레시피·식단관리·재료소분` 4개로 통일하고, 장보기·남은 재료·마이페이지는 해당 흐름의 카드·버튼·시트에서 진입한다.

## 8. 도메인과 계산 규칙

### 재료와 레시피

- `RecipeIngredient`의 원문명, `CanonicalIngredient` ID, 전처리·부위 정보를 분리한다.
- 불확실한 별칭 매핑은 신뢰도 또는 사용자 확인 경로 없이 확정하지 않는다.
- 질량, 부피, 개수 단위를 근거 없이 변환하지 않는다.
- 불호 재료는 자동 추천에서 제외하되 사용자가 직접 선택한 레시피를 조용히 삭제하지 않고 경고한다.
- 알레르기·못 먹는 재료는 불호와 별도 집합으로 저장하고 자동 추천에서 하드 제외한다. 사용자가 직접 고른 레시피도 경고·확인 없이는 식단에 확정하지 않는다.
- 필요한 조리도구가 없으면 자동 추천에서 제외하거나 대체 조리법이 확인된 경우만 제안한다.
- `가벼운 아침`은 명시적 레시피 메타데이터로 판정한다. 제목이나 AI 문구만으로 추측하지 않는다.
- `찜 기반 취향 노트`는 찜 목록의 저장된 태그·카테고리·조리 시간 집계만 사용한다.

### 수량·재고

- `추가 필요량 = max(총 필요량 - 사용 가능한 보유량, 0)`
- `구매량 = 추가 필요량을 충족하는 최소 판매 단위 수`
- `예상 잔여량 = 보유량 + 구매량 - 예상 사용량`
- `있음·수량 미상`과 정확한 수량을 구분한다. 수량 미상은 0이나 충분한 보유량으로 간주하지 않는다.
- 값은 음수가 될 수 없고 조리 완료·구매 반영은 중복 실행에 안전해야 한다.
- 사용자 수정 전 예상값과 수정 후 확정값을 덮어쓰지 않고 함께 보존한다.

### 예산·가격

- `예상 구매 비용 = 가격 근거가 있는 구매 품목의 구매 포장 수 × 포장 가격`
- `보유 재료 절감액`은 같은 시점·판매 단위 기준으로 실제 구매하지 않아도 되는 포장 또는 사용 가치 중 제품이 채택한 정의로 계산한다. 정의를 혼용하지 않고 UI에 근거를 표시한다.
- 기본 절감액 정의는 `확인된 가격의 구매 포장 중 보유 재료 때문에 덜 산 포장 금액`으로 둔다. 외식·배달을 하지 않아 절약했다는 비교 금액은 가격·대체 식사·기간 근거가 별도로 확정되기 전에는 계산하지 않는다.
- `잔여 예산 = 목표 예산 - 근거가 있는 예상 구매 비용`이 기본 관계지만, 가격 미확인 품목이 있으면 `확정 잔여 예산`으로 표현하지 않는다.
- 번들 가격 카탈로그는 `source`, 단위, 확인·갱신 시점을 보존하고, 근거가 없는 가격은 임의 생성하지 않는다.
- 단위가 다르거나 가격이 없거나 오래된 경우 임의 환산·추정을 하지 않는다.
- 잔여 예산 관련 재계산은 결정론적으로 유지하되, Figma에 없는 독립 업그레이드 선택 UI는 노출하지 않는다.

### 보관·남은 재료

- `storageNote`처럼 재료에 등록된 근거 있는 보관 문구만 보여준다.
- 남은 재료의 먼저 사용 우선순위는 현재 재고의 수량·상태와 명시된 데이터에 근거한다.

### 다일 식단 추천

추천 순서는 다음을 반영한다.

1. 사용자가 찜하거나 직접 선택한 메뉴
2. 불호·조리도구·끼니 조건 충족
3. 목표 예산을 넘지 않는 근거 있는 비용
4. 보유 재료와 남을 재료의 재사용
5. 새로 살 재료와 예상 잔여량 최소화
6. 난이도와 같은 메뉴의 과도한 반복 제한은 명시적 메타데이터가 있을 때만 선택적 보조 기준으로 사용한다.

동점 규칙을 명시해 같은 입력은 같은 결과를 내게 한다. 생성형 AI는 후보 생성과 설명을 도울 수 있지만, 최종 유효성·금액·수량·순위는 검증된 코드가 결정한다.

## 9. 데이터 모델 경계

구체 DB를 강제하지 않지만 다음 경계를 유지한다.

- `UserAccount`, `UserProfile`(닉네임·생년월일·동네·선택적 좌표), `FoodPreference`(불호·알레르기·불호 메뉴), `CookingSkill`, `CookTimePreference`, `CookingTool`
- `Recipe`, `RecipeIngredient`, `RecipeRequirement`
- `CanonicalIngredient`, `IngredientAlias`
- `MealPlanRequest` — 기간, 날짜별 끼니, 목표 예산
- `MealPlanOption`, `PlannedMeal`, `MealPlanRevision`
- `InventoryItem`, `PackageSize`, `IngredientPrice`
- `BudgetEstimate`, `BudgetLineItem`, `UpgradeSuggestion`(내부 재계산 모델 전용, 독립 UI 없음)
- `ShoppingList`, `ShoppingListItem`, `PurchaseConfirmation`
- `CookingCompletion`, `IngredientConsumption`, `SkippedMealDecision`
- `Recommendation`, `RecommendationIngredient`
- `HomeSummary`, `WeeklyMealSummary`, `MealHistorySummary`, `StorageGuidance` — 홈·주간 식단·지난 식단·보관 안내 화면용 집계와 근거 문구
- `SharePost`, `ShareDraft`, `ShareMatch`, `ShareMessage`, `ShareMeetup` — 공동구매·소분 글, 요청/참여 상태, 멤버 전용 채팅과 약속 정보
- `ShareRequest` 또는 `ShareParticipation` — 참여 요청·취소·수락/마감 상태. `SharePost.participantIDs`에 합쳐 저장하더라도 상태 전이를 잃지 않는다.
- `AIChatSession`, `AIChatMessage`, `AIChatResponse` — 현재 식단·선호·재고 문맥, 대화, 검증된 후보 레시피 ID. 수량·가격·예산 결과를 저장하는 AI 모델은 만들지 않는다.

수량과 금액에는 값만 두지 말고 단위·통화·원천·확인 상태·시점을 추적한다. 식단 제안과 사용자의 최종 확정을 구분하고, 메뉴 교체와 계획 수량 기준 완료는 감사 가능한 이벤트 또는 변경 이력으로 남긴다.

## 10. AI와 외부 연동 경계

현재 확정된 식단 수정 AI의 경계:

- iOS는 Firebase callable function `aiChat`만 호출하고 OpenAI 키를 보관하지 않는다. iOS의 키는 Firebase Secret `OPENAI_API_KEY`로 관리하고, 모바일 웹은 사용자 승인에 따라 같은 키를 Vercel Production의 민감 서버 환경변수로 재사용한다. 어느 클라이언트 번들에도 키를 포함하지 않는다.
- 함수는 현재 식단·선호·알레르기·보유 재료 문맥을 받아 대화 답변과 후보 레시피 ID를 반환한다. 앱은 후보 ID가 실제 레시피이며 추천 규칙을 통과하는지 다시 검증한다.
- AI는 메뉴 후보 선택·설명·대화만 담당한다. 수량·단위 환산·판매 단위·가격·예산·재고 차감·최종 식단 확정은 Swift 결정론적 코드와 사용자가 담당한다.
- OpenAI 응답이 없거나 잘못되면 수동 메뉴 교체·직접 구성으로 돌아간다. 실제 OpenAI 응답·기기 동작 확인 전에는 `부분 구현`이다.

규칙과 검증된 코드가 담당할 일:

- 단위 변환, 합산, 보유량 차감, 판매 단위 올림
- 식단 유효성, 조리도구·불호 필터의 최종 판정
- 구매량, 예상 잔여량, 가격, 예산, 절감액, 업그레이드 한도
- 조리·구매 후 재고 반영과 멱등성

AI 출력은 구조화된 스키마로 검증한다. 빈 결과, 잘못된 형식, 시간 초과, 네트워크 오류에서도 수동 구성과 기존 데이터가 정상 동작해야 한다. 외부 연동에는 타임아웃, 제한된 재시도, 오류 설명, 대체 경로를 둔다.

## 11. UX·접근성·개인정보

- 핵심 행동과 결과를 한국어로 쓰고 내부 AI·규칙 용어를 노출하지 않는다.
- 예산 충족 여부, 가격 미확인, 필요량, 실제 구매량, 예상 잔여량을 구분한다.
- 추천 근거와 변경 전후 차이를 보여주고 사용자가 언제든 교체·건너뛰기·직접 구성을 할 수 있게 한다.
- 로딩, 빈 상태, 부분 결과, 오류, 재시도, 오프라인 상태를 설계한다.
- 불호와 알레르기를 같은 선택지·문구로 합치지 않는다. 알레르기는 자동 추천에서 제외하고 직접 선택 시 확인을 요구한다.
- 색상만으로 상태를 구분하지 않고 키보드 조작, 포커스 표시, 의미 있는 레이블, 충분한 대비를 제공한다.
- 드래그 앤 드롭에는 버튼·키보드 대체 조작을 제공한다.
- 식단 삭제, 계정 탈퇴, 재고 대량 변경, 위치 공유에는 확인 또는 실행 취소 경로를 둔다.
- 나이·거주지·불호·조리도구·Google 계정 정보는 최소 수집하고 보존 기간과 삭제 경로를 명확히 한다.
- GPS 권한을 거부해도 동네 이름으로 재료공유를 계속 사용할 수 있게 한다. 서버에는 약 100m 격자로 반올림한 좌표만 저장하고 도보 시간 표시 외 용도로 사용하지 않는다.
- 재료공유의 표시 금액, 요청·참여·모집 종료·채팅·약속 상태는 화면과 Firebase 권한으로 설명한다.

## 12. 분석 이벤트와 성공 지표

앱 이벤트 이름과 속성은 `AppStore.swift`와 도메인 모델의 중앙 경로에서 정의하고 중복 발행을 테스트한다. 사용자 콘텐츠와 민감정보를 이벤트 속성에 넣지 않는다.

- 온보딩 시작 → Google 연동 → 불호·조리도구 설정 완료
- 홈 진입 → 식단 생성·요리·장보기·남은 재료 진입
- 레시피 조회 → 찜 → 식단 생성 시작
- 레시피 필터·검색 → 찜 목록·취향 노트 조회 → 레시피를 날짜·끼니에 담기
- 기간·끼니·예산 입력 → 식단안 노출 → 식단안 선택·교체 → 최종 확정
- AI 채팅 시작 → 후보 조회·상세 확인 → 후보 적용·수동 교체·오류 복구
- 보유 재료 확인 → 번들 가격 기반 예산 리뷰 → 장보기 생성
- 장보기 리스트 생성 → 품목 체크 → 구매 완료
- 계획된 식사 → 요리 완료 또는 미취식 이동·삭제
- 주간 식단 조회 → 식사 미루기·교체·비활성화·삭제 → 재계산
- 남은 재료 추천 노출 → 선택 → 실제 조리 완료
- 재료공유 글 작성 → 목록 조회 → 참여·취소·모집 종료 → 채팅·약속 저장·수정·삭제
- 구매 식재료 활용률, 예산 이내 식단 확정률, 가격 미확인 비율
- 예상량·예상 비용과 사용자 확정값의 차이

## 13. 구현 규칙

- 작업 전 코드, 설정, 테스트, 인접 `AGENTS.md`를 읽고 현재 구조와 관례를 따른다.
- 관련 없는 리팩터링, 대규모 파일 이동, 의존성 교체를 함께 수행하지 않는다.
- UI, 도메인 규칙, 영속성, 인증, AI, 가격 계산을 분리한다.
- 계산 로직을 컴포넌트나 프롬프트에 흩뿌리지 않고 순수 함수 또는 독립 서비스에 둔다.
- 사용자 확정 범위의 Firebase·OpenAI·GPS 경계는 그대로 사용하고, 인증·DB·AI·가격 계산의 경계를 임의로 바꾸지 않는다.
- API 키, 토큰, 개인정보, 실제 사용자 데이터를 코드·샘플·로그·커밋에 남기지 않는다.
- 기존 UserDefaults 스키마를 바꾸면 버전·마이그레이션·오염 데이터 복구 테스트를 추가한다.
- 완료 후 이 문서의 `6. 현재 구현 현황`과 변경 이력을 실제 결과에 맞게 갱신한다.
- 부분 완료나 실패를 숨기지 않고 구체적인 미완료 항목과 안전한 대체 경로를 남긴다.

## 14. 테스트와 완료 기준

변경 영향에 맞는 자동 테스트와 사용자 흐름 검증을 함께 제공한다. 최소 검증 항목은 다음과 같다.

- 별칭 재료 통합, 같은 단위 합산, 단위 충돌
- 보유량이 필요량보다 적음·같음·많음, 수량 미상
- 판매 단위 경계 올림, 예상 잔여량, 사용자 포장 단위 수정
- 1~7일과 날짜별 끼니 조합, 빈 끼니, 잘못된 기간·예산
- 찜 우선, 불호 제외, 조리도구 부족, 가벼운 아침. 난이도·같은 메뉴 반복 제한은 명시적 메타데이터가 있을 때만 선택적으로 검증
- 알레르기 하드 제외와 직접 선택 경고, 생년월일·숙련도·선호 조리 시간·알레르기 저장·하위 호환
- 같은 입력의 결정론적 결과와 여러 식단안의 실질적 차이
- 가격 있음·없음·단위 불일치·오래된 가격·부분 가격에서 예산 표현
- 보유 재료 절감액과 잔여 예산 경계값, 식단 변경 전후 전체 재계산
- 메뉴 교체·미취식 이동 후 재료량, 예산, 사용 예정일 갱신
- 요리 완료·구매 완료의 중복 요청이 재고를 이중 반영하지 않음
- AI·인증·외부 연동의 빈 결과, 잘못된 형식, 오류, 시간 초과 복구
- Firebase callable AI 후보 ID 검증, OpenAI 키 비노출, AI 후보 적용 후 Swift 재계산
- GPS 권한 허용·거부, 좌표 100m 반올림, 도보 시간, 좌표 없는 기존 나눔 글 하위 호환
- 재료공유 글·참여·정원 마감, 멤버 전용 채팅·약속 권한, 발신자·무관 사용자 차단
- 주요 화면의 로딩·빈 상태·부분 결과·오류·재시도·키보드 접근성
- UserDefaults 마이그레이션과 오염 데이터 복구

기능을 `완료`로 표시하려면 관련 XCTest·UI 테스트, `xcodebuild test`, 핵심 iOS 화면 흐름을 모두 통과해야 한다. 실기기 검증을 하지 못했다면 해당 기능의 상태를 `부분 구현`으로 남긴다.

작업 완료 보고에는 반드시 다음을 포함한다.

1. 변경한 내용과 사용자 가치
2. 실행한 테스트·검증과 결과
3. 남은 위험, 가정, 미완료 또는 후속 작업

## 15. 결정이 모호할 때

다음 순서로 판단한다.

1. 사용자 데이터, 인증, 개인정보, 금액·재고 정확성 보호
2. 목표 예산 안에서 사용자가 식단을 선택하고 장보기까지 갈 수 있는가
3. 사용자의 메뉴 선택권과 설명 가능성
4. 남은 식재료 활용률과 입력 부담
5. 접근성, 실패 복구, 구현 단순성, 향후 교체 가능성

중요한 제품 결정을 새로 내려야 하면 확인 가능한 선택지, 사용자 영향, 데이터·기술 트레이드오프를 제시하고 승인을 받는다.
