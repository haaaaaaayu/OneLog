import { NextRequest, NextResponse } from "next/server";

const catalog = [
  { id: "chicken", title: "간장 닭다리 덮밥", minutes: 20, tags: ["든든", "점심", "덮밥"] },
  { id: "tofu", title: "두부 김치", minutes: 15, tags: ["한식", "저녁", "두부"] },
  { id: "tuna", title: "참치 마요 주먹밥", minutes: 10, tags: ["간단", "아침", "밥"] },
  { id: "cabbage", title: "양배추 달걀볶음", minutes: 12, tags: ["간단", "가벼운", "저녁"] },
  { id: "kimchi", title: "김치 볶음밥", minutes: 15, tags: ["매콤", "한식", "밥"] },
  { id: "cucumber", title: "오이 참치 비빔밥", minutes: 10, tags: ["가벼운", "점심", "간단"] },
];

function fallback(message: string) {
  const normalized = message.toLowerCase();
  let ids = ["cabbage", "tuna", "cucumber"];
  if (normalized.includes("매운") || normalized.includes("김치")) ids = ["kimchi", "tofu"];
  else if (normalized.includes("든든") || normalized.includes("고기")) ids = ["chicken", "kimchi"];
  else if (normalized.includes("아침")) ids = ["tuna", "cucumber"];
  return { reply: "요청하신 조건을 반영해 현재 식단에서 바꿀 수 있는 메뉴를 골랐어요.", candidates: ids, source: "fallback" as const };
}

export async function POST(request: NextRequest) {
  const body = await request.json().catch(() => ({}));
  const message = typeof body.message === "string" ? body.message.slice(0, 500) : "";
  if (!message.trim()) return NextResponse.json({ error: "메시지를 입력해 주세요." }, { status: 400 });
  const key = process.env.OPENAI_API_KEY;
  if (!key) return NextResponse.json(fallback(message));

  try {
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { authorization: `Bearer ${key}`, "content-type": "application/json" },
      body: JSON.stringify({
        model: process.env.OPENAI_MODEL || "gpt-4.1-mini",
        store: false,
        max_output_tokens: 300,
        input: [
          { role: "system", content: `너는 한끼로그 식단 수정 도우미다. 반드시 카탈로그 ID만 추천한다. 카탈로그: ${JSON.stringify(catalog)}. JSON만 반환: {"reply":"짧은 한국어 설명","candidates":["id"]}` },
          { role: "user", content: message },
        ],
        text: {
          format: {
            type: "json_schema",
            name: "meal_plan_candidates",
            strict: true,
            schema: {
              type: "object",
              properties: {
                reply: { type: "string" },
                candidates: {
                  type: "array",
                  items: { type: "string", enum: catalog.map((item) => item.id) },
                  maxItems: 3,
                },
              },
              required: ["reply", "candidates"],
              additionalProperties: false,
            },
          },
        },
      }),
    });
    if (!response.ok) throw new Error(`OpenAI ${response.status}`);
    const payload = await response.json();
    const text = payload.output_text ?? payload.output?.flatMap((item: { content?: { text?: string }[] }) => item.content ?? []).map((item: { text?: string }) => item.text ?? "").join("");
    const parsed = JSON.parse(text);
    const valid = Array.isArray(parsed.candidates) ? parsed.candidates.filter((id: string) => catalog.some((item) => item.id === id)).slice(0, 3) : [];
    return NextResponse.json({ reply: String(parsed.reply || "조건에 맞는 메뉴를 골랐어요."), candidates: valid.length ? valid : fallback(message).candidates, source: "openai" });
  } catch {
    return NextResponse.json(fallback(message));
  }
}
