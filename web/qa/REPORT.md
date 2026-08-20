# 한끼로그 Web 최종 QA

- 일자: 2026-08-20 KST
- 기준 뷰포트: iPhone 393×852pt
- Production: https://onelog-web.vercel.app
- Vercel project: `bodleims-projects/onelog-web`
- Production deployment: `dpl_GfRuZQQFLuy7S8FDkA75uVtKwXCr`

## 결과

Figma 최종본과 웹 런타임을 동일 크기로 나란히 비교했다. 최종 수정에서 다음을 확인했다.

- 공개 루트의 첫 진입 화면까지 다시 감사해 Figma에 없던 소개 화면을 제거하고, 노란 스플래시 → Google 로그인 → 1/3~3/3 온보딩 순서로 교체했다.
- 식단관리·재료소분의 로고를 30px로 축소하던 잘못된 selector와 제목 굵기 누락을 수정했다.
- AI 채팅의 안내 pill·식단 카드·대화 순서를 Figma 기준으로 다시 맞췄다.
- 9.9MB 웹폰트를 202KB subset으로, 약 13MB 레시피 PNG 초기 요청을 828KB WebP로 줄여 이미지가 늦게 나타나는 문제를 완화했다.

- 홈·레시피·식단관리·재료소분의 모바일 내비게이션과 주요 CTA가 동작한다.
- 식단 만들기 4단계는 멈춘 화면처럼 보이지 않도록 spinner와 `계산 중…` 상태를 표시한다.
- Figma에 없는 가격·판매 단위 수동 입력 화면과 조리 실제 사용량 입력·토글 화면은 웹에도 만들지 않았다.
- AI 채팅 후보는 Figma의 텍스트 카드 형태로 맞추고, 별도 사진·노란 교체 버튼을 제거했다.
- 받은 소분 요청과 소분 채팅은 Figma 카드·메시지 구조로 재조정하고, Figma에 없던 독립 약속 카드를 제거했다.
- 마이페이지·장보기 목록은 카드 높이, 여백, 진행 상태, 하단 CTA를 Figma 기준으로 다시 맞췄다.
- iOS 코드는 웹 구현 중 변경하지 않았다.
- 후속 iPhone Safari 감사에서 Google 버튼의 가짜 화면 전환, 온보딩 CTA 가림, 전환 후 스크롤 누수, 잘못 연결된 소분 CTA를 발견해 실제 Firebase Web Auth·문서 스크롤·safe-area·공통 스크롤 초기화·소분 작성 흐름으로 교체했다.
- 기기 전용 시작, 프로필 설정 저장, 식단관리·재료소분 마이페이지 진입, 채팅 버튼 접근성 이름과 44pt 터치 대상을 추가했다.
- 날짜·끼니 선택, 주간 식단, 제외 재료 직접 추가, 남은 재료 추천, 소분 요청 거절까지 남은 무동작 버튼을 실제 화면 상태와 라우트로 연결했다.

## 자동·런타임 검증

| 검증 | 결과 |
| --- | --- |
| `npm run lint -- --quiet` | 통과, 오류 0건 |
| `npm run build` | 통과, `/` 정적 페이지와 `/api/ai-chat` 동적 Route Handler 생성 |
| Vercel Production build | 통과, Next.js·TypeScript·정적 페이지 생성 완료 |
| Production 기본 진입 | 빈 저장소에서 스플래시 → 로그인 전환 확인 |
| Production 핵심 화면 13개 HTTP smoke | 모두 HTTP 200 |
| Production AI 요청 2건 | 모두 `source: openai`, 카탈로그 후보 ID만 반환 |
| iPhone Simulator Production 화면 | 홈·AI 채팅 캡처 및 렌더링 확인 |
| iPhone Safari 대응 브라우저 회귀 | 짧은 높이 온보딩 스크롤, 탭·식단 단계 `scrollY` 초기화, 소분 작성·완료, 프로필 저장, 채팅 전송 통과 |
| Production Google OAuth 진입 | Firebase Web App·허용 도메인 구성 후 인증 상태 진입, unauthorized-domain·콘솔 오류 없음. 실제 계정 선택·콜백은 사용자 계정 필요 |
| iPhone Simulator Safari | iOS 26.1 WebKit에서 Production 로그인·온보딩 렌더링과 상·하단 안전영역 확인 |
| `git diff --check` | 통과 |

OpenAI 키는 기존 Firebase Secret을 Vercel Production의 민감 환경변수로 직접 전달했다. 값은 로그·저장소·브라우저 번들에 노출하지 않았다. Responses API는 JSON Schema 구조화 출력을 사용하고 `store: false`로 호출한다.

## 비교 자료

비교 이미지의 왼쪽은 Figma 기준, 오른쪽은 393×852 웹 런타임이다.

- `comparisons/home.png`
- `comparisons/recipe.png`
- `comparisons/plan-04-loading.png`
- `comparisons/plan-07.png`
- `comparisons/plan-10.png`
- `comparisons/plan-11.png`
- `comparisons/meals.png`
- `comparisons/shopping.png`
- `comparisons/share.png`
- `comparisons/share-requests.png`
- `comparisons/share-chat.png`
- `comparisons/mypage.png`
- `comparisons/ai-chat.png`
- `comparisons/production-home.png`
- `comparisons/production-ai.png`
- `2026-08-20-ui-repair/comparisons/production-splash-final.png`
- `2026-08-20-ui-repair/comparisons/production-login-final.png`
- `2026-08-20-ui-repair/comparisons/production-home-final.png`
- `2026-08-20-ui-repair/comparisons/production-ai-final.png`

## 남은 경계

- 웹 데이터는 현재 브라우저 로컬·화면 상태를 사용한다. iOS의 UserDefaults 데이터나 Firebase 나눔 데이터를 웹과 자동 동기화하지 않는다.
- 웹 Google OAuth는 실제 인증 진입까지 확인했고 iPhone Simulator Safari WebKit 렌더링도 교차 확인했다. 사용자 계정 선택·콜백 완료와 물리 iPhone 1회 확인은 계정·실기기가 필요한 최종 수동 항목이다.
- GPS 실측, 서로 다른 두 실기기의 Firebase 나눔·채팅 검증과 App Store archive는 iOS 쪽의 별도 배포 준비 항목이다.
- Simulator의 Dynamic Island·안전영역은 일부 Figma 기준 기기와 다르지만, 콘텐츠 캔버스는 393×852 기준으로 대조했다.
