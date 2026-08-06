export type MealSlot = "아침" | "점심" | "저녁";

export type Unit = "g" | "ml" | "개" | "큰술" | "작은술" | "장" | "봉" | "팩";

export type QuantityStatus = "exact" | "unknown";
export type RiskLevel = "high" | "medium" | "low";

export interface PackageSize {
  amount: number;
  unit: Unit;
  label: string;
}

export interface CanonicalIngredient {
  id: string;
  name: string;
  aliases: string[];
  defaultUnit: Unit;
  representativeSaleUnit: PackageSize;
  riskLevel: RiskLevel;
  storageNote: string;
}

export interface RecipeIngredient {
  ingredientId: string;
  rawName: string;
  quantity: number;
  unit: Unit;
  preparation?: string;
}

export interface Recipe {
  id: string;
  title: string;
  description: string;
  mealSlots: MealSlot[];
  difficulty: 1 | 2 | 3;
  cookTime: number;
  servings: number;
  imageUrl: string;
  imageAlt: string;
  ingredients: RecipeIngredient[];
  steps: string[];
  tags: string[];
}

export interface PlannedMeal {
  id: string;
  recipeId: string;
  date: string;
  mealSlot: MealSlot;
  status: "planned" | "cooked";
  createdAt: string;
}

export interface InventoryItem {
  ingredientId: string;
  quantity: number | null;
  unit: Unit;
  quantityStatus: QuantityStatus;
  updatedAt: string;
}

export interface CookingConsumption {
  ingredientId: string;
  unit: Unit;
  expectedQuantity: number;
  actualQuantity: number;
  remainingQuantity: number | null;
}

export interface CookingCompletion {
  plannedMealId: string;
  recipeId: string;
  completedAt: string;
  consumptions: CookingConsumption[];
}

export type WasteReason = "spoiled" | "expired" | "leftover" | "other";

export const WASTE_REASON_LABELS: Record<WasteReason, string> = {
  spoiled: "상해서 버림",
  expired: "유통기한 지남",
  leftover: "먹고 남아서 버림",
  other: "기타",
};

/** F10: 사용자가 버린 재료 기록. 예상값이 아니라 사용자가 직접 확인한 값만 저장합니다. */
export interface WasteLog {
  id: string;
  ingredientId: string;
  quantity: number;
  unit: Unit;
  reason: WasteReason;
  loggedAt: string;
}

/**
 * F10: 사용자가 확인한 가격만 저장합니다. 대표 가격 데이터가 없으므로
 * 앱이 금액을 임의로 추정하지 않습니다(제품 원칙 6·7).
 */
export interface IngredientPrice {
  /** packageAmount 만큼의 포장 하나에 지불한 금액(원) */
  price: number;
  packageAmount: number;
  unit: Unit;
  confirmedAt: string;
  source: "user";
}

/** F16: 알림 종류별 on/off와 선행 일수. 사용자가 언제든 끌 수 있어야 합니다. */
export interface NotificationSettings {
  riskAlerts: boolean;
  mealReminders: boolean;
  leadDays: number;
}

export const DEFAULT_NOTIFICATION_SETTINGS: NotificationSettings = {
  riskAlerts: true,
  mealReminders: true,
  leadDays: 1,
};

export interface AppState {
  favorites: string[];
  plannedMeals: PlannedMeal[];
  inventory: InventoryItem[];
  packageOverrides: Record<string, PackageSize>;
  completions: CookingCompletion[];
  /** F10 */
  wasteLogs: WasteLog[];
  /** F10 — 재료 ID별 사용자 확인 가격 */
  prices: Record<string, IngredientPrice>;
  /** F14 — 장보기 목록 품목별 구매 체크 상태 (ShoppingPlanItem.key 기준) */
  purchaseChecks: Record<string, boolean>;
  /** F16 */
  notificationSettings: NotificationSettings;
  /** F16 — 같은 사유의 알림을 다시 띄우지 않기 위한 해제 기록 */
  dismissedAlerts: string[];
}

export interface IngredientRequirement {
  key: string;
  ingredientId: string;
  ingredientName: string;
  quantity: number;
  unit: Unit;
  recipeIds: string[];
  unitConflict: boolean;
}

export interface ShoppingPlanItem extends IngredientRequirement {
  availableQuantity: number | null;
  quantityStatus: QuantityStatus;
  additionalNeeded: number;
  packageSize: PackageSize;
  purchaseQuantity: number;
  purchaseTotal: number;
  expectedRemaining: number | null;
  precision: "exact" | "estimated" | "manual";
  note?: string;
}

export interface Recommendation {
  recipe: Recipe;
  usedIngredients: string[];
  usedIngredientIds: string[];
  additionalIngredients: string[];
  additionalPurchaseItems: ShoppingPlanItem[];
  score: number;
  reason: string;
}

/** F15: 근거가 충분할 때만 0~100 점수를 냅니다. score가 null이면 "확인 필요"입니다. */
export type RiskState = "urgent" | "soon" | "stable" | "unknown";

export interface DepletionRisk {
  ingredientId: string;
  ingredientName: string;
  unit: Unit;
  score: number | null;
  state: RiskState;
  reasons: string[];
  /** 예정된 식단이 이 재료를 쓰는 총량 */
  plannedUsage: number;
  daysSinceUpdate: number;
  shelfDays: number;
}

/** F13 */
export interface PlannedMealDraft {
  recipeId: string;
  date: string;
  mealSlot: MealSlot;
  /** 이 후보를 고른 이유 */
  reason: string;
  reusedIngredientIds: string[];
  newPurchaseCount: number;
}

export interface MealPlanDraft {
  drafts: PlannedMealDraft[];
  /** 계획 전체에서 추가 구매가 필요한 품목 수 */
  totalNewPurchases: number;
  /** 두 끼 이상에서 재사용되는 재료 이름 */
  sharedIngredientNames: string[];
  /** 후보가 부족해 채우지 못한 칸 수 */
  unfilledSlots: number;
}

/** F10 */
export interface SavingsBreakdown {
  ingredientId: string;
  ingredientName: string;
  unit: Unit;
  usedQuantity: number;
  wastedQuantity: number;
  /** 가격 미확인이면 null — 임의로 추정하지 않습니다. */
  usedValue: number | null;
  wastedValue: number | null;
}

export interface RecordSummary {
  cookedMealCount: number;
  usedIngredientCount: number;
  fullyUsedIngredientCount: number;
  wasteLogCount: number;
  breakdowns: SavingsBreakdown[];
  /** 가격이 확인된 재료만 합산한 금액 */
  confirmedUsedValue: number;
  confirmedWastedValue: number;
  /** 가격이 없어 금액에서 빠진 재료 수 */
  unpricedIngredientCount: number;
}

/** F16 */
export type AlertKind = "risk" | "meal";

export interface AppAlert {
  /** 같은 사유의 중복 발행을 막는 안정적 키 */
  id: string;
  kind: AlertKind;
  title: string;
  body: string;
  severity: "high" | "medium";
  /** 활용 메뉴 연결용 */
  ingredientId?: string;
  plannedMealId?: string;
}

export const MEAL_SLOTS: MealSlot[] = ["아침", "점심", "저녁"];

export const UNIT_LABELS: Record<Unit, string> = {
  g: "g",
  ml: "ml",
  개: "개",
  큰술: "큰술",
  작은술: "작은술",
  장: "장",
  봉: "봉",
  팩: "팩",
};

export function isUnit(value: unknown): value is Unit {
  return typeof value === "string" && Object.prototype.hasOwnProperty.call(UNIT_LABELS, value);
}

export function formatQuantity(value: number | null, unit?: Unit): string {
  if (value === null) return "수량 미상";
  if (!Number.isFinite(value)) return "확인 필요";
  const normalized = new Intl.NumberFormat("ko-KR", {
    useGrouping: false,
    maximumFractionDigits: 3,
  }).format(value);
  return unit ? `${normalized}${UNIT_LABELS[unit]}` : normalized;
}
