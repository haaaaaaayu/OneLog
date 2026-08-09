import { getIngredient } from "./ingredients";
import { RECIPES } from "./seed-data";
import type {
  AppState,
  CookingCompletion,
  IngredientPrice,
  InventoryItem,
  NotificationSettings,
  PackageSize,
  PlannedMeal,
  WasteLog,
} from "./types";
import { DEFAULT_NOTIFICATION_SETTINGS, isUnit, MEAL_SLOTS, WASTE_REASON_LABELS } from "./types";

export const STORAGE_KEY = "onelog:p0-state:v1";

const recipeIds = new Set(RECIPES.map((recipe) => recipe.id));
const mealSlots = new Set(MEAL_SLOTS);

function isDateString(value: unknown): value is string {
  return typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value);
}

function isFiniteNonNegative(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && value >= 0;
}

function isPlannedMeal(value: unknown): value is PlannedMeal {
  if (!value || typeof value !== "object") return false;
  const meal = value as Partial<PlannedMeal>;
  return (
    typeof meal.id === "string" &&
    recipeIds.has(String(meal.recipeId)) &&
    isDateString(meal.date) &&
    mealSlots.has(meal.mealSlot as PlannedMeal["mealSlot"]) &&
    (meal.status === "planned" || meal.status === "cooked") &&
    typeof meal.createdAt === "string"
  );
}

function normalizeInventory(value: unknown): InventoryItem | null {
  if (!value || typeof value !== "object") return null;
  const item = value as Partial<InventoryItem>;
  if (typeof item.ingredientId !== "string" || !isUnit(item.unit)) return null;
  try {
    getIngredient(item.ingredientId);
  } catch {
    return null;
  }

  if (item.quantityStatus === "unknown") {
    return {
      ingredientId: item.ingredientId,
      quantity: null,
      unit: item.unit,
      quantityStatus: "unknown",
      updatedAt: typeof item.updatedAt === "string" ? item.updatedAt : new Date().toISOString(),
    };
  }

  if (item.quantityStatus !== "exact" || !isFiniteNonNegative(item.quantity)) return null;
  return {
    ingredientId: item.ingredientId,
    quantity: item.quantity,
    unit: item.unit,
    quantityStatus: "exact",
    updatedAt: typeof item.updatedAt === "string" ? item.updatedAt : new Date().toISOString(),
  };
}

function normalizePackageOverride(ingredientId: string, value: unknown): PackageSize | null {
  if (!value || typeof value !== "object") return null;
  const packageSize = value as Partial<PackageSize>;
  if (!isFiniteNonNegative(packageSize.amount) || packageSize.amount <= 0 || !isUnit(packageSize.unit)) return null;
  try {
    getIngredient(ingredientId);
  } catch {
    return null;
  }
  return {
    amount: packageSize.amount,
    unit: packageSize.unit,
    label: typeof packageSize.label === "string" ? packageSize.label : `${packageSize.amount}${packageSize.unit}`,
  };
}

function normalizeCompletion(value: unknown, meals: PlannedMeal[]): CookingCompletion | null {
  if (!value || typeof value !== "object") return null;
  const completion = value as Partial<CookingCompletion>;
  const meal = meals.find((item) => item.id === completion.plannedMealId);
  if (!meal || meal.recipeId !== completion.recipeId || typeof completion.completedAt !== "string" || !Array.isArray(completion.consumptions)) return null;

  const consumptions = completion.consumptions.filter((consumption) => {
    if (!consumption || typeof consumption !== "object") return false;
    const item = consumption as Partial<CookingCompletion["consumptions"][number]>;
    // 존재하지 않는 재료 ID가 남아 있으면 기록/집계 화면이 getIngredient에서 터집니다.
    if (typeof item.ingredientId !== "string") return false;
    try {
      getIngredient(item.ingredientId);
    } catch {
      return false;
    }
    return (
      isUnit(item.unit) &&
      isFiniteNonNegative(item.expectedQuantity) &&
      isFiniteNonNegative(item.actualQuantity) &&
      (item.remainingQuantity === null || isFiniteNonNegative(item.remainingQuantity))
    );
  }).map((item) => ({ ...item })) as CookingCompletion["consumptions"];
  if (consumptions.length !== completion.consumptions.length) return null;

  return {
    plannedMealId: meal.id,
    recipeId: meal.recipeId,
    completedAt: completion.completedAt,
    consumptions,
  };
}

function normalizeWasteLog(value: unknown): WasteLog | null {
  if (!value || typeof value !== "object") return null;
  const log = value as Partial<WasteLog>;
  if (typeof log.ingredientId !== "string" || !isUnit(log.unit) || !isFiniteNonNegative(log.quantity)) return null;
  if (!log.reason || !Object.prototype.hasOwnProperty.call(WASTE_REASON_LABELS, log.reason)) return null;
  try {
    getIngredient(log.ingredientId);
  } catch {
    return null;
  }
  const loggedAt = typeof log.loggedAt === "string" ? log.loggedAt : new Date().toISOString();
  return {
    id: typeof log.id === "string" ? log.id : `${log.ingredientId}-${log.unit}-${loggedAt}`,
    ingredientId: log.ingredientId,
    quantity: log.quantity,
    unit: log.unit,
    reason: log.reason,
    loggedAt,
  };
}

function normalizePrice(ingredientId: string, value: unknown): IngredientPrice | null {
  if (!value || typeof value !== "object") return null;
  const price = value as Partial<IngredientPrice>;
  if (!isFiniteNonNegative(price.price) || !isFiniteNonNegative(price.packageAmount) || price.packageAmount <= 0) return null;
  if (!isUnit(price.unit)) return null;
  try {
    getIngredient(ingredientId);
  } catch {
    return null;
  }
  return {
    price: price.price,
    packageAmount: price.packageAmount,
    unit: price.unit,
    confirmedAt: typeof price.confirmedAt === "string" ? price.confirmedAt : new Date().toISOString(),
    source: "user",
  };
}

function normalizeNotificationSettings(value: unknown): NotificationSettings {
  if (!value || typeof value !== "object") return { ...DEFAULT_NOTIFICATION_SETTINGS };
  const settings = value as Partial<NotificationSettings>;
  return {
    riskAlerts: typeof settings.riskAlerts === "boolean" ? settings.riskAlerts : DEFAULT_NOTIFICATION_SETTINGS.riskAlerts,
    mealReminders: typeof settings.mealReminders === "boolean" ? settings.mealReminders : DEFAULT_NOTIFICATION_SETTINGS.mealReminders,
    leadDays: isFiniteNonNegative(settings.leadDays) && settings.leadDays <= 7 ? Math.trunc(settings.leadDays) : DEFAULT_NOTIFICATION_SETTINGS.leadDays,
  };
}

export function createInitialState(): AppState {
  return {
    favorites: [],
    plannedMeals: [],
    inventory: [],
    packageOverrides: {},
    completions: [],
    wasteLogs: [],
    prices: {},
    purchaseChecks: {},
    notificationSettings: { ...DEFAULT_NOTIFICATION_SETTINGS },
    dismissedAlerts: [],
  };
}

export function restoreState(raw: string | null): AppState {
  if (!raw) return createInitialState();
  try {
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    const plannedMealsById = new Map<string, PlannedMeal>();
    if (Array.isArray(parsed.plannedMeals)) {
      for (const rawMeal of parsed.plannedMeals) {
        if (isPlannedMeal(rawMeal)) plannedMealsById.set(rawMeal.id, rawMeal);
      }
    }
    const plannedMeals = [...plannedMealsById.values()];
    const inventoryByKey = new Map<string, InventoryItem>();
    if (Array.isArray(parsed.inventory)) {
      for (const rawItem of parsed.inventory) {
        const item = normalizeInventory(rawItem);
        if (item) inventoryByKey.set(`${item.ingredientId}:${item.unit}`, item);
      }
    }

    const packageOverrides: Record<string, PackageSize> = {};
    if (parsed.packageOverrides && typeof parsed.packageOverrides === "object") {
      for (const [ingredientId, rawPackage] of Object.entries(parsed.packageOverrides)) {
        const packageSize = normalizePackageOverride(ingredientId, rawPackage);
        if (packageSize) packageOverrides[ingredientId] = packageSize;
      }
    }

    const completionsByMealId = Array.isArray(parsed.completions)
      ? parsed.completions.map((item) => normalizeCompletion(item, plannedMeals)).filter((item): item is CookingCompletion => item !== null)
      : [];
    const completions = [...new Map(completionsByMealId.map((item) => [item.plannedMealId, item])).values()];

    const prices: Record<string, IngredientPrice> = {};
    if (parsed.prices && typeof parsed.prices === "object") {
      for (const [ingredientId, rawPrice] of Object.entries(parsed.prices)) {
        const price = normalizePrice(ingredientId, rawPrice);
        if (price) prices[ingredientId] = price;
      }
    }

    const purchaseChecks: Record<string, boolean> = {};
    if (parsed.purchaseChecks && typeof parsed.purchaseChecks === "object") {
      for (const [key, checked] of Object.entries(parsed.purchaseChecks)) {
        if (checked === true) purchaseChecks[key] = true;
      }
    }

    return {
      favorites: Array.isArray(parsed.favorites) ? parsed.favorites.filter((id): id is string => typeof id === "string" && recipeIds.has(id)) : [],
      plannedMeals,
      inventory: [...inventoryByKey.values()],
      packageOverrides,
      completions,
      wasteLogs: Array.isArray(parsed.wasteLogs)
        ? parsed.wasteLogs.map(normalizeWasteLog).filter((log): log is WasteLog => log !== null)
        : [],
      prices,
      purchaseChecks,
      notificationSettings: normalizeNotificationSettings(parsed.notificationSettings),
      dismissedAlerts: Array.isArray(parsed.dismissedAlerts)
        ? parsed.dismissedAlerts.filter((id): id is string => typeof id === "string")
        : [],
    };
  } catch {
    return createInitialState();
  }
}
