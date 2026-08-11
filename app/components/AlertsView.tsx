"use client";

import { useMemo } from "react";
import { deriveAlerts } from "../../lib/notifications";
import { rankDepletionRisks } from "../../lib/risk";
import type { AppState, DepletionRisk, NotificationSettings, Recipe } from "../../lib/types";
import { formatQuantity } from "../../lib/types";

/**
 * F15 소진 위험 + F16 인앱 알림 화면.
 * 브라우저 푸시는 서비스 워커와 발송 서버가 필요해 포함하지 않았습니다.
 */

const STATE_LABELS: Record<DepletionRisk["state"], { label: string; className: string }> = {
  urgent: { label: "먼저 사용", className: "bg-[#fbe6df] text-[#c75c3b]" },
  soon: { label: "곧 사용", className: "bg-[#fff2df] text-[#986b1e]" },
  stable: { label: "여유", className: "bg-[#e8f0e5] text-[#356b43]" },
  unknown: { label: "확인 필요", className: "bg-[#fff2df] text-[#986b1e]" },
};

export default function AlertsView({
  state,
  recipes,
  onDismiss,
  onUpdateSettings,
  onUseIngredient,
  onOpenMeal,
}: {
  state: AppState;
  recipes: Recipe[];
  onDismiss: (alertId: string) => void;
  onUpdateSettings: (updates: Partial<NotificationSettings>) => void;
  onUseIngredient: (ingredientId: string) => void;
  onOpenMeal: (plannedMealId: string) => void;
}) {
  const alerts = useMemo(() => deriveAlerts(state, recipes), [recipes, state]);
  const risks = useMemo(
    () => rankDepletionRisks(state.inventory, state.plannedMeals, recipes),
    [recipes, state.inventory, state.plannedMeals],
  );
  const settings = state.notificationSettings;

  return (
    <section className="space-y-5" aria-labelledby="alerts-heading">
      <div className="panel bg-[#fff8e9] p-6 sm:p-8">
        <p className="eyebrow text-[#986b1e]">Alerts</p>
        <h2 id="alerts-heading" className="mt-2 text-3xl font-black tracking-[-0.05em]">먼저 써야 할 것만 알려줘요.</h2>
        <p className="mt-2 max-w-2xl text-sm leading-6 text-[#79571b]">
          보관 특성과 기록한 지난 시간, 예정된 식단을 근거로 계산해요. 근거가 부족하면 점수를 매기지 않고 확인이 필요하다고만 표시합니다.
        </p>
      </div>

      <div className="panel p-5 sm:p-6">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <h3 className="text-xl font-black">알림 설정</h3>
          <div className="flex flex-wrap items-center gap-4">
            <label className="flex items-center gap-2 text-sm font-bold text-[#445244]">
              <input type="checkbox" checked={settings.riskAlerts} onChange={(event) => onUpdateSettings({ riskAlerts: event.target.checked })} />
              소진 위험 알림
            </label>
            <label className="flex items-center gap-2 text-sm font-bold text-[#445244]">
              <input type="checkbox" checked={settings.mealReminders} onChange={(event) => onUpdateSettings({ mealReminders: event.target.checked })} />
              식단 알림
            </label>
            <label className="flex items-center gap-2 text-sm font-bold text-[#445244]">
              며칠 전부터
              <select className="field" value={settings.leadDays} onChange={(event) => onUpdateSettings({ leadDays: Number(event.target.value) })}>
                {[0, 1, 2, 3, 7].map((option) => <option key={option} value={option}>{option === 0 ? "당일" : `${option}일 전`}</option>)}
              </select>
            </label>
          </div>
        </div>
      </div>

      <div className="panel p-5 sm:p-6">
        <div className="flex items-center justify-between gap-3">
          <h3 className="text-xl font-black">지금 알림</h3>
          <span className="tag">{alerts.length}건</span>
        </div>
        {alerts.length === 0 ? (
          <p className="mt-3 text-sm text-[#657166]">지금 알릴 내용이 없어요. 알림을 껐거나, 먼저 써야 할 재료와 임박한 식사가 없는 상태예요.</p>
        ) : (
          <ul className="mt-4 space-y-3">
            {alerts.map((alert) => (
              <li key={alert.id} className={`rounded-2xl border p-4 ${alert.severity === "high" ? "border-[#e8b8a6] bg-[#fdf2ee]" : "border-[#dfe6dc] bg-[#f8fbf6]"}`}>
                <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                  <div>
                    <div className="flex items-center gap-2">
                      <span aria-hidden="true">{alert.kind === "risk" ? "🥬" : "🍽️"}</span>
                      <strong className="text-sm">{alert.title}</strong>
                    </div>
                    <p className="mt-1 text-xs leading-5 text-[#657166]">{alert.body}</p>
                  </div>
                  <div className="flex shrink-0 gap-2">
                    {alert.ingredientId ? (
                      <button type="button" className="secondary-button" onClick={() => onUseIngredient(alert.ingredientId!)}>활용 메뉴 보기</button>
                    ) : null}
                    {alert.plannedMealId ? (
                      <button type="button" className="secondary-button" onClick={() => onOpenMeal(alert.plannedMealId!)}>요리하기</button>
                    ) : null}
                    <button type="button" className="quiet-button" onClick={() => onDismiss(alert.id)}>그만 보기</button>
                  </div>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="panel p-5 sm:p-6">
        <h3 className="text-xl font-black">재료별 소진 위험</h3>
        {risks.length === 0 ? (
          <p className="mt-3 text-sm text-[#657166]">냉장고에 기록한 재료가 없어요.</p>
        ) : (
          <ul className="mt-4 grid gap-3 sm:grid-cols-2">
            {risks.map((risk) => {
              const badge = STATE_LABELS[risk.state];
              return (
                <li key={`${risk.ingredientId}-${risk.unit}`} className="rounded-2xl border border-[#dfe6dc] p-4">
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <span className={`tag ${badge.className}`}>{badge.label}</span>
                      <h4 className="mt-2 text-lg font-black">{risk.ingredientName}</h4>
                    </div>
                    <strong className={`text-sm font-black ${risk.state === "urgent" ? "text-[#c75c3b]" : "text-[#657166]"}`}>
                      {risk.score === null ? "확인 필요" : `${risk.score}점`}
                    </strong>
                  </div>
                  <ul className="mt-3 space-y-1 text-xs leading-5 text-[#657166]">
                    {risk.reasons.map((reason) => <li key={reason}>· {reason}</li>)}
                  </ul>
                  {risk.plannedUsage > 0 ? (
                    <p className="mt-2 text-xs font-bold text-[#356b43]">예정 사용량 {formatQuantity(risk.plannedUsage, risk.unit)}</p>
                  ) : (
                    <button type="button" className="quiet-button mt-3 text-xs" onClick={() => onUseIngredient(risk.ingredientId)}>이 재료로 만들 메뉴 보기</button>
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </div>
    </section>
  );
}
