import type { CanonicalIngredient, Unit } from "./types";

export const INGREDIENTS: CanonicalIngredient[] = [
  {
    id: "egg",
    name: "계란",
    aliases: ["계란", "달걀", "계란 노른자", "달걀 노른자"],
    defaultUnit: "개",
    representativeSaleUnit: { amount: 10, unit: "개", label: "계란 10구" },
    riskLevel: "medium",
    storageNote: "냉장 보관하고 깨진 계란은 먼저 사용하세요.",
  },
  {
    id: "onion",
    name: "양파",
    aliases: ["양파", "채 썬 양파", "다진 양파"],
    defaultUnit: "개",
    representativeSaleUnit: { amount: 3, unit: "개", label: "양파 3개 묶음" },
    riskLevel: "medium",
    storageNote: "손질한 양파는 밀폐해 냉장 보관하세요.",
  },
  {
    id: "green-onion",
    name: "대파",
    aliases: ["대파", "다진 대파", "송송 썬 대파", "파"],
    defaultUnit: "g",
    representativeSaleUnit: { amount: 300, unit: "g", label: "대파 300g" },
    riskLevel: "high",
    storageNote: "손질 후 키친타월과 함께 밀폐해 냉장 보관하세요.",
  },
  {
    id: "chicken-thigh",
    name: "닭다리살",
    aliases: ["닭다리살", "닭고기", "닭 허벅지살"],
    defaultUnit: "g",
    representativeSaleUnit: { amount: 500, unit: "g", label: "닭다리살 500g" },
    riskLevel: "high",
    storageNote: "구매 후 1~2일 안에 사용하고 오래 둘 때는 냉동하세요.",
  },
  {
    id: "tofu",
    name: "두부",
    aliases: ["두부", "부침용 두부", "찌개용 두부"],
    defaultUnit: "팩",
    representativeSaleUnit: { amount: 1, unit: "팩", label: "두부 1팩" },
    riskLevel: "high",
    storageNote: "개봉 후 물에 담아 냉장 보관하고 가능한 빨리 사용하세요.",
  },
  {
    id: "rice",
    name: "밥",
    aliases: ["밥", "즉석밥", "쌀밥"],
    defaultUnit: "g",
    representativeSaleUnit: { amount: 210, unit: "g", label: "즉석밥 210g" },
    riskLevel: "low",
    storageNote: "남은 밥은 식힌 뒤 밀폐해 냉장 또는 냉동 보관하세요.",
  },
  {
    id: "kimchi",
    name: "김치",
    aliases: ["김치", "배추김치", "묵은지"],
    defaultUnit: "g",
    representativeSaleUnit: { amount: 500, unit: "g", label: "김치 500g" },
    riskLevel: "medium",
    storageNote: "개봉 후 냉장 보관하고 덜어 먹는 집게를 사용하세요.",
  },
  {
    id: "tuna",
    name: "참치캔",
    aliases: ["참치", "참치캔", "통조림 참치"],
    defaultUnit: "팩",
    representativeSaleUnit: { amount: 1, unit: "팩", label: "참치캔 1개" },
    riskLevel: "low",
    storageNote: "개봉 후에는 캔에서 꺼내 밀폐 냉장 보관하세요.",
  },
  {
    id: "carrot",
    name: "당근",
    aliases: ["당근", "채 썬 당근"],
    defaultUnit: "g",
    representativeSaleUnit: { amount: 300, unit: "g", label: "당근 300g" },
    riskLevel: "medium",
    storageNote: "물기를 닦고 밀폐해 냉장 보관하세요.",
  },
  {
    id: "garlic",
    name: "다진 마늘",
    aliases: ["마늘", "다진 마늘", "간 마늘"],
    defaultUnit: "큰술",
    representativeSaleUnit: { amount: 10, unit: "큰술", label: "다진 마늘 10큰술" },
    riskLevel: "medium",
    storageNote: "개봉한 다진 마늘은 냉장 또는 냉동 보관하세요.",
  },
  {
    id: "cabbage",
    name: "양배추",
    aliases: ["양배추", "채 썬 양배추"],
    defaultUnit: "g",
    representativeSaleUnit: { amount: 500, unit: "g", label: "양배추 500g" },
    riskLevel: "medium",
    storageNote: "자른 단면을 랩으로 감싸 냉장 보관하세요.",
  },
  {
    id: "soy-sauce",
    name: "간장",
    aliases: ["간장", "진간장", "양조간장"],
    defaultUnit: "큰술",
    representativeSaleUnit: { amount: 30, unit: "큰술", label: "간장 30큰술" },
    riskLevel: "low",
    storageNote: "직사광선을 피해 실온 보관하세요.",
  },
  {
    id: "sesame-oil",
    name: "참기름",
    aliases: ["참기름"],
    defaultUnit: "큰술",
    representativeSaleUnit: { amount: 20, unit: "큰술", label: "참기름 20큰술" },
    riskLevel: "low",
    storageNote: "직사광선을 피해 서늘한 곳에 보관하세요.",
  },
  {
    id: "seaweed",
    name: "김",
    aliases: ["김", "김가루", "조미김"],
    defaultUnit: "장",
    representativeSaleUnit: { amount: 10, unit: "장", label: "김 10장" },
    riskLevel: "low",
    storageNote: "습기를 피해 밀폐 보관하세요.",
  },
  {
    id: "cucumber",
    name: "오이",
    aliases: ["오이", "채 썬 오이"],
    defaultUnit: "개",
    representativeSaleUnit: { amount: 3, unit: "개", label: "오이 3개" },
    riskLevel: "high",
    storageNote: "물기를 닦고 냉장 보관하며 빨리 사용하세요.",
  },
  {
    id: "gochujang",
    name: "고추장",
    aliases: ["고추장"],
    defaultUnit: "큰술",
    representativeSaleUnit: { amount: 25, unit: "큰술", label: "고추장 25큰술" },
    riskLevel: "low",
    storageNote: "개봉 후 냉장 보관하세요.",
  },
];

function normalizedName(name: string): string {
  return name.trim().toLowerCase().replace(/[\s·,./_-]/g, "");
}

const aliasIndex = new Map<string, CanonicalIngredient>();
for (const ingredient of INGREDIENTS) {
  aliasIndex.set(normalizedName(ingredient.name), ingredient);
  for (const alias of ingredient.aliases) aliasIndex.set(normalizedName(alias), ingredient);
}

export function resolveIngredient(name: string): CanonicalIngredient | undefined {
  return aliasIndex.get(normalizedName(name));
}

export function getIngredient(ingredientId: string): CanonicalIngredient {
  const ingredient = INGREDIENTS.find((item) => item.id === ingredientId);
  if (!ingredient) throw new Error(`Unknown ingredient: ${ingredientId}`);
  return ingredient;
}

export function ingredientUnit(ingredientId: string): Unit {
  return getIngredient(ingredientId).defaultUnit;
}
