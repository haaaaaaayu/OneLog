export const ANALYTICS_EVENTS = {
  RECIPE_VIEWED: "recipe_viewed",
  RECIPE_FAVORITED: "recipe_favorited",
  MEAL_PLAN_CREATED: "meal_plan_created",
  SHOPPING_STARTED: "shopping_started",
  INVENTORY_CONFIRMED: "inventory_confirmed",
  SHOPPING_LIST_CREATED: "shopping_list_created",
  SHOPPING_COMPLETED: "shopping_completed",
  COOKING_COMPLETED: "cooking_completed",
  LEFTOVER_RECOMMENDATION_VIEWED: "leftover_recommendation_viewed",
  LEFTOVER_RECIPE_SELECTED: "leftover_recipe_selected",
  // F14 장보기 실행
  SHOPPING_ITEM_CHECKED: "shopping_item_checked",
  SHOPPING_LIST_COPIED: "shopping_list_copied",
  SHOPPING_LIST_SHARED: "shopping_list_shared",
  // F13 다일 식단
  MEAL_PLAN_GENERATED: "meal_plan_generated",
  MEAL_PLAN_APPLIED: "meal_plan_applied",
  MEAL_PLAN_SWAPPED: "meal_plan_swapped",
  // F10 기록
  WASTE_LOGGED: "waste_logged",
  PRICE_CONFIRMED: "price_confirmed",
  RECORD_VIEWED: "record_viewed",
  // F16 알림
  ALERT_VIEWED: "alert_viewed",
  ALERT_DISMISSED: "alert_dismissed",
} as const;

export type AnalyticsEventName = (typeof ANALYTICS_EVENTS)[keyof typeof ANALYTICS_EVENTS];

export function trackEvent(name: AnalyticsEventName, properties: Record<string, string | number | boolean> = {}): void {
  if (typeof window === "undefined") return;
  // 민감한 식습관 원문은 수집하지 않고, 퍼널 확인에 필요한 최소 속성만 남깁니다.
  window.dispatchEvent(new CustomEvent("onelog:analytics", { detail: { name, properties } }));
  if (process.env.NODE_ENV !== "production") console.info(`[analytics] ${name}`, properties);
}
