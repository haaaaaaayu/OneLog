import { calculateRecipeShoppingPlan } from "./calculations";
import { getIngredient, resolveIngredient } from "./ingredients";
import type { InventoryItem, PackageSize, Recipe, Recommendation, ShoppingPlanItem } from "./types";

function exactAvailableIngredientIds(inventory: InventoryItem[]): Set<string> {
  return new Set(
    inventory
      .filter((item) => item.quantityStatus === "exact" && item.quantity !== null && item.quantity > 0)
      .map((item) => item.ingredientId),
  );
}

function contextIngredientIds(additionalNames: string[]): Set<string> {
  return new Set(
    additionalNames
      .map((name) => resolveIngredient(name)?.id)
      .filter((ingredientId): ingredientId is string => Boolean(ingredientId)),
  );
}

function markContextOnlyItem(item: ShoppingPlanItem, contextIds: Set<string>): ShoppingPlanItem {
  if (!contextIds.has(item.ingredientId)) return item;
  return {
    ...item,
    availableQuantity: null,
    quantityStatus: "unknown",
    precision: item.precision === "manual" ? "manual" : "estimated",
    note: "추가 입력 재료의 실제 수량을 확인하면 구매량을 더 정확하게 계산할 수 있어요.",
  };
}

export function rankLeftoverRecipes(
  recipes: Recipe[],
  inventory: InventoryItem[],
  additionalNames: string[] = [],
  packageOverrides: Record<string, PackageSize> = {},
): Recommendation[] {
  const exactIds = exactAvailableIngredientIds(inventory);
  const contextIds = contextIngredientIds(additionalNames);

  return recipes
    .map((recipe) => {
      const uniqueIngredients = [...new Map(recipe.ingredients.map((item) => [item.ingredientId, item])).values()];
      const used = uniqueIngredients.filter((item) => exactIds.has(item.ingredientId) || contextIds.has(item.ingredientId));
      if (used.length === 0) return null;

      const shoppingPlan = calculateRecipeShoppingPlan(recipe, inventory, packageOverrides);
      const additionalPurchaseItems = shoppingPlan
        .filter((item) => item.purchaseQuantity > 0 || item.precision === "manual")
        .map((item) => markContextOnlyItem(item, contextIds));
      const highRiskUsed = used.filter((item) => getIngredient(item.ingredientId).riskLevel === "high");
      const mediumRiskUsed = used.filter((item) => getIngredient(item.ingredientId).riskLevel === "medium");
      const usedIngredientIds = used.map((item) => item.ingredientId);
      const usedNames = used.map((item) => getIngredient(item.ingredientId).name);
      // 사용자가 직접 입력한 추가 재료는 "활용 재료"이므로 "추가 구매"로 중복 표기하지 않습니다.
      // (수량 미상이라 미니 장보기 목록에는 안내 문구와 함께 그대로 남깁니다.)
      const additionalNamesForPurchase = additionalPurchaseItems
        .filter((item) => !contextIds.has(item.ingredientId))
        .map((item) => item.ingredientName);
      const purchaseCount = additionalNamesForPurchase.length;
      const riskName = highRiskUsed[0] ? getIngredient(highRiskUsed[0].ingredientId).name : usedNames[0];
      const score = used.length * 100 + highRiskUsed.length * 25 + mediumRiskUsed.length * 10 - purchaseCount * 12 + (4 - recipe.difficulty);
      const reason = highRiskUsed.length > 0
        ? `${riskName}처럼 먼저 쓰면 좋은 재료를 포함해 남은 재료 ${used.length}가지를 활용해요${purchaseCount > 0 ? `. 추가 구매 ${purchaseCount}개 품목이 필요해요` : ""}.`
        : purchaseCount === 0
          ? `추가 구매 없이 남은 재료 ${used.length}가지를 한 끼로 연결해요.`
          : `남은 재료 ${used.length}가지를 활용하고 ${purchaseCount}개 품목을 더 준비하면 돼요.`;

      return {
        recipe,
        usedIngredients: usedNames,
        usedIngredientIds,
        additionalIngredients: additionalNamesForPurchase,
        additionalPurchaseItems,
        score,
        reason,
      } satisfies Recommendation;
    })
    .filter((recommendation): recommendation is Recommendation => recommendation !== null)
    .sort((left, right) => {
      const usedDifference = right.usedIngredients.length - left.usedIngredients.length;
      if (usedDifference !== 0) return usedDifference;
      const leftHighRisk = left.usedIngredientIds.filter((id) => getIngredient(id).riskLevel === "high").length;
      const rightHighRisk = right.usedIngredientIds.filter((id) => getIngredient(id).riskLevel === "high").length;
      if (rightHighRisk !== leftHighRisk) return rightHighRisk - leftHighRisk;
      const missingDifference = left.additionalIngredients.length - right.additionalIngredients.length;
      if (missingDifference !== 0) return missingDifference;
      if (left.recipe.difficulty !== right.recipe.difficulty) return left.recipe.difficulty - right.recipe.difficulty;
      return right.score - left.score;
    });
}
