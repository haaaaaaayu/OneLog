# 한끼로그 Web

한끼로그 iOS 최종 UI를 393pt 폭 모바일 화면에 맞춰 옮긴 Next.js + Tailwind CSS 웹앱이다. 데스크톱 전용 레이아웃은 만들지 않았고, 넓은 화면에서도 모바일 캔버스를 유지한다.

- Production: https://onelog-web.vercel.app
- Framework: Next.js 16.3.1, React 19, Tailwind CSS 4
- AI: Vercel Route Handler → OpenAI Responses API
- AI Secret: Vercel Production의 `OPENAI_API_KEY` 민감 환경변수. 브라우저 번들에는 포함하지 않는다.

## 로컬 실행

```bash
npm install
npm run dev
```

품질 확인:

```bash
npm run lint -- --quiet
npm run build
```

## 화면 QA 진입점

`/?demo=1&screen=<name>`으로 고정 상태를 열 수 있다.

`home`, `recipe`, `plan4`, `plan7`, `plan10`, `plan11`, `meals`, `shopping`, `share`, `requests`, `shareChat`, `mypage`, `ai`

Figma 원본과 393×852 화면을 붙인 비교 자료와 검증 결과는 [`qa/REPORT.md`](qa/REPORT.md)에 있다.

## 데이터 경계

- 웹 온보딩 닉네임은 브라우저 로컬 저장소에 보존한다.
- 주요 탐색·식단·요리·장보기·재료소분 화면은 모바일 웹에서 직접 조작할 수 있다.
- AI 요청은 서버에서만 처리하며, 응답 후보 ID를 화면의 레시피 카탈로그로 다시 제한한다.
- OpenAI 장애나 키 미설정 시에도 제한된 결정론적 후보 추천으로 복구한다.
- iOS 프로젝트와 Firebase callable functions는 수정하거나 대체하지 않고 그대로 유지한다.
