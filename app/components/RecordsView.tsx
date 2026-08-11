"use client";

import { useMemo, useState } from "react";
import { getIngredient, INGREDIENTS } from "../../lib/ingredients";
import { summarizeRecords, unitPrice, type RecordRange } from "../../lib/records";
import type { AppState, Recipe, Unit, WasteReason } from "../../lib/types";
import { formatQuantity, WASTE_REASON_LABELS } from "../../lib/types";

/** F10 식사·절약 기록 화면. 금액은 사용자가 확인한 가격이 있는 재료에만 표시합니다. */
export default function RecordsView({
  state,
  recipes,
  formatDate,
  onLogWaste,
  onSetPrice,
  onClearPrice,
}: {
  state: AppState;
  recipes: Recipe[];
  formatDate: (date: string) => string;
  onLogWaste: (ingredientId: string, quantity: number, unit: Unit, reason: WasteReason) => void;
  onSetPrice: (ingredientId: string, price: number, packageAmount: number, unit: Unit) => void;
  onClearPrice: (ingredientId: string) => void;
}) {
  const [range, setRange] = useState<RecordRange>("all");
  const [wasteId, setWasteId] = useState(INGREDIENTS[0]?.id ?? "");
  const [wasteQuantity, setWasteQuantity] = useState("1");
  const [wasteReason, setWasteReason] = useState<WasteReason>("spoiled");
  const [priceId, setPriceId] = useState(INGREDIENTS[0]?.id ?? "");
  const [priceAmount, setPriceAmount] = useState("");
  const [pricePackage, setPricePackage] = useState("");

  const summary = useMemo(() => summarizeRecords(state, range), [range, state]);
  const wasteIngredient = getIngredient(wasteId);
  const priceIngredient = getIngredient(priceId);
  const cookedMeals = useMemo(
    () =>
      [...state.completions]
        .sort((left, right) => right.completedAt.localeCompare(left.completedAt))
        .map((completion) => ({ completion, recipe: recipes.find((item) => item.id === completion.recipeId) })),
    [recipes, state.completions],
  );

  function submitWaste() {
    const quantity = Number(wasteQuantity);
    if (!Number.isFinite(quantity) || quantity <= 0) return;
    onLogWaste(wasteId, quantity, wasteIngredient.defaultUnit, wasteReason);
    setWasteQuantity("1");
  }

  function submitPrice() {
    const price = Number(priceAmount);
    const packageAmount = Number(pricePackage);
    if (!Number.isFinite(price) || price < 0 || !Number.isFinite(packageAmount) || packageAmount <= 0) return;
    onSetPrice(priceId, price, packageAmount, priceIngredient.representativeSaleUnit.unit);
    setPriceAmount("");
    setPricePackage("");
  }

  return (
    <section className="space-y-5" aria-labelledby="records-heading">
      <div className="panel p-6 sm:p-8">
        <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p className="eyebrow">Records</p>
            <h2 id="records-heading" className="mt-2 text-3xl font-black tracking-[-0.05em]">얼마나 끝까지 먹었는지 봐요.</h2>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-[#657166]">
              요리 기록과 직접 남긴 폐기 기록으로 계산해요. 가격을 입력한 재료만 금액이 나오고, 모르는 가격은 추측하지 않습니다.
            </p>
          </div>
          <div className="flex gap-2" role="group" aria-label="기간 선택">
            {(["week", "all"] as RecordRange[]).map((option) => (
              <button
                key={option}
                type="button"
                className={`secondary-button ${range === option ? "border-[#356b43] bg-[#e8f0e5]" : ""}`}
                aria-pressed={range === option}
                onClick={() => setRange(option)}
              >
                {option === "week" ? "최근 7일" : "누적"}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <div className="panel p-4"><span className="eyebrow">직접 요리한 횟수</span><strong className="mt-1 block text-2xl text-[#356b43]">{summary.cookedMealCount}</strong></div>
        <div className="panel p-4"><span className="eyebrow">사용한 재료</span><strong className="mt-1 block text-2xl text-[#356b43]">{summary.usedIngredientCount}</strong></div>
        <div className="panel p-4"><span className="eyebrow">남김없이 쓴 재료</span><strong className="mt-1 block text-2xl text-[#356b43]">{summary.fullyUsedIngredientCount}</strong></div>
        <div className="panel p-4"><span className="eyebrow">폐기 기록</span><strong className="mt-1 block text-2xl text-[#c75c3b]">{summary.wasteLogCount}</strong></div>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <div className="panel p-5">
          <p className="eyebrow">먹은 재료 금액</p>
          <strong className="mt-1 block text-3xl font-black text-[#356b43]">{summary.confirmedUsedValue.toLocaleString("ko-KR")}원</strong>
          <p className="mt-2 text-xs leading-5 text-[#657166]">
            가격을 확인한 재료의 실제 사용량 × 단가입니다. {summary.unpricedIngredientCount > 0 ? `가격을 모르는 재료 ${summary.unpricedIngredientCount}가지는 금액에서 빠졌어요.` : "모든 재료의 가격이 입력돼 있어요."}
          </p>
        </div>
        <div className="panel p-5">
          <p className="eyebrow">버린 재료 금액</p>
          <strong className="mt-1 block text-3xl font-black text-[#c75c3b]">{summary.confirmedWastedValue.toLocaleString("ko-KR")}원</strong>
          <p className="mt-2 text-xs leading-5 text-[#657166]">직접 기록한 폐기량 × 단가입니다. 기록하지 않은 폐기는 포함되지 않아요.</p>
        </div>
      </div>

      <div className="panel p-5 sm:p-6">
        <h3 className="text-xl font-black">재료별 사용과 폐기</h3>
        {summary.breakdowns.length === 0 ? (
          <p className="mt-3 text-sm text-[#657166]">아직 요리 완료나 폐기 기록이 없어요. 요리를 완료하면 이곳에 쌓여요.</p>
        ) : (
          <div className="mt-4 overflow-hidden rounded-2xl border border-[#dfe6dc]">
            <div className="hidden grid-cols-[1.2fr_0.8fr_0.8fr_0.9fr] gap-3 bg-[#f8fbf6] px-4 py-3 text-xs font-black text-[#657166] sm:grid">
              <span>재료</span><span>사용량</span><span>폐기량</span><span>금액</span>
            </div>
            <div className="divide-y divide-[#edf1eb]">
              {summary.breakdowns.map((item) => (
                <div key={`${item.ingredientId}-${item.unit}`} className="grid gap-2 px-4 py-4 sm:grid-cols-[1.2fr_0.8fr_0.8fr_0.9fr] sm:items-center sm:gap-3">
                  <strong className="text-sm">{item.ingredientName}</strong>
                  <span className="text-sm"><span className="text-xs text-[#657166] sm:hidden">사용 </span>{formatQuantity(item.usedQuantity, item.unit)}</span>
                  <span className={`text-sm ${item.wastedQuantity > 0 ? "font-bold text-[#c75c3b]" : "text-[#657166]"}`}>
                    <span className="text-xs text-[#657166] sm:hidden">폐기 </span>{formatQuantity(item.wastedQuantity, item.unit)}
                  </span>
                  <span className="text-sm">
                    {item.usedValue === null && item.wastedValue === null ? (
                      <span className="font-bold text-[#986b1e]">가격 미입력</span>
                    ) : (
                      <>
                        <span className="text-[#356b43]">{(item.usedValue ?? 0).toLocaleString("ko-KR")}원 사용</span>
                        {item.wastedValue ? <span className="block text-xs text-[#c75c3b]">{item.wastedValue.toLocaleString("ko-KR")}원 폐기</span> : null}
                      </>
                    )}
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <div className="panel p-5">
          <h3 className="text-xl font-black">버린 재료 기록하기</h3>
          <p className="mt-1 text-sm text-[#657166]">기록한 양은 재고에서도 빠져요.</p>
          <div className="mt-4 grid gap-3">
            <label className="grid gap-1.5 text-sm font-bold text-[#445244]">재료
              <select className="field" value={wasteId} onChange={(event) => setWasteId(event.target.value)}>
                {INGREDIENTS.map((ingredient) => <option key={ingredient.id} value={ingredient.id}>{ingredient.name}</option>)}
              </select>
            </label>
            <div className="grid gap-3 sm:grid-cols-2">
              <label className="grid gap-1.5 text-sm font-bold text-[#445244]">수량 ({wasteIngredient.defaultUnit})
                <input className="field" type="number" min="0" step="0.1" value={wasteQuantity} onChange={(event) => setWasteQuantity(event.target.value)} />
              </label>
              <label className="grid gap-1.5 text-sm font-bold text-[#445244]">이유
                <select className="field" value={wasteReason} onChange={(event) => setWasteReason(event.target.value as WasteReason)}>
                  {Object.entries(WASTE_REASON_LABELS).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                </select>
              </label>
            </div>
            <button type="button" className="secondary-button" onClick={submitWaste}>폐기 기록 추가</button>
          </div>
        </div>

        <div className="panel p-5">
          <h3 className="text-xl font-black">재료 가격 입력</h3>
          <p className="mt-1 text-sm text-[#657166]">실제로 낸 금액만 입력하세요. 입력한 재료만 금액 계산에 들어가요.</p>
          <div className="mt-4 grid gap-3">
            <label className="grid gap-1.5 text-sm font-bold text-[#445244]">재료
              <select className="field" value={priceId} onChange={(event) => setPriceId(event.target.value)}>
                {INGREDIENTS.map((ingredient) => <option key={ingredient.id} value={ingredient.id}>{ingredient.name}</option>)}
              </select>
            </label>
            <div className="grid gap-3 sm:grid-cols-2">
              <label className="grid gap-1.5 text-sm font-bold text-[#445244]">지불 금액 (원)
                <input className="field" type="number" min="0" step="100" placeholder="4000" value={priceAmount} onChange={(event) => setPriceAmount(event.target.value)} />
              </label>
              <label className="grid gap-1.5 text-sm font-bold text-[#445244]">그 금액의 포장량 ({priceIngredient.representativeSaleUnit.unit})
                <input className="field" type="number" min="0.1" step="0.1" placeholder={String(priceIngredient.representativeSaleUnit.amount)} value={pricePackage} onChange={(event) => setPricePackage(event.target.value)} />
              </label>
            </div>
            <button type="button" className="secondary-button" onClick={submitPrice}>가격 저장</button>
          </div>
          {Object.keys(state.prices).length > 0 ? (
            <ul className="mt-4 space-y-2 border-t border-[#edf1eb] pt-4">
              {Object.entries(state.prices).map(([ingredientId, price]) => (
                <li key={ingredientId} className="flex items-center justify-between gap-3 text-sm">
                  <span>
                    <strong>{getIngredient(ingredientId).name}</strong>
                    <span className="ml-2 text-xs text-[#657166]">
                      {price.price.toLocaleString("ko-KR")}원 / {price.packageAmount}{price.unit} · 단가 {Math.round(unitPrice(price, price.unit) ?? 0).toLocaleString("ko-KR")}원
                    </span>
                  </span>
                  <button type="button" className="quiet-button" onClick={() => onClearPrice(ingredientId)}>삭제</button>
                </li>
              ))}
            </ul>
          ) : null}
        </div>
      </div>

      <div className="panel p-5 sm:p-6">
        <h3 className="text-xl font-black">지난 식단</h3>
        {cookedMeals.length === 0 ? (
          <p className="mt-3 text-sm text-[#657166]">아직 완료한 식사가 없어요.</p>
        ) : (
          <ul className="mt-4 divide-y divide-[#edf1eb]">
            {cookedMeals.map(({ completion, recipe }) => (
              <li key={completion.plannedMealId} className="flex flex-wrap items-center justify-between gap-3 py-3">
                <span>
                  <strong className="text-sm">{recipe?.title ?? "삭제된 레시피"}</strong>
                  <span className="mt-0.5 block text-xs text-[#657166]">재료 {completion.consumptions.length}가지 사용</span>
                </span>
                <span className="text-xs font-bold text-[#657166]">{formatDate(completion.completedAt.slice(0, 10))}</span>
              </li>
            ))}
          </ul>
        )}
      </div>

      {state.wasteLogs.length > 0 ? (
        <div className="panel p-5 sm:p-6">
          <h3 className="text-xl font-black">폐기 기록</h3>
          <ul className="mt-4 divide-y divide-[#edf1eb]">
            {[...state.wasteLogs].reverse().map((log) => (
              <li key={log.id} className="flex flex-wrap items-center justify-between gap-3 py-3 text-sm">
                <span>
                  <strong>{getIngredient(log.ingredientId).name}</strong>
                  <span className="ml-2 text-xs text-[#657166]">{formatQuantity(log.quantity, log.unit)} · {WASTE_REASON_LABELS[log.reason]}</span>
                </span>
                <span className="text-xs font-bold text-[#657166]">{formatDate(log.loggedAt.slice(0, 10))}</span>
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </section>
  );
}
