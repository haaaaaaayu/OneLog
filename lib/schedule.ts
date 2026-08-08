import { getIngredient } from "./ingredients";
import type { PlannedMeal, Recipe } from "./types";

const STORAGE_CHECK_DAYS = {
  high: 2,
  medium: 5,
  low: Number.POSITIVE_INFINITY,
} as const;

function startOfDay(value: Date): number {
  return Date.UTC(value.getFullYear(), value.getMonth(), value.getDate());
}

function daysUntil(date: string, now: Date): number {
  const target = new Date(`${date}T00:00:00`);
  return Math.ceil((startOfDay(target) - startOfDay(now)) / (24 * 60 * 60 * 1000));
}

export function getMealStorageWarnings(meal: PlannedMeal, recipe: Recipe, now = new Date()): string[] {
  const days = daysUntil(meal.date, now);
  const ingredientNames = [...new Set(
    recipe.ingredients
      .map((item) => getIngredient(item.ingredientId))
      .filter((ingredient) => days > STORAGE_CHECK_DAYS[ingredient.riskLevel])
      .map((ingredient) => ingredient.name),
  )];

  if (days < 0) return ["사용 예정일이 지났어요. 재료 상태를 먼저 확인하세요."];
  if (ingredientNames.length === 0) return [];
  return [`${ingredientNames.join(", ")} 사용 예정일이 ${days}일 뒤예요. 보관 상태와 개봉 여부를 확인하세요.`];
}
