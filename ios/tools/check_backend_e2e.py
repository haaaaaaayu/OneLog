#!/usr/bin/env python3
"""App Check가 적용된 실제 Firebase callable·OpenAI 왕복 검증.

임시 App Check 디버그 토큰을 Firebase에 등록한 뒤 환경 변수로 넘긴다.
  FIREBASE_APPCHECK_DEBUG_TOKEN=... python3 ios/tools/check_backend_e2e.py

검증 데이터와 익명 계정은 deleteAccount callable로 마지막에 삭제한다.
"""

from __future__ import annotations

import json
import os
import plistlib
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

PLIST = Path(__file__).resolve().parents[1] / "OneLog" / "OneLogApp" / "GoogleService-Info.plist"


def http(method: str, url: str, body: dict | None = None, headers: dict | None = None) -> tuple[int, dict]:
    request = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, method=method)
    request.add_header("Content-Type", "application/json")
    for key, value in (headers or {}).items():
        request.add_header(key, value)
    try:
        with urllib.request.urlopen(request, timeout=90) as response:
            return response.status, json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            return error.code, json.loads(raw or b"{}")
        except json.JSONDecodeError:
            return error.code, {"raw": raw.decode(errors="replace")}


def firestore_fields(**values: object) -> dict:
    fields: dict[str, dict] = {}
    for key, value in values.items():
        if isinstance(value, bool): fields[key] = {"booleanValue": value}
        elif isinstance(value, int): fields[key] = {"integerValue": str(value)}
        elif isinstance(value, float): fields[key] = {"doubleValue": value}
        elif isinstance(value, str): fields[key] = {"stringValue": value}
        elif isinstance(value, datetime): fields[key] = {"timestampValue": value.isoformat().replace("+00:00", "Z")}
        elif isinstance(value, list): fields[key] = {"arrayValue": {"values": [{"stringValue": item} for item in value]}}
        elif value is None: fields[key] = {"nullValue": None}
        else: raise TypeError(f"unsupported field {key}: {value!r}")
    return {"fields": fields}


def expect(label: str, condition: bool, detail: object = "") -> None:
    print(f"[{'PASS' if condition else 'FAIL'}] {label}")
    if not condition:
        raise RuntimeError(f"{label}: {detail}")


def main() -> int:
    debug_token = os.environ.get("FIREBASE_APPCHECK_DEBUG_TOKEN", "").strip()
    if not debug_token:
        print("FIREBASE_APPCHECK_DEBUG_TOKEN이 필요합니다.")
        return 2
    options = plistlib.loads(PLIST.read_bytes())
    api_key = options["API_KEY"]
    project = options["PROJECT_ID"]
    project_number = options["GCM_SENDER_ID"]
    app_id = options["GOOGLE_APP_ID"]
    firestore = f"https://firestore.googleapis.com/v1/projects/{project}/databases/(default)/documents"
    callable_base = f"https://us-central1-{project}.cloudfunctions.net"

    def exchange_app_check() -> str:
        status, value = http("POST", f"https://firebaseappcheck.googleapis.com/v1/projects/{project_number}/apps/{urllib.parse.quote(app_id, safe='')}:exchangeDebugToken?key={api_key}", {"debugToken": debug_token})
        expect("App Check 디버그 토큰 교환", status == 200 and bool(value.get("token")), value)
        return value["token"]

    exchange_app_check()

    def sign_in() -> tuple[str, str]:
        code, payload = http("POST", f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={api_key}", {"returnSecureToken": True})
        expect("익명 로그인", code == 200, payload)
        return payload["idToken"], payload["localId"]

    def auth_header(token: str) -> dict[str, str]:
        return {"Authorization": f"Bearer {token}"}

    def call(name: str, token: str, data: dict) -> tuple[int, dict]:
        app_check = exchange_app_check()
        return http("POST", f"{callable_base}/{name}", {"data": data}, {
            "Authorization": f"Bearer {token}",
            "X-Firebase-AppCheck": app_check,
        })

    author_token, author_id = sign_in()
    joiner_token, joiner_id = sign_in()
    neighborhood = f"E2E-{uuid.uuid4().hex[:8]}"
    post_id = str(uuid.uuid4())
    request_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)

    try:
        for token, uid, nickname in [(author_token, author_id, "E2E작성자"), (joiner_token, joiner_id, "E2E참여자")]:
            code, payload = http("PATCH", f"{firestore}/users/{uid}", firestore_fields(
                neighborhood=neighborhood, nickname=nickname, updatedAt=datetime.now(timezone.utc)
            ), auth_header(token))
            expect("동네 접근정보 저장", code == 200, payload)

        post = firestore_fields(
            id=post_id, kind="split", ingredientID="egg", ingredientName="달걀", amount=5.0,
            unit="개", neighborhood=neighborhood, meetupNote="", pricePerShare=2500,
            authorID=author_id, authorNickname="E2E작성자", participantIDs=[], capacity=2,
            status="open", createdAt=now, expiresAt=now + timedelta(days=7), coordinate=None,
        )
        code, payload = http("POST", f"{firestore}/sharePosts?documentId={post_id}", post, auth_header(author_token))
        expect("소분 글 작성", code == 200, payload)

        join_request = firestore_fields(
            id=request_id, postID=post_id, authorID=author_id, requesterID=joiner_id,
            requesterNickname="E2E참여자", message="달걀을 함께 나누고 싶어요.", status="pending",
            createdAt=datetime.now(timezone.utc), updatedAt=datetime.now(timezone.utc),
        )
        code, payload = http("POST", f"{firestore}/shareRequests?documentId={request_id}", join_request, auth_header(joiner_token))
        expect("참여 요청 작성", code == 200, payload)

        code, payload = call("respondShareRequest", author_token, {"requestID": request_id, "decision": "accepted"})
        expect("App Check 적용 요청 수락 callable", code == 200 and payload.get("result", {}).get("status") == "accepted", payload)

        code, payload = http("GET", f"{firestore}/sharePosts/{post_id}", headers=auth_header(joiner_token))
        participants = payload.get("fields", {}).get("participantIDs", {}).get("arrayValue", {}).get("values", [])
        expect("수락 후 실제 멤버 반영", code == 200 and any(item.get("stringValue") == joiner_id for item in participants), payload)

        ai_data = {
            "message": "저녁을 15분 안에 만들 수 있는 메뉴로 바꿔줘",
            "history": [],
            "plan": {"title": "E2E 식단", "startDate": now.date().isoformat(), "days": 1, "targetBudget": 15000,
                     "meals": [{"date": now.date().isoformat(), "slot": "저녁", "recipeID": "egg-rice", "title": "달걀밥"}]},
            "preferences": {"disliked": [], "allergies": [], "tools": ["프라이팬"]},
            "inventory": [{"name": "달걀", "quantity": "2", "unit": "개"}],
            "candidateRecipes": [
                {"id": "egg-rice", "title": "달걀밥", "description": "간단한 한 그릇", "mealSlots": ["저녁"], "cookTime": 10, "isLightBreakfast": False, "ingredients": ["달걀", "밥"], "tags": ["한식"]},
                {"id": "tofu-bowl", "title": "두부덮밥", "description": "빠른 덮밥", "mealSlots": ["저녁"], "cookTime": 15, "isLightBreakfast": False, "ingredients": ["두부", "밥"], "tags": ["한식"]},
            ],
        }
        code, payload = call("aiChat", author_token, ai_data)
        result = payload.get("result", {})
        expect("배포된 OpenAI 실응답", code == 200 and bool(result.get("reply")) and isinstance(result.get("suggestions"), list), payload)

        code, payload = call("deleteSharePost", author_token, {"postID": post_id})
        expect("글·채팅 재귀 삭제 callable", code == 200 and payload.get("result", {}).get("deleted") is True, payload)
    finally:
        for token in [joiner_token, author_token]:
            code, payload = call("deleteAccount", token, {})
            expect("계정 서버 데이터 완전삭제", code == 200 and payload.get("result", {}).get("deleted") is True, payload)
    print("실제 Firebase·App Check·OpenAI 왕복 검증을 모두 통과했습니다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
