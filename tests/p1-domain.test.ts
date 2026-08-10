import { describe, expect, it } from "vitest";
import { deriveAlerts } from "../lib/notifications";
import { restoreState } from "../lib/persistence";
import { generateMealPlan, recomputePlan, type PlanRequest } from "../lib/planner";
import { summarizeRecords, unitPrice } from "../lib/records";
import { calculateDepletionRisk, rankDepletionRisks } from "../lib/risk";
import { RECIPES } from "../lib/seed-data";
import {
  applyMealPlanDrafts,
  createInitialState,
  dismissAlert,
  logWaste,
  setIngredientPrice,
  setPurchaseChecked,
} from "../lib/state";
import type { AppState, InventoryItem, PlannedMeal, Recipe, RecipeIngredient } from "../lib/types";

const NOW = new Date("2026-08-12T00:00:00.000Z");

function inventory(
  ingredientId: string,
  quantity: number | null,
  unit: InventoryItem["unit"] = "개",
  updatedAt = "2026-08-12T00:00:00.000Z",
  quantityStatus: InventoryItem["quantityStatus"] = "exact",
): InventoryItem {
  return { ingredientId, quantity, unit, quantityStatus, updatedAt };
}

function meal(recipeId: string, id: string, date = "2026-08-12"): PlannedMeal {
  return { id, recipeId, date, mealSlot: "저녁", status: "planned", createdAt: "2026-08-11T00:00:00.000Z" };
}

function recipe(id: string, ingredients: RecipeIngredient[], mealSlots: Recipe["mealSlots"] = ["저녁"]): Recipe {
  return {
    id,
    title: id,
    description: "test",
    mealSlots,
    difficulty: 1,
    cookTime: 10,
    servings: 1,
    imageUrl: "",
    imageAlt: "test",
    ingredients,
    steps: [],
    tags: [],
  };
}

describe("F15 재료 소진 위험", () => {
  it("오래 둔 상하기 쉬운 재료를 높은 위험으로 계산한다", () => {
    const risk = calculateDepletionRisk(inventory("green-onion", 200, "g", "2026-08-05T00:00:00.000Z"), [], [], NOW);
    expect(risk.score).not.toBeNull();
    expect(risk.state).toBe("urgent");
    expect(risk.reasons.join(" ")).toContain("아직 사용 계획이 없어요");
  });

  it("오래 보관 가능한 재료를 상하기 쉬운 재료보다 먼저 경고하지 않는다", () => {
    const perishable = calculateDepletionRisk(inventory("green-onion", 100, "g", "2026-08-09T00:00:00.000Z"), [], [], NOW);
    const shelfStable = calculateDepletionRisk(inventory("soy-sauce", 10, "큰술", "2026-08-09T00:00:00.000Z"), [], [], NOW);
    expect(perishable.score!).toBeGreaterThan(shelfStable.score!);
  });

  it("예정된 식단이 전부 소비하면 위험도를 낮춘다", () => {
    const recipes = [recipe("use-it", [{ ingredientId: "green-onion", rawName: "대파", quantity: 200, unit: "g" }])];
    const item = inventory("green-onion", 200, "g", "2026-08-08T00:00:00.000Z");
    const withoutPlan = calculateDepletionRisk(item, [], recipes, NOW);
    const withPlan = calculateDepletionRisk(item, [meal("use-it", "m1")], recipes, NOW);
    expect(withPlan.plannedUsage).toBe(200);
    expect(withPlan.score!).toBeLessThan(withoutPlan.score!);
    expect(withPlan.reasons.join(" ")).toContain("전부 사용할 계획");
  });

  it("수량을 모르면 거짓 정밀도 대신 확인 필요 상태로 남긴다", () => {
    const risk = calculateDepletionRisk(inventory("egg", null, "개", "2026-08-01T00:00:00.000Z", "unknown"), [], [], NOW);
    expect(risk.score).toBeNull();
    expect(risk.state).toBe("unknown");
  });

  it("위험이 큰 재료를 앞에 정렬한다", () => {
    const ranked = rankDepletionRisks(
      [
        inventory("soy-sauce", 10, "큰술", "2026-08-11T00:00:00.000Z"),
        inventory("green-onion", 200, "g", "2026-08-01T00:00:00.000Z"),
      ],
      [],
      [],
      NOW,
    );
    expect(ranked[0].ingredientName).toBe("대파");
  });
});

describe("F13 다일 식단 계획", () => {
  const request: PlanRequest = {
    startDate: "2026-08-12",
    days: 3,
    slots: ["저녁"],
    seedRecipeIds: [],
    inventory: [],
    recipes: RECIPES,
  };

  it("기간과 끼니만큼 칸을 채우고 같은 입력에 같은 결과를 낸다", () => {
    const first = generateMealPlan({ ...request, slots: ["점심", "저녁"] });
    const second = generateMealPlan({ ...request, slots: ["점심", "저녁"] });
    expect(first.drafts).toHaveLength(6);
    expect(first.drafts.map((draft) => draft.recipeId)).toEqual(second.drafts.map((draft) => draft.recipeId));
    expect(first.unfilledSlots).toBe(0);
  });

  it("먹지 않는 끼니는 계획에서 제외한다", () => {
    const plan = generateMealPlan({ ...request, slots: ["아침"] });
    expect(plan.drafts).toHaveLength(3);
    expect(plan.drafts.every((draft) => draft.mealSlot === "아침")).toBe(true);
  });

  it("찜한 메뉴를 먼저 배치한다", () => {
    const plan = generateMealPlan({ ...request, seedRecipeIds: ["kimchi-fried-rice"] });
    expect(plan.drafts[0].recipeId).toBe("kimchi-fried-rice");
  });

  it("재료가 겹치는 메뉴를 골라 추가 구매를 줄인다", () => {
    const recipes = [
      recipe("shares", [
        { ingredientId: "egg", rawName: "계란", quantity: 1, unit: "개" },
        { ingredientId: "rice", rawName: "밥", quantity: 210, unit: "g" },
      ]),
      recipe("unrelated", [
        { ingredientId: "cucumber", rawName: "오이", quantity: 1, unit: "개" },
        { ingredientId: "gochujang", rawName: "고추장", quantity: 1, unit: "큰술" },
      ]),
    ];
    const plan = generateMealPlan({ ...request, days: 2, recipes, inventory: [inventory("egg", 4)] });
    expect(plan.drafts[0].recipeId).toBe("shares");
    expect(plan.drafts[0].reusedIngredientIds).toContain("egg");
  });

  it("메뉴를 하나 교체하면 재사용·추가 구매 수치를 다시 계산한다", () => {
    const plan = generateMealPlan({ ...request, days: 1 });
    const swapped = plan.drafts.map((draft, index) => (index === 0 ? { ...draft, recipeId: "tofu-kimchi" } : draft));
    const recomputed = recomputePlan(swapped, request);
    expect(recomputed.drafts[0].recipeId).toBe("tofu-kimchi");
    expect(recomputed.drafts[0].newPurchaseCount).toBe(5);
  });

  it("레시피가 없거나 끼니를 고르지 않아도 예외 없이 빈 계획을 준다", () => {
    expect(generateMealPlan({ ...request, recipes: [] }).drafts).toHaveLength(0);
    expect(generateMealPlan({ ...request, slots: [] }).drafts).toHaveLength(0);
    expect(generateMealPlan({ ...request, days: 0 }).drafts).toHaveLength(0);
  });

  it("확정하면 기존 계획을 지우지 않고 중복만 건너뛴다", () => {
    const plan = generateMealPlan({ ...request, days: 1 });
    const first = applyMealPlanDrafts(createInitialState(), plan.drafts, "2026-08-11T00:00:00.000Z");
    const second = applyMealPlanDrafts(first.state, plan.drafts, "2026-08-11T00:00:00.000Z");
    expect(first.added).toBe(1);
    expect(second.added).toBe(0);
    expect(second.state.plannedMeals).toHaveLength(1);
  });
});

describe("F10 식사·절약 기록", () => {
  function stateWithRecords(): AppState {
    let state = createInitialState();
    state = { ...state, inventory: [inventory("egg", 10)] };
    state = setIngredientPrice(state, "egg", 4000, 10, "개", "2026-08-12T00:00:00.000Z");
    state = {
      ...state,
      completions: [
        {
          plannedMealId: "m1",
          recipeId: "kimchi-fried-rice",
          completedAt: "2026-08-12T12:00:00.000Z",
          consumptions: [
            { ingredientId: "egg", unit: "개", expectedQuantity: 2, actualQuantity: 2, remainingQuantity: null },
            { ingredientId: "kimchi", unit: "g", expectedQuantity: 150, actualQuantity: 150, remainingQuantity: null },
          ],
        },
      ],
    };
    return state;
  }

  it("확인된 가격이 있는 재료만 금액으로 계산한다", () => {
    const summary = summarizeRecords(stateWithRecords(), "all", NOW);
    const egg = summary.breakdowns.find((item) => item.ingredientId === "egg");
    const kimchi = summary.breakdowns.find((item) => item.ingredientId === "kimchi");
    expect(egg?.usedValue).toBe(800); // 4000원 / 10개 * 2개
    expect(kimchi?.usedValue).toBeNull();
    expect(summary.confirmedUsedValue).toBe(800);
    expect(summary.unpricedIngredientCount).toBe(1);
  });

  it("단위가 다른 가격은 환산하지 않는다", () => {
    expect(unitPrice({ price: 4000, packageAmount: 10, unit: "개", confirmedAt: "", source: "user" }, "g")).toBeNull();
  });

  it("폐기를 기록하면 재고에서 빼고 낭비 금액에 반영한다", () => {
    const state = logWaste(stateWithRecords(), "egg", 3, "개", "spoiled", "2026-08-12T13:00:00.000Z");
    expect(state.inventory[0].quantity).toBe(7);
    const summary = summarizeRecords(state, "all", NOW);
    expect(summary.wasteLogCount).toBe(1);
    expect(summary.confirmedWastedValue).toBe(1200);
    expect(summary.breakdowns.find((item) => item.ingredientId === "egg")?.wastedQuantity).toBe(3);
  });

  it("남김없이 쓴 재료와 요리 횟수를 집계한다", () => {
    const summary = summarizeRecords(stateWithRecords(), "all", NOW);
    expect(summary.cookedMealCount).toBe(1);
    expect(summary.usedIngredientCount).toBe(2);
    expect(summary.fullyUsedIngredientCount).toBe(2);
  });

  it("존재하지 않는 재료가 섞인 요리 기록은 집계 전에 제거한다", () => {
    const restored = restoreState(JSON.stringify({
      plannedMeals: [meal("kimchi-fried-rice", "m1")],
      completions: [{
        plannedMealId: "m1",
        recipeId: "kimchi-fried-rice",
        completedAt: "2026-08-12T12:00:00.000Z",
        consumptions: [{ ingredientId: "삭제된-재료", unit: "개", expectedQuantity: 1, actualQuantity: 1, remainingQuantity: null }],
      }],
    }));
    expect(restored.completions).toHaveLength(0);
    // 집계가 예외 없이 통과해야 기록 화면이 뜹니다.
    expect(() => summarizeRecords(restored, "all", NOW)).not.toThrow();
  });

  it("주간 범위는 7일이 지난 기록을 제외한다", () => {
    const state = stateWithRecords();
    const later = new Date("2026-08-25T00:00:00.000Z");
    expect(summarizeRecords(state, "all", later).cookedMealCount).toBe(1);
    expect(summarizeRecords(state, "week", later).cookedMealCount).toBe(0);
  });

  it("잘못된 가격 입력은 저장하지 않는다", () => {
    const state = createInitialState();
    expect(setIngredientPrice(state, "egg", 4000, 0, "개").prices.egg).toBeUndefined();
    expect(setIngredientPrice(state, "missing", 4000, 10, "개").prices.missing).toBeUndefined();
  });
});

describe("F14 장보기 실행", () => {
  it("품목별 구매 체크를 저장하고 해제할 수 있다", () => {
    let state = setPurchaseChecked(createInitialState(), "egg:개", true);
    expect(state.purchaseChecks["egg:개"]).toBe(true);
    state = setPurchaseChecked(state, "egg:개", false);
    expect(state.purchaseChecks["egg:개"]).toBeUndefined();
  });

  it("체크 상태를 저장하고 다시 불러온다", () => {
    const state = setPurchaseChecked(createInitialState(), "egg:개", true);
    const restored = restoreState(JSON.stringify(state));
    expect(restored.purchaseChecks["egg:개"]).toBe(true);
  });
});

describe("F16 알림", () => {
  const recipes = [recipe("tonight", [{ ingredientId: "egg", rawName: "계란", quantity: 1, unit: "개" }])];

  function alertState(overrides: Partial<AppState> = {}): AppState {
    return { ...createInitialState(), ...overrides };
  }

  it("위험한 재료와 임박한 식사를 알린다", () => {
    const alerts = deriveAlerts(
      alertState({
        inventory: [inventory("green-onion", 200, "g", "2026-08-01T00:00:00.000Z")],
        plannedMeals: [meal("tonight", "m1", "2026-08-12")],
      }),
      recipes,
      NOW,
    );
    expect(alerts.some((alert) => alert.kind === "risk" && alert.ingredientId === "green-onion")).toBe(true);
    expect(alerts.some((alert) => alert.kind === "meal" && alert.plannedMealId === "m1")).toBe(true);
  });

  it("같은 사유의 알림을 중복 발행하지 않는다", () => {
    const state = alertState({ inventory: [inventory("green-onion", 200, "g", "2026-08-01T00:00:00.000Z")] });
    const alerts = deriveAlerts(state, recipes, NOW);
    expect(new Set(alerts.map((alert) => alert.id)).size).toBe(alerts.length);

    const dismissed = dismissAlert(state, alerts[0].id);
    expect(deriveAlerts(dismissed, recipes, NOW).some((alert) => alert.id === alerts[0].id)).toBe(false);
  });

  it("알림을 끄면 해당 종류를 만들지 않는다", () => {
    const state = alertState({
      inventory: [inventory("green-onion", 200, "g", "2026-08-01T00:00:00.000Z")],
      plannedMeals: [meal("tonight", "m1", "2026-08-12")],
      notificationSettings: { riskAlerts: false, mealReminders: false, leadDays: 1 },
    });
    expect(deriveAlerts(state, recipes, NOW)).toHaveLength(0);
  });

  it("선행 일수를 넘긴 식사는 아직 알리지 않는다", () => {
    const state = alertState({ plannedMeals: [meal("tonight", "m1", "2026-08-20")] });
    expect(deriveAlerts(state, recipes, NOW).filter((alert) => alert.kind === "meal")).toHaveLength(0);
  });

  it("재고와 식단이 비어 있어도 예외 없이 빈 목록을 준다", () => {
    expect(deriveAlerts(alertState(), recipes, NOW)).toEqual([]);
  });
});
