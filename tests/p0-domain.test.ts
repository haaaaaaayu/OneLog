import { describe, expect, it } from "vitest";
import { aggregateRequirements, applyPurchases, calculateShoppingPlan } from "../lib/calculations";
import { resolveIngredient } from "../lib/ingredients";
import { restoreState } from "../lib/persistence";
import { rankLeftoverRecipes } from "../lib/recommendations";
import { getMealStorageWarnings } from "../lib/schedule";
import { RECIPES } from "../lib/seed-data";
import { addPlannedMeal, applyShoppingToState, completePlannedMeal, createInitialState } from "../lib/state";
import type { InventoryItem, PlannedMeal, Recipe, RecipeIngredient } from "../lib/types";
import { formatQuantity } from "../lib/types";

function meal(recipeId: string, id: string): PlannedMeal {
  return { id, recipeId, date: "2026-08-12", mealSlot: "저녁", status: "planned", createdAt: "2026-08-11T00:00:00.000Z" };
}

function recipe(id: string, ingredients: RecipeIngredient[], difficulty: Recipe["difficulty"] = 1): Recipe {
  return {
    id,
    title: id,
    description: "test",
    mealSlots: ["저녁"],
    difficulty,
    cookTime: 10,
    servings: 1,
    imageUrl: "",
    imageAlt: "test",
    ingredients,
    steps: [],
    tags: [],
  };
}

function inventory(ingredientId: string, quantity: number | null, unit: InventoryItem["unit"] = "개", quantityStatus: InventoryItem["quantityStatus"] = "exact"): InventoryItem {
  return { ingredientId, quantity, unit, quantityStatus, updatedAt: "2026-08-11T00:00:00.000Z" };
}

describe("재료 정규화와 식단 수량 계산", () => {
  it("서로 다른 재료 별칭을 같은 표준 재료로 연결한다", () => {
    expect(resolveIngredient("달걀")?.id).toBe("egg");
    expect(resolveIngredient("계란 노른자")?.id).toBe("egg");
    expect(resolveIngredient("송송 썬 대파")?.id).toBe("green-onion");
  });

  it("여러 레시피의 같은 재료를 같은 단위에서 합산한다", () => {
    const recipes = [
      recipe("one", [{ ingredientId: "egg", rawName: "달걀", quantity: 2, unit: "개" }]),
      recipe("two", [{ ingredientId: "egg", rawName: "계란", quantity: 1, unit: "개" }]),
    ];
    const requirements = aggregateRequirements([meal("one", "m1"), meal("two", "m2")], recipes);
    expect(requirements).toHaveLength(1);
    expect(requirements[0].quantity).toBe(3);
    expect(requirements[0].unitConflict).toBe(false);
  });

  it("보유량이 적거나 같거나 많을 때 구매량을 올바르게 계산한다", () => {
    const recipes = [recipe("one", [{ ingredientId: "egg", rawName: "계란", quantity: 4, unit: "개" }])];
    const [requirement] = aggregateRequirements([meal("one", "m1")], recipes);

    const less = calculateShoppingPlan([requirement], [inventory("egg", 2)]);
    expect(less[0].additionalNeeded).toBe(2);
    expect(less[0].purchaseQuantity).toBe(1);
    expect(less[0].expectedRemaining).toBe(8);

    const equal = calculateShoppingPlan([requirement], [inventory("egg", 4)]);
    expect(equal[0].purchaseQuantity).toBe(0);
    expect(equal[0].expectedRemaining).toBe(0);

    const more = calculateShoppingPlan([requirement], [inventory("egg", 7)]);
    expect(more[0].purchaseQuantity).toBe(0);
    expect(more[0].expectedRemaining).toBe(3);
  });

  it("판매 단위 경계에서 최소 포장 수와 잔여량을 계산한다", () => {
    const recipes = [recipe("one", [{ ingredientId: "egg", rawName: "계란", quantity: 11, unit: "개" }])];
    const [requirement] = aggregateRequirements([meal("one", "m1")], recipes);
    const plan = calculateShoppingPlan([requirement], [], { egg: { amount: 10, unit: "개", label: "10구" } });
    expect(plan[0].purchaseQuantity).toBe(2);
    expect(plan[0].purchaseTotal).toBe(20);
    expect(plan[0].expectedRemaining).toBe(9);
  });

  it("수량 미상 보유 재료를 정확한 수량으로 오인하지 않는다", () => {
    const recipes = [recipe("one", [{ ingredientId: "egg", rawName: "있음", quantity: 2, unit: "개" }])];
    const [requirement] = aggregateRequirements([meal("one", "m1")], recipes);
    const [plan] = calculateShoppingPlan([requirement], [inventory("egg", null, "개", "unknown")]);
    expect(plan.availableQuantity).toBeNull();
    expect(plan.quantityStatus).toBe("unknown");
    expect(plan.precision).toBe("estimated");
    expect(plan.purchaseQuantity).toBe(1);
  });

  it("사용자가 대표 판매 단위를 수정하면 구매량도 바뀐다", () => {
    const recipes = [recipe("one", [{ ingredientId: "egg", rawName: "계란", quantity: 11, unit: "개" }])];
    const [requirement] = aggregateRequirements([meal("one", "m1")], recipes);
    const [plan] = calculateShoppingPlan([requirement], [], { egg: { amount: 6, unit: "개", label: "6구" } });
    expect(plan.purchaseQuantity).toBe(2);
    expect(plan.purchaseTotal).toBe(12);
  });

  it("잘못된 판매 단위 입력은 무한 구매량을 만들지 않고 대표값으로 안전하게 대체한다", () => {
    const recipes = [recipe("one", [{ ingredientId: "egg", rawName: "계란", quantity: 2, unit: "개" }])];
    const [requirement] = aggregateRequirements([meal("one", "m1")], recipes);
    const [plan] = calculateShoppingPlan([requirement], [], { egg: { amount: 0, unit: "개", label: "잘못된 포장" } });
    expect(Number.isFinite(plan.purchaseQuantity)).toBe(true);
    expect(plan.purchaseQuantity).toBe(1);
  });

  it("소수 수량을 화면 표시에서 임의로 1자리로 반올림하지 않는다", () => {
    expect(formatQuantity(0.25, "개")).toBe("0.25개");
    expect(formatQuantity(1.5, "큰술")).toBe("1.5큰술");
  });

  it("구매 완료 시 정확한 재고에만 구매량을 더한다", () => {
    const recipes = [recipe("one", [{ ingredientId: "egg", rawName: "계란", quantity: 4, unit: "개" }])];
    const [requirement] = aggregateRequirements([meal("one", "m1")], recipes);
    const [plan] = calculateShoppingPlan([requirement], [inventory("egg", 2)]);
    const next = applyPurchases([inventory("egg", 2)], [plan], "2026-08-11T00:00:00.000Z");
    expect(next[0].quantity).toBe(12);
  });
});

describe("요리 완료 멱등성과 추천", () => {
  it("같은 요리 완료 요청을 다시 보내도 재고를 이중 차감하지 않는다", () => {
    let state = createInitialState();
    state = addPlannedMeal(state, "one", "2026-08-12", "저녁", "2026-08-11T00:00:00.000Z");
    state = { ...state, inventory: [inventory("egg", 4)] };
    const plannedMeal = state.plannedMeals[0];
    const first = completePlannedMeal(state, plannedMeal.id, [{ ingredientId: "egg", unit: "개", expectedQuantity: 2, actualQuantity: 2, remainingQuantity: null }], "2026-08-12T12:00:00.000Z");
    const second = completePlannedMeal(first.state, plannedMeal.id, [{ ingredientId: "egg", unit: "개", expectedQuantity: 2, actualQuantity: 2, remainingQuantity: null }], "2026-08-12T12:01:00.000Z");
    expect(first.applied).toBe(true);
    expect(second.applied).toBe(false);
    expect(second.state.inventory[0].quantity).toBe(2);
    expect(second.state.completions).toHaveLength(1);
  });

  it("completion 기록이 유실된 cooked 식사도 재고를 다시 차감하지 않는다", () => {
    const restored = restoreState(JSON.stringify({
      favorites: [],
      plannedMeals: [{ ...meal("kimchi-fried-rice", "m1"), status: "cooked" }],
      inventory: [inventory("egg", 3)],
      packageOverrides: {},
      completions: [{ plannedMealId: "m1", recipeId: "다른-레시피", completedAt: "x", consumptions: [] }],
    }));
    expect(restored.plannedMeals[0].status).toBe("cooked");
    expect(restored.completions).toHaveLength(0);

    const retry = completePlannedMeal(restored, "m1", [{ ingredientId: "egg", unit: "개", expectedQuantity: 1, actualQuantity: 1, remainingQuantity: null }]);
    expect(retry.applied).toBe(false);
    expect(retry.state.inventory[0].quantity).toBe(3);
  });

  it("직접 입력한 추가 재료를 활용 재료와 추가 구매에 중복 표기하지 않는다", () => {
    const recipes = [recipe("egg-meal", [{ ingredientId: "egg", rawName: "계란", quantity: 2, unit: "개" }])];
    const [ranked] = rankLeftoverRecipes(recipes, [], ["계란"]);
    expect(ranked.usedIngredients).toContain("계란");
    expect(ranked.additionalIngredients).not.toContain("계란");
    expect(ranked.reason).toContain("추가 구매 없이");
    // 수량 미상이므로 미니 장보기 목록에는 안내와 함께 남습니다.
    expect(ranked.additionalPurchaseItems.map((item) => item.ingredientName)).toContain("계란");
  });

  it("남은 재료를 많이 활용하고 상하기 쉬운 재료를 포함한 레시피를 우선한다", () => {
    const recipes = [
      recipe("green-onion-meal", [
        { ingredientId: "green-onion", rawName: "대파", quantity: 20, unit: "g" },
        { ingredientId: "egg", rawName: "계란", quantity: 1, unit: "개" },
      ]),
      recipe("egg-meal", [{ ingredientId: "egg", rawName: "계란", quantity: 1, unit: "개" }]),
    ];
    const ranked = rankLeftoverRecipes(recipes, [inventory("green-onion", 100, "g"), inventory("egg", 2)]);
    expect(ranked[0].recipe.id).toBe("green-onion-meal");
    expect(ranked[0].usedIngredients).toEqual(expect.arrayContaining(["대파", "계란"]));
    expect(ranked[0].additionalIngredients).toHaveLength(0);
  });

  it("남은 재료가 필요량보다 적으면 추천 결과에 실제 추가 구매량을 포함한다", () => {
    const recipes = [recipe("green-onion-meal", [{ ingredientId: "green-onion", rawName: "대파", quantity: 200, unit: "g" }])];
    const ranked = rankLeftoverRecipes(recipes, [inventory("green-onion", 20, "g")]);
    expect(ranked[0].additionalPurchaseItems[0].ingredientName).toBe("대파");
    expect(ranked[0].additionalPurchaseItems[0].purchaseQuantity).toBe(1);
    expect(ranked[0].reason).toContain("1개 품목");
  });

  it("일정을 뒤로 옮기면 보관 주의 메시지를 생성한다", () => {
    const planned = { ...meal("chicken-donburi", "m1"), date: "2026-08-20" };
    const warnings = getMealStorageWarnings(planned, {
      id: "chicken-donburi",
      title: "닭 요리",
      description: "",
      mealSlots: ["저녁"],
      difficulty: 1,
      cookTime: 10,
      servings: 1,
      imageUrl: "",
      imageAlt: "",
      ingredients: [{ ingredientId: "chicken-thigh", rawName: "닭다리살", quantity: 200, unit: "g" }],
      steps: [],
      tags: [],
    }, new Date("2026-08-12T00:00:00.000Z"));
    expect(warnings[0]).toContain("닭다리살");
  });

  it("오염되거나 오래된 localStorage 데이터는 계산에 들어가기 전에 제거한다", () => {
    const restored = restoreState(JSON.stringify({
      favorites: ["not-a-recipe", "kimchi-fried-rice"],
      plannedMeals: [meal("kimchi-fried-rice", "valid"), { id: "invalid", recipeId: "missing", date: "bad", mealSlot: "저녁", status: "planned" }],
      inventory: [inventory("egg", 2), inventory("egg", -2), { ingredientId: "missing", quantity: 1, unit: "개", quantityStatus: "exact" }],
      packageOverrides: { egg: { amount: 0, unit: "개", label: "bad" }, onion: { amount: 2, unit: "개", label: "2개" } },
      completions: [],
    }));
    expect(restored.favorites).toEqual(["kimchi-fried-rice"]);
    expect(restored.plannedMeals).toHaveLength(1);
    expect(restored.inventory).toHaveLength(1);
    expect(restored.packageOverrides.egg).toBeUndefined();
    expect(restored.packageOverrides.onion.amount).toBe(2);
  });

  it("식사 선택부터 장보기·구매 반영·요리 완료까지 한 흐름으로 재고를 연결한다", () => {
    let state = createInitialState();
    state = addPlannedMeal(state, "tuna-mayo-rice", "2026-08-12", "점심", "2026-08-11T00:00:00.000Z");
    const requirements = aggregateRequirements(state.plannedMeals, RECIPES);
    const shoppingPlan = calculateShoppingPlan(requirements, state.inventory);
    expect(shoppingPlan.every((item) => item.purchaseQuantity > 0)).toBe(true);

    state = applyShoppingToState(state, shoppingPlan, "2026-08-12T08:00:00.000Z");
    const recipe = RECIPES.find((item) => item.id === "tuna-mayo-rice")!;
    const completion = completePlannedMeal(
      state,
      state.plannedMeals[0].id,
      recipe.ingredients.map((ingredient) => ({
        ingredientId: ingredient.ingredientId,
        unit: ingredient.unit,
        expectedQuantity: ingredient.quantity,
        actualQuantity: ingredient.quantity,
        remainingQuantity: null,
      })),
      "2026-08-12T12:00:00.000Z",
    );

    expect(completion.applied).toBe(true);
    expect(completion.state.plannedMeals[0].status).toBe("cooked");
    expect(completion.state.completions).toHaveLength(1);
    expect(completion.state.inventory.find((item) => item.ingredientId === "rice")?.quantity).toBe(0);
  });
});
