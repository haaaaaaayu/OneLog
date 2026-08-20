# Web 기본 진입 UI 교정 보고서

- 일자: 2026-08-20 KST
- 기준: Figma 최종본, 393×852pt
- Production: https://onelog-web.vercel.app
- Deployment: `dpl_HRd1VuKRn3tS39j47gzoajf24K2b`

## 원인

이전 QA가 `?demo=1&screen=home` 같은 화면 fixture에서 시작해 공개 루트의 최초 진입 상태를 검증하지 않았다. 그 결과 Figma에 없는 흰 배경 소개 화면과 노란 미리보기 카드가 기본 진입 UI에 남았다. 또한 `.simple-brand-header img` 규칙이 브랜드 로고까지 30px로 축소했고, Tailwind reset 이후 일부 제목의 명시적 굵기가 빠져 있었다.

## 수정

- 최초 진입을 Figma의 노란 스플래시 → Google 로그인 → 기본 정보 1/3 → 조리도구 2/3 → 제외 재료 3/3 순서로 교체했다.
- 임의의 기기 전용 로그인 버튼, 별도 소개 카드, Figma에 없는 온보딩 단계를 제거했다.
- 식단관리·재료소분의 브랜드 로고 selector와 제목 굵기를 수정했다.
- AI 채팅을 안내 pill → 현재 식단 카드 → 대화 → 후보 카드 순서로 복원했다.
- 홈·레시피·식단관리·재료소분·마이페이지의 fixture 데이터와 시각 상태를 Figma 캡처에 맞췄다.
- Noto Sans KR 전송량을 9.9MB에서 202KB로 줄이고, 레시피 6장의 초기 전송 이미지를 약 13MB에서 828KB WebP로 교체했다. 주요 마스코트는 lossless WebP를 사용했다.

## 검증

- 온보딩 6개 화면과 핵심 8개 화면을 iPhone 393×852 Simulator에서 다시 캡처했다.
- 각 캡처는 같은 크기의 Figma 원본과 좌우 비교 이미지로 확인했다.
- 수정 후 `npm run lint -- --quiet`, `npm run build`, Vercel Production build가 통과했다.
- 새 Production에서 스플래시·로그인·홈·AI 화면의 settled state를 다시 캡처했다.
- `POST /api/ai-chat` 실요청이 `source: "openai"`, 후보 `cabbage`를 반환했다.
- iOS 소스는 이 교정 작업에서 변경하지 않았다.

## 증거 위치

- 런타임 캡처: `screenshots/`
- Figma 병렬 비교: `comparisons/`
- 최종 대표: `comparisons/09-onboardingLogin.png`, `comparisons/08-home.png`, `comparisons/09-ai.png`, `comparisons/production-splash-final.png`, `comparisons/production-login-final.png`

Simulator의 Dynamic Island와 home indicator는 Figma 프레임 밖의 운영체제 chrome이며, 웹 콘텐츠 좌표와 별도로 판단했다.
