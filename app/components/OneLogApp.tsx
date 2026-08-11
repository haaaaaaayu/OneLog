"use client";

import { useEffect, useMemo, useState } from "react";
import { aggregateRequirements, calculateShoppingPlan, ingredientKey } from "../../lib/calculations";
import { ANALYTICS_EVENTS, trackEvent } from "../../lib/analytics";
import { getIngredient, INGREDIENTS, resolveIngredient } from "../../lib/ingredients";
import { rankLeftoverRecipes } from "../../lib/recommendations";
import { STORAGE_KEY, restoreState } from "../../lib/persistence";
import { RECIPES } from "../../lib/seed-data";
import { getMealStorageWarnings } from "../../lib/schedule";
import {
  addPlannedMeal,
  applyMealPlanDrafts,
  applyShoppingToState,
  clearIngredientPrice,
  clearPurchaseChecks,
  completePlannedMeal,
  createInitialState,
  dismissAlert,
  logWaste,
  removePlannedMeal,
  setIngredientPrice,
  setInventoryQuantity,
  setPackageOverride,
  setPurchaseChecked,
  updateNotificationSettings,
  updatePlannedMeal,
} from "../../lib/state";
import { deriveAlerts } from "../../lib/notifications";
import AlertsView from "./AlertsView";
import PlannerView from "./PlannerView";
import RecordsView from "./RecordsView";
import type {
  AppState,
  MealPlanDraft,
  MealSlot,
  NotificationSettings,
  Recipe,
  ShoppingPlanItem,
  Unit,
  WasteReason,
} from "../../lib/types";
import { MEAL_SLOTS, formatQuantity } from "../../lib/types";

type View = "home" | "meals" | "planner" | "shopping" | "cooking" | "fridge" | "leftover" | "records" | "alerts";
type RecipeFilter = "전체" | MealSlot;
type ShoppingMode = "estimate" | "list";

// toISOString은 UTC라 KST 00~09시에 어제 날짜가 나옵니다. sv-SE 로케일이 로컬 기준 YYYY-MM-DD를 줍니다.
const TODAY = new Date().toLocaleDateString("sv-SE");

const NAV_ITEMS: Array<{ id: View; label: string; shortLabel: string }> = [
  { id: "home", label: "레시피", shortLabel: "레시피" },
  { id: "meals", label: "내 식사", shortLabel: "내 식사" },
  { id: "planner", label: "식단 짜기", shortLabel: "식단 짜기" },
  { id: "shopping", label: "장보기", shortLabel: "장보기" },
  { id: "cooking", label: "요리 완료", shortLabel: "요리" },
  { id: "fridge", label: "내 냉장고", shortLabel: "냉장고" },
  { id: "leftover", label: "남은 재료 추천", shortLabel: "추천" },
  { id: "alerts", label: "알림", shortLabel: "알림" },
  { id: "records", label: "절약 기록", shortLabel: "기록" },
];

function parseQuantity(value: string): number | null {
  if (value.trim() === "") return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return null;
  return Math.max(parsed, 0);
}

function formatDate(date: string): string {
  if (!date) return "날짜 미정";
  const parsed = new Date(`${date}T00:00:00`);
  return new Intl.DateTimeFormat("ko-KR", { month: "long", day: "numeric", weekday: "short" }).format(parsed);
}

function difficultyLabel(difficulty: Recipe["difficulty"]): string {
  return difficulty === 1 ? "초보 추천" : difficulty === 2 ? "보통" : "도전";
}

function recipeForId(recipeId: string): Recipe | undefined {
  return RECIPES.find((recipe) => recipe.id === recipeId);
}

function PlanControls({
  date,
  mealSlot,
  onDateChange,
  onMealSlotChange,
}: {
  date: string;
  mealSlot: MealSlot;
  onDateChange: (date: string) => void;
  onMealSlotChange: (mealSlot: MealSlot) => void;
}) {
  return (
    <div className="grid gap-3 sm:grid-cols-2">
      <label className="grid gap-1.5 text-sm font-bold text-[#445244]">
        먹을 날짜
        <input className="field" type="date" value={date} onChange={(event) => onDateChange(event.target.value)} />
      </label>
      <label className="grid gap-1.5 text-sm font-bold text-[#445244]">
        끼니
        <select className="field" value={mealSlot} onChange={(event) => onMealSlotChange(event.target.value as MealSlot)}>
          {MEAL_SLOTS.map((slot) => (
            <option key={slot} value={slot}>
              {slot}
            </option>
          ))}
        </select>
      </label>
    </div>
  );
}

function EmptyState({
  title,
  description,
  actionLabel,
  onAction,
}: {
  title: string;
  description: string;
  actionLabel?: string;
  onAction?: () => void;
}) {
  return (
    <div className="rounded-2xl border border-dashed border-[#cbd8c9] bg-[#f8fbf6] px-6 py-12 text-center">
      <p className="text-3xl" aria-hidden="true">
        🥣
      </p>
      <h3 className="mt-4 text-lg font-extrabold text-[#172018]">{title}</h3>
      <p className="mx-auto mt-2 max-w-md text-sm leading-6 text-[#657166]">{description}</p>
      {actionLabel && onAction ? (
        <button type="button" className="primary-button mt-5" onClick={onAction}>
          {actionLabel}
        </button>
      ) : null}
    </div>
  );
}

export default function OneLogApp() {
  const [state, setState] = useState<AppState>(() => createInitialState());
  const [hydrated, setHydrated] = useState(false);
  const [view, setView] = useState<View>("home");
  const [recipeFilter, setRecipeFilter] = useState<RecipeFilter>("전체");
  const [search, setSearch] = useState("");
  const [selectedRecipeId, setSelectedRecipeId] = useState<string | null>(null);
  const [selectedCookingMealId, setSelectedCookingMealId] = useState<string | null>(null);
  const [plannerDate, setPlannerDate] = useState(TODAY);
  const [plannerSlot, setPlannerSlot] = useState<MealSlot>("저녁");
  const [shoppingMode, setShoppingMode] = useState<ShoppingMode>("estimate");
  const [notice, setNotice] = useState("");
  const [lastShoppingItems, setLastShoppingItems] = useState<ShoppingPlanItem[]>([]);
  const [cookingUsage, setCookingUsage] = useState<Record<string, string>>({});
  const [cookingRemaining, setCookingRemaining] = useState<Record<string, string>>({});
  const [additionalInput, setAdditionalInput] = useState("");
  const [additionalIngredients, setAdditionalIngredients] = useState<string[]>([]);
  const [selectedRecommendationId, setSelectedRecommendationId] = useState<string | null>(null);
  const [newInventoryId, setNewInventoryId] = useState(INGREDIENTS[0]?.id ?? "");
  const [newInventoryQuantity, setNewInventoryQuantity] = useState("1");
  const [newInventoryUnknown, setNewInventoryUnknown] = useState(false);
  const [storageFailed, setStorageFailed] = useState(false);
  const [shareStatus, setShareStatus] = useState("");
  const [manualCopyText, setManualCopyText] = useState("");
  const [purchaseOverrides, setPurchaseOverrides] = useState<Record<string, string>>({});

  // 사파리 프라이빗 모드나 저장 용량 초과에서 localStorage 접근이 예외를 던져도 앱이 죽지 않아야 합니다.
  useEffect(() => {
    try {
      setState(restoreState(window.localStorage.getItem(STORAGE_KEY)));
    } catch {
      setState(createInitialState());
    }
    setHydrated(true);
  }, []);

  useEffect(() => {
    if (!hydrated) return;
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
      setStorageFailed(false);
    } catch {
      setStorageFailed(true);
    }
  }, [hydrated, state]);

  const requirements = useMemo(() => aggregateRequirements(state.plannedMeals, RECIPES), [state.plannedMeals]);
  const shoppingPlan = useMemo(
    () => calculateShoppingPlan(requirements, state.inventory, state.packageOverrides),
    [requirements, state.inventory, state.packageOverrides],
  );
  const currentPurchaseItems = useMemo(
    () => shoppingPlan.filter((item) => item.purchaseQuantity > 0 && item.precision !== "manual"),
    [shoppingPlan],
  );
  const manualShoppingItems = useMemo(() => shoppingPlan.filter((item) => item.precision === "manual"), [shoppingPlan]);
  const displayShoppingItems = currentPurchaseItems.length > 0 ? currentPurchaseItems : lastShoppingItems;
  const sortedMeals = useMemo(
    () => [...state.plannedMeals].sort((left, right) => `${left.date}-${left.mealSlot}`.localeCompare(`${right.date}-${right.mealSlot}`, "ko")),
    [state.plannedMeals],
  );
  const activeCookingMeal = state.plannedMeals.find((meal) => meal.id === selectedCookingMealId) ?? sortedMeals[0];
  const activeCookingRecipe = activeCookingMeal ? recipeForId(activeCookingMeal.recipeId) : undefined;
  const exactLeftovers = useMemo(
    () => state.inventory.filter((item) => item.quantityStatus === "exact" && item.quantity !== null && item.quantity > 0),
    [state.inventory],
  );
  const recommendations = useMemo(
    () => rankLeftoverRecipes(RECIPES, state.inventory, additionalIngredients, state.packageOverrides),
    [state.inventory, additionalIngredients, state.packageOverrides],
  );
  const filteredRecipes = useMemo(
    () =>
      RECIPES.filter((recipe) => {
        const matchesSlot = recipeFilter === "전체" || recipe.mealSlots.includes(recipeFilter);
        const query = search.trim().toLowerCase();
        const matchesSearch = !query || `${recipe.title} ${recipe.description} ${recipe.tags.join(" ")}`.toLowerCase().includes(query);
        return matchesSlot && matchesSearch;
      }),
    [recipeFilter, search],
  );
  const selectedRecipe = selectedRecipeId ? recipeForId(selectedRecipeId) : undefined;
  const cookedMealIds = useMemo(() => new Set(state.completions.map((completion) => completion.plannedMealId)), [state.completions]);
  const alerts = useMemo(() => (hydrated ? deriveAlerts(state, RECIPES) : []), [hydrated, state]);

  useEffect(() => {
    if (view === "leftover") trackEvent(ANALYTICS_EVENTS.LEFTOVER_RECOMMENDATION_VIEWED, { count: recommendations.length });
  }, [recommendations.length, view]);

  useEffect(() => {
    if (!activeCookingRecipe || !activeCookingMeal) return;
    const initialUsage: Record<string, string> = {};
    const initialRemaining: Record<string, string> = {};
    for (const ingredient of activeCookingRecipe.ingredients) {
      const key = ingredientKey(ingredient.ingredientId, ingredient.unit);
      initialUsage[key] = String(ingredient.quantity);
      initialRemaining[key] = "";
    }
    setCookingUsage(initialUsage);
    setCookingRemaining(initialRemaining);
  }, [activeCookingMeal?.id, activeCookingRecipe?.id]);

  function navigate(nextView: View) {
    setView(nextView);
    if (nextView === "shopping") trackEvent(ANALYTICS_EVENTS.SHOPPING_STARTED);
  }

  function showNotice(message: string) {
    setNotice(message);
    window.setTimeout(() => setNotice((current) => (current === message ? "" : current)), 4200);
  }

  function toggleFavorite(recipeId: string) {
    const wasFavorite = state.favorites.includes(recipeId);
    setState((current) => ({
      ...current,
      favorites: wasFavorite ? current.favorites.filter((id) => id !== recipeId) : [...current.favorites, recipeId],
    }));
    trackEvent(ANALYTICS_EVENTS.RECIPE_FAVORITED, { recipeId, favorite: !wasFavorite });
    showNotice(wasFavorite ? "찜에서 뺐어요." : "찜했어요. 내 식사에 바로 추가할 수 있어요.");
  }

  function openRecipe(recipeId: string) {
    setSelectedRecipeId(recipeId);
    trackEvent(ANALYTICS_EVENTS.RECIPE_VIEWED, { recipeId });
  }

  function addRecipeToPlan(recipeId: string) {
    const duplicate = state.plannedMeals.some(
      (meal) => meal.recipeId === recipeId && meal.date === plannerDate && meal.mealSlot === plannerSlot && meal.status === "planned",
    );
    const createdAt = new Date().toISOString();
    setState((current) => addPlannedMeal(current, recipeId, plannerDate, plannerSlot, createdAt));
    if (duplicate) {
      showNotice("같은 날짜와 끼니에 이미 담긴 메뉴예요.");
      return;
    }
    const recipe = recipeForId(recipeId);
    trackEvent(ANALYTICS_EVENTS.MEAL_PLAN_CREATED, { recipeId, mealSlot: plannerSlot });
    showNotice(`${recipe?.title ?? "레시피"}을(를) ${formatDate(plannerDate)} ${plannerSlot} 식사로 담았어요.`);
    setView("meals");
  }

  function updateRequirementInventory(item: ShoppingPlanItem, value: string, unknown: boolean) {
    const quantity = unknown ? null : parseQuantity(value) ?? 0;
    setState((current) => setInventoryQuantity(current, item.ingredientId, quantity, item.unit, unknown ? "unknown" : "exact"));
    trackEvent(ANALYTICS_EVENTS.INVENTORY_CONFIRMED, { ingredientId: item.ingredientId, known: !unknown });
  }

  function updatePackageSize(item: ShoppingPlanItem, value: string) {
    const amount = parseQuantity(value);
    if (amount === null || amount <= 0) return;
    setState((current) =>
      setPackageOverride(current, item.ingredientId, { ...item.packageSize, amount }),
    );
  }

  function makeShoppingList() {
    setShoppingMode("list");
    trackEvent(ANALYTICS_EVENTS.SHOPPING_LIST_CREATED, { itemCount: currentPurchaseItems.length });
    showNotice(currentPurchaseItems.length > 0 ? "필요한 구매 품목을 장보기 목록으로 정리했어요." : "추가 구매 품목이 없어요. 보유량을 다시 확인해도 좋아요.");
  }

  function completeShopping() {
    if (currentPurchaseItems.length === 0) {
      showNotice("먼저 구매량을 계산해 주세요.");
      return;
    }
    // F14: 사용자가 실제로 산 포장 수로 바꿔 재고에 반영합니다. 0포장은 사지 않은 것으로 봅니다.
    const purchased = currentPurchaseItems
      .map((item) => {
        const quantity = purchaseQuantityFor(item);
        return { ...item, purchaseQuantity: quantity, purchaseTotal: quantity * item.packageSize.amount };
      })
      .filter((item) => item.purchaseTotal > 0);

    if (purchased.length === 0) {
      showNotice("실제로 산 품목이 없어요. 구매한 포장 수를 입력해 주세요.");
      return;
    }

    setState((current) => clearPurchaseChecks(applyShoppingToState(current, purchased), purchased.map((item) => item.key)));
    setLastShoppingItems(purchased);
    setPurchaseOverrides({});
    trackEvent(ANALYTICS_EVENTS.SHOPPING_COMPLETED, { itemCount: purchased.length });
    showNotice("구매한 수량을 재고에 반영했어요. 수량 미상 재료는 자동으로 확정하지 않았어요.");
  }

  function selectCookingMeal(mealId: string) {
    setSelectedCookingMealId(mealId);
    setView("cooking");
  }

  function completeCooking() {
    if (!activeCookingMeal || !activeCookingRecipe) return;
    if (cookedMealIds.has(activeCookingMeal.id)) {
      showNotice("이미 완료한 요리예요. 재고는 다시 차감하지 않았어요.");
      return;
    }
    const consumptions = activeCookingRecipe.ingredients.map((ingredient) => {
      const key = ingredientKey(ingredient.ingredientId, ingredient.unit);
      return {
        ingredientId: ingredient.ingredientId,
        unit: ingredient.unit,
        expectedQuantity: ingredient.quantity,
        actualQuantity: parseQuantity(cookingUsage[key] ?? "") ?? ingredient.quantity,
        remainingQuantity: parseQuantity(cookingRemaining[key] ?? ""),
      };
    });
    const result = completePlannedMeal(state, activeCookingMeal.id, consumptions);
    if (!result.applied) {
      showNotice("이미 처리된 식사이거나 찾을 수 없는 식사예요.");
      return;
    }
    setState(result.state);
    trackEvent(ANALYTICS_EVENTS.COOKING_COMPLETED, { recipeId: activeCookingMeal.recipeId });
    showNotice("요리 완료! 실제 사용량을 반영하고 남은 재료를 다시 계산했어요.");
    setView("leftover");
  }

  function finishCurrentMeal() {
    if (!activeCookingMeal) return;
    if (!cookedMealIds.has(activeCookingMeal.id)) {
      showNotice("먼저 요리 완료한 식사를 선택해 주세요.");
      return;
    }
    const recipe = activeCookingRecipe?.title ?? "완료한 식사";
    if (!window.confirm(`${recipe}을(를) 현재 식단에서 정리할까요? 재고는 유지됩니다.`)) return;
    setState((current) => removePlannedMeal(current, activeCookingMeal.id));
    setSelectedCookingMealId(null);
    setNotice("완료한 식사를 정리했어요. 남은 재료는 냉장고에 남아 있어요.");
  }

  function addFridgeIngredient() {
    const ingredient = getIngredient(newInventoryId);
    const quantity = newInventoryUnknown ? null : parseQuantity(newInventoryQuantity) ?? 0;
    setState((current) => setInventoryQuantity(current, ingredient.id, quantity, ingredient.defaultUnit, newInventoryUnknown ? "unknown" : "exact"));
    showNotice(`${ingredient.name}을(를) 냉장고에 기록했어요.`);
  }

  function removeFridgeIngredient(ingredientId: string, unit: Unit) {
    const ingredient = getIngredient(ingredientId);
    if (!window.confirm(`${ingredient.name} 재고를 삭제할까요?`)) return;
    setState((current) => ({
      ...current,
      inventory: current.inventory.filter((item) => !(item.ingredientId === ingredientId && item.unit === unit)),
    }));
  }

  function updateFridgeIngredient(ingredientId: string, unit: Unit, value: string, unknown = false) {
    setState((current) => setInventoryQuantity(current, ingredientId, unknown ? null : parseQuantity(value) ?? 0, unit, unknown ? "unknown" : "exact"));
  }

  function addAdditionalIngredient() {
    const raw = additionalInput.trim();
    if (!raw) return;
    if (additionalIngredients.length >= 5) {
      showNotice("추가 재료는 최대 5개까지 입력할 수 있어요.");
      return;
    }
    const resolved = resolveIngredient(raw);
    const normalized = resolved?.name ?? raw;
    if (additionalIngredients.includes(normalized)) {
      showNotice("이미 추가한 재료예요.");
      return;
    }
    setAdditionalIngredients((current) => [...current, normalized]);
    setAdditionalInput("");
  }

  function removeAdditionalIngredient(name: string) {
    setAdditionalIngredients((current) => current.filter((item) => item !== name));
  }

  // ---- F14 장보기 실행 지원 ----

  function shoppingListText(items: ShoppingPlanItem[]): string {
    return [
      "한끼로그 장보기 목록",
      ...items.map((item) => `- ${item.ingredientName} ${purchaseQuantityFor(item)}포장 (${formatQuantity(purchaseQuantityFor(item) * item.packageSize.amount, item.unit)})`),
    ].join("\n");
  }

  async function copyShoppingList() {
    const text = shoppingListText(displayShoppingItems);
    try {
      await navigator.clipboard.writeText(text);
      trackEvent(ANALYTICS_EVENTS.SHOPPING_LIST_COPIED, { itemCount: displayShoppingItems.length });
      setShareStatus("장보기 목록을 복사했어요.");
      setManualCopyText("");
    } catch {
      // 클립보드 접근이 막힌 환경에서는 직접 복사할 수 있는 텍스트를 그대로 보여줍니다.
      setShareStatus("자동 복사가 막혀 있어요. 아래 목록을 선택해 직접 복사해 주세요.");
      setManualCopyText(text);
    }
  }

  async function shareShoppingList() {
    const text = shoppingListText(displayShoppingItems);
    if (typeof navigator === "undefined" || !navigator.share) {
      await copyShoppingList();
      return;
    }
    try {
      await navigator.share({ title: "한끼로그 장보기", text });
      trackEvent(ANALYTICS_EVENTS.SHOPPING_LIST_SHARED, { itemCount: displayShoppingItems.length });
      setShareStatus("장보기 목록을 공유했어요.");
    } catch (error) {
      if (error instanceof Error && error.name === "AbortError") return; // 사용자가 공유를 취소한 경우
      await copyShoppingList();
    }
  }

  function purchaseQuantityFor(item: ShoppingPlanItem): number {
    const override = purchaseOverrides[item.key];
    if (override === undefined) return item.purchaseQuantity;
    const parsed = Number(override);
    return Number.isFinite(parsed) && parsed >= 0 ? parsed : item.purchaseQuantity;
  }

  function togglePurchaseChecked(item: ShoppingPlanItem, checked: boolean) {
    setState((current) => setPurchaseChecked(current, item.key, checked));
    trackEvent(ANALYTICS_EVENTS.SHOPPING_ITEM_CHECKED, { checked });
  }

  // ---- F13 다일 식단 ----

  function applyPlan(plan: MealPlanDraft) {
    const result = applyMealPlanDrafts(state, plan.drafts);
    setState(result.state);
    trackEvent(ANALYTICS_EVENTS.MEAL_PLAN_APPLIED, { added: result.added, requested: plan.drafts.length });
    showNotice(
      result.added === 0
        ? "이미 같은 날짜와 끼니에 담긴 메뉴라 새로 추가된 식사가 없어요."
        : `${result.added}개 식사를 내 식사에 담았어요.`,
    );
    if (result.added > 0) setView("meals");
  }

  // ---- F10 기록 ----

  function handleLogWaste(ingredientId: string, quantity: number, unit: Unit, reason: WasteReason) {
    setState((current) => logWaste(current, ingredientId, quantity, unit, reason));
    trackEvent(ANALYTICS_EVENTS.WASTE_LOGGED, { ingredientId, reason });
    showNotice(`${getIngredient(ingredientId).name} 폐기를 기록하고 재고에서 뺐어요.`);
  }

  function handleSetPrice(ingredientId: string, price: number, packageAmount: number, unit: Unit) {
    setState((current) => setIngredientPrice(current, ingredientId, price, packageAmount, unit));
    trackEvent(ANALYTICS_EVENTS.PRICE_CONFIRMED, { ingredientId });
    showNotice(`${getIngredient(ingredientId).name} 가격을 저장했어요.`);
  }

  // ---- F16 알림 ----

  function handleDismissAlert(alertId: string) {
    setState((current) => dismissAlert(current, alertId));
    trackEvent(ANALYTICS_EVENTS.ALERT_DISMISSED, { kind: alertId.split(":")[0] });
  }

  function useIngredientForRecommendation(ingredientId: string) {
    const name = getIngredient(ingredientId).name;
    setAdditionalIngredients((current) => (current.includes(name) || current.length >= 5 ? current : [...current, name]));
    setView("leftover");
  }

  if (!hydrated) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-[#fbfaf5] px-6">
        <div className="text-center">
          <p className="text-4xl" aria-hidden="true">
            🥕
          </p>
          <p className="mt-3 text-sm font-bold text-[#657166]">한끼로그를 준비하고 있어요.</p>
        </div>
      </main>
    );
  }

  const plannedCount = state.plannedMeals.filter((meal) => meal.status === "planned").length;
  const shoppingCount = currentPurchaseItems.length;
  const fridgeCount = state.inventory.filter((item) => item.quantityStatus === "unknown" || (item.quantity ?? 0) > 0).length;

  return (
    <main className="shell">
      <header className="border-b border-[#dfe6dc] py-5">
        <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p className="eyebrow">남아서 버리는 식재료를, 다음 한 끼로.</p>
            <div className="mt-2 flex items-center gap-3">
              <span className="grid h-11 w-11 place-items-center rounded-2xl bg-[#356b43] text-2xl" aria-hidden="true">
                🍚
              </span>
              <div>
                <h1 className="text-2xl font-black tracking-[-0.04em] text-[#172018] sm:text-3xl">한끼로그</h1>
                <p className="mt-0.5 text-sm text-[#657166]">먹고 싶은 요리는 내가 고르고, 다음 계획은 함께.</p>
              </div>
            </div>
          </div>
          <div className="flex items-center gap-2 rounded-2xl bg-[#f0f5ed] px-4 py-3 text-sm font-bold text-[#356b43]">
            <span className="text-lg" aria-hidden="true">
              ✦
            </span>
            <span>기능 중심 MVP · 브라우저에 안전하게 저장</span>
          </div>
        </div>
        <nav className="mt-6 flex gap-1 overflow-x-auto pb-1" aria-label="주요 메뉴">
          {NAV_ITEMS.map((item) => (
            <button
              key={item.id}
              type="button"
              className={`tab-button whitespace-nowrap ${view === item.id ? "tab-button-active" : ""}`}
              aria-current={view === item.id ? "page" : undefined}
              onClick={() => navigate(item.id)}
            >
              {item.shortLabel}
              {item.id === "meals" && plannedCount > 0 ? <span className="ml-1.5 text-xs">{plannedCount}</span> : null}
              {item.id === "shopping" && shoppingCount > 0 ? <span className="ml-1.5 text-xs">{shoppingCount}</span> : null}
              {item.id === "alerts" && alerts.length > 0 ? <span className="ml-1.5 text-xs">{alerts.length}</span> : null}
            </button>
          ))}
        </nav>
      </header>

      <section className="grid gap-3 py-5 sm:grid-cols-3" aria-label="현재 상태">
        <button type="button" className="panel flex items-center justify-between p-4 text-left" onClick={() => navigate("meals")}>
          <span>
            <span className="eyebrow">내 식사</span>
            <span className="mt-1 block text-sm text-[#657166]">아직 요리하지 않은 계획</span>
          </span>
          <strong className="text-2xl text-[#356b43]">{plannedCount}</strong>
        </button>
        <button type="button" className="panel flex items-center justify-between p-4 text-left" onClick={() => navigate("shopping")}>
          <span>
            <span className="eyebrow">장보기</span>
            <span className="mt-1 block text-sm text-[#657166]">추가로 살 품목</span>
          </span>
          <strong className="text-2xl text-[#c75c3b]">{shoppingCount}</strong>
        </button>
        <button type="button" className="panel flex items-center justify-between p-4 text-left" onClick={() => navigate("fridge")}>
          <span>
            <span className="eyebrow">내 냉장고</span>
            <span className="mt-1 block text-sm text-[#657166]">남아 있는 재료</span>
          </span>
          <strong className="text-2xl text-[#356b43]">{fridgeCount}</strong>
        </button>
      </section>

      {storageFailed ? (
        <div className="mb-5 flex items-start gap-3 rounded-2xl border border-[#e8b8a6] bg-[#fdf2ee] px-4 py-3 text-sm font-bold text-[#a5442a]" role="alert">
          <span aria-hidden="true">⚠</span>
          <p>브라우저에 저장하지 못했어요. 시크릿 모드이거나 저장 공간이 가득 찼을 수 있어요. 화면을 새로고침하면 지금까지의 변경이 사라집니다.</p>
        </div>
      ) : null}

      {notice ? (
        <div className="mb-5 flex items-start gap-3 rounded-2xl border border-[#cbd8c9] bg-[#eef4ec] px-4 py-3 text-sm font-bold text-[#285736]" role="status">
          <span aria-hidden="true">✓</span>
          <p>{notice}</p>
        </div>
      ) : null}

      {view === "home" ? (
        <div className="space-y-6">
          <section className="grid gap-5 lg:grid-cols-[1.35fr_0.65fr]">
            <div className="panel overflow-hidden bg-[#e8f0e5] p-6 sm:p-8">
              <p className="eyebrow text-[#356b43]">01 · 먹고 싶은 메뉴</p>
              <h2 className="mt-3 max-w-2xl text-3xl font-black leading-tight tracking-[-0.05em] text-[#172018] sm:text-5xl">
                오늘의 한 끼를
                <br />
                먼저 골라요.
              </h2>
              <p className="mt-4 max-w-xl text-sm leading-6 text-[#506153] sm:text-base">
                선택한 메뉴를 기준으로 필요한 재료만 모으고, 사고 남은 양까지 계산해요. 지금은 데모 레시피로 전체 흐름을 바로 확인할 수 있어요.
              </p>
              <div className="mt-7 rounded-2xl border border-[#cbd8c9] bg-white/75 p-4">
                <p className="text-sm font-extrabold text-[#356b43]">식사로 담을 기본값</p>
                <div className="mt-3">
                  <PlanControls date={plannerDate} mealSlot={plannerSlot} onDateChange={setPlannerDate} onMealSlotChange={setPlannerSlot} />
                </div>
              </div>
            </div>
            <div className="panel flex flex-col justify-between p-6">
              <div>
                <p className="eyebrow">한끼로그의 순서</p>
                <ol className="mt-5 space-y-4">
                  {[
                    ["01", "메뉴 선택", "찜하거나 날짜와 끼니를 정해 담기"],
                    ["02", "재료 확인", "가지고 있는 양을 알려주기"],
                    ["03", "남김 없이", "구매량과 다음 메뉴까지 이어가기"],
                  ].map(([number, title, description]) => (
                    <li key={number} className="flex gap-3">
                      <span className="grid h-8 w-8 shrink-0 place-items-center rounded-xl bg-[#356b43] text-xs font-black text-white">{number}</span>
                      <span>
                        <strong className="block text-sm text-[#172018]">{title}</strong>
                        <span className="mt-0.5 block text-xs leading-5 text-[#657166]">{description}</span>
                      </span>
                    </li>
                  ))}
                </ol>
              </div>
              <p className="mt-8 border-t border-[#dfe6dc] pt-4 text-xs leading-5 text-[#657166]">
                수량 계산은 AI 추측이 아니라 단위와 판매 포장 기준의 규칙으로 처리해요.
              </p>
            </div>
          </section>

          <section className="panel p-5 sm:p-6" aria-labelledby="recipe-heading">
            <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
              <div>
                <p className="eyebrow">Recipe explorer</p>
                <h2 id="recipe-heading" className="mt-1 text-2xl font-black tracking-[-0.04em]">먹고 싶은 메뉴를 찾아보세요</h2>
              </div>
              <label className="w-full lg:max-w-xs">
                <span className="sr-only">레시피 검색</span>
                <input className="field w-full" type="search" placeholder="메뉴나 재료로 검색" value={search} onChange={(event) => setSearch(event.target.value)} />
              </label>
            </div>
            <div className="mt-5 flex gap-2 overflow-x-auto pb-1" role="group" aria-label="끼니별 레시피 필터">
              {["전체", ...MEAL_SLOTS].map((slot) => (
                <button
                  key={slot}
                  type="button"
                  className={`secondary-button whitespace-nowrap ${recipeFilter === slot ? "border-[#356b43] bg-[#e8f0e5]" : ""}`}
                  aria-pressed={recipeFilter === slot}
                  onClick={() => setRecipeFilter(slot as RecipeFilter)}
                >
                  {slot}
                </button>
              ))}
            </div>
            {filteredRecipes.length === 0 ? (
              <div className="mt-5">
                <EmptyState title="조건에 맞는 레시피가 없어요" description="검색어를 지우거나 다른 끼니를 선택해 보세요." />
              </div>
            ) : (
              <div className="mt-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                {filteredRecipes.map((recipe) => {
                  const favorite = state.favorites.includes(recipe.id);
                  return (
                    <article key={recipe.id} className="overflow-hidden rounded-2xl border border-[#dfe6dc] bg-white transition hover:-translate-y-0.5 hover:shadow-soft">
                      <div className="relative h-44 overflow-hidden bg-[#dce8d5]">
                        <img
                          src={recipe.imageUrl}
                          alt={recipe.imageAlt}
                          className="h-full w-full object-cover"
                          loading="lazy"
                          onError={(event) => {
                            event.currentTarget.style.display = "none";
                          }}
                        />
                        <span className="absolute left-3 top-3 tag bg-white/90">{recipe.cookTime}분</span>
                        <button
                          type="button"
                          className="absolute right-3 top-3 grid h-9 w-9 place-items-center rounded-full bg-white/90 text-lg shadow-sm"
                          aria-label={`${recipe.title} ${favorite ? "찜 해제" : "찜하기"}`}
                          aria-pressed={favorite}
                          onClick={() => toggleFavorite(recipe.id)}
                        >
                          <span className={favorite ? "text-[#c75c3b]" : "text-[#657166]"} aria-hidden="true">{favorite ? "♥" : "♡"}</span>
                        </button>
                      </div>
                      <div className="p-4">
                        <div className="flex flex-wrap gap-1.5">
                          {recipe.tags.map((tag) => <span className="tag" key={tag}>{tag}</span>)}
                        </div>
                        <h3 className="mt-3 text-lg font-black text-[#172018]">{recipe.title}</h3>
                        <p className="mt-1 min-h-10 text-sm leading-5 text-[#657166]">{recipe.description}</p>
                        <div className="mt-4 flex items-center justify-between gap-2 text-xs font-bold text-[#657166]">
                          <span>{recipe.mealSlots.join(" · ")} · {difficultyLabel(recipe.difficulty)}</span>
                          <button type="button" className="quiet-button" onClick={() => openRecipe(recipe.id)}>상세 보기</button>
                        </div>
                        <button type="button" className="primary-button mt-3 w-full" onClick={() => addRecipeToPlan(recipe.id)}>이 메뉴를 식사로 담기</button>
                      </div>
                    </article>
                  );
                })}
              </div>
            )}
          </section>

          {selectedRecipe ? (
            <section className="panel p-5 sm:p-6" aria-labelledby="recipe-detail-heading">
              <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <p className="eyebrow">Recipe detail</p>
                  <h2 id="recipe-detail-heading" className="mt-1 text-2xl font-black">{selectedRecipe.title}</h2>
                  <p className="mt-2 text-sm leading-6 text-[#657166]">{selectedRecipe.description}</p>
                </div>
                <button type="button" className="quiet-button self-start" onClick={() => setSelectedRecipeId(null)}>닫기</button>
              </div>
              <div className="mt-6 grid gap-6 lg:grid-cols-[0.9fr_1.1fr]">
                <div>
                  <h3 className="text-sm font-black text-[#356b43]">재료 · 1인분</h3>
                  <ul className="mt-3 divide-y divide-[#edf1eb] rounded-2xl border border-[#dfe6dc]">
                    {selectedRecipe.ingredients.map((ingredient) => (
                      <li key={ingredientKey(ingredient.ingredientId, ingredient.unit)} className="flex items-center justify-between gap-4 px-4 py-3 text-sm">
                        <span>{ingredient.rawName}{ingredient.preparation ? <span className="text-[#657166]"> · {ingredient.preparation}</span> : null}</span>
                        <strong>{formatQuantity(ingredient.quantity, ingredient.unit)}</strong>
                      </li>
                    ))}
                  </ul>
                </div>
                <div>
                  <h3 className="text-sm font-black text-[#356b43]">조리 순서</h3>
                  <ol className="mt-3 space-y-3">
                    {selectedRecipe.steps.map((step, index) => (
                      <li key={step} className="flex gap-3 text-sm leading-6 text-[#445244]">
                        <span className="grid h-6 w-6 shrink-0 place-items-center rounded-full bg-[#e8f0e5] text-xs font-black text-[#356b43]">{index + 1}</span>
                        <span>{step}</span>
                      </li>
                    ))}
                  </ol>
                </div>
              </div>
              <button type="button" className="primary-button mt-6" onClick={() => addRecipeToPlan(selectedRecipe.id)}>이 레시피를 {formatDate(plannerDate)} {plannerSlot}으로 담기</button>
            </section>
          ) : null}
        </div>
      ) : null}

      {view === "meals" ? (
        <section className="space-y-5" aria-labelledby="meals-heading">
          <div className="panel bg-[#e8f0e5] p-6 sm:p-8">
            <p className="eyebrow text-[#356b43]">My meals</p>
            <div className="mt-2 flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
              <div>
                <h2 id="meals-heading" className="text-3xl font-black tracking-[-0.05em]">선택한 메뉴를 한눈에 봐요.</h2>
                <p className="mt-2 max-w-xl text-sm leading-6 text-[#506153]">날짜와 끼니를 바꾸면 이 계획을 기준으로 필요한 재료와 장보기 양도 다시 계산돼요.</p>
              </div>
              <button type="button" className="secondary-button bg-white" onClick={() => navigate("home")}>레시피 더 고르기</button>
            </div>
          </div>
          {sortedMeals.length === 0 ? (
            <EmptyState title="아직 식사 계획이 없어요" description="레시피에서 먹고 싶은 메뉴를 고르면 날짜와 끼니를 정해 이곳에 담을 수 있어요." actionLabel="레시피 둘러보기" onAction={() => navigate("home")} />
          ) : (
            <div className="space-y-3">
              {sortedMeals.map((meal) => {
                const recipe = recipeForId(meal.recipeId);
                if (!recipe) return null;
                const cooked = meal.status === "cooked" || cookedMealIds.has(meal.id);
                const storageWarnings = getMealStorageWarnings(meal, recipe);
                return (
                  <article key={meal.id} className="panel p-4 sm:p-5">
                    <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
                      <div className="flex items-start gap-4">
                        <div className="grid h-16 w-16 shrink-0 place-items-center overflow-hidden rounded-2xl bg-[#dce8d5] text-3xl" aria-hidden="true">
                          🍽️
                        </div>
                        <div>
                          <div className="flex flex-wrap items-center gap-2">
                            <span className={`tag ${cooked ? "bg-[#e8f0e5] text-[#356b43]" : ""}`}>{cooked ? "요리 완료" : meal.mealSlot}</span>
                            <span className="text-xs font-bold text-[#657166]">{formatDate(meal.date)}</span>
                          </div>
                          <h3 className="mt-2 text-xl font-black">{recipe.title}</h3>
                          <p className="mt-1 text-sm text-[#657166]">재료 {recipe.ingredients.length}가지 · {recipe.cookTime}분</p>
                          {storageWarnings.length > 0 ? <p className="mt-2 text-xs font-bold leading-5 text-[#986b1e]" role="status">⚠ {storageWarnings[0]}</p> : null}
                        </div>
                      </div>
                      <div className="flex flex-wrap items-center gap-2 lg:justify-end">
                        <label className="sr-only" htmlFor={`date-${meal.id}`}>식사 날짜 변경</label>
                        <input id={`date-${meal.id}`} className="field" type="date" value={meal.date} onChange={(event) => setState((current) => updatePlannedMeal(current, meal.id, { date: event.target.value }))} />
                        <label className="sr-only" htmlFor={`slot-${meal.id}`}>식사 끼니 변경</label>
                        <select id={`slot-${meal.id}`} className="field" value={meal.mealSlot} onChange={(event) => setState((current) => updatePlannedMeal(current, meal.id, { mealSlot: event.target.value as MealSlot }))}>
                          {MEAL_SLOTS.map((slot) => <option key={slot}>{slot}</option>)}
                        </select>
                        <button type="button" className="primary-button" onClick={() => selectCookingMeal(meal.id)}>{cooked ? "완료 내용" : "요리하기"}</button>
                        <button type="button" className="quiet-button" onClick={() => { if (window.confirm("이 식사 계획을 삭제할까요?")) setState((current) => removePlannedMeal(current, meal.id)); }}>삭제</button>
                      </div>
                    </div>
                  </article>
                );
              })}
            </div>
          )}
          {sortedMeals.length > 0 ? (
            <div className="flex flex-wrap gap-3">
              <button type="button" className="primary-button" onClick={() => navigate("shopping")}>필요 재료 계산하기</button>
              <button type="button" className="secondary-button" onClick={() => navigate("leftover")}>내 냉장고 보기</button>
            </div>
          ) : null}
        </section>
      ) : null}

      {view === "shopping" ? (
        <section className="space-y-5" aria-labelledby="shopping-heading">
          <div className="panel p-6 sm:p-8">
            <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
              <div>
                <p className="eyebrow">Shopping · 단위 기반 계산</p>
                <h2 id="shopping-heading" className="mt-2 text-3xl font-black tracking-[-0.05em]">필요한 만큼만 장봐요.</h2>
                <p className="mt-2 max-w-2xl text-sm leading-6 text-[#657166]">선택한 식사들의 재료를 합치고, 보유량과 대표 판매 단위를 비교했어요. 수량 미상이나 단위 충돌은 자동 확정하지 않습니다.</p>
              </div>
              <div className="flex gap-2" role="group" aria-label="장보기 화면 전환">
                <button type="button" className={`secondary-button ${shoppingMode === "estimate" ? "border-[#356b43] bg-[#e8f0e5]" : ""}`} onClick={() => setShoppingMode("estimate")}>재료 확인</button>
                <button type="button" className={`secondary-button ${shoppingMode === "list" ? "border-[#356b43] bg-[#e8f0e5]" : ""}`} onClick={makeShoppingList}>장보기 목록</button>
              </div>
            </div>
          </div>
          {requirements.length === 0 ? (
            <EmptyState title="계산할 식사 계획이 없어요" description="먼저 먹을 메뉴를 선택하면 필요한 재료만 이곳에 모여요." actionLabel="내 식사로 이동" onAction={() => navigate("meals")} />
          ) : shoppingMode === "estimate" ? (
            <div className="space-y-4">
              <div className="panel overflow-hidden">
                <div className="hidden grid-cols-[1.2fr_0.7fr_0.8fr_0.8fr_0.8fr] gap-3 border-b border-[#dfe6dc] bg-[#f8fbf6] px-5 py-3 text-xs font-black text-[#657166] md:grid">
                  <span>재료</span><span>총 필요량</span><span>보유량</span><span>대표 포장</span><span>예상 잔여</span>
                </div>
                <div className="divide-y divide-[#edf1eb]">
                  {shoppingPlan.map((item) => {
                    const stock = state.inventory.find((inventoryItem) => inventoryItem.ingredientId === item.ingredientId && inventoryItem.unit === item.unit);
                    const isUnknown = stock?.quantityStatus === "unknown";
                    return (
                      <div key={item.key} className="grid gap-4 px-5 py-5 md:grid-cols-[1.2fr_0.7fr_0.8fr_0.8fr_0.8fr] md:items-center md:gap-3">
                        <div>
                          <div className="flex flex-wrap items-center gap-2">
                            <strong>{item.ingredientName}</strong>
                            {item.unitConflict ? <span className="tag bg-[#fff2df] text-[#986b1e]">단위 확인</span> : null}
                            {item.quantityStatus === "unknown" ? <span className="tag bg-[#fff2df] text-[#986b1e]">수량 미상</span> : null}
                          </div>
                          <p className="mt-1 text-xs text-[#657166]">{item.recipeIds.length}개 메뉴에서 사용 · {item.unit}</p>
                          {item.note ? <p className="mt-2 text-xs leading-5 text-[#986b1e]">{item.note}</p> : null}
                        </div>
                        <div className="flex justify-between gap-3 text-sm md:block"><span className="text-[#657166] md:hidden">총 필요량</span><strong>{formatQuantity(item.quantity, item.unit)}</strong></div>
                        <div>
                          <span className="text-xs font-bold text-[#657166] md:hidden">현재 보유량</span>
                          <div className="mt-1 flex flex-wrap items-center gap-2 md:mt-0">
                            {isUnknown ? (
                              <span className="rounded-xl bg-[#fff2df] px-3 py-2 text-sm font-bold text-[#986b1e]">있음 · 수량 미상</span>
                            ) : (
                              <input
                                className="number-input"
                                type="number"
                                min="0"
                                step="0.1"
                                aria-label={`${item.ingredientName} 보유량`}
                                value={stock?.quantity ?? 0}
                                onChange={(event) => updateRequirementInventory(item, event.target.value, false)}
                              />
                            )}
                            <label className="flex items-center gap-1.5 text-xs font-bold text-[#657166]">
                              <input type="checkbox" checked={isUnknown} onChange={(event) => updateRequirementInventory(item, String(stock?.quantity ?? ""), event.target.checked)} />
                              있음(수량 미상)
                            </label>
                          </div>
                        </div>
                        <div>
                          <span className="text-xs font-bold text-[#657166] md:hidden">실제 포장량</span>
                          <div className="mt-1 flex items-center gap-1 md:mt-0">
                            <input className="number-input" type="number" min="0.1" step="0.1" aria-label={`${item.ingredientName} 대표 포장량`} value={item.packageSize.amount} onChange={(event) => updatePackageSize(item, event.target.value)} />
                            <span className="text-xs font-bold text-[#657166]">{item.packageSize.unit}</span>
                          </div>
                          <span className="mt-1 block text-[11px] text-[#657166]">{item.packageSize.label}</span>
                        </div>
                        <div className="flex items-center justify-between gap-3 md:block">
                          <div><span className="text-xs font-bold text-[#657166] md:hidden">예상 잔여량</span><strong className="block text-[#356b43]">{item.expectedRemaining === null ? "확인 필요" : formatQuantity(item.expectedRemaining, item.unit)}</strong></div>
                          <span className={`mt-1 block text-xs font-bold ${item.precision === "exact" ? "text-[#356b43]" : "text-[#986b1e]"}`}>{item.precision === "exact" ? "정확 계산" : item.precision === "estimated" ? "예상값" : "수동 확인"}</span>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
              {manualShoppingItems.length > 0 ? (
                <div className="rounded-2xl border border-[#e8c986] bg-[#fff8e9] px-5 py-4 text-sm leading-6 text-[#79571b]">
                  <strong>확인이 필요한 재료 {manualShoppingItems.length}개</strong>
                  <p className="mt-1">질량·개수처럼 서로 다른 단위는 근거 없이 바꾸지 않았어요. 실제 포장 단위를 확인한 뒤 냉장고에서 단위를 맞춰 입력해 주세요.</p>
                </div>
              ) : null}
              <div className="flex flex-wrap items-center justify-between gap-3">
                <p className="text-sm text-[#657166]">보유량 입력을 바꾸면 구매 수량과 예상 잔여량이 즉시 다시 계산돼요.</p>
                <button type="button" className="primary-button" onClick={makeShoppingList}>장보기 목록 만들기 ({currentPurchaseItems.length})</button>
              </div>
            </div>
          ) : (
            <div className="grid gap-5 lg:grid-cols-[1fr_0.35fr]">
              <div className="panel overflow-hidden">
                <div className="flex items-center justify-between border-b border-[#dfe6dc] px-5 py-4">
                  <div><p className="eyebrow">Shopping list</p><h3 className="mt-1 text-xl font-black">이번 장보기</h3></div>
                  <span className="tag bg-[#fff2df] text-[#986b1e]">{displayShoppingItems.length}개 품목</span>
                </div>
                {displayShoppingItems.length === 0 ? (
                  <div className="p-6"><EmptyState title="추가 구매 품목이 없어요" description="현재 보유량으로 계획한 식사를 만들 수 있어요. 보유량을 수정하려면 재료 확인으로 돌아가세요." actionLabel="재료 다시 확인" onAction={() => setShoppingMode("estimate")} /></div>
                ) : (
                  <ul className="divide-y divide-[#edf1eb]">
                    {displayShoppingItems.map((item) => {
                      const checked = state.purchaseChecks[item.key] === true;
                      const quantity = purchaseQuantityFor(item);
                      return (
                        <li key={item.key} className={`flex flex-col gap-3 px-5 py-5 sm:flex-row sm:items-center sm:justify-between ${checked ? "bg-[#f4f8f2]" : ""}`}>
                          <div>
                            <label className="flex items-center gap-2">
                              <input
                                type="checkbox"
                                className="h-5 w-5 accent-[#356b43]"
                                checked={checked}
                                onChange={(event) => togglePurchaseChecked(item, event.target.checked)}
                              />
                              <strong className={checked ? "text-[#657166] line-through" : ""}>{item.ingredientName}</strong>
                            </label>
                            <p className="mt-1 pl-7 text-sm text-[#657166]">
                              필요량 {formatQuantity(item.quantity, item.unit)} · 보유량 {item.availableQuantity === null ? "수량 미상" : formatQuantity(item.availableQuantity, item.unit)}
                            </p>
                          </div>
                          <div className="flex items-center gap-3 pl-7 sm:pl-0">
                            <label className="text-right">
                              <span className="block text-xs font-bold text-[#657166]">실제로 산 포장 수</span>
                              <span className="mt-1 flex items-center justify-end gap-1">
                                <input
                                  className="number-input"
                                  type="number"
                                  min="0"
                                  step="1"
                                  aria-label={`${item.ingredientName} 실제 구매 포장 수`}
                                  value={purchaseOverrides[item.key] ?? String(item.purchaseQuantity)}
                                  onChange={(event) => setPurchaseOverrides((current) => ({ ...current, [item.key]: event.target.value }))}
                                />
                                <span className="text-sm font-bold text-[#657166]">포장</span>
                              </span>
                              <span className="mt-0.5 block text-xs text-[#c75c3b]">{formatQuantity(quantity * item.packageSize.amount, item.unit)}</span>
                            </label>
                          </div>
                        </li>
                      );
                    })}
                  </ul>
                )}
                {displayShoppingItems.length > 0 ? (
                  <div className="flex flex-wrap items-center justify-between gap-3 border-t border-[#dfe6dc] px-5 py-4">
                    <p className="text-xs text-[#657166]">
                      체크한 품목 {displayShoppingItems.filter((item) => state.purchaseChecks[item.key]).length} / {displayShoppingItems.length}
                    </p>
                    <div className="flex gap-2">
                      <button type="button" className="secondary-button" onClick={copyShoppingList}>목록 복사</button>
                      <button type="button" className="secondary-button" onClick={shareShoppingList}>공유</button>
                    </div>
                  </div>
                ) : null}
                {shareStatus ? <p className="px-5 pb-3 text-xs font-bold text-[#356b43]" role="status">{shareStatus}</p> : null}
                {manualCopyText ? (
                  <div className="px-5 pb-5">
                    <label className="text-xs font-bold text-[#986b1e]">
                      직접 복사할 목록
                      <textarea className="field mt-1 h-32 w-full font-mono text-xs" readOnly value={manualCopyText} onFocus={(event) => event.currentTarget.select()} />
                    </label>
                  </div>
                ) : null}
              </div>
              <aside className="panel h-fit p-5">
                <p className="eyebrow">Next</p>
                <h3 className="mt-1 text-xl font-black">장본 뒤에는</h3>
                <p className="mt-2 text-sm leading-6 text-[#657166]">구매한 포장량을 재고에 반영하고, 실제로 요리한 뒤 남은 양을 다시 확인해요.</p>
                <button type="button" className="primary-button mt-5 w-full" onClick={completeShopping} disabled={currentPurchaseItems.length === 0}>장보기 완료 · 재고 반영</button>
                <button type="button" className="secondary-button mt-2 w-full" onClick={() => navigate("cooking")}>요리 화면으로 이동</button>
                {shoppingPlan.some((item) => item.quantityStatus === "unknown") ? <p className="mt-4 text-xs leading-5 text-[#986b1e]">수량 미상으로 표시된 재료는 장보기 반영 후에도 자동으로 확정하지 않아요.</p> : null}
              </aside>
            </div>
          )}
        </section>
      ) : null}

      {view === "cooking" ? (
        <section className="space-y-5" aria-labelledby="cooking-heading">
          <div className="panel bg-[#fff8e9] p-6 sm:p-8">
            <p className="eyebrow text-[#986b1e]">Cooking</p>
            <h2 id="cooking-heading" className="mt-2 text-3xl font-black tracking-[-0.05em]">먹은 만큼만 차감해요.</h2>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-[#79571b]">예상 사용량을 그대로 쓰거나 실제 사용량과 요리 후 남은 수량을 수정할 수 있어요. 완료 요청을 다시 눌러도 같은 식사를 두 번 차감하지 않습니다.</p>
          </div>
          {sortedMeals.length === 0 ? (
            <EmptyState title="요리할 식사가 없어요" description="먼저 레시피를 내 식사에 담아 주세요." actionLabel="레시피 둘러보기" onAction={() => navigate("home")} />
          ) : (
            <div className="grid gap-5 lg:grid-cols-[0.7fr_1.3fr]">
              <div className="panel h-fit p-4">
                <p className="eyebrow px-2">요리할 식사</p>
                <div className="mt-3 space-y-2">
                  {sortedMeals.map((meal) => {
                    const recipe = recipeForId(meal.recipeId);
                    if (!recipe) return null;
                    const cooked = cookedMealIds.has(meal.id);
                    return (
                      <button key={meal.id} type="button" className={`w-full rounded-2xl border p-3 text-left transition ${activeCookingMeal?.id === meal.id ? "border-[#356b43] bg-[#e8f0e5]" : "border-[#dfe6dc] hover:bg-[#f8fbf6]"}`} onClick={() => setSelectedCookingMealId(meal.id)}>
                        <span className="flex items-center justify-between gap-3"><strong className="text-sm">{recipe.title}</strong><span className="tag">{cooked ? "완료" : meal.mealSlot}</span></span>
                        <span className="mt-1 block text-xs text-[#657166]">{formatDate(meal.date)}</span>
                      </button>
                    );
                  })}
                </div>
              </div>
              {activeCookingMeal && activeCookingRecipe ? (
                <div className="panel p-5 sm:p-6">
                  <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                    <div><span className="tag">{activeCookingMeal.mealSlot} · {formatDate(activeCookingMeal.date)}</span><h3 className="mt-2 text-2xl font-black">{activeCookingRecipe.title}</h3></div>
                    {cookedMealIds.has(activeCookingMeal.id) ? <span className="tag bg-[#e8f0e5] text-[#356b43]">요리 완료됨</span> : null}
                  </div>
                  <div className="mt-6 overflow-hidden rounded-2xl border border-[#dfe6dc]">
                    <div className="hidden grid-cols-[1.2fr_0.75fr_0.85fr_0.85fr] gap-3 bg-[#f8fbf6] px-4 py-3 text-xs font-black text-[#657166] sm:grid"><span>재료</span><span>예상 사용량</span><span>실제 사용량</span><span>요리 후 남음</span></div>
                    <div className="divide-y divide-[#edf1eb]">
                      {activeCookingRecipe.ingredients.map((ingredient) => {
                        const key = ingredientKey(ingredient.ingredientId, ingredient.unit);
                        const stock = state.inventory.find((item) => item.ingredientId === ingredient.ingredientId && item.unit === ingredient.unit);
                        return (
                          <div key={key} className="grid gap-3 px-4 py-4 sm:grid-cols-[1.2fr_0.75fr_0.85fr_0.85fr] sm:items-center sm:gap-3">
                            <div><strong className="text-sm">{ingredient.rawName}</strong><span className="mt-0.5 block text-xs text-[#657166]">현재 {stock?.quantityStatus === "unknown" ? "수량 미상" : formatQuantity(stock?.quantity ?? 0, ingredient.unit)}</span></div>
                            <div className="flex justify-between text-sm sm:block"><span className="text-xs text-[#657166] sm:hidden">예상</span><strong>{formatQuantity(ingredient.quantity, ingredient.unit)}</strong></div>
                            <label><span className="text-xs font-bold text-[#657166] sm:hidden">실제 사용량</span><input className="field mt-1 w-full sm:mt-0" type="number" min="0" step="0.1" aria-label={`${ingredient.rawName} 실제 사용량`} value={cookingUsage[key] ?? ingredient.quantity} onChange={(event) => setCookingUsage((current) => ({ ...current, [key]: event.target.value }))} /></label>
                            <label><span className="text-xs font-bold text-[#657166] sm:hidden">요리 후 남음</span><input className="field mt-1 w-full sm:mt-0" type="number" min="0" step="0.1" placeholder="자동 계산" aria-label={`${ingredient.rawName} 요리 후 남은 양`} value={cookingRemaining[key] ?? ""} onChange={(event) => setCookingRemaining((current) => ({ ...current, [key]: event.target.value }))} /></label>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                  <div className="mt-5 flex flex-wrap items-center justify-between gap-3">
                    <p className="text-xs leading-5 text-[#657166]">남은 양을 입력하면 사용량보다 남은 양을 우선해 재고를 확정해요.</p>
                    <button type="button" className="primary-button" onClick={completeCooking} disabled={cookedMealIds.has(activeCookingMeal.id)}>요리 완료 처리</button>
                  </div>
                </div>
              ) : null}
            </div>
          )}
        </section>
      ) : null}

      {view === "fridge" ? (
        <section className="space-y-5" aria-labelledby="fridge-heading">
          <div className="panel p-6 sm:p-8">
            <p className="eyebrow">My fridge</p>
            <h2 id="fridge-heading" className="mt-2 text-3xl font-black tracking-[-0.05em]">내가 가진 재료를 가볍게 기록해요.</h2>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-[#657166]">냉장고 전체를 완벽하게 채울 필요는 없어요. 다음 식사에 쓸 재료와 먼저 써야 할 재료만 기록해도 충분합니다.</p>
          </div>
          <div className="panel p-5 sm:p-6">
            <div className="flex flex-col gap-4 lg:flex-row lg:items-end">
              <label className="grid flex-1 gap-1.5 text-sm font-bold text-[#445244]">재료
                <select className="field" value={newInventoryId} onChange={(event) => setNewInventoryId(event.target.value)}>{INGREDIENTS.map((ingredient) => <option key={ingredient.id} value={ingredient.id}>{ingredient.name}</option>)}</select>
              </label>
              <label className="grid gap-1.5 text-sm font-bold text-[#445244]">수량
                <input className="field" type="number" min="0" step="0.1" value={newInventoryQuantity} disabled={newInventoryUnknown} onChange={(event) => setNewInventoryQuantity(event.target.value)} />
              </label>
              <label className="flex min-h-10 items-center gap-2 text-sm font-bold text-[#445244]"><input type="checkbox" checked={newInventoryUnknown} onChange={(event) => setNewInventoryUnknown(event.target.checked)} /> 있음 · 수량 미상</label>
              <button type="button" className="primary-button" onClick={addFridgeIngredient}>냉장고에 추가</button>
            </div>
          </div>
          {state.inventory.length === 0 ? (
            <EmptyState title="아직 기록한 재료가 없어요" description="위에서 가지고 있는 재료를 추가하면 남은 재료 추천에 바로 활용돼요." />
          ) : (
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {state.inventory.map((item) => {
                const ingredient = getIngredient(item.ingredientId);
                return (
                  <article key={`${item.ingredientId}-${item.unit}`} className="panel p-4">
                    <div className="flex items-start justify-between gap-3"><div><span className="eyebrow">{ingredient.riskLevel === "high" ? "먼저 사용" : ingredient.riskLevel === "medium" ? "냉장 보관" : "오래 보관"}</span><h3 className="mt-1 text-lg font-black">{ingredient.name}</h3></div><button type="button" className="quiet-button" onClick={() => removeFridgeIngredient(item.ingredientId, item.unit)}>삭제</button></div>
                    <div className="mt-4 flex items-center gap-2">
                      {item.quantityStatus === "unknown" ? <span className="rounded-xl bg-[#fff2df] px-3 py-2 text-sm font-bold text-[#986b1e]">있음 · 수량 미상</span> : <><input className="number-input" type="number" min="0" step="0.1" aria-label={`${ingredient.name} 재고 수량`} value={item.quantity ?? 0} onChange={(event) => updateFridgeIngredient(item.ingredientId, item.unit, event.target.value)} /><span className="text-sm font-bold text-[#657166]">{item.unit}</span></>}
                      <button type="button" className="quiet-button ml-auto text-xs" onClick={() => updateFridgeIngredient(item.ingredientId, item.unit, String(item.quantity ?? 0), item.quantityStatus !== "unknown")}>{item.quantityStatus === "unknown" ? "수량 입력" : "수량 미상으로"}</button>
                    </div>
                    <p className="mt-3 text-xs leading-5 text-[#657166]">{ingredient.storageNote}</p>
                  </article>
                );
              })}
            </div>
          )}
        </section>
      ) : null}

      {view === "leftover" ? (
        <section className="space-y-5" aria-labelledby="leftover-heading">
          <div className="panel bg-[#e8f0e5] p-6 sm:p-8">
            <p className="eyebrow text-[#356b43]">Leftover recipe</p>
            <div className="mt-2 flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
              <div><h2 id="leftover-heading" className="text-3xl font-black tracking-[-0.05em]">남은 재료로 다음 한 끼를 찾아요.</h2><p className="mt-2 max-w-2xl text-sm leading-6 text-[#506153]">많이 활용하고, 먼저 상할 재료를 쓰고, 새로 살 재료는 적은 순서로 정리했어요. 추천은 선택지일 뿐, 건너뛰어도 괜찮아요.</p></div>
              <div className="flex flex-wrap gap-2 lg:justify-end">
                <button type="button" className="secondary-button bg-white" onClick={() => navigate("fridge")}>냉장고 수정</button>
                <button type="button" className="secondary-button bg-white" onClick={() => navigate("meals")}>다음 식단으로 이월</button>
                <button type="button" className="quiet-button" onClick={finishCurrentMeal}>현재 식단 종료</button>
              </div>
            </div>
          </div>
          <div className="panel p-5 sm:p-6">
            <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
              <div><p className="eyebrow">More context · 최대 5개</p><h3 className="mt-1 text-xl font-black">지금 함께 쓰고 싶은 재료가 있나요?</h3></div>
              <div className="flex w-full gap-2 lg:max-w-md"><input className="field min-w-0 flex-1" type="text" placeholder="예: 계란, 양파" value={additionalInput} onChange={(event) => setAdditionalInput(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter") { event.preventDefault(); addAdditionalIngredient(); } }} /><button type="button" className="secondary-button" onClick={addAdditionalIngredient}>추가</button></div>
            </div>
            <div className="mt-4 flex flex-wrap gap-2">
              {additionalIngredients.length === 0 ? <span className="text-sm text-[#657166]">입력하지 않아도 내 냉장고 재료만으로 추천해요.</span> : additionalIngredients.map((name) => <button key={name} type="button" className="tag bg-[#356b43] text-white" onClick={() => removeAdditionalIngredient(name)}>{name} ×</button>)}
            </div>
          </div>
          {exactLeftovers.length === 0 && additionalIngredients.length === 0 ? (
            <EmptyState title="추천할 수 있는 남은 재료가 없어요" description="냉장고에 수량을 알고 있는 재료를 추가하거나, 함께 쓰고 싶은 재료를 최대 5개 입력해 주세요." actionLabel="내 냉장고 열기" onAction={() => navigate("fridge")} />
          ) : recommendations.length === 0 ? (
            <EmptyState title="아직 맞는 추천이 없어요" description="재료를 더 입력하거나 수량을 확인하면 추천 후보가 늘어날 수 있어요." actionLabel="냉장고 수정" onAction={() => navigate("fridge")} />
          ) : (
            <div className="grid gap-4 md:grid-cols-2">
              {recommendations.map((recommendation, index) => {
                const isSelected = selectedRecommendationId === recommendation.recipe.id;
                return (
                  <article key={recommendation.recipe.id} className="panel overflow-hidden p-5">
                    <div className="flex items-start justify-between gap-3"><div><span className="tag bg-[#356b43] text-white">추천 {index + 1}</span><h3 className="mt-3 text-xl font-black">{recommendation.recipe.title}</h3></div><span className="text-sm font-black text-[#356b43]">{recommendation.score}점</span></div>
                    <p className="mt-3 text-sm leading-6 text-[#445244]">{recommendation.reason}</p>
                    <div className="mt-4 grid gap-3 sm:grid-cols-2"><div><span className="eyebrow">활용 재료</span><p className="mt-1 text-sm font-bold text-[#356b43]">{recommendation.usedIngredients.join(", ")}</p></div><div><span className="eyebrow">추가 구매</span><p className="mt-1 text-sm font-bold text-[#c75c3b]">{recommendation.additionalIngredients.length ? recommendation.additionalIngredients.join(", ") : "없음"}</p></div></div>
                    {isSelected ? (
                      <div className="mt-4 rounded-2xl border border-[#dfe6dc] bg-[#f8fbf6] p-4" aria-live="polite">
                        <div className="flex items-center justify-between gap-3"><strong className="text-sm text-[#356b43]">이 메뉴의 미니 장보기</strong><span className="text-xs font-bold text-[#657166]">{recommendation.additionalPurchaseItems.length}개 품목</span></div>
                        {recommendation.additionalPurchaseItems.length === 0 ? (
                          <p className="mt-3 text-sm text-[#657166]">현재 정확히 입력한 재고만으로 만들 수 있어요.</p>
                        ) : (
                          <ul className="mt-3 space-y-2">
                            {recommendation.additionalPurchaseItems.map((item) => (
                              <li key={item.key} className="flex items-start justify-between gap-3 text-sm">
                                <span><strong>{item.ingredientName}</strong><span className="mt-0.5 block text-xs text-[#657166]">필요량 {formatQuantity(item.quantity, item.unit)} · {item.note ?? "현재 보유량 반영"}</span></span>
                                <strong className="shrink-0 text-[#c75c3b]">{item.precision === "manual" ? "확인 필요" : `${item.purchaseQuantity}포장`}</strong>
                              </li>
                            ))}
                          </ul>
                        )}
                      </div>
                    ) : null}
                    <div className="mt-5 flex flex-wrap items-center justify-between gap-3 border-t border-[#edf1eb] pt-4"><span className="text-xs font-bold text-[#657166]">{recommendation.recipe.cookTime}분 · {difficultyLabel(recommendation.recipe.difficulty)}</span><div className="flex flex-wrap justify-end gap-2"><button type="button" className="secondary-button" onClick={() => setSelectedRecommendationId(isSelected ? null : recommendation.recipe.id)}>{isSelected ? "미니 장보기 닫기" : "미니 장보기"}</button><button type="button" className="primary-button" onClick={() => { trackEvent(ANALYTICS_EVENTS.LEFTOVER_RECIPE_SELECTED, { recipeId: recommendation.recipe.id }); addRecipeToPlan(recommendation.recipe.id); }}>이 메뉴를 다음 식사로</button></div></div>
                  </article>
                );
              })}
            </div>
          )}
        </section>
      ) : null}

      {view === "planner" ? (
        <PlannerView
          state={state}
          recipes={RECIPES}
          today={TODAY}
          formatDate={formatDate}
          onGenerate={(plan) => trackEvent(ANALYTICS_EVENTS.MEAL_PLAN_GENERATED, { slots: plan.drafts.length, newPurchases: plan.totalNewPurchases })}
          onSwap={(recipeId) => trackEvent(ANALYTICS_EVENTS.MEAL_PLAN_SWAPPED, { recipeId })}
          onApply={applyPlan}
        />
      ) : null}

      {view === "alerts" ? (
        <AlertsView
          state={state}
          recipes={RECIPES}
          onDismiss={handleDismissAlert}
          onUpdateSettings={(updates: Partial<NotificationSettings>) => setState((current) => updateNotificationSettings(current, updates))}
          onUseIngredient={useIngredientForRecommendation}
          onOpenMeal={selectCookingMeal}
        />
      ) : null}

      {view === "records" ? (
        <RecordsView
          state={state}
          recipes={RECIPES}
          formatDate={formatDate}
          onLogWaste={handleLogWaste}
          onSetPrice={handleSetPrice}
          onClearPrice={(ingredientId) => setState((current) => clearIngredientPrice(current, ingredientId))}
        />
      ) : null}
    </main>
  );
}
