# 2026-08-20 배포 준비 검증 보고서

## 결론

앱 코드, Firebase 서버, 개인정보 고지, 계정 삭제, 사용자 콘텐츠 신고·차단, 결정론적 계산, 핵심 UI 흐름은 실사용 기준으로 구현·검증했다. Firebase 규칙과 Functions는 실제 프로젝트 `onelog-21cb6`에 배포했다.

App Store/TestFlight 제출만 현재 Apple Personal Team의 외부 제한으로 완료하지 못했다. `com.onelog.native`의 Release 아카이브는 App Attest와 Push Notifications entitlement를 요구하지만 무료 팀 프로파일은 두 capability를 발급하지 않는다. 유료 Apple Developer Program 팀으로 전환한 뒤 Release 프로파일을 다시 만들면 된다.

## 구현 보완

- 필수 이용약관·개인정보 동의, 개인정보 manifest, 법률·오픈소스·지원 문의 화면
- 실제 MapKit 동네 검색, 명시적 1회 GPS, 약 100m 좌표 반올림, 권한 거부 fallback
- 로컬 식사·장보기 알림과 서버 푸시 수신·읽음 상태·토큰 정리
- 원격 알림 수신 핸들러에 필요한 `remote-notification` background mode
- 소분 참여 요청과 승인 전 멤버 분리, 신고·차단·금칙어, 작성자 재귀 삭제
- 서버 원자적 참여 승인, 계정·글 완전삭제, 만료 글 정리, App Check, 호출 rate limit
- Google 계정 개인 백업, 엄격한 생년월일 검증, 사용자 확인 보관 날짜와 임박 재료 우선 추천
- 완료 식사의 확인 가격만 사용하는 월별 보유 재료 절감액
- 앱 아이콘 alpha 제거, 버전 1.0.0, Debug/Release 서명 경계 분리

## 자동 검증

- Firestore 배포 규칙 서버 왕복: 27/27 PASS
- Firebase·App Check·OpenAI 실제 종단: 익명 인증, 글, 요청, callable 승인, 멤버 반영, OpenAI 실응답, 글 재귀 삭제, 계정 완전삭제 모두 PASS
- Functions: `node --check`, 런타임 import PASS; `npm audit --audit-level=moderate` 취약점 0건
- iOS 도메인 XCTest: 56/56 PASS
- iOS 핵심 UI: 9/9 시나리오 PASS. 전체 실행에서 7개 통과 후 수정한 AI 채팅·나눔 2개를 분리 재실행해 통과
- 나눔 시각 QA: 목록·알림·받은 요청·채팅·약속 5장 캡처, 잘림·겹침 없음. 요청 대기 글의 CTA를 `요청 확인`으로 보정
- Debug 실기기 서명: 버전 1.0.0, `PrivacyInfo.xcprivacy` 포함, iPhone 14 Pro 설치·일반 실행·홈 및 재료소분 목록 진입 성공

## 서명·배포 경계

- Release는 `OneLogRelease.entitlements`의 production App Attest·APNs를 유지한다.
- Debug는 Personal Team 설치를 위해 빈 `OneLogLocal.entitlements`와 App Check debug provider를 사용한다.
- 설치한 Debug 앱의 기기 전용 App Check token을 Firebase에 등록하고 앱에 저장했다. 이후 일반 아이콘 실행으로 홈과 재료소분 목록이 오류 없이 열리는 것을 확인했다. 이 token은 Personal Team Debug 설치 전용이며 Release 배포 전에는 폐기한다.
- Release archive 실제 시도 결과: Personal Team 프로파일이 App Attest와 Push Notifications를 지원하지 않아 실패. 코드 오류가 아니라 Apple 계정 capability 제한이다.
- App Store 제출 전 필수: 유료 Apple Developer Program 가입/팀 선택, App ID capability 활성화, APNs 키를 Firebase에 업로드, App Attest provider 설정 확인, 새 Distribution 프로파일로 archive, TestFlight 실기기 검증.

## 남은 수동 검증

- iPhone에서 Google 계정 선택과 Firebase 링크 완료
- GPS 권한 팝업과 실제 좌표/도보 시간 확인
- iPhone 식단 수정 화면에서 실제 AI 대화 1회 확인
- 서로 다른 두 실기기에서 소분 요청·실시간 채팅·약속 알림
- Dynamic Type 큰 글자와 VoiceOver
