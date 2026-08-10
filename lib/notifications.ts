import { rankDepletionRisks } from "./risk";
import { getMealStorageWarnings } from "./schedule";
import type { AppAlert, AppState, Recipe } from "./types";

/**
 * F16 인앱 알림.
 *
 * 알림은 재고와 식단에서 그때그때 도출합니다. 저장하는 것은 사용자가 끈 알림의 id뿐이라
 * 재고·일정이 바뀌면 알림도 자동으로 갱신되고, 같은 사유가 두 번 발행되지 않습니다.
 *
 * 브라우저 푸시 알림은 서비스 워커와 발송 서버가 필요해 포함하지 않았습니다.
 */

function daysUntil(date: string, now: Date): number {
  const target = new Date(`${date}T00:00:00`);
  if (Number.isNaN(target.getTime())) return Number.POSITIVE_INFINITY;
  const toDay = (value: Date) => Date.UTC(value.getFullYear(), value.getMonth(), value.getDate());
  return Math.round((toDay(target) - toDay(now)) / 86_400_000);
}

export function deriveAlerts(
  state: Pick<AppState, "inventory" | "plannedMeals" | "notificationSettings" | "dismissedAlerts">,
  recipes: Recipe[],
  now = new Date(),
): AppAlert[] {
  const settings = state.notificationSettings;
  const dismissed = new Set(state.dismissedAlerts);
  const alerts: AppAlert[] = [];

  if (settings.riskAlerts) {
    for (const risk of rankDepletionRisks(state.inventory, state.plannedMeals, recipes, now)) {
      if (risk.state !== "urgent" && risk.state !== "unknown") continue;
      // 위험 상태가 바뀌면 새 알림으로 취급되도록 id에 상태를 포함합니다.
      const id = `risk:${risk.ingredientId}:${risk.unit}:${risk.state}`;
      if (dismissed.has(id)) continue;
      alerts.push({
        id,
        kind: "risk",
        severity: risk.state === "urgent" ? "high" : "medium",
        title: risk.state === "urgent" ? `${risk.ingredientName}을(를) 먼저 쓰세요` : `${risk.ingredientName} 수량 확인이 필요해요`,
        body: risk.reasons.join(" "),
        ingredientId: risk.ingredientId,
      });
    }
  }

  if (settings.mealReminders) {
    const recipeMap = new Map(recipes.map((recipe) => [recipe.id, recipe]));
    for (const meal of state.plannedMeals) {
      if (meal.status !== "planned") continue;
      const recipe = recipeMap.get(meal.recipeId);
      if (!recipe) continue;

      const remaining = daysUntil(meal.date, now);
      if (remaining < 0 || remaining > settings.leadDays) continue;
      const id = `meal:${meal.id}:${meal.date}`;
      if (dismissed.has(id)) continue;

      const warning = getMealStorageWarnings(meal, recipe, now)[0];
      alerts.push({
        id,
        kind: "meal",
        severity: remaining === 0 ? "high" : "medium",
        title: remaining === 0 ? `오늘 ${meal.mealSlot}: ${recipe.title}` : `${remaining}일 뒤 ${meal.mealSlot}: ${recipe.title}`,
        body: warning ?? `재료 ${recipe.ingredients.length}가지 · ${recipe.cookTime}분이면 만들 수 있어요.`,
        plannedMealId: meal.id,
      });
    }
  }

  return alerts.sort((left, right) => {
    if (left.severity !== right.severity) return left.severity === "high" ? -1 : 1;
    return left.id.localeCompare(right.id);
  });
}
