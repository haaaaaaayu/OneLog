#!/usr/bin/env python3
"""F26 공동구매·소분과 F27 채팅·약속의 서버 왕복 검증.

`ios/firestore.rules`가 실제로 배포되어 있고, 앱이 쓰는 것과 같은 문서 모양으로
익명 사용자가 글을 올리고 참여하고 대화하고 약속을 저장할 수 있는지,
멤버가 아닌 사용자는 약속 정보를 못 읽고 못 고치는지를
진짜 서버에 요청해서 확인한다. 시뮬레이터 없이 REST로만 돈다.

선행 조건 (Firebase 콘솔):
  - Authentication → 로그인 방법 → **익명** 사용 설정
  - `firebase deploy --only firestore:rules`로 규칙 배포

실행:
  python3 ios/tools/check_firestore_rules.py
"""

from __future__ import annotations

import json
import plistlib
import sys
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

PLIST = Path(__file__).resolve().parents[1] / "OneLog" / "OneLogApp" / "GoogleService-Info.plist"
# 실제 사용자 동네 목록에 섞이지 않도록 검증용 동네 이름을 따로 쓴다.
NEIGHBORHOOD = "규칙검증용동네"


def request(method: str, url: str, token: str | None = None, body: dict | None = None) -> tuple[int, dict]:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req) as response:
            return response.status, json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            return error.code, json.loads(raw or b"{}")
        except json.JSONDecodeError:
            return error.code, {"raw": raw.decode(errors="replace")}


def timestamp(moment: datetime) -> str:
    return moment.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def fields(**values) -> dict:
    """파이썬 값 → Firestore REST의 타입 태그. 앱(Swift Codable)이 쓰는 타입과 같아야 규칙이 같게 판정한다."""
    out = {}
    for key, value in values.items():
        if isinstance(value, bool):
            out[key] = {"booleanValue": value}
        elif isinstance(value, int):
            out[key] = {"integerValue": str(value)}
        elif isinstance(value, float):
            out[key] = {"doubleValue": value}
        elif isinstance(value, str):
            out[key] = {"stringValue": value}
        elif isinstance(value, datetime):
            out[key] = {"timestampValue": timestamp(value)}
        elif isinstance(value, list):
            out[key] = {"arrayValue": {"values": [{"stringValue": item} for item in value]}}
        elif value is None:
            out[key] = {"nullValue": None}
        else:
            raise TypeError(f"지원하지 않는 타입: {key}={value!r}")
    return {"fields": out}


class Checker:
    def __init__(self) -> None:
        self.failures = 0

    def expect(self, label: str, actual: int, expected: int, payload: dict) -> None:
        ok = actual == expected
        self.failures += 0 if ok else 1
        mark = "PASS" if ok else "FAIL"
        print(f"[{mark}] {label} (기대 {expected}, 실제 {actual})")
        if not ok:
            print(f"       {json.dumps(payload, ensure_ascii=False)[:300]}")


def main() -> int:
    if not PLIST.exists():
        print(f"GoogleService-Info.plist를 찾지 못했습니다: {PLIST}")
        return 2
    options = plistlib.loads(PLIST.read_bytes())
    api_key, project = options["API_KEY"], options["PROJECT_ID"]
    base = f"https://firestore.googleapis.com/v1/projects/{project}/databases/(default)/documents"

    def sign_in(who: str) -> tuple[str, str]:
        status, body = request(
            "POST",
            f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={api_key}",
            body={"returnSecureToken": True},
        )
        if status != 200:
            message = body.get("error", {}).get("message", body)
            print(f"익명 로그인 실패({who}): {message}")
            if message == "CONFIGURATION_NOT_FOUND":
                print("→ Firebase 콘솔 Authentication에서 익명 로그인을 먼저 켜주세요.")
            elif message == "ADMIN_ONLY_OPERATION":
                print("→ 익명 로그인 제공업체가 꺼져 있습니다.")
            sys.exit(2)
        return body["idToken"], body["localId"]

    author_token, author_id = sign_in("작성자")
    joiner_token, joiner_id = sign_in("참여자")
    stranger_token, _ = sign_in("제3자")

    check = Checker()
    post_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)
    post = fields(
        id=post_id,
        kind="split",
        ingredientID="check-script",
        ingredientName="검증용 대파",
        amount=0.5,
        unit="개",
        neighborhood=NEIGHBORHOOD,
        meetupNote="",
        pricePerShare=1500,
        authorID=author_id,
        authorNickname="검증봇",
        participantIDs=[],
        capacity=2,
        status="open",
        createdAt=now,
        expiresAt=now + timedelta(days=7),
    )

    try:
        # 로그인하지 않으면 아무것도 못 읽는다.
        status, body = request("GET", f"{base}/sharePosts")
        check.expect("비로그인 읽기 차단", status, 403, body)

        status, body = request("POST", f"{base}/sharePosts?documentId={post_id}", author_token, post)
        check.expect("작성자 글 작성", status, 200, body)

        meetup_path = f"{base}/sharePosts/{post_id}/meetup/details"
        meetup = fields(
            scheduledAt=now + timedelta(days=2),
            placeNote="성수역 2번 출구 앞",
            updatedBy=author_id,
            updatedAt=datetime.now(timezone.utc),
        )
        status, body = request("PATCH", meetup_path, author_token, meetup)
        check.expect("작성자 약속 저장", status, 200, body)

        status, body = request("GET", meetup_path, stranger_token)
        check.expect("무관한 사용자 약속 읽기 차단", status, 403, body)

        status, body = request("GET", meetup_path, joiner_token)
        check.expect("참여 전 약속 읽기 차단", status, 403, body)

        # 규칙이 배포되지 않았다면(기본 테스트 모드 등) 이 위반이 통과해버린다.
        bad = json.loads(json.dumps(post))
        bad["fields"]["capacity"] = {"integerValue": "99"}
        bad["fields"]["id"] = {"stringValue": "check-bad"}
        status, body = request("POST", f"{base}/sharePosts?documentId=check-bad-{post_id}", author_token, bad)
        check.expect("정원 한도(2~8) 위반 차단", status, 403, body)

        status, body = request(
            "PATCH",
            f"{base}/sharePosts/{post_id}?updateMask.fieldPaths=authorNickname",
            joiner_token,
            fields(authorNickname="가로챈닉네임"),
        )
        check.expect("남의 글 내용 수정 차단", status, 403, body)

        status, body = request(
            "PATCH",
            f"{base}/sharePosts/{post_id}?updateMask.fieldPaths=participantIDs&updateMask.fieldPaths=status",
            joiner_token,
            fields(participantIDs=[joiner_id], status="matched"),
        )
        check.expect("참여자 참여 신청", status, 200, body)

        status, body = request("GET", meetup_path, joiner_token)
        check.expect("참여자 약속 읽기", status, 200, body)

        status, body = request(
            "PATCH",
            f"{meetup_path}?updateMask.fieldPaths=placeNote&updateMask.fieldPaths=updatedBy&updateMask.fieldPaths=updatedAt",
            joiner_token,
            fields(
                placeNote="성수역 2번 출구 앞 카페",
                updatedBy=joiner_id,
                updatedAt=datetime.now(timezone.utc),
            ),
        )
        check.expect("참여자 약속 수정", status, 200, body)

        status, body = request(
            "PATCH",
            f"{meetup_path}?updateMask.fieldPaths=placeNote&updateMask.fieldPaths=updatedBy&updateMask.fieldPaths=updatedAt",
            stranger_token,
            fields(
                placeNote="가로챈 장소",
                updatedBy="가로챈사용자",
                updatedAt=datetime.now(timezone.utc),
            ),
        )
        check.expect("무관한 사용자 약속 수정 차단", status, 403, body)

        message_id = str(uuid.uuid4())
        message = fields(
            id=message_id,
            senderID=joiner_id,
            senderNickname="참여봇",
            text="검증 메시지입니다.",
            createdAt=datetime.now(timezone.utc),
        )
        status, body = request(
            "POST", f"{base}/sharePosts/{post_id}/messages?documentId={message_id}", joiner_token, message
        )
        check.expect("참여자 채팅 작성", status, 200, body)

        status, body = request("GET", f"{base}/sharePosts/{post_id}/messages", author_token)
        check.expect("작성자 채팅 읽기", status, 200, body)

        status, body = request("GET", f"{base}/sharePosts/{post_id}/messages", stranger_token)
        check.expect("무관한 사용자 채팅 읽기 차단", status, 403, body)

        forged = fields(
            id="forged",
            senderID=author_id,  # 남의 이름으로 보내기
            senderNickname="사칭봇",
            text="사칭 메시지",
            createdAt=datetime.now(timezone.utc),
        )
        status, body = request(
            "POST", f"{base}/sharePosts/{post_id}/messages?documentId=forged-{message_id}", joiner_token, forged
        )
        check.expect("발신자 사칭 차단", status, 403, body)

        status, body = request("DELETE", f"{base}/sharePosts/{post_id}", joiner_token)
        check.expect("참여자의 글 삭제 차단", status, 403, body)

        status, body = request(
            "PATCH",
            f"{base}/sharePosts/{post_id}?updateMask.fieldPaths=status",
            author_token,
            fields(status="closed"),
        )
        check.expect("작성자 모집 마감", status, 200, body)
    finally:
        # ponytail: 메시지는 규칙상 지울 수 없어(분쟁 기록 보존) 약속 문서와 부모 글만 지운다.
        # 메시지 하위 컬렉션은 앱의 어느 화면에서도 보이지 않는다. 쌓이면 서버측 정리 작업이 필요하다.
        request("DELETE", f"{base}/sharePosts/{post_id}/meetup/details", author_token)
        request("DELETE", f"{base}/sharePosts/{post_id}", author_token)
        request("DELETE", f"{base}/sharePosts/check-bad-{post_id}", author_token)

    print()
    if check.failures:
        print(f"{check.failures}개 실패. `firebase deploy --only firestore:rules`로 규칙을 배포했는지 확인하세요.")
        return 1
    print("모두 통과. 서버가 앱과 같은 경계를 강제하고 있습니다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
