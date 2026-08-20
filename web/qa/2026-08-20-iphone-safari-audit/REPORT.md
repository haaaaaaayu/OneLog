# 한끼로그 웹 iPhone Safari 대응 수정·브라우저 재검증

- 실행일: 2026-08-20 KST
- 대상: `https://onelog-web.vercel.app`
- 최신 Production deployment: `https://onelog-1pyl98n0c-bodleims-projects.vercel.app`
- 기준: 393pt 모바일 캔버스, Safari 주소창·하단 도구막대가 보이는 짧은 가용 높이, 키보드 축소 높이
- 상태: Production 배포 성공, 공개 URL HTTP 200, 확인한 화면의 브라우저 콘솔 오류 0건, iPhone Simulator iOS 26.1 Safari(WebKit) 렌더링 확인
- 한계: 상호작용 자동화는 Codex 인앱 브라우저에서 수행하고 실제 Safari 렌더링은 `OneLog-Figma393` Simulator에서 교차 확인했다. 실제 Google 계정 선택과 OAuth 콜백 완료는 사용자 계정 입력 없이 진행하지 않았으며, 물리 iPhone의 계정 콜백 1회가 최종 외부 검증 경계다.

## 결론

최초 감사에서 확인한 릴리스 차단 이슈를 코드 수정하고 운영 배포까지 완료했다.

1. Google 버튼을 Firebase Web Auth의 실제 Google OAuth 팝업 흐름에 연결했다. iOS Safari가 팝업을 차단하지 않도록 클릭 핸들러 안에서 인증 창을 즉시 열며, Production 허용 도메인과 Firebase Web App 설정을 추가했다.
2. 기기 전용 익명 시작 경로와 인증 오류·재시도 안내를 추가했다.
3. 온보딩의 `min-height: 700px`·`overflow: hidden` 조합을 제거하고 문서 스크롤, CTA 콘텐츠 여백, 하단 safe-area를 적용했다.
4. 탭·라우트·온보딩·식단 단계·소분 완료·프로필 편집 전환마다 스크롤을 0으로 초기화했다.
5. 잘못 연결된 소분 CTA를 실제 작성 폼과 완료 화면으로 연결하고, 식단관리·소분의 마이페이지 버튼과 프로필 설정 저장을 구현했다.
6. 채팅 버튼 이름, 44px 터치 대상, 필드셋 의미 구조, 화면 확대, 하단 내비게이션 safe-area를 보완했다.
7. 최종 Figma 페이지의 visible top-level frame 50개를 다시 전수 대조해 공통 36px 뒤로가기·18px 제목, 마이페이지 중앙 정렬, Google 첫 화면, 동네 인증, 설정·알림, 받은 요청, 미취식 변경, 소분 요청·채팅, 식단 12/12 표시를 웹에 반영했다.
8. Firebase 세션이 없으면 과거 `localStorage` 온보딩 값만으로 홈에 진입하지 않도록 인증 상태 관찰을 추가했다. 따라서 로그아웃·세션 만료 뒤에는 반드시 Google·기기 전용 시작 화면이 다시 보인다.
9. 달력 월·날짜 이동, 소분 추가 요청, 프로필 사진 선택, Firebase 계정 삭제 확인·실행을 연결하고 클릭 가능한 무동작 요소를 제거했다.

## 수정 후 결과

| 점검 | 결과 | 근거 |
| --- | --- | --- |
| Production 로그인 화면 | 통과 | Google·기기 전용 시작 버튼 렌더링, 콘솔 오류 없음 |
| Google OAuth 진입 | 부분 통과 | Production에서 클릭 후 `Google 연결 중…` 인증 상태로 전환되고 `auth/unauthorized-domain` 오류가 발생하지 않음. 실제 계정 선택·콜백은 사용자 계정 필요 |
| 짧은 Safari 높이 온보딩 | 통과 | 초기에는 CTA가 고정되지만 문서 `scrollHeight > innerHeight`; 최대 스크롤에서 마지막 조리 시간 필드가 CTA 위에 완전히 노출됨 |
| 탭 전환 스크롤 | 통과 | 레시피 하단 위치에서 다른 탭 전환 시 `scrollY: 132 → 0` |
| 식단 8→9단계 전환 | 통과 | 8단계 하단에서 다음 클릭 시 `scrollY: 132 → 0`, 9/11 헤더 노출 |
| 소분 작성 | 통과 | 시작 CTA → 작성 폼 → 완료 화면 → 목록 복귀 연결, 완료 전환 시 `scrollY: 0` |
| 프로필 | 통과 | 홈·식단관리·소분 진입 연결, 닉네임·숙련도·시간·도구·제외 재료 편집과 로컬 저장 확인 |
| 채팅 | 통과 | 접근 가능한 닫기·입력·전송 이름 확인, 테스트 메시지 렌더링 확인 |
| 잔여 무동작 버튼 | 통과 | 날짜·끼니 선택, 주간 식단, 제외 재료 직접 추가, 남은 재료 추천, 요청 거절 흐름 연결 |
| Production 회귀 | 통과 | 배포본에서 스크롤 초기화, 소분 작성 라우팅, 콘솔 오류 0건 재확인 |
| iPhone Safari WebKit 렌더링 | 통과 | iOS 26.1 Simulator에서 Production 로그인·온보딩을 열어 Dynamic Island·Safari 하단 도구막대·safe-area 환경에서 CTA와 주요 콘텐츠 노출 확인 |
| Figma 최종 프레임 재대조 | 통과 | 최종 페이지의 visible top-level frame 50개를 인벤토리화하고 누락 화면·12단계 표시·프로필 정렬을 수정 |
| 393×667 짧은 높이 | 통과 | 로그인 Google 버튼 하단 608.5px, 약관 하단 653px. 식단 12단계 최하단 행은 최대 스크롤에서 고정 CTA 상단보다 45px 위에 노출 |
| 프로필 정렬 | 통과 | Production에서 아바타 중심 x=197px, viewport 중심 x=196.5px. 문서 최대 스크롤 77px 정상 동작 |
| 식단 12단계 | 통과 | 4/12 분석 화면이 2.2초 뒤에도 유지되고 사용자 CTA로 전환. 12/12 장보기 7개와 확인 버튼 렌더링 |
| 소분·설정·동네 | 통과 | 재료·이웃 선택 → 요청 전송 → 채팅, 알림 토글, 동네 검색 → 인증 확인, 식단 삭제 재계산 완료 상태를 브라우저에서 조작 |
| Production Google Auth | 부분 통과 | 인증 iframe과 `Google 연결 중…` 상태 진입, `auth/unauthorized-domain`·콘솔 오류 없음. 실제 계정 선택·콜백은 사용자 계정 입력 없이 중단 |
| Production OpenAI | 통과 | `/api/ai-chat`이 후보 `cabbage`와 `source: openai` 구조화 응답 반환 |
| 최종 iPhone Safari WebKit | 통과 | `OneLog-Figma393` iOS 26.1 Simulator Safari에서 최종 Production 로그인과 식단 12/12를 다시 열어 Google CTA·약관·고정 확인 버튼이 Safari 하단 도구막대 위에 노출되는 것을 확인 |
| 잔여 무동작 감사 | 통과 | 달력 이전/다음 달·날짜, 소분 추가 요청, 알림 이력 의미 구조, 프로필 사진 파일 선택, 실제 Firebase 계정 삭제 확인 모달을 연결. 탈퇴의 최종 삭제는 안전상 실행하지 않음 |

## 주요 구현 위치

- Firebase Web Auth: `web/lib/firebase-client.ts`, `web/.env.production`
- 로그인·온보딩·라우팅·프로필·소분·채팅: `web/app/page.tsx`
- Safari 스크롤·safe-area·터치 대상: `web/app/globals.css`
- 확대 허용 viewport: `web/app/layout.tsx`

## 정적·배포 검증

- `npm run lint`: 오류 0건, 경고 35건. 경고는 기존 `<img>` 최적화 권고 34건과 PostCSS default export 형식 1건이다.
- `npm run build`: 통과. `/` 정적 페이지와 `/api/ai-chat` 동적 Route Handler 생성.
- Vercel Production build: Next.js 컴파일, TypeScript, 정적 페이지 생성, 배포와 alias 모두 성공.
- Production alias: `https://onelog-web.vercel.app`
- 최신 immutable URL: `https://onelog-1pyl98n0c-bodleims-projects.vercel.app`

## 최초 감사 증거

수정 전 재현 화면은 같은 디렉터리의 `03-safari-toolbar-height.png`, `06-keyboard-focus-scroll.png`, `14-meals-tab-scroll-leak.png`, `19-sharing-cta-mismatch.png`, `23-recipe-detail-scroll-leak.png`, `29-plan-step9-scroll-leak.png`에 보존한다.

수정 후 실제 Safari 캡처는 `30-ios-safari-onboarding-fixed.png`, `31-ios-safari-login-fixed.png`에 보존한다.
