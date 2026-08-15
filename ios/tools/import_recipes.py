#!/usr/bin/env python3
"""식품안전나라 조리식품 레시피 DB(COOKRCP01)를 앱 번들 JSON으로 변환한다.

빌드 타임에 한 번만 돌린다. 앱은 외부 API를 호출하지 않는다.

원칙(AGENTS 8절):
- 재료명이 canonical ingredient에 매핑되지 않으면 그 레시피는 버린다. 추측해서 넣지 않는다.
- 질량↔부피↔개수 변환은 하지 않는다. kg→g, L→ml 같은 같은 차원 변환만 한다.
- 원본에 없는 값(난이도, 조리시간)은 만들어내지 않고 null로 둔다.

사용법:
    python3 ios/tools/import_recipes.py --key <인증키>
    python3 ios/tools/import_recipes.py --key sample          # 소량 스모크 테스트
    python3 ios/tools/import_recipes.py --key <키> --pantry ios/tools/pantry.json
"""

import argparse
import json
import os
import re
import sys
import urllib.request
from collections import Counter, defaultdict

API = "http://openapi.foodsafetykorea.go.kr/api/{key}/COOKRCP01/json/{start}/{end}"
PAGE = 100

SOURCE_NOTE = "식품의약품안전처 식품안전나라 조리식품의 레시피 DB (공공누리 제1유형: 출처표시)"

# 앱 Unit rawValue로 바로 쓰는 단위만 허용한다. 나머지 단위가 나오면 레시피를 버린다.
UNIT_MAP = {
    "g": ("g", 1.0),
    "kg": ("g", 1000.0),
    "ml": ("ml", 1.0),
    "mL": ("ml", 1.0),
    "L": ("ml", 1000.0),
    "l": ("ml", 1000.0),
    "개": ("개", 1.0),
    "장": ("장", 1.0),
    "큰술": ("큰술", 1.0),
    "작은술": ("작은술", 1.0),
    "봉": ("봉", 1.0),
    "팩": ("팩", 1.0),
}

# 원본에 두 가지 표기가 섞여 있다.
#   A형 "연두부 75g(3/4모)"  - 수량이 괄호 밖
#   B형 "돼지고기(50g)", "닭고기(가슴살, 120g)" - 수량이 괄호 안
UNIT_PATTERN = "kg|g|mL|ml|L|l|개|장|큰술|작은술|봉|팩"
TOKEN = re.compile(
    rf"^(?P<name>.*?)\s*(?P<qty>\d+(?:\.\d+)?(?:/\d+)?)\s*(?P<unit>{UNIT_PATTERN})\s*(?:\(.*\))?$"
)
PAREN_TOKEN = re.compile(r"^(?P<name>[^(]+)\((?P<inner>.+)\)\s*$")
QUANTITY_ONLY = re.compile(rf"^(?P<qty>\d+(?:\.\d+)?(?:/\d+)?)\s*(?P<unit>{UNIT_PATTERN})$")
SERVINGS = re.compile(r"\[\s*(\d+)\s*인분\s*\]")
STEP_PREFIX = re.compile(r"^\s*\d+\s*[.)]\s*")
STEP_SUFFIX = re.compile(r"\s*[a-z]\s*$")

# RCP_PAT2(요리 종류) → 끼니 후보. 후식은 한 끼로 계획하지 않으므로 제외한다.
SLOTS_BY_CATEGORY = {
    "밥": ["점심", "저녁"],
    "일품": ["점심", "저녁"],
    "국&찌개": ["점심", "저녁"],
    "반찬": ["점심", "저녁"],
}
SYMBOL_BY_CATEGORY = {"밥": "🍚", "일품": "🍱", "국&찌개": "🍲", "반찬": "🥗"}

# RCP_WAY2(조리 방법) → 최소한으로 확실한 조리도구만 매긴다.
# ponytail: 휴리스틱. 잘못 넣으면 추천에서 레시피가 사라지므로 애매하면 비워 둔다.
TOOLS_BY_METHOD = {
    "끓이기": ["냄비"], "찌기": ["냄비"], "삶기": ["냄비"],
    "굽기": ["프라이팬"], "볶기": ["프라이팬"], "튀기기": ["프라이팬"], "부치기": ["프라이팬"],
}

# 가벼운 아침 기준. 제목 추측이 아니라 원본 열량(INFO_ENG) 값으로만 판정한다(제품 원칙 5).
LIGHT_BREAKFAST_MAX_KCAL = 400
BREAKFAST_CATEGORIES = {"밥", "일품"}


def parse_ingredients_from_swift(path):
    """canonical 재료의 단일 출처는 SeedData.swift다. 별칭 표를 여기서 읽어 온다."""
    source = open(path, encoding="utf-8").read()
    entries = re.findall(
        r'CanonicalIngredient\(id:\s*"([^"]+)",\s*name:\s*"([^"]+)",\s*aliases:\s*\[([^\]]*)\]',
        source,
    )
    if not entries:
        sys.exit(f"재료 표를 읽지 못했습니다: {path} 형식이 바뀌었는지 확인하세요.")
    table = {}
    for ingredient_id, name, aliases in entries:
        names = [name] + re.findall(r'"([^"]+)"', aliases)
        for alias in names:
            table[normalize(alias)] = ingredient_id
    return table


def normalize(text):
    return re.sub(r"\s+", "", text).lower()


def fetch(key, cache_path):
    if os.path.exists(cache_path):
        return json.load(open(cache_path, encoding="utf-8"))
    rows, start = [], 1
    while True:
        url = API.format(key=key, start=start, end=start + PAGE - 1)
        with urllib.request.urlopen(url, timeout=30) as response:
            body = json.loads(response.read().decode("utf-8"))
        block = body.get("COOKRCP01", {})
        result = block.get("RESULT", {})
        if result.get("CODE") not in (None, "INFO-000"):
            sys.exit(f"API 오류 {result.get('CODE')}: {result.get('MSG')}")
        page_rows = block.get("row", [])
        rows.extend(page_rows)
        total = int(block.get("total_count", len(rows)))
        print(f"  {len(rows)}/{total} 건 수신", file=sys.stderr)
        if len(page_rows) < PAGE or len(rows) >= total:
            break
        start += PAGE
    os.makedirs(os.path.dirname(cache_path), exist_ok=True)
    json.dump(rows, open(cache_path, "w", encoding="utf-8"), ensure_ascii=False)
    return rows


def parse_quantity(text):
    if "/" in text:
        numerator, denominator = text.split("/", 1)
        return float(numerator) / float(denominator)
    return float(text)


def split_tokens(line):
    """괄호 안의 쉼표는 구분자로 보지 않는다. "닭고기(가슴살, 120g)"이 쪼개지면 안 된다."""
    # "토마토 25g[양념장] 간장 5g"처럼 소제목이 줄 중간에 끼는 경우가 있어 구분자로 바꾼다.
    line = re.sub(r"\[[^\]]*\]", ",", line)
    tokens, depth, current = [], 0, []
    for character in line:
        if character in "([":
            depth += 1
        elif character in ")]":
            depth = max(0, depth - 1)
        if character in ",，" and depth == 0:
            tokens.append("".join(current))
            current = []
        else:
            current.append(character)
    tokens.append("".join(current))
    return [token.strip().strip("·•-") for token in tokens if token.strip()]


def parse_token(token):
    """(원문명, 수량, 앱 단위) 또는 None."""
    # "양념장 : 저염간장"처럼 소제목이 앞에 붙는 줄이 있어 콜론 뒤를 재료명으로 본다.
    def clean(name):
        return name.split(":")[-1].strip(" ·")

    match = TOKEN.match(token)  # A형
    if match:
        name = clean(match.group("name"))
        app_unit, factor = UNIT_MAP[match.group("unit")]
        if name:
            return name, parse_quantity(match.group("qty")) * factor, app_unit

    match = PAREN_TOKEN.match(token)  # B형
    if match:
        name = clean(match.group("name"))
        parts = [part.strip() for part in match.group("inner").split(",")]
        for part in reversed(parts):
            quantity = QUANTITY_ONLY.match(part)
            if quantity and name:
                app_unit, factor = UNIT_MAP[quantity.group("unit")]
                return name, parse_quantity(quantity.group("qty")) * factor, app_unit
    return None


def parse_parts(raw):
    """재료 문단을 (원문명, 수량, 단위) 목록과 수량을 못 읽은 토큰 목록으로 나눈다."""
    parsed, without_quantity = [], []
    for line in raw.split("\n"):
        line = SERVINGS.sub("", line).strip()
        if not line or not any(character.isdigit() for character in line):
            continue  # 요리명 줄과 "고명" 같은 소제목 줄
        for token in split_tokens(line):
            result = parse_token(token)
            if result:
                parsed.append(result)
            else:
                without_quantity.append(token)
    return parsed, without_quantity


def build_steps(row):
    steps = []
    for index in range(1, 21):
        text = (row.get(f"MANUAL{index:02d}") or "").strip()
        if not text:
            continue
        text = STEP_PREFIX.sub("", text)
        text = STEP_SUFFIX.sub("", text).strip()
        if text:
            steps.append(text)
    return steps


def auto_ingredient_id(name):
    """등록되지 않은 재료에 붙일 안정적인 ID. 같은 이름이면 항상 같은 ID가 나온다."""
    slug = re.sub(r"[^0-9A-Za-z가-힣]+", "-", name).strip("-")
    return "auto-" + (slug or "unknown")


def convert(row, aliases, pantry, auto_register=False, auto_sink=None):
    """레시피 1건을 앱 Recipe로 바꾼다. 실패하면 (None, 차단된 재료명 집합)을 준다.

    auto_register=True면 미등록 재료를 판매 단위 없는 canonical로 만들어 통과시킨다.
    그 재료는 앱에서 구매량·예산을 계산하지 않고 사용자 확인 품목으로 표시된다.
    """
    category = (row.get("RCP_PAT2") or "").strip()
    slots = SLOTS_BY_CATEGORY.get(category)
    if not slots:
        return None, {f"[요리종류] {category or '미상'}"}

    steps = build_steps(row)
    if not steps:
        return None, {"[조리순서 없음]"}

    parsed, without_quantity = parse_parts(row.get("RCP_PARTS_DTLS") or "")
    if not parsed:
        return None, {"[재료 파싱 실패]"}

    blocked, pantry_used, ingredients = set(), [], []
    for name, quantity, unit in parsed:
        key = normalize(name)
        if key in pantry:
            pantry_used.append(name)
            continue
        if quantity <= 0:
            blocked.add(name)
            continue
        if len(name) > 20:
            # 개행 없이 이어진 줄은 재료 여러 개가 한 토큰으로 뭉친 것이다. 그대로 등록하지 않는다.
            blocked.add(name[:20] + "…")
            continue
        ingredient_id = aliases.get(key)
        if not ingredient_id:
            if not auto_register:
                blocked.add(name)
                continue
            ingredient_id = auto_ingredient_id(name)
            if auto_sink is not None:
                entry = auto_sink.setdefault(ingredient_id, {"id": ingredient_id, "name": name, "aliases": [], "units": Counter()})
                entry["units"][unit] += 1
        ingredients.append(
            {"ingredientID": ingredient_id, "rawName": name, "quantity": round(quantity, 3), "unit": unit, "preparation": None}
        )

    unmeasured = []
    for token in without_quantity:
        # "소금 약간"처럼 수량이 없는 토큰. 수량을 지어내지 않는다.
        stripped = re.sub(r"(약간|적당량|조금|톡톡).*$", "", token).strip()
        if normalize(stripped) in pantry:
            pantry_used.append(stripped)
        elif auto_register:
            unmeasured.append(token)  # 계산에 넣지 않고 설명에 그대로 보여준다
        else:
            # 리포트에서 상비 조미료 후보로 알아볼 수 있도록 "약간"을 뗀 이름으로 남긴다.
            blocked.add(stripped or token)

    if blocked or not ingredients:
        return None, blocked or {"[매칭된 재료 없음]"}

    # 가벼운 아침: 낮은 열량 + 한 끼로 성립하는 요리 종류. 반찬·국은 단독 아침으로 넣지 않는다.
    kcal = (row.get("INFO_ENG") or "").strip()
    is_light = bool(kcal) and float(kcal) <= LIGHT_BREAKFAST_MAX_KCAL and category in BREAKFAST_CATEGORIES
    meal_slots = (["아침"] if is_light else []) + slots

    method = (row.get("RCP_WAY2") or "").strip()
    tools = set(TOOLS_BY_METHOD.get(method, []))
    if any("전자레인지" in step for step in steps):
        tools.add("전자레인지")

    servings_match = SERVINGS.search(row.get("RCP_PARTS_DTLS") or "")
    tip = (row.get("RCP_NA_TIP") or "").strip()
    description = tip if tip else f"{category} · {method or '조리법 미상'}"
    if pantry_used:
        description += " 상비 조미료: " + ", ".join(sorted(set(pantry_used))) + "."
    if unmeasured:
        description += " 수량 미표기 재료: " + ", ".join(sorted(set(unmeasured))) + "."

    # 완성 사진만 가져온다. 원본 URL이 http라서 ATS에 막히므로 https로 바꾼다(같은 호스트에서 서빙됨).
    image_url = (row.get("ATT_FILE_NO_MAIN") or "").strip().replace("http://", "https://") or None

    tags = [tag for tag in [category, method] if tag]
    hash_tag = (row.get("HASH_TAG") or "").strip()
    if hash_tag:
        tags.append(hash_tag)

    return {
        "id": f"fsk-{row.get('RCP_SEQ')}",
        "title": re.sub(r"\s+", " ", (row.get("RCP_NM") or "").strip()),
        "description": description,
        "mealSlots": meal_slots,
        "difficulty": None,   # 원본에 없음. 추측하지 않는다.
        "cookTime": None,     # 원본에 없음. 추측하지 않는다.
        "servings": int(servings_match.group(1)) if servings_match else 1,
        "symbolName": SYMBOL_BY_CATEGORY.get(category, "🍽️"),
        "imageURL": image_url,
        "ingredients": ingredients,
        "steps": steps,
        "tags": tags[:3],
        "isLightBreakfast": is_light,
        "requiredTools": sorted(tools),
    }, set()


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    parser = argparse.ArgumentParser()
    # 키를 셸 히스토리에 남기지 않도록 환경변수를 먼저 본다.
    parser.add_argument("--key", default=os.environ.get("FOODSAFETY_API_KEY"),
                        help="식품안전나라 인증키. FOODSAFETY_API_KEY 환경변수로도 됩니다 (스모크 테스트는 sample)")
    parser.add_argument("--seed", default=os.path.join(root, "OneLog/OneLogApp/SeedData.swift"))
    parser.add_argument("--out", default=os.path.join(root, "OneLog/OneLogApp/Resources/imported_recipes.json"))
    parser.add_argument("--report", default=os.path.join(here, "unmatched_report.md"))
    parser.add_argument("--pantry", default=os.path.join(here, "pantry.json"))
    parser.add_argument("--cache", default=os.path.join(here, ".cache/cookrcp01.json"))
    parser.add_argument("--ingredients-out", default=os.path.join(root, "OneLog/OneLogApp/Resources/imported_ingredients.json"))
    parser.add_argument("--sale-units", default=os.path.join(here, "sale_units.json"))
    parser.add_argument("--auto-register", action="store_true",
                        help="미등록 재료를 판매 단위 없는 canonical로 자동 등록해 레시피를 최대한 살린다")
    args = parser.parse_args()
    key_file = os.path.join(here, ".api_key")
    if not args.key and os.path.exists(key_file):
        args.key = open(key_file, encoding="utf-8").read().strip()
    if not args.key:
        sys.exit(f"인증키가 필요합니다. {key_file} 에 키를 저장하거나 --key / FOODSAFETY_API_KEY 를 쓰세요.")

    aliases = parse_ingredients_from_swift(args.seed)
    pantry = set()
    if os.path.exists(args.pantry):
        pantry = {normalize(name) for name in json.load(open(args.pantry, encoding="utf-8"))}
    print(f"canonical 재료 {len(set(aliases.values()))}종 / 별칭 {len(aliases)}개, 상비 조미료 {len(pantry)}종", file=sys.stderr)

    rows = fetch(args.key, args.cache)
    print(f"원본 {len(rows)}건 처리", file=sys.stderr)

    recipes, blockers, solo_blockers = [], Counter(), Counter()
    dropped_by_reason = defaultdict(int)
    auto_sink = {}
    for row in rows:
        recipe, blocked = convert(row, aliases, pantry, auto_register=args.auto_register, auto_sink=auto_sink)
        if recipe:
            recipes.append(recipe)
            continue
        for name in blocked:
            blockers[name] += 1
            if name.startswith("["):
                dropped_by_reason[name] += 1
        if len(blocked) == 1:
            solo_blockers[next(iter(blocked))] += 1

    recipes.sort(key=lambda item: item["id"])
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    payload = {"source": SOURCE_NOTE, "lightBreakfastMaxKcal": LIGHT_BREAKFAST_MAX_KCAL, "recipes": recipes}
    json.dump(payload, open(args.out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    # 대표 판매 단위가 있는 재료만 구매량을 계산한다. 없으면 비워 두고 앱이 확인을 요청한다.
    sale_units = {}
    if os.path.exists(args.sale_units):
        sale_units = json.load(open(args.sale_units, encoding="utf-8")).get("saleUnits", {})

    used_ids = {item["ingredientID"] for recipe in recipes for item in recipe["ingredients"]}
    auto_ingredients = []
    priced = 0
    for entry in sorted(auto_sink.values(), key=lambda item: item["id"]):
        if entry["id"] not in used_ids:
            continue
        default_unit = entry["units"].most_common(1)[0][0]
        sale = sale_units.get(entry["name"]) or sale_units.get(entry["id"][len("auto-"):])
        unit_grams = (sale or {}).get("unitGrams")
        # 판매 단위와 레시피 단위가 다르면 환산 근거가 있을 때만 붙인다.
        if sale and sale["unit"] != default_unit and not (unit_grams and sale["unit"] in unit_grams and default_unit in unit_grams):
            sale = None
            unit_grams = None
        if sale:
            priced += 1
        auto_ingredients.append({
            "id": entry["id"],
            "name": entry["name"],
            "aliases": [entry["name"]],
            "defaultUnit": default_unit,
            "representativeSaleUnit": {k: sale[k] for k in ("amount", "unit", "label")} if sale else None,
            "storageNote": None,
            "unitGrams": unit_grams,
        })
    json.dump({"source": SOURCE_NOTE, "ingredients": auto_ingredients},
              open(args.ingredients_out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    lines = [
        "# 미매칭 재료 리포트",
        "",
        f"- 원본 {len(rows)}건 중 **{len(recipes)}건** 변환, {len(rows) - len(recipes)}건 제외",
        f"- 출처: {SOURCE_NOTE}",
        "",
        "## 이 재료 하나만 등록하면 바로 통과하는 레시피 수",
        "",
        "| 원본 재료명 | 단독 차단 레시피 | 전체 등장 |",
        "| --- | --- | --- |",
    ]
    for name, count in solo_blockers.most_common(40):
        if name.startswith("["):
            continue
        lines.append(f"| {name} | {count} | {blockers[name]} |")
    lines += ["", "## 전체 미매칭 빈도 (상위 60)", "", "| 원본 재료명 | 등장 레시피 |", "| --- | --- |"]
    for name, count in blockers.most_common(60):
        if name.startswith("["):
            continue
        lines.append(f"| {name} | {count} |")
    lines += ["", "## 재료 외 사유로 제외", ""]
    for reason, count in sorted(dropped_by_reason.items(), key=lambda item: -item[1]):
        lines.append(f"- {reason}: {count}건")
    open(args.report, "w", encoding="utf-8").write("\n".join(lines) + "\n")

    print(f"변환 {len(recipes)}건 → {args.out}", file=sys.stderr)
    print(f"자동 등록 재료 {len(auto_ingredients)}종 (그중 대표 판매 단위 보유 {priced}종) → {args.ingredients_out}", file=sys.stderr)
    print(f"리포트 → {args.report}", file=sys.stderr)


if __name__ == "__main__":
    main()
