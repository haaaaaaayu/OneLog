import { getIngredient } from "./ingredients";
import type { DepletionRisk, InventoryItem, PlannedMeal, Recipe, RiskLevel, RiskState } from "./types";

/**
 * F15 재료 소진 위험.
 *
 * 위험도는 규칙으로만 계산합니다(제품 원칙 6). 근거가 부족하면 거짓 정밀도 대신
 * score를 null로 두고 "확인 필요" 상태를 표시합니다.
 */

/** 보관 특성별 권장 소진 기한(일). 냉동처럼 오래 가는 재료를 우선 경고하지 않기 위한 기준입니다. */
const SHELF_DAYS: Record<RiskLevel, number> = {
  high: 3,
  medium: 7,
  low: 30,
};

const URGENT_SCORE = 70;
const SOON_SCORE = 40;

function startOfDay(value: Date): number {
  return Date.UTC(value.getFullYear(), value.getMonth(), value.getDate());
}

export function daysBetween(fromIso: string, now: Date): number {
  const from = new Date(fromIso);
  if (Number.isNaN(from.getTime())) return 0;
  return Math.max(Math.floor((startOfDay(now) - startOfDay(from)) / 86_400_000), 0);
}

/** 예정된(아직 요리하지 않은) 식사가 이 재료를 같은 단위로 얼마나 쓰는지 합산합니다. */
export function plannedUsageFor(
  ingredientId: string,
  unit: InventoryItem["unit"],
  plannedMeals: PlannedMeal[],
  recipes: Recipe[],
): number {
  const recipeMap = new Map(recipes.map((recipe) => [recipe.id, recipe]));
  let total = 0;
  for (const meal of plannedMeals) {
    if (meal.status !== "planned") continue;
    const recipe = recipeMap.get(meal.recipeId);
    if (!recipe) continue;
    for (const ingredient of recipe.ingredients) {
      if (ingredient.ingredientId === ingredientId && ingredient.unit === unit) total += ingredient.quantity;
    }
  }
  return total;
}

function toState(score: number | null): RiskState {
  if (score === null) return "unknown";
  if (score >= URGENT_SCORE) return "urgent";
  if (score >= SOON_SCORE) return "soon";
  return "stable";
}

export function calculateDepletionRisk(
  item: InventoryItem,
  plannedMeals: PlannedMeal[],
  recipes: Recipe[],
  now = new Date(),
): DepletionRisk {
  const ingredient = getIngredient(item.ingredientId);
  const shelfDays = SHELF_DAYS[ingredient.riskLevel];
  const daysSinceUpdate = daysBetween(item.updatedAt, now);
  const plannedUsage = plannedUsageFor(item.ingredientId, item.unit, plannedMeals, recipes);
  const reasons: string[] = [];

  // 수량을 모르면 소진율을 계산할 근거가 없습니다. 보관 경과만 알리고 점수는 내지 않습니다.
  if (item.quantityStatus === "unknown" || item.quantity === null) {
    reasons.push(`수량을 몰라 위험도를 계산할 수 없어요. 기록한 지 ${daysSinceUpdate}일 지났어요.`);
    if (plannedUsage > 0) reasons.push("예정된 식단에서 사용할 계획이 있어요.");
    return {
      ingredientId: item.ingredientId,
      ingredientName: ingredient.name,
      unit: item.unit,
      score: null,
      state: "unknown",
      reasons,
      plannedUsage,
      daysSinceUpdate,
      shelfDays,
    };
  }

  if (item.quantity <= 0) {
    return {
      ingredientId: item.ingredientId,
      ingredientName: ingredient.name,
      unit: item.unit,
      score: 0,
      state: "stable",
      reasons: ["남은 수량이 없어요."],
      plannedUsage,
      daysSinceUpdate,
      shelfDays,
    };
  }

  // 보관 경과 비율이 기본 점수, 사용 계획이 있으면 그만큼 위험을 낮춥니다.
  const elapsedRatio = Math.min(daysSinceUpdate / shelfDays, 1.5);
  const coverage = Math.min(plannedUsage / item.quantity, 1);
  const score = Math.max(Math.min(Math.round(elapsedRatio * 100 - coverage * 45), 100), 0);

  reasons.push(
    ingredient.riskLevel === "high"
      ? `빨리 상하는 재료예요. 권장 소진 기한은 ${shelfDays}일이에요.`
      : `권장 소진 기한 ${shelfDays}일 기준이에요.`,
  );
  reasons.push(`기록한 지 ${daysSinceUpdate}일 지났어요.`);
  if (coverage >= 1) reasons.push("예정된 식단만으로 전부 사용할 계획이에요.");
  else if (plannedUsage > 0) reasons.push(`예정된 식단에서 일부(${plannedUsage}${item.unit})만 사용해요.`);
  else reasons.push("아직 사용 계획이 없어요.");

  return {
    ingredientId: item.ingredientId,
    ingredientName: ingredient.name,
    unit: item.unit,
    score,
    state: toState(score),
    reasons,
    plannedUsage,
    daysSinceUpdate,
    shelfDays,
  };
}

/** 위험이 큰 순, 같으면 사용 계획 없는 순, 그다음 이름 순으로 정렬합니다. */
export function rankDepletionRisks(
  inventory: InventoryItem[],
  plannedMeals: PlannedMeal[],
  recipes: Recipe[],
  now = new Date(),
): DepletionRisk[] {
  return inventory
    .map((item) => calculateDepletionRisk(item, plannedMeals, recipes, now))
    .sort((left, right) => {
      // 근거 없는 항목(unknown)은 점수 있는 항목 뒤, 안정 항목 앞에 둡니다.
      const rank = (risk: DepletionRisk) => (risk.score === null ? SOON_SCORE - 1 : risk.score);
      if (rank(right) !== rank(left)) return rank(right) - rank(left);
      if (left.plannedUsage !== right.plannedUsage) return left.plannedUsage - right.plannedUsage;
      return left.ingredientName.localeCompare(right.ingredientName, "ko");
    });
}
