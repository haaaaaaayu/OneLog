import { getIngredient } from "./ingredients";
import type {
  IngredientRequirement,
  InventoryItem,
  PackageSize,
  PlannedMeal,
  Recipe,
  RecipeIngredient,
  ShoppingPlanItem,
} from "./types";
import { isUnit } from "./types";

const EPSILON = 0.000001;

export function ingredientKey(ingredientId: string, unit: RecipeIngredient["unit"]): string {
  return `${ingredientId}:${unit}`;
}

function safeQuantity(quantity: number): number {
  if (!Number.isFinite(quantity) || quantity < 0) return 0;
  return quantity;
}

function safePackageSize(packageSize: PackageSize | undefined, fallback: PackageSize): PackageSize {
  if (!packageSize || !Number.isFinite(packageSize.amount) || packageSize.amount <= 0 || !isUnit(packageSize.unit)) return fallback;
  return {
    amount: packageSize.amount,
    unit: packageSize.unit,
    label: typeof packageSize.label === "string" && packageSize.label.trim() ? packageSize.label : `${packageSize.amount}${packageSize.unit}`,
  };
}

export function aggregateRequirements(
  plannedMeals: PlannedMeal[],
  recipes: Recipe[],
): IngredientRequirement[] {
  const recipeMap = new Map(recipes.map((recipe) => [recipe.id, recipe]));
  const grouped = new Map<string, IngredientRequirement>();
  const unitsByIngredient = new Map<string, Set<RecipeIngredient["unit"]>>();

  for (const meal of plannedMeals.filter((item) => item.status === "planned")) {
    const recipe = recipeMap.get(meal.recipeId);
    if (!recipe) continue;

    for (const ingredient of recipe.ingredients) {
      const key = ingredientKey(ingredient.ingredientId, ingredient.unit);
      const existingUnits = unitsByIngredient.get(ingredient.ingredientId) ?? new Set();
      existingUnits.add(ingredient.unit);
      unitsByIngredient.set(ingredient.ingredientId, existingUnits);

      const existing = grouped.get(key);
      if (existing) {
        existing.quantity += safeQuantity(ingredient.quantity);
        if (!existing.recipeIds.includes(recipe.id)) existing.recipeIds.push(recipe.id);
      } else {
        grouped.set(key, {
          key,
          ingredientId: ingredient.ingredientId,
          ingredientName: getIngredient(ingredient.ingredientId).name,
          quantity: safeQuantity(ingredient.quantity),
          unit: ingredient.unit,
          recipeIds: [recipe.id],
          unitConflict: false,
        });
      }
    }
  }

  return [...grouped.values()]
    .map((requirement) => ({
      ...requirement,
      unitConflict: (unitsByIngredient.get(requirement.ingredientId)?.size ?? 0) > 1,
    }))
    .sort((left, right) => left.ingredientName.localeCompare(right.ingredientName, "ko"));
}

function getMatchingInventory(
  inventory: InventoryItem[],
  ingredientId: string,
  unit: InventoryItem["unit"],
): InventoryItem | undefined {
  return inventory.find((item) => item.ingredientId === ingredientId && item.unit === unit);
}

function hasDifferentUnitInventory(inventory: InventoryItem[], ingredientId: string, unit: InventoryItem["unit"]): boolean {
  return inventory.some((item) => item.ingredientId === ingredientId && item.unit !== unit);
}

export function calculateShoppingPlan(
  requirements: IngredientRequirement[],
  inventory: InventoryItem[],
  packageOverrides: Record<string, PackageSize> = {},
): ShoppingPlanItem[] {
  return requirements.map((requirement) => {
    const ingredient = getIngredient(requirement.ingredientId);
    const inventoryItem = getMatchingInventory(inventory, requirement.ingredientId, requirement.unit);
    const quantityIsUnknown = inventoryItem?.quantityStatus === "unknown" || inventoryItem?.quantity === null;
    const availableQuantity = quantityIsUnknown ? null : safeQuantity(inventoryItem?.quantity ?? 0);
    const calculationAvailable = quantityIsUnknown ? 0 : availableQuantity;
    const packageSize = safePackageSize(packageOverrides[requirement.ingredientId], ingredient.representativeSaleUnit);
    const unitMismatch = hasDifferentUnitInventory(inventory, requirement.ingredientId, requirement.unit);
    const manualCalculation = requirement.unitConflict || packageSize.unit !== requirement.unit;

    if (manualCalculation) {
      const reasons = [
        requirement.unitConflict ? "레시피마다 단위가 달라 합산하지 않았어요." : "대표 판매 단위와 필요한 단위가 달라요.",
        unitMismatch ? "보유 재료 단위도 확인이 필요해요." : "구매 전 단위를 확인해 주세요.",
      ];
      return {
        ...requirement,
        availableQuantity,
        quantityStatus: quantityIsUnknown ? "unknown" : "exact",
        additionalNeeded: Math.max(requirement.quantity - (calculationAvailable ?? 0), 0),
        packageSize,
        purchaseQuantity: 0,
        purchaseTotal: 0,
        expectedRemaining: null,
        precision: "manual",
        note: reasons.join(" "),
      };
    }

    const additionalNeeded = Math.max(requirement.quantity - (calculationAvailable ?? 0), 0);
    const purchaseQuantity = additionalNeeded > EPSILON ? Math.ceil(additionalNeeded / packageSize.amount) : 0;
    const purchaseTotal = purchaseQuantity * packageSize.amount;
    const expectedRemaining = Math.max((calculationAvailable ?? 0) + purchaseTotal - requirement.quantity, 0);
    const note = quantityIsUnknown
      ? "보유량을 수량 미상으로 입력해, 구매량 계산에서 제외했어요. 실제 수량을 확인하면 더 정확해져요."
      : unitMismatch
        ? "같은 재료의 다른 단위 보유량은 자동 변환하지 않았어요."
        : undefined;

    return {
      ...requirement,
      availableQuantity,
      quantityStatus: quantityIsUnknown ? "unknown" : "exact",
      additionalNeeded,
      packageSize,
      purchaseQuantity,
      purchaseTotal,
      expectedRemaining,
      precision: quantityIsUnknown ? "estimated" : "exact",
      note,
    };
  });
}

export function calculateRecipeShoppingPlan(
  recipe: Recipe,
  inventory: InventoryItem[],
  packageOverrides: Record<string, PackageSize> = {},
): ShoppingPlanItem[] {
  const requirements = aggregateRequirements(
    [{ id: `preview:${recipe.id}`, recipeId: recipe.id, date: "2099-01-01", mealSlot: recipe.mealSlots[0] ?? "저녁", status: "planned", createdAt: "2099-01-01T00:00:00.000Z" }],
    [recipe],
  );
  return calculateShoppingPlan(requirements, inventory, packageOverrides);
}

export function applyPurchases(
  inventory: InventoryItem[],
  shoppingItems: ShoppingPlanItem[],
  now = new Date().toISOString(),
): InventoryItem[] {
  const next = inventory.map((item) => ({ ...item }));

  for (const item of shoppingItems) {
    if (item.purchaseTotal <= EPSILON || item.precision === "manual") continue;
    const existing = next.find((stock) => stock.ingredientId === item.ingredientId && stock.unit === item.unit);

    if (!existing) {
      next.push({
        ingredientId: item.ingredientId,
        quantity: item.purchaseTotal,
        unit: item.unit,
        quantityStatus: "exact",
        updatedAt: now,
      });
      continue;
    }

    if (existing.quantityStatus === "exact" && existing.quantity !== null) {
      existing.quantity += item.purchaseTotal;
      existing.updatedAt = now;
    }
    // 수량 미상 보유 재료에 구매량을 더해 확정값처럼 보이게 만들지 않습니다.
  }

  return next;
}

export interface ConsumptionInput {
  ingredientId: string;
  unit: RecipeIngredient["unit"];
  expectedQuantity: number;
  actualQuantity: number;
  remainingQuantity: number | null;
}

export function applyConsumption(
  inventory: InventoryItem[],
  consumptions: ConsumptionInput[],
  now = new Date().toISOString(),
): InventoryItem[] {
  const next = inventory.map((item) => ({ ...item }));

  for (const consumption of consumptions) {
    const actualQuantity = safeQuantity(consumption.actualQuantity);
    const existing = next.find(
      (stock) => stock.ingredientId === consumption.ingredientId && stock.unit === consumption.unit,
    );

    if (consumption.remainingQuantity !== null && Number.isFinite(consumption.remainingQuantity)) {
      const remainingQuantity = safeQuantity(consumption.remainingQuantity);
      if (existing) {
        existing.quantity = remainingQuantity;
        existing.quantityStatus = "exact";
        existing.updatedAt = now;
      } else {
        next.push({
          ingredientId: consumption.ingredientId,
          quantity: remainingQuantity,
          unit: consumption.unit,
          quantityStatus: "exact",
          updatedAt: now,
        });
      }
      continue;
    }

    if (!existing) {
      next.push({
        ingredientId: consumption.ingredientId,
        quantity: 0,
        unit: consumption.unit,
        quantityStatus: "exact",
        updatedAt: now,
      });
      continue;
    }

    if (existing.quantityStatus === "exact" && existing.quantity !== null) {
      existing.quantity = Math.max(existing.quantity - actualQuantity, 0);
      existing.updatedAt = now;
    }
    // 수량 미상 재고는 실제 남은 수량을 입력하기 전까지 미상으로 유지합니다.
  }

  return next;
}
