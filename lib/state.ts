import { applyConsumption, applyPurchases, type ConsumptionInput } from "./calculations";
import { getIngredient } from "./ingredients";
import { createWasteLog } from "./records";
import { getRecipe } from "./seed-data";
import { createInitialState } from "./persistence";
import type {
  AppState,
  CookingCompletion,
  InventoryItem,
  MealSlot,
  NotificationSettings,
  PackageSize,
  PlannedMeal,
  WasteReason,
} from "./types";
import { isUnit } from "./types";

export { createInitialState } from "./persistence";

export function addPlannedMeal(
  state: AppState,
  recipeId: string,
  date: string,
  mealSlot: MealSlot,
  now = new Date().toISOString(),
): AppState {
  const duplicate = state.plannedMeals.some(
    (meal) => meal.recipeId === recipeId && meal.date === date && meal.mealSlot === mealSlot && meal.status === "planned",
  );
  if (duplicate) return state;

  const plannedMeal: PlannedMeal = {
    id: `${recipeId}-${date}-${mealSlot}-${now}`,
    recipeId,
    date,
    mealSlot,
    status: "planned",
    createdAt: now,
  };
  return { ...state, plannedMeals: [...state.plannedMeals, plannedMeal] };
}

export function updatePlannedMeal(
  state: AppState,
  mealId: string,
  updates: Partial<Pick<PlannedMeal, "date" | "mealSlot">>,
): AppState {
  return {
    ...state,
    plannedMeals: state.plannedMeals.map((meal) => (meal.id === mealId ? { ...meal, ...updates } : meal)),
  };
}

export function removePlannedMeal(state: AppState, mealId: string): AppState {
  return {
    ...state,
    plannedMeals: state.plannedMeals.filter((meal) => meal.id !== mealId),
    completions: state.completions.filter((completion) => completion.plannedMealId !== mealId),
  };
}

export function setInventoryQuantity(
  state: AppState,
  ingredientId: string,
  quantity: number | null,
  unit: InventoryItem["unit"],
  quantityStatus: InventoryItem["quantityStatus"],
  now = new Date().toISOString(),
): AppState {
  try {
    getIngredient(ingredientId);
  } catch {
    return state;
  }
  if (!isUnit(unit)) return state;
  const normalizedQuantity = quantityStatus === "unknown"
    ? null
    : typeof quantity === "number" && Number.isFinite(quantity) && quantity >= 0
      ? quantity
      : 0;
  const nextItem: InventoryItem = { ingredientId, quantity: normalizedQuantity, unit, quantityStatus, updatedAt: now };
  const existing = state.inventory.some((item) => item.ingredientId === ingredientId && item.unit === unit);
  return {
    ...state,
    inventory: existing
      ? state.inventory.map((item) => (item.ingredientId === ingredientId && item.unit === unit ? nextItem : item))
      : [...state.inventory, nextItem],
  };
}

export function setPackageOverride(state: AppState, ingredientId: string, packageSize: PackageSize): AppState {
  try {
    getIngredient(ingredientId);
  } catch {
    return state;
  }
  if (!Number.isFinite(packageSize.amount) || packageSize.amount <= 0 || !isUnit(packageSize.unit)) return state;
  return { ...state, packageOverrides: { ...state.packageOverrides, [ingredientId]: packageSize } };
}

export function completePlannedMeal(
  state: AppState,
  mealId: string,
  consumptions: ConsumptionInput[],
  now = new Date().toISOString(),
): { state: AppState; applied: boolean } {
  const meal = state.plannedMeals.find((item) => item.id === mealId);
  if (!meal) return { state, applied: false };
  // completion 기록이 유실돼도 cooked 상태만으로 재차감을 막습니다.
  if (meal.status === "cooked") return { state, applied: false };
  if (state.completions.some((completion) => completion.plannedMealId === mealId)) return { state, applied: false };

  const completion: CookingCompletion = {
    plannedMealId: mealId,
    recipeId: meal.recipeId,
    completedAt: now,
    consumptions: consumptions.map((item) => ({ ...item })),
  };
  const inventory = applyConsumption(state.inventory, consumptions, now);
  return {
    applied: true,
    state: {
      ...state,
      inventory,
      completions: [...state.completions, completion],
      plannedMeals: state.plannedMeals.map((item) => (item.id === mealId ? { ...item, status: "cooked" } : item)),
    },
  };
}

export function applyShoppingToState(
  state: AppState,
  shoppingItems: Parameters<typeof applyPurchases>[1],
  now = new Date().toISOString(),
): AppState {
  return { ...state, inventory: applyPurchases(state.inventory, shoppingItems, now) };
}

/** F13: 초안을 실제 식사 계획으로 확정합니다. 기존 계획은 유지하고 중복만 건너뜁니다. */
export function applyMealPlanDrafts(
  state: AppState,
  drafts: Array<{ recipeId: string; date: string; mealSlot: MealSlot }>,
  now = new Date().toISOString(),
): { state: AppState; added: number } {
  let next = state;
  let added = 0;
  for (const [index, draft] of drafts.entries()) {
    const before = next.plannedMeals.length;
    // now만 쓰면 같은 밀리초에 만든 계획들의 id가 겹치므로 순번을 덧붙입니다.
    next = addPlannedMeal(next, draft.recipeId, draft.date, draft.mealSlot, `${now}#${index}`);
    if (next.plannedMeals.length > before) added += 1;
  }
  return { state: next, added };
}

/** F10: 버린 재료를 기록하고 같은 양을 재고에서 뺍니다. */
export function logWaste(
  state: AppState,
  ingredientId: string,
  quantity: number,
  unit: InventoryItem["unit"],
  reason: WasteReason,
  now = new Date().toISOString(),
): AppState {
  try {
    getIngredient(ingredientId);
  } catch {
    return state;
  }
  if (!isUnit(unit) || !Number.isFinite(quantity) || quantity <= 0) return state;

  const log = createWasteLog(ingredientId, quantity, unit, reason, now);
  return {
    ...state,
    wasteLogs: [...state.wasteLogs, log],
    inventory: state.inventory.map((item) =>
      item.ingredientId === ingredientId && item.unit === unit && item.quantityStatus === "exact" && item.quantity !== null
        ? { ...item, quantity: Math.max(item.quantity - quantity, 0), updatedAt: now }
        : item,
    ),
  };
}

/** F10: 사용자가 확인한 가격만 저장합니다. 앱이 금액을 추정하지 않습니다. */
export function setIngredientPrice(
  state: AppState,
  ingredientId: string,
  price: number,
  packageAmount: number,
  unit: InventoryItem["unit"],
  now = new Date().toISOString(),
): AppState {
  try {
    getIngredient(ingredientId);
  } catch {
    return state;
  }
  if (!isUnit(unit) || !Number.isFinite(price) || price < 0 || !Number.isFinite(packageAmount) || packageAmount <= 0) return state;
  return {
    ...state,
    prices: { ...state.prices, [ingredientId]: { price, packageAmount, unit, confirmedAt: now, source: "user" } },
  };
}

export function clearIngredientPrice(state: AppState, ingredientId: string): AppState {
  if (!(ingredientId in state.prices)) return state;
  const prices = { ...state.prices };
  delete prices[ingredientId];
  return { ...state, prices };
}

/** F14: 장보는 동안 품목별 구매 완료를 체크/해제합니다. */
export function setPurchaseChecked(state: AppState, itemKey: string, checked: boolean): AppState {
  const purchaseChecks = { ...state.purchaseChecks };
  if (checked) purchaseChecks[itemKey] = true;
  else delete purchaseChecks[itemKey];
  return { ...state, purchaseChecks };
}

export function clearPurchaseChecks(state: AppState, itemKeys: string[]): AppState {
  const purchaseChecks = { ...state.purchaseChecks };
  for (const key of itemKeys) delete purchaseChecks[key];
  return { ...state, purchaseChecks };
}

/** F16 */
export function updateNotificationSettings(state: AppState, updates: Partial<NotificationSettings>): AppState {
  const leadDays = updates.leadDays;
  return {
    ...state,
    notificationSettings: {
      ...state.notificationSettings,
      ...updates,
      leadDays: typeof leadDays === "number" && Number.isFinite(leadDays)
        ? Math.max(Math.min(Math.trunc(leadDays), 7), 0)
        : state.notificationSettings.leadDays,
    },
  };
}

export function dismissAlert(state: AppState, alertId: string): AppState {
  if (state.dismissedAlerts.includes(alertId)) return state;
  return { ...state, dismissedAlerts: [...state.dismissedAlerts, alertId] };
}

export function recipeForMeal(meal: PlannedMeal) {
  return getRecipe(meal.recipeId);
}
