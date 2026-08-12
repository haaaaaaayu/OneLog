import Combine
import Foundation

private struct PersistedEnvelope: Codable {
    let version: Int
    let state: AppState
}

@MainActor
final class AppStore: ObservableObject {
    private static let storageKey = "onelog.native.state.v1"

    @Published private(set) var state: AppState
    @Published var notice: String?
    /// 계정 연동 실패 사유. 온보딩과 마이페이지에서 재시도 안내로 보여준다.
    @Published var accountError: String?

    init() {
        // UI 테스트가 온보딩부터 다시 확인할 수 있도록 저장 상태를 비운다.
        if ProcessInfo.processInfo.arguments.contains("-uiTestResetState") {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        }
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let envelope = try? JSONDecoder().decode(PersistedEnvelope.self, from: data),
           envelope.version == 1 {
            state = Self.sanitize(envelope.state)
        } else {
            state = AppState()
        }
    }

    var plannedMeals: [PlannedMeal] {
        state.plannedMeals.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.mealSlot != $1.mealSlot { return MealSlot.allCases.firstIndex(of: $0.mealSlot)! < MealSlot.allCases.firstIndex(of: $1.mealSlot)! }
            return $0.createdAt < $1.createdAt
        }
    }

    var currentShoppingItems: [ShoppingPlanItem] {
        calculateShoppingPlan(requirements: aggregateRequirements(for: state.plannedMeals), inventory: state.inventory, packageOverrides: state.packageOverrides)
    }

    func estimate(for drafts: [PlannedMealDraft], targetBudget: Int) -> BudgetEstimate {
        budgetEstimate(drafts: drafts, targetBudget: targetBudget, inventory: state.inventory, prices: state.prices, packageOverrides: state.packageOverrides)
    }

    func save() {
        let envelope = PersistedEnvelope(version: 1, state: state)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    func clearNotice() {
        notice = nil
    }

    func completeOnboarding() {
        guard !state.hasCompletedOnboarding else { return }
        update { $0.hasCompletedOnboarding = true }
    }

    // MARK: - 계정 (F23)

    /// Info.plist의 `GIDClientID`가 있어야 Google 로그인을 시도한다.
    /// ponytail: 클라이언트 ID와 GoogleSignIn SDK가 정해지면 이 함수 본문의 TODO 지점만 교체한다.
    var isGoogleSignInConfigured: Bool {
        let value = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
        return (value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    func signInWithGoogle() {
        guard isGoogleSignInConfigured else {
            accountError = "아직 Google 로그인을 연결할 수 없어요. 지금은 이 기기에만 저장하고 시작한 뒤, 나중에 마이페이지에서 계정을 연결할 수 있어요."
            return
        }
        // TODO: GoogleSignIn SDK 인증 결과를 linkAccount(...)로 전달한다.
        accountError = "Google 로그인 연결을 확인하지 못했어요. 잠시 후 다시 시도해 주세요."
    }

    func linkAccount(_ account: UserAccount) {
        update { $0.account = account }
        accountError = nil
        notice = account.provider == .google ? "Google 계정을 연결했어요." : "이 기기에만 저장하도록 시작했어요."
    }

    func useDeviceOnlyAccount() {
        linkAccount(UserAccount(provider: .deviceOnly, userID: UUID().uuidString, email: nil, displayName: nil, linkedAt: ISO8601DateFormatter().string(from: Date())))
    }

    /// 연결만 해제한다. 기기에 저장한 식단·재고 데이터는 그대로 둔다.
    func unlinkAccount() {
        guard state.account != nil else { return }
        update { $0.account = nil }
        accountError = nil
        notice = "계정 연결을 해제했어요. 이 기기에 저장한 식단과 재고는 그대로예요."
    }

    /// 탈퇴. 이 기기에 저장한 모든 데이터를 지우고 온보딩부터 다시 시작한다.
    func deleteAllData() {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        state = AppState()
        accountError = nil
        notice = "계정 연결과 저장한 데이터를 모두 지웠어요."
    }

    func setProfile(nickname: String, age: Int?) {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeAge = age.flatMap { (14...120).contains($0) ? $0 : nil }
        update { state in
            state.profile.nickname = String(trimmed.prefix(20))
            state.profile.age = safeAge
        }
        notice = "프로필을 저장했어요."
    }

    func toggleFavorite(_ recipeID: String) {
        guard recipe(for: recipeID) != nil else { return }
        update { state in
            if let index = state.favorites.firstIndex(of: recipeID) {
                state.favorites.remove(at: index)
                self.notice = "찜을 해제했어요."
            } else {
                state.favorites.append(recipeID)
                self.notice = "찜한 메뉴에 저장했어요."
            }
        }
    }

    @discardableResult
    func addPlannedMeal(recipeID: String, date: String, slot: MealSlot) -> Bool {
        guard recipe(for: recipeID) != nil, date.count == 10 else { return false }
        let duplicate = state.plannedMeals.contains { $0.recipeID == recipeID && $0.date == date && $0.mealSlot == slot && $0.status == .planned }
        guard !duplicate else {
            notice = "같은 날짜와 끼니에 이미 담긴 메뉴예요."
            return false
        }
        update { state in
            state.plannedMeals.append(PlannedMeal(id: UUID().uuidString, recipeID: recipeID, date: date, mealSlot: slot, status: .planned, createdAt: ISO8601DateFormatter().string(from: Date())))
        }
        let title = recipe(for: recipeID)?.title ?? "메뉴"
        notice = ["\(title)를 내 식사에 담았어요.", preferenceWarning(forRecipeID: recipeID)].compactMap { $0 }.joined(separator: " ")
        return true
    }

    /// 직접 고른 메뉴는 삭제하지 않고 불호·조리도구 조건만 알려준다(AGENTS 8절).
    func preferenceWarning(forRecipeID recipeID: String) -> String? {
        guard let recipe = recipe(for: recipeID) else { return nil }
        var reasons: [String] = []
        if state.preferences.dislikedRecipeIDs.contains(recipeID) {
            reasons.append("불호 메뉴로 설정한 메뉴")
        }
        let disliked = Set(recipe.ingredients.map(\.ingredientID)).intersection(state.preferences.dislikedIngredientIDs)
        if !disliked.isEmpty {
            reasons.append("불호 재료 \(disliked.compactMap { ingredient(for: $0)?.name }.sorted().joined(separator: ", ")) 포함")
        }
        let missingTools = recipe.requiredTools.subtracting(state.preferences.availableTools)
        if !missingTools.isEmpty {
            reasons.append("조리도구 \(missingTools.map(\.rawValue).sorted().joined(separator: ", ")) 필요")
        }
        guard !reasons.isEmpty else { return nil }
        return "\(reasons.joined(separator: " · "))예요. 자동 추천에서는 빼지만 직접 고른 메뉴는 그대로 둘게요."
    }

    @discardableResult
    func applyPlan(_ option: MealPlanOption) -> Int {
        var added = 0
        update { state in
            for draft in option.drafts {
                let duplicate = state.plannedMeals.contains { $0.recipeID == draft.recipeID && $0.date == draft.date && $0.mealSlot == draft.mealSlot && $0.status == .planned }
                guard !duplicate else { continue }
                state.plannedMeals.append(PlannedMeal(id: UUID().uuidString, recipeID: draft.recipeID, date: draft.date, mealSlot: draft.mealSlot, status: .planned, createdAt: ISO8601DateFormatter().string(from: Date())))
                added += 1
            }
        }
        notice = added == 0 ? "이미 같은 계획이 있어 새로 추가된 식사가 없어요." : "\(added)개 식사를 내 식사에 담았어요."
        return added
    }

    func replaceMeal(_ mealID: String, recipeID: String) {
        guard let recipe = recipe(for: recipeID), let existing = state.plannedMeals.first(where: { $0.id == mealID }), recipe.mealSlots.contains(existing.mealSlot) else { return }
        update { state in
            guard let index = state.plannedMeals.firstIndex(where: { $0.id == mealID }) else { return }
            state.plannedMeals[index].recipeID = recipeID
        }
        notice = ["메뉴를 \(recipe.title)(으)로 바꿨어요. 필요한 재료와 예산도 다시 계산돼요.", preferenceWarning(forRecipeID: recipeID)].compactMap { $0 }.joined(separator: " ")
    }

    func moveMeal(_ mealID: String, date: String, slot: MealSlot) {
        guard let existing = state.plannedMeals.first(where: { $0.id == mealID }), existing.status == .planned else { return }
        let conflict = state.plannedMeals.contains { $0.id != mealID && $0.date == date && $0.mealSlot == slot && $0.status == .planned }
        guard !conflict else {
            notice = "그 날짜와 끼니에 이미 다른 계획이 있어요."
            return
        }
        update { state in
            guard let index = state.plannedMeals.firstIndex(where: { $0.id == mealID }) else { return }
            state.plannedMeals[index].date = date
            state.plannedMeals[index].mealSlot = slot
        }
        notice = "식사 일정을 옮겼어요. 필요한 재료와 보관 주의를 다시 확인해 주세요."
    }

    func removeMeal(_ mealID: String) {
        guard state.plannedMeals.contains(where: { $0.id == mealID }) else { return }
        update { state in
            state.plannedMeals.removeAll { $0.id == mealID }
            state.completions.removeAll { $0.plannedMealID == mealID }
        }
        notice = "식사 계획을 삭제했어요."
    }

    func setInventory(ingredientID: String, quantity: Double?, unit: Unit, status: QuantityStatus) {
        guard ingredient(for: ingredientID) != nil else { return }
        let safe = status == .unknown ? nil : max(quantity ?? 0, 0)
        update { state in
            let item = InventoryItem(ingredientID: ingredientID, quantity: safe, unit: unit, quantityStatus: status, updatedAt: ISO8601DateFormatter().string(from: Date()))
            if let index = state.inventory.firstIndex(where: { $0.ingredientID == ingredientID && $0.unit == unit }) {
                state.inventory[index] = item
            } else {
                state.inventory.append(item)
            }
        }
    }

    func removeInventory(_ item: InventoryItem) {
        update { state in
            state.inventory.removeAll { $0.id == item.id }
        }
        notice = "\(ingredient(for: item.ingredientID)?.name ?? "재료")를 냉장고에서 지웠어요."
    }

    func setPackageOverride(ingredientID: String, package: PackageSize) {
        guard package.amount.isFinite, package.amount > 0, ingredient(for: ingredientID) != nil else { return }
        update { $0.packageOverrides[ingredientID] = package }
    }

    func setPrice(ingredientID: String, price: Int, packageAmount: Double, unit: Unit) {
        guard price >= 0, packageAmount.isFinite, packageAmount > 0, ingredient(for: ingredientID) != nil else { return }
        update { state in
            state.prices[ingredientID] = IngredientPrice(price: price, packageAmount: packageAmount, unit: unit, confirmedAt: ISO8601DateFormatter().string(from: Date()), source: "user")
        }
    }

    func setPreferences(dislikedIngredientIDs: Set<String>, dislikedRecipeIDs: Set<String> = [], availableTools: Set<CookingTool>) {
        update { state in
            state.preferences.dislikedIngredientIDs = dislikedIngredientIDs
            state.preferences.dislikedRecipeIDs = dislikedRecipeIDs
            state.preferences.availableTools = availableTools
        }
        notice = "추천 설정을 저장했어요. 이미 담은 식사는 지우지 않았어요."
    }

    func setPurchaseChecked(itemID: String, checked: Bool) {
        update { state in
            if checked {
                state.purchaseChecks[itemID] = true
            } else {
                state.purchaseChecks.removeValue(forKey: itemID)
            }
            appendShoppingEvent(.itemChecked, itemIDs: [itemID], to: &state)
        }
    }

    func setPurchaseQuantity(itemID: String, value: Double?) {
        guard let value, value.isFinite, value >= 0 else {
            update { state in
                state.purchaseQuantityOverrides.removeValue(forKey: itemID)
                appendShoppingEvent(.quantityAdjusted, itemIDs: [itemID], to: &state)
            }
            return
        }
        update { state in
            state.purchaseQuantityOverrides[itemID] = floor(value)
            appendShoppingEvent(.quantityAdjusted, itemIDs: [itemID], to: &state)
        }
    }

    func recordShoppingEvent(_ action: ShoppingEventAction, itemIDs: [String]) {
        guard !itemIDs.isEmpty else { return }
        update { state in
            appendShoppingEvent(action, itemIDs: itemIDs, to: &state)
        }
    }

    @discardableResult
    func confirmPurchase(items: [ShoppingPlanItem]) -> Bool {
        guard !items.isEmpty else {
            notice = "추가로 살 품목이 없어요."
            return false
        }
        let signature = shoppingSignature(items, quantityOverrides: state.purchaseQuantityOverrides)
        guard !state.appliedPurchaseSignatures.contains(signature) else {
            notice = "이 장보기 목록은 이미 재고에 반영했어요."
            return false
        }
        update { state in
            state.inventory = applyPurchases(inventory: state.inventory, shoppingItems: items, quantityOverrides: state.purchaseQuantityOverrides)
            state.appliedPurchaseSignatures.append(signature)
            appendShoppingEvent(.purchaseConfirmed, itemIDs: items.map(\.id), to: &state)
        }
        notice = "구매한 양을 냉장고 재고에 반영했어요. 같은 목록을 다시 눌러도 중복되지 않아요."
        return true
    }

    @discardableResult
    func completeMeal(_ mealID: String, consumptions: [CookingConsumption]) -> Bool {
        guard let meal = state.plannedMeals.first(where: { $0.id == mealID }), meal.status == .planned else {
            notice = "이미 완료한 식사예요. 재고를 다시 차감하지 않았어요."
            return false
        }
        guard !state.completions.contains(where: { $0.plannedMealID == mealID }) else {
            notice = "이미 완료한 식사예요. 재고를 다시 차감하지 않았어요."
            return false
        }
        let completion = CookingCompletion(plannedMealID: mealID, recipeID: meal.recipeID, completedAt: ISO8601DateFormatter().string(from: Date()), consumptions: consumptions)
        update { state in
            state.inventory = applyConsumption(inventory: state.inventory, consumptions: consumptions)
            state.completions.append(completion)
            if let index = state.plannedMeals.firstIndex(where: { $0.id == mealID }) {
                state.plannedMeals[index].status = .cooked
            }
        }
        notice = "요리 완료를 기록하고 실제 사용량을 냉장고에 반영했어요."
        return true
    }

    private func update(_ transform: (inout AppState) -> Void) {
        var next = state
        transform(&next)
        state = next
        save()
    }

    private func appendShoppingEvent(_ action: ShoppingEventAction, itemIDs: [String], to state: inout AppState) {
        state.shoppingEvents.append(ShoppingEvent(id: UUID().uuidString, action: action, itemIDs: itemIDs, createdAt: ISO8601DateFormatter().string(from: Date())))
        if state.shoppingEvents.count > 500 {
            state.shoppingEvents.removeFirst(state.shoppingEvents.count - 500)
        }
    }

    private static func sanitize(_ input: AppState) -> AppState {
        var state = input
        let recipeIDs = Set(recipes.map(\.id))
        let ingredientIDs = Set(ingredients.map(\.id))
        state.favorites = state.favorites.filter { recipeIDs.contains($0) }
        state.plannedMeals = state.plannedMeals.filter { recipeIDs.contains($0.recipeID) && $0.date.count == 10 }
        state.inventory = state.inventory.filter { ingredientIDs.contains($0.ingredientID) && ($0.quantity == nil || ($0.quantity ?? 0) >= 0) }
        state.prices = state.prices.filter { ingredientIDs.contains($0.key) && $0.value.price >= 0 && $0.value.packageAmount > 0 }
        state.purchaseQuantityOverrides = state.purchaseQuantityOverrides.filter { $0.value.isFinite && $0.value >= 0 }
        state.shoppingEvents = Array(state.shoppingEvents.suffix(500))
        state.preferences.dislikedIngredientIDs = state.preferences.dislikedIngredientIDs.intersection(ingredientIDs)
        state.preferences.dislikedRecipeIDs = state.preferences.dislikedRecipeIDs.intersection(recipeIDs)
        if state.preferences.availableTools.isEmpty { state.preferences.availableTools = Set(CookingTool.allCases) }
        state.profile.nickname = String(state.profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        state.profile.age = state.profile.age.flatMap { (14...120).contains($0) ? $0 : nil }
        return state
    }
}
