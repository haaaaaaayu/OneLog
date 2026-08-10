import { getIngredient } from "./ingredients";
import type {
  AppState,
  IngredientPrice,
  RecordSummary,
  SavingsBreakdown,
  Unit,
  WasteLog,
} from "./types";

/**
 * F10 식사·절약 기록.
 *
 * 금액은 사용자가 확인한 가격이 있는 재료에만 적용합니다. 가격을 모르는 재료를
 * 평균가나 추측으로 채우지 않고 `null`로 남긴 뒤 몇 건이 빠졌는지 표시합니다
 * (제품 원칙 6·7, AGENTS 3.1 F10 마지막 항목).
 */

export type RecordRange = "week" | "all";

function withinRange(iso: string, range: RecordRange, now: Date): boolean {
  if (range === "all") return true;
  const at = new Date(iso);
  if (Number.isNaN(at.getTime())) return false;
  return now.getTime() - at.getTime() <= 7 * 86_400_000;
}

/** 단가 = 지불 금액 / 그 금액에 해당하는 포장량. 단위가 다르면 환산하지 않습니다. */
export function unitPrice(price: IngredientPrice | undefined, unit: Unit): number | null {
  if (!price || price.unit !== unit) return null;
  if (!Number.isFinite(price.price) || !Number.isFinite(price.packageAmount) || price.packageAmount <= 0) return null;
  return price.price / price.packageAmount;
}

function valueOf(quantity: number, price: IngredientPrice | undefined, unit: Unit): number | null {
  const rate = unitPrice(price, unit);
  return rate === null ? null : Math.round(quantity * rate);
}

export function summarizeRecords(
  state: Pick<AppState, "completions" | "wasteLogs" | "prices">,
  range: RecordRange = "all",
  now = new Date(),
): RecordSummary {
  const completions = state.completions.filter((completion) => withinRange(completion.completedAt, range, now));
  const wasteLogs = state.wasteLogs.filter((log) => withinRange(log.loggedAt, range, now));

  const used = new Map<string, { unit: Unit; quantity: number }>();
  const wasted = new Map<string, { unit: Unit; quantity: number }>();

  for (const completion of completions) {
    for (const consumption of completion.consumptions) {
      const key = `${consumption.ingredientId}:${consumption.unit}`;
      const entry = used.get(key) ?? { unit: consumption.unit, quantity: 0 };
      entry.quantity += consumption.actualQuantity;
      used.set(key, entry);
    }
  }

  for (const log of wasteLogs) {
    const key = `${log.ingredientId}:${log.unit}`;
    const entry = wasted.get(key) ?? { unit: log.unit, quantity: 0 };
    entry.quantity += log.quantity;
    wasted.set(key, entry);
  }

  const breakdowns: SavingsBreakdown[] = [];
  let confirmedUsedValue = 0;
  let confirmedWastedValue = 0;
  let unpricedIngredientCount = 0;

  for (const key of new Set([...used.keys(), ...wasted.keys()])) {
    const [ingredientId, rawUnit] = key.split(":");
    const unit = rawUnit as Unit;
    const usedQuantity = used.get(key)?.quantity ?? 0;
    const wastedQuantity = wasted.get(key)?.quantity ?? 0;
    const price = state.prices[ingredientId];
    const usedValue = valueOf(usedQuantity, price, unit);
    const wastedValue = valueOf(wastedQuantity, price, unit);

    if (usedValue === null && wastedValue === null) unpricedIngredientCount += 1;
    if (usedValue !== null) confirmedUsedValue += usedValue;
    if (wastedValue !== null) confirmedWastedValue += wastedValue;

    breakdowns.push({
      ingredientId,
      ingredientName: getIngredient(ingredientId).name,
      unit,
      usedQuantity,
      wastedQuantity,
      usedValue,
      wastedValue,
    });
  }

  breakdowns.sort((left, right) => {
    if (right.wastedQuantity !== left.wastedQuantity) return right.wastedQuantity - left.wastedQuantity;
    return right.usedQuantity - left.usedQuantity;
  });

  return {
    cookedMealCount: completions.length,
    usedIngredientCount: used.size,
    // 사용 기록이 있고 폐기 기록이 없는 재료 = 남김없이 쓴 재료
    fullyUsedIngredientCount: breakdowns.filter((item) => item.usedQuantity > 0 && item.wastedQuantity === 0).length,
    wasteLogCount: wasteLogs.length,
    breakdowns,
    confirmedUsedValue,
    confirmedWastedValue,
    unpricedIngredientCount,
  };
}

export function createWasteLog(
  ingredientId: string,
  quantity: number,
  unit: Unit,
  reason: WasteLog["reason"],
  now = new Date().toISOString(),
): WasteLog {
  return {
    id: `${ingredientId}-${unit}-${now}`,
    ingredientId,
    quantity: Number.isFinite(quantity) && quantity > 0 ? quantity : 0,
    unit,
    reason,
    loggedAt: now,
  };
}
