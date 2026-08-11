"use client";

import { useMemo, useState } from "react";
import { candidatesForSlot, generateMealPlan, recomputePlan, MAX_PLAN_DAYS } from "../../lib/planner";
import type { AppState, MealPlanDraft, MealSlot, Recipe } from "../../lib/types";
import { MEAL_SLOTS } from "../../lib/types";

/** F13 다일 식단 계획 화면. 초안을 보여주고 사용자가 확정하기 전까지 아무것도 바꾸지 않습니다. */
export default function PlannerView({
  state,
  recipes,
  today,
  formatDate,
  onGenerate,
  onSwap,
  onApply,
}: {
  state: AppState;
  recipes: Recipe[];
  today: string;
  formatDate: (date: string) => string;
  onGenerate: (plan: MealPlanDraft) => void;
  onSwap: (recipeId: string) => void;
  onApply: (plan: MealPlanDraft) => void;
}) {
  const [days, setDays] = useState(3);
  const [slots, setSlots] = useState<MealSlot[]>(["점심", "저녁"]);
  const [startDate, setStartDate] = useState(today);
  const [plan, setPlan] = useState<MealPlanDraft | null>(null);
  const [editingIndex, setEditingIndex] = useState<number | null>(null);

  const request = useMemo(
    () => ({
      startDate,
      days,
      slots,
      // 찜한 메뉴와 이미 담아 둔 메뉴를 출발점으로 씁니다.
      seedRecipeIds: [...new Set([...state.favorites, ...state.plannedMeals.map((meal) => meal.recipeId)])],
      inventory: state.inventory,
      recipes,
    }),
    [days, recipes, slots, startDate, state.favorites, state.inventory, state.plannedMeals],
  );

  function toggleSlot(slot: MealSlot) {
    setSlots((current) => (current.includes(slot) ? current.filter((item) => item !== slot) : [...current, slot]));
  }

  function generate() {
    const next = generateMealPlan(request);
    setPlan(next);
    setEditingIndex(null);
    onGenerate(next);
  }

  function swap(index: number, recipeId: string) {
    if (!plan) return;
    const swapped = plan.drafts.map((draft, position) => (position === index ? { ...draft, recipeId } : draft));
    // 메뉴 하나만 바꿔도 재사용 재료와 추가 구매 수치를 전부 다시 계산합니다.
    setPlan(recomputePlan(swapped, request));
    setEditingIndex(null);
    onSwap(recipeId);
  }

  return (
    <section className="space-y-5" aria-labelledby="planner-heading">
      <div className="panel bg-[#e8f0e5] p-6 sm:p-8">
        <p className="eyebrow text-[#356b43]">Meal planner</p>
        <h2 id="planner-heading" className="mt-2 text-3xl font-black tracking-[-0.05em]">며칠치 식단을 한 번에 짜요.</h2>
        <p className="mt-2 max-w-2xl text-sm leading-6 text-[#506153]">
          찜하거나 이미 담은 메뉴를 먼저 배치하고, 같은 재료를 여러 끼니에서 나눠 쓰도록 후보를 골라요. 제안일 뿐이라 메뉴를 바꾸거나 전부 무시해도 됩니다.
        </p>
      </div>

      <div className="panel p-5 sm:p-6">
        <div className="grid gap-4 lg:grid-cols-[auto_auto_1fr_auto] lg:items-end">
          <label className="grid gap-1.5 text-sm font-bold text-[#445244]">
            시작 날짜
            <input className="field" type="date" value={startDate} onChange={(event) => setStartDate(event.target.value)} />
          </label>
          <label className="grid gap-1.5 text-sm font-bold text-[#445244]">
            기간
            <select className="field" value={days} onChange={(event) => setDays(Number(event.target.value))}>
              {[3, 5, 7, MAX_PLAN_DAYS].map((option) => (
                <option key={option} value={option}>{option}일</option>
              ))}
            </select>
          </label>
          <fieldset className="grid gap-1.5">
            <legend className="text-sm font-bold text-[#445244]">먹는 끼니</legend>
            <div className="flex gap-2">
              {MEAL_SLOTS.map((slot) => (
                <button
                  key={slot}
                  type="button"
                  className={`secondary-button ${slots.includes(slot) ? "border-[#356b43] bg-[#e8f0e5]" : ""}`}
                  aria-pressed={slots.includes(slot)}
                  onClick={() => toggleSlot(slot)}
                >
                  {slot}
                </button>
              ))}
            </div>
          </fieldset>
          <button type="button" className="primary-button" onClick={generate} disabled={slots.length === 0}>
            식단 제안 받기
          </button>
        </div>
        {slots.length === 0 ? <p className="mt-3 text-sm font-bold text-[#986b1e]">먹는 끼니를 하나 이상 선택해 주세요.</p> : null}
      </div>

      {plan === null ? (
        <div className="rounded-2xl border border-dashed border-[#cbd8c9] bg-[#f8fbf6] px-6 py-12 text-center">
          <p className="text-3xl" aria-hidden="true">🗓️</p>
          <h3 className="mt-4 text-lg font-extrabold text-[#172018]">아직 제안이 없어요</h3>
          <p className="mx-auto mt-2 max-w-md text-sm leading-6 text-[#657166]">기간과 끼니를 정하고 제안을 받아 보세요. 마음에 들지 않으면 그냥 두고 직접 담아도 됩니다.</p>
        </div>
      ) : plan.drafts.length === 0 ? (
        <div className="rounded-2xl border border-[#e8c986] bg-[#fff8e9] px-5 py-4 text-sm leading-6 text-[#79571b]">
          <strong>제안할 메뉴를 찾지 못했어요.</strong>
          <p className="mt-1">선택한 끼니에 맞는 레시피가 없어요. 다른 끼니를 선택하거나 레시피 화면에서 직접 담아 주세요.</p>
        </div>
      ) : (
        <div className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-3">
            <div className="panel p-4"><span className="eyebrow">제안된 끼니</span><strong className="mt-1 block text-2xl text-[#356b43]">{plan.drafts.length}</strong></div>
            <div className="panel p-4"><span className="eyebrow">추가 구매 품목</span><strong className="mt-1 block text-2xl text-[#c75c3b]">{plan.totalNewPurchases}</strong></div>
            <div className="panel p-4">
              <span className="eyebrow">여러 끼니에서 쓰는 재료</span>
              <strong className="mt-1 block text-sm font-bold text-[#356b43]">{plan.sharedIngredientNames.length ? plan.sharedIngredientNames.join(", ") : "없음"}</strong>
            </div>
          </div>

          {plan.unfilledSlots > 0 ? (
            <p className="rounded-2xl border border-[#e8c986] bg-[#fff8e9] px-5 py-3 text-sm font-bold text-[#79571b]">
              후보가 부족해 {plan.unfilledSlots}칸은 비워 뒀어요. 그 끼니는 직접 담아 주세요.
            </p>
          ) : null}

          <ol className="space-y-3">
            {plan.drafts.map((draft, index) => {
              const recipe = recipes.find((item) => item.id === draft.recipeId);
              if (!recipe) return null;
              const alternatives = candidatesForSlot(draft.mealSlot, recipes).filter((item) => item.id !== draft.recipeId);
              return (
                <li key={`${draft.date}-${draft.mealSlot}`} className="panel p-4 sm:p-5">
                  <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
                    <div>
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="tag">{draft.mealSlot}</span>
                        <span className="text-xs font-bold text-[#657166]">{formatDate(draft.date)}</span>
                        {draft.newPurchaseCount === 0 ? <span className="tag bg-[#e8f0e5] text-[#356b43]">추가 구매 없음</span> : null}
                      </div>
                      <h3 className="mt-2 text-xl font-black">{recipe.title}</h3>
                      <p className="mt-1 text-sm text-[#657166]">{draft.reason}</p>
                    </div>
                    <button
                      type="button"
                      className="secondary-button shrink-0"
                      aria-expanded={editingIndex === index}
                      onClick={() => setEditingIndex(editingIndex === index ? null : index)}
                    >
                      {editingIndex === index ? "교체 닫기" : "메뉴 교체"}
                    </button>
                  </div>
                  {editingIndex === index ? (
                    <div className="mt-4 flex flex-wrap gap-2 border-t border-[#edf1eb] pt-4">
                      {alternatives.length === 0 ? (
                        <p className="text-sm text-[#657166]">이 끼니에 바꿀 수 있는 다른 메뉴가 없어요.</p>
                      ) : (
                        alternatives.map((alternative) => (
                          <button key={alternative.id} type="button" className="secondary-button" onClick={() => swap(index, alternative.id)}>
                            {alternative.title}
                          </button>
                        ))
                      )}
                    </div>
                  ) : null}
                </li>
              );
            })}
          </ol>

          <div className="flex flex-wrap items-center justify-between gap-3">
            <p className="text-sm text-[#657166]">확정하면 내 식사에 추가돼요. 이미 담긴 같은 날짜·끼니 메뉴는 건너뜁니다.</p>
            <div className="flex gap-2">
              <button type="button" className="quiet-button" onClick={() => setPlan(null)}>제안 버리기</button>
              <button type="button" className="primary-button" onClick={() => onApply(plan)}>이 식단으로 확정</button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}
