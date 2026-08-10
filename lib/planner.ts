import { getIngredient } from "./ingredients";
import type {
  InventoryItem,
  MealPlanDraft,
  MealSlot,
  PlannedMealDraft,
  Recipe,
} from "./types";
import { MEAL_SLOTS } from "./types";

/**
 * F13 다일 식단 계획.
 *
 * 생성형 AI가 아니라 결정론적 규칙으로 후보를 고릅니다(제품 원칙 6, AGENTS 7절).
 * 같은 입력이면 항상 같은 결과가 나오고, 사용자가 언제든 메뉴를 교체하거나
 * 계획 전체를 버릴 수 있습니다. 이 함수는 계획을 확정하지 않고 초안만 만듭니다.
 */

export const MAX_PLAN_DAYS = 14;

export interface PlanRequest {
  startDate: string;
  days: number;
  /** 사용자가 먹는 끼니만. 비우면 계획이 생성되지 않습니다. */
  slots: MealSlot[];
  /** 찜하거나 이미 선택한 레시피 — 가능한 먼저 배치합니다. */
  seedRecipeIds: string[];
  inventory: InventoryItem[];
  recipes: Recipe[];
}

function addDays(date: string, offset: number): string {
  const parsed = new Date(`${date}T00:00:00`);
  if (Number.isNaN(parsed.getTime())) return date;
  parsed.setDate(parsed.getDate() + offset);
  return parsed.toLocaleDateString("sv-SE");
}

function availableIngredientIds(inventory: InventoryItem[]): Set<string> {
  return new Set(
    inventory
      .filter((item) => item.quantityStatus === "exact" && item.quantity !== null && item.quantity > 0)
      .map((item) => item.ingredientId),
  );
}

function uniqueIngredientIds(recipe: Recipe): string[] {
  return [...new Set(recipe.ingredients.map((item) => item.ingredientId))];
}

export function candidatesForSlot(slot: MealSlot, recipes: Recipe[]): Recipe[] {
  return recipes.filter((recipe) => recipe.mealSlots.includes(slot));
}

/** 계획에 포함된 각 칸의 재사용/추가 구매 수치와 전체 요약을 다시 계산합니다. */
export function recomputePlan(
  drafts: Array<Pick<PlannedMealDraft, "recipeId" | "date" | "mealSlot">>,
  request: Pick<PlanRequest, "inventory" | "recipes">,
): MealPlanDraft {
  const recipeMap = new Map(request.recipes.map((recipe) => [recipe.id, recipe]));
  const available = availableIngredientIds(request.inventory);
  const usageCount = new Map<string, number>();
  const detailed: PlannedMealDraft[] = [];

  for (const draft of drafts) {
    const recipe = recipeMap.get(draft.recipeId);
    if (!recipe) continue;

    const ids = uniqueIngredientIds(recipe);
    const reused = ids.filter((id) => available.has(id));
    const fresh = ids.filter((id) => !available.has(id));
    for (const id of ids) usageCount.set(id, (usageCount.get(id) ?? 0) + 1);
    // 이번 끼니에서 새로 사는 재료는 포장 단위 특성상 남으므로 이후 끼니에서 재사용 가능합니다.
    for (const id of fresh) available.add(id);

    const reason = reused.length === 0
      ? "새로 준비하는 메뉴예요."
      : fresh.length === 0
        ? `가진 재료 ${reused.length}가지만으로 만들 수 있어요.`
        : `가진 재료 ${reused.length}가지를 쓰고 ${fresh.length}가지만 새로 사면 돼요.`;

    detailed.push({
      recipeId: recipe.id,
      date: draft.date,
      mealSlot: draft.mealSlot,
      reason,
      reusedIngredientIds: reused,
      newPurchaseCount: fresh.length,
    });
  }

  const sharedIngredientNames = [...usageCount.entries()]
    .filter(([, count]) => count > 1)
    .map(([id]) => getIngredient(id).name)
    .sort((left, right) => left.localeCompare(right, "ko"));

  return {
    drafts: detailed,
    totalNewPurchases: detailed.reduce((sum, draft) => sum + draft.newPurchaseCount, 0),
    sharedIngredientNames,
    unfilledSlots: drafts.length - detailed.length,
  };
}

export function generateMealPlan(request: PlanRequest): MealPlanDraft {
  const days = Math.max(Math.min(Math.trunc(request.days), MAX_PLAN_DAYS), 0);
  const slots = MEAL_SLOTS.filter((slot) => request.slots.includes(slot));
  if (days === 0 || slots.length === 0 || request.recipes.length === 0) {
    return { drafts: [], totalNewPurchases: 0, sharedIngredientNames: [], unfilledSlots: 0 };
  }

  const available = availableIngredientIds(request.inventory);
  const seeds = request.seedRecipeIds.filter((id) => request.recipes.some((recipe) => recipe.id === id));
  const pendingSeeds = new Set(seeds);
  const chosenCount = new Map<string, number>();
  const picks: Array<Pick<PlannedMealDraft, "recipeId" | "date" | "mealSlot">> = [];
  let unfilledSlots = 0;

  for (let day = 0; day < days; day += 1) {
    const date = addDays(request.startDate, day);
    for (const slot of slots) {
      const candidates = candidatesForSlot(slot, request.recipes);
      if (candidates.length === 0) {
        unfilledSlots += 1;
        continue;
      }

      const recent = picks.slice(-slots.length).map((pick) => pick.recipeId);
      let best: Recipe | undefined;
      let bestScore = -Infinity;

      for (const recipe of candidates) {
        const ids = uniqueIngredientIds(recipe);
        const reuse = ids.filter((id) => available.has(id)).length;
        const fresh = ids.length - reuse;
        const repeats = chosenCount.get(recipe.id) ?? 0;
        const score =
          reuse * 100 -
          fresh * 15 +
          (4 - recipe.difficulty) * 3 +
          (pendingSeeds.has(recipe.id) ? 250 : 0) - // 사용자가 고른 메뉴를 먼저 배치
          repeats * 60 -
          (recent.includes(recipe.id) ? 500 : 0); // 직전 하루 안에서 같은 메뉴 반복 회피

        // 동점이면 레시피 목록 순서를 따라 결과를 결정론적으로 유지합니다.
        if (score > bestScore) {
          bestScore = score;
          best = recipe;
        }
      }

      if (!best) {
        unfilledSlots += 1;
        continue;
      }

      picks.push({ recipeId: best.id, date, mealSlot: slot });
      pendingSeeds.delete(best.id);
      chosenCount.set(best.id, (chosenCount.get(best.id) ?? 0) + 1);
      for (const id of uniqueIngredientIds(best)) available.add(id);
    }
  }

  const plan = recomputePlan(picks, request);
  return { ...plan, unfilledSlots: plan.unfilledSlots + unfilledSlots };
}
