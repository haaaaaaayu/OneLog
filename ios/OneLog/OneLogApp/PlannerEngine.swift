import Foundation

private let epsilon = 0.000001

func ingredientKey(_ ingredientID: String, _ unit: Unit) -> String {
    "\(ingredientID):\(unit.rawValue)"
}

private func safeQuantity(_ value: Double?) -> Double {
    guard let value, value.isFinite, value >= 0 else { return 0 }
    return value
}

private func safePackageSizeIfKnown(_ candidate: PackageSize?, fallback: PackageSize?) -> PackageSize? {
    if let candidate, candidate.amount.isFinite, candidate.amount > 0 { return candidate }
    guard let fallback, fallback.amount.isFinite, fallback.amount > 0 else { return nil }
    return fallback
}

private func exactInventory(_ inventory: [InventoryItem], ingredientID: String, unit: Unit) -> InventoryItem? {
    inventory.first(where: { $0.ingredientID == ingredientID && $0.unit == unit })
}

/// 재료에 명시된 단위별 무게가 있을 때만 환산한다. 근거가 없으면 nil을 돌려 수동 확인으로 보낸다.
func convertQuantity(_ value: Double, from source: Unit, to target: Unit, using canonical: CanonicalIngredient?) -> Double? {
    if source == target { return value }
    guard let table = canonical?.unitGrams,
          let sourceGrams = table[source.rawValue], let targetGrams = table[target.rawValue],
          sourceGrams.isFinite, targetGrams.isFinite, sourceGrams > 0, targetGrams > 0 else { return nil }
    let converted = value * sourceGrams / targetGrams
    return converted.isFinite ? converted : nil
}

/// 요구 단위로 환산 가능한 보유량을 찾는다. 같은 단위가 우선이다.
private func availableQuantity(_ inventory: [InventoryItem], ingredientID: String, unit: Unit, canonical: CanonicalIngredient?) -> (quantity: Double?, isUnknown: Bool, converted: Bool)? {
    if let exact = exactInventory(inventory, ingredientID: ingredientID, unit: unit) {
        let unknown = exact.quantityStatus == .unknown || exact.quantity == nil
        return (unknown ? nil : safeQuantity(exact.quantity), unknown, false)
    }
    for item in inventory where item.ingredientID == ingredientID {
        if item.quantityStatus == .unknown || item.quantity == nil {
            return (nil, true, false)
        }
        if let converted = convertQuantity(safeQuantity(item.quantity), from: item.unit, to: unit, using: canonical) {
            return (converted, false, true)
        }
    }
    return nil
}

private func hasDifferentUnitInventory(_ inventory: [InventoryItem], ingredientID: String, unit: Unit) -> Bool {
    inventory.contains(where: { $0.ingredientID == ingredientID && $0.unit != unit })
}

private func requirements(from recipeIngredients: [(recipeID: String, ingredients: [RecipeIngredient])]) -> [IngredientRequirement] {
    var grouped: [String: IngredientRequirement] = [:]
    var unitsByIngredient: [String: Set<Unit>] = [:]

    for item in recipeIngredients {
        for component in item.ingredients {
            let key = ingredientKey(component.ingredientID, component.unit)
            unitsByIngredient[component.ingredientID, default: []].insert(component.unit)
            if var existing = grouped[key] {
                existing.quantity += safeQuantity(component.quantity)
                if !existing.recipeIDs.contains(item.recipeID) {
                    existing.recipeIDs.append(item.recipeID)
                }
                grouped[key] = existing
            } else {
                grouped[key] = IngredientRequirement(
                    key: key,
                    ingredientID: component.ingredientID,
                    ingredientName: ingredient(for: component.ingredientID)?.name ?? component.rawName,
                    quantity: safeQuantity(component.quantity),
                    unit: component.unit,
                    recipeIDs: [item.recipeID],
                    unitConflict: false
                )
            }
        }
    }

    return grouped.values
        .map { item in
            var copy = item
            copy = IngredientRequirement(
                key: copy.key,
                ingredientID: copy.ingredientID,
                ingredientName: copy.ingredientName,
                quantity: copy.quantity,
                unit: copy.unit,
                recipeIDs: copy.recipeIDs,
                unitConflict: (unitsByIngredient[copy.ingredientID]?.count ?? 0) > 1
            )
            return copy
        }
        .sorted { $0.ingredientName.localizedCompare($1.ingredientName) == .orderedAscending }
}

func aggregateRequirements(for meals: [PlannedMeal], recipes: [Recipe] = recipes) -> [IngredientRequirement] {
    let recipeMap = Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0) })
    let source = meals
        .filter { $0.status == .planned }
        .compactMap { meal -> (recipeID: String, ingredients: [RecipeIngredient])? in
            guard let recipe = recipeMap[meal.recipeID] else { return nil }
            return (recipe.id, recipe.ingredients)
        }
    return requirements(from: source)
}

func aggregateRequirements(for drafts: [PlannedMealDraft], recipes: [Recipe] = recipes) -> [IngredientRequirement] {
    let recipeMap = Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0) })
    let source = drafts.compactMap { draft -> (recipeID: String, ingredients: [RecipeIngredient])? in
        guard let recipe = recipeMap[draft.recipeID] else { return nil }
        return (recipe.id, recipe.ingredients)
    }
    return requirements(from: source)
}

func calculateShoppingPlan(
    requirements: [IngredientRequirement],
    inventory: [InventoryItem],
    packageOverrides: [String: PackageSize] = [:]
) -> [ShoppingPlanItem] {
    requirements.map { requirement in
        guard let canonical = ingredient(for: requirement.ingredientID) else {
            return ShoppingPlanItem(requirement: requirement, availableQuantity: nil, quantityStatus: .unknown, additionalNeeded: requirement.quantity, packageSize: PackageSize(amount: 1, unit: requirement.unit, label: "확인 필요"), purchaseQuantity: 0, purchaseTotal: 0, expectedRemaining: nil, precision: .manual, note: "재료 정보를 확인해 주세요.")
        }

        let stock = availableQuantity(inventory, ingredientID: requirement.ingredientID, unit: requirement.unit, canonical: canonical)
        let isUnknown = stock?.isUnknown ?? false
        let available = stock?.quantity
        let calculationAvailable = available ?? 0
        // 판매 단위가 확인되지 않은 재료는 임의로 만들지 않고 사용자 확인 경로로 보낸다.
        let declaredPackage = safePackageSizeIfKnown(packageOverrides[requirement.ingredientID], fallback: canonical.representativeSaleUnit)
        // 판매 단위가 필요한 단위와 달라도 재료에 확인된 환산값이 있으면 환산해서 계산한다.
        let knownPackage: PackageSize? = declaredPackage.flatMap { package in
            guard package.unit != requirement.unit else { return package }
            guard let amount = convertQuantity(package.amount, from: package.unit, to: requirement.unit, using: canonical), amount > 0 else { return nil }
            return PackageSize(amount: amount, unit: requirement.unit, label: package.label)
        }
        let packageSize = knownPackage ?? declaredPackage ?? PackageSize(amount: 1, unit: requirement.unit, label: "판매 단위 확인 필요")
        let unitMismatch = stock?.converted == false && hasDifferentUnitInventory(inventory, ingredientID: requirement.ingredientID, unit: requirement.unit)
        let manual = requirement.unitConflict || knownPackage == nil
        let additional = max(requirement.quantity - calculationAvailable, 0)

        if manual {
            let reason: String
            if requirement.unitConflict {
                reason = "레시피마다 단위가 달라 합산하지 않았어요."
            } else if declaredPackage == nil {
                reason = "마트 판매 단위가 아직 확인되지 않았어요."
            } else {
                reason = "대표 판매 단위와 필요한 단위가 달라 환산하지 않았어요."
            }
            let followUp = unitMismatch ? "보유 재료 단위도 확인이 필요해요." : "구매 전 단위를 확인해 주세요."
            return ShoppingPlanItem(requirement: requirement, availableQuantity: available, quantityStatus: isUnknown ? .unknown : .exact, additionalNeeded: additional, packageSize: packageSize, purchaseQuantity: 0, purchaseTotal: 0, expectedRemaining: nil, precision: .manual, note: "\(reason) \(followUp)")
        }

        let purchaseQuantity = additional > epsilon ? Int(ceil(additional / packageSize.amount)) : 0
        let purchaseTotal = Double(purchaseQuantity) * packageSize.amount
        let expectedRemaining = max(calculationAvailable + purchaseTotal - requirement.quantity, 0)
        let note: String?
        if isUnknown {
            note = "보유량이 수량 미상이라 구매량 계산에서 제외했어요. 실제 수량을 확인하면 더 정확해져요."
        } else if unitMismatch {
            note = "같은 재료의 다른 단위 보유량은 자동 변환하지 않았어요."
        } else {
            note = nil
        }

        return ShoppingPlanItem(requirement: requirement, availableQuantity: available, quantityStatus: isUnknown ? .unknown : .exact, additionalNeeded: additional, packageSize: packageSize, purchaseQuantity: purchaseQuantity, purchaseTotal: purchaseTotal, expectedRemaining: expectedRemaining, precision: isUnknown ? .estimated : .exact, note: note)
    }
}

func applyPurchases(
    inventory: [InventoryItem],
    shoppingItems: [ShoppingPlanItem],
    quantityOverrides: [String: Double] = [:],
    now: String = ISO8601DateFormatter().string(from: Date())
) -> [InventoryItem] {
    var next = inventory

    for item in shoppingItems {
        guard item.precision != .manual else { continue }
        let packageCount = purchasePackageCount(quantityOverrides[item.id], fallback: item.purchaseQuantity)
        guard packageCount > 0 else { continue }
        let purchaseTotal = Double(packageCount) * item.packageSize.amount
        guard purchaseTotal.isFinite, purchaseTotal > epsilon else { continue }

        if let index = next.firstIndex(where: { $0.ingredientID == item.ingredientID && $0.unit == item.unit }) {
            if next[index].quantityStatus == .exact, let quantity = next[index].quantity {
                next[index].quantity = quantity + purchaseTotal
                next[index].updatedAt = now
            }
        } else {
            next.append(InventoryItem(ingredientID: item.ingredientID, quantity: purchaseTotal, unit: item.unit, quantityStatus: .exact, updatedAt: now))
        }
    }

    return next
}

func purchasePackageCount(_ value: Double?, fallback: Int) -> Int {
    guard let value, value.isFinite, value >= 0 else { return max(fallback, 0) }
    if value >= Double(Int.max) { return Int.max }
    return Int(value.rounded(.down))
}

func applyConsumption(
    inventory: [InventoryItem],
    consumptions: [CookingConsumption],
    now: String = ISO8601DateFormatter().string(from: Date())
) -> [InventoryItem] {
    var next = inventory

    for consumption in consumptions {
        let actual = safeQuantity(consumption.actualQuantity)
        if let remaining = consumption.remainingQuantity, remaining.isFinite, remaining >= 0 {
            if let index = next.firstIndex(where: { $0.ingredientID == consumption.ingredientID && $0.unit == consumption.unit }) {
                next[index].quantity = remaining
                next[index].quantityStatus = .exact
                next[index].updatedAt = now
            } else {
                next.append(InventoryItem(ingredientID: consumption.ingredientID, quantity: remaining, unit: consumption.unit, quantityStatus: .exact, updatedAt: now))
            }
            continue
        }

        if let index = next.firstIndex(where: { $0.ingredientID == consumption.ingredientID && $0.unit == consumption.unit }) {
            if next[index].quantityStatus == .exact, let quantity = next[index].quantity {
                next[index].quantity = max(quantity - actual, 0)
                next[index].updatedAt = now
            }
        } else {
            next.append(InventoryItem(ingredientID: consumption.ingredientID, quantity: 0, unit: consumption.unit, quantityStatus: .exact, updatedAt: now))
        }
    }

    return next
}

func budgetEstimate(
    drafts: [PlannedMealDraft],
    targetBudget: Int,
    inventory: [InventoryItem],
    prices: [String: IngredientPrice],
    packageOverrides: [String: PackageSize] = [:]
) -> BudgetEstimate {
    let items = calculateShoppingPlan(requirements: aggregateRequirements(for: drafts), inventory: inventory, packageOverrides: packageOverrides)
    var knownCost = 0
    var savings = 0
    var unknownIDs: [String] = []
    var lines: [BudgetLineItem] = []

    for item in items {
        guard let price = prices[item.ingredientID], price.unit == item.unit, price.packageAmount.isFinite, price.packageAmount > 0, price.price >= 0, abs(price.packageAmount - item.packageSize.amount) < epsilon, item.precision != .manual else {
            // 판매 단위·단위 충돌로 구매량을 못 낸 품목도 금액 미산정으로 잡아야
            // 잔여 예산을 `확정`처럼 보여주지 않는다(AGENTS 8절).
            if item.purchaseQuantity > 0 || item.precision == .manual { unknownIDs.append(item.ingredientID) }
            lines.append(BudgetLineItem(shoppingItem: item, price: prices[item.ingredientID], knownCost: nil, avoidedPackageCount: 0))
            continue
        }

        let itemCost = item.purchaseQuantity * price.price
        knownCost += itemCost
        let baselinePackages = Int(ceil(item.quantity / price.packageAmount))
        let availableIsExact = item.quantityStatus == .exact && item.availableQuantity != nil
        let avoidedPackages = availableIsExact ? max(baselinePackages - item.purchaseQuantity, 0) : 0
        savings += avoidedPackages * price.price
        lines.append(BudgetLineItem(shoppingItem: item, price: price, knownCost: itemCost, avoidedPackageCount: avoidedPackages))
    }

    return BudgetEstimate(targetBudget: max(targetBudget, 0), lineItems: lines, knownPurchaseCost: knownCost, confirmedInventorySavings: savings, unknownCostIngredientIDs: Array(Set(unknownIDs)).sorted())
}

private func availableIngredientIDs(_ inventory: [InventoryItem]) -> Set<String> {
    Set(inventory.filter { $0.quantityStatus == .exact && ($0.quantity ?? 0) > 0 }.map(\.ingredientID))
}

private func uniqueIngredientIDs(_ recipe: Recipe) -> [String] {
    Array(Set(recipe.ingredients.map(\.ingredientID))).sorted()
}

private func validRecipe(_ recipe: Recipe, request: PlanRequest) -> Bool {
    isRecommendable(recipe, preferences: request.preferences)
}

/// 자동 추천 후보 판정. 직접 고른 메뉴에는 적용하지 않는다(AGENTS 8절).
func isRecommendable(_ recipe: Recipe, preferences: AppPreferences) -> Bool {
    let IDs = Set(recipe.ingredients.map(\.ingredientID))
    guard !preferences.dislikedRecipeIDs.contains(recipe.id) else { return false }
    guard preferences.dislikedIngredientIDs.isDisjoint(with: IDs) else { return false }
    guard recipe.requiredTools.isSubset(of: preferences.availableTools) else { return false }
    return true
}

private func recomputeDrafts(_ drafts: [PlannedMealDraft], request: PlanRequest) -> (drafts: [PlannedMealDraft], shared: [String], unfilled: Int) {
    let recipeMap = Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0) })
    var available = availableIngredientIDs(request.inventory)
    var usage: [String: Int] = [:]
    var output: [PlannedMealDraft] = []

    for draft in drafts {
        guard let recipe = recipeMap[draft.recipeID] else { continue }
        let IDs = uniqueIngredientIDs(recipe)
        let reused = IDs.filter { available.contains($0) }
        let fresh = IDs.filter { !available.contains($0) }
        IDs.forEach { usage[$0, default: 0] += 1; available.insert($0) }
        let reason: String
        if reused.isEmpty {
            reason = "새로 준비하는 메뉴예요."
        } else if fresh.isEmpty {
            reason = "가진 재료 \(reused.count)가지로 만들 수 있어요."
        } else {
            reason = "가진 재료 \(reused.count)가지와 새 재료 \(fresh.count)가지가 필요해요."
        }
        output.append(PlannedMealDraft(recipeID: recipe.id, date: draft.date, mealSlot: draft.mealSlot, reason: reason, reusedIngredientIDs: reused, newPurchaseCount: fresh.count))
    }

    let shared = usage.filter { $0.value > 1 }.map { ingredient(for: $0.key)?.name ?? $0.key }.sorted()
    return (output, shared, drafts.count - output.count)
}

private func candidateRecipes(for slot: MealSlot, request: PlanRequest) -> [Recipe] {
    recipes.filter { $0.mealSlots.contains(slot) && validRecipe($0, request: request) }
}

func planCandidates(for slot: MealSlot, preferences: AppPreferences) -> [Recipe] {
    recipes.filter { $0.mealSlots.contains(slot) && isRecommendable($0, preferences: preferences) }
}

private func hasPriceForEveryIngredient(_ recipe: Recipe, prices: [String: IngredientPrice]) -> Bool {
    recipe.ingredients.allSatisfy { prices[$0.ingredientID] != nil }
}

private func recipeCostScore(_ recipe: Recipe, request: PlanRequest) -> Int {
    // 가격이 하나라도 없으면 어차피 미산정(0)이다. 무거운 계산을 돌리지 않는다.
    guard hasPriceForEveryIngredient(recipe, prices: request.prices) else { return 0 }
    let draft = PlannedMealDraft(recipeID: recipe.id, date: request.startDate, mealSlot: recipe.mealSlots.first ?? .dinner, reason: "", reusedIngredientIDs: [], newPurchaseCount: 0)
    let estimate = budgetEstimate(drafts: [draft], targetBudget: request.targetBudget, inventory: request.inventory, prices: request.prices)
    return estimate.isComplete ? estimate.knownPurchaseCost : 0
}

private func generatedPlan(for request: PlanRequest, variant: Int) -> MealPlanOption {
    let days = min(max(request.days, 1), 7)
    var available = availableIngredientIDs(request.inventory)
    var counts: [String: Int] = [:]
    var picks: [PlannedMealDraft] = []
    var unfilled = 0
    let orderedDates = (0..<days).map { dateByAddingDays(request.startDate, $0) }

    for date in orderedDates {
        let slots = MealSlot.allCases.filter { request.slotsByDate[date]?.contains($0) == true }
        for (slotIndex, slot) in slots.enumerated() {
            let candidates = candidateRecipes(for: slot, request: request)
            guard !candidates.isEmpty else {
                unfilled += 1
                continue
            }

            var ranked: [(recipe: Recipe, score: Int, index: Int)] = []
            let recentIDs = picks.suffix(slots.count).map(\.recipeID)
            for (index, recipe) in candidates.enumerated() {
                let IDs = uniqueIngredientIDs(recipe)
                let reuse = IDs.filter { available.contains($0) }.count
                let fresh = IDs.count - reuse
                let repeatPenalty = (counts[recipe.id] ?? 0) * (variant == 2 ? 30 : 60)
                let recentPenalty = recentIDs.contains(recipe.id) ? 500 : 0
                let favoriteBonus = request.favorites.contains(recipe.id) ? 260 : 0
                let lightBonus = slot == .breakfast && recipe.isLightBreakfast ? 80 : (slot == .breakfast ? -120 : 0)
                // 난이도는 명시적 메타데이터가 있을 때만 보조 기준으로 쓴다(AGENTS 3절 원칙 6).
                let difficultyBonus = recipe.difficulty.map { (4 - $0) * (variant == 2 ? 10 : 5) } ?? 0
                let reuseWeight = variant == 1 ? 75 : 110
                let freshWeight = variant == 1 ? 5 : 18
                let varietyBonus = variant == 1 ? ((index + slotIndex) % 4) * 20 : 0
                let costPenalty = variant == 2 ? recipeCostScore(recipe, request: request) / 10 : 0
                let score = reuse * reuseWeight - fresh * freshWeight - repeatPenalty - recentPenalty + favoriteBonus + lightBonus + difficultyBonus + varietyBonus - costPenalty

                ranked.append((recipe, score, index))
            }

            let ordered = ranked.sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.index < $1.index
            }
            guard !ordered.isEmpty else {
                unfilled += 1
                continue
            }
            // 첫 안은 최고 점수, 두 번째와 세 번째 안은 같은 유효 후보의 다음 순위를
            // 선택합니다. 후보가 하나뿐인 끼니는 안전하게 같은 메뉴를 사용합니다.
            let selected = ordered[min(variant, ordered.count - 1)].recipe
            let IDs = uniqueIngredientIDs(selected)
            IDs.forEach { available.insert($0) }
            counts[selected.id, default: 0] += 1
            picks.append(PlannedMealDraft(recipeID: selected.id, date: date, mealSlot: slot, reason: "", reusedIngredientIDs: [], newPurchaseCount: 0))
        }
    }

    let recomputed = recomputeDrafts(picks, request: request)
    let titles = ["재료 재사용 중심", "찜·균형 중심", "가볍고 쉬운 식단"]
    let subtitles = ["가지고 있는 재료를 먼저 쓰고 남김을 줄여요.", "찜한 메뉴와 끼니별 균형을 우선했어요.", "초보자도 부담 없이 이어갈 수 있어요."]
    let reason = recomputed.shared.isEmpty ? "식단을 고른 뒤 필요한 재료를 한 번에 확인할 수 있어요." : "여러 끼니에서 \(recomputed.shared.joined(separator: ", "))을(를) 다시 사용해요."
    return MealPlanOption(id: "option-\(variant)", title: titles[variant], subtitle: subtitles[variant], drafts: recomputed.drafts, reason: reason, sharedIngredientNames: recomputed.shared, unfilledSlots: recomputed.unfilled + unfilled)
}

func generateMealPlanOptions(request: PlanRequest) -> [MealPlanOption] {
    guard request.days > 0, request.days <= 7, request.slotsByDate.values.contains(where: { !$0.isEmpty }) else { return [] }
    return (0..<3).map { generatedPlan(for: request, variant: $0) }
}

func recomputePlanOption(_ option: MealPlanOption, request: PlanRequest) -> MealPlanOption {
    let recomputed = recomputeDrafts(option.drafts, request: request)
    return MealPlanOption(id: option.id, title: option.title, subtitle: option.subtitle, drafts: recomputed.drafts, reason: option.reason, sharedIngredientNames: recomputed.shared, unfilledSlots: recomputed.unfilled)
}

func leftoverRecommendations(inventory: [InventoryItem], preferences: AppPreferences, recipes: [Recipe] = recipes) -> [LeftoverRecommendation] {
    let candidates = recipes.filter { validRecipe($0, request: PlanRequest(startDate: isoDateString(), days: 1, slotsByDate: [:], targetBudget: 0, favorites: [], inventory: inventory, prices: [:], preferences: preferences)) }
    return candidates.compactMap { recipe in
        let used = recipe.ingredients.filter { ingredient in
            guard let stock = exactInventory(inventory, ingredientID: ingredient.ingredientID, unit: ingredient.unit), stock.quantityStatus == .exact, let quantity = stock.quantity else { return false }
            return quantity >= ingredient.quantity
        }.map(\.ingredientID)
        let items = calculateShoppingPlan(requirements: aggregateRequirements(for: [PlannedMealDraft(recipeID: recipe.id, date: isoDateString(), mealSlot: recipe.mealSlots.first ?? .dinner, reason: "", reusedIngredientIDs: [], newPurchaseCount: 0)], recipes: [recipe]), inventory: inventory)
        let missing = items.filter { $0.purchaseQuantity > 0 || $0.precision == .manual }
        let score = used.count * 100 - missing.count * 12 - (recipe.difficulty ?? 0) * 3
        let reason: String
        if used.isEmpty {
            reason = "현재 재고와 필요한 양을 확인하면 다음 장보기까지 함께 준비할 수 있어요."
        } else if missing.isEmpty {
            reason = "보유한 재료 \(used.count)가지를 추가 구매 없이 활용해요."
        } else {
            reason = "보유 재료 \(used.count)가지에 \(missing.count)개 품목만 더하면 만들 수 있어요."
        }
        return LeftoverRecommendation(recipe: recipe, usedIngredientIDs: Array(Set(used)), additionalPurchaseItems: missing, reason: reason, score: score)
    }.sorted {
        if $0.score != $1.score { return $0.score > $1.score }
        return $0.recipe.title.localizedCompare($1.recipe.title) == .orderedAscending
    }
}

func upgradeSuggestions(for option: MealPlanOption, request: PlanRequest) -> [UpgradeSuggestion] {
    let current = budgetEstimate(drafts: option.drafts, targetBudget: request.targetBudget, inventory: request.inventory, prices: request.prices)
    guard let remaining = current.remainingBudget else { return [] }
    var suggestions: [UpgradeSuggestion] = []

    for draft in option.drafts {
        guard let original = recipe(for: draft.recipeID) else { continue }
        // 가격이 다 확인된 후보만 검토한다. 어차피 isComplete가 아니면 제안할 수 없다.
        for candidate in candidateRecipes(for: draft.mealSlot, request: request)
        where candidate.id != original.id && hasPriceForEveryIngredient(candidate, prices: request.prices) {
            var replacement = option.drafts
            guard let index = replacement.firstIndex(where: { $0.id == draft.id }) else { continue }
            replacement[index] = PlannedMealDraft(recipeID: candidate.id, date: draft.date, mealSlot: draft.mealSlot, reason: "", reusedIngredientIDs: [], newPurchaseCount: 0)
            let estimate = budgetEstimate(drafts: replacement, targetBudget: request.targetBudget, inventory: request.inventory, prices: request.prices)
            guard estimate.isComplete else { continue }
            let delta = estimate.knownPurchaseCost - current.knownPurchaseCost
            guard delta > 0, delta <= remaining else { continue }
            suggestions.append(UpgradeSuggestion(id: "\(draft.id):\(candidate.id)", originalRecipeID: original.id, replacementRecipeID: candidate.id, date: draft.date, mealSlot: draft.mealSlot, additionalCost: delta, reason: "\(candidate.title)(으)로 바꾸면 메뉴가 풍성해지고, 확인된 추가 비용은 \(won(delta))예요."))
        }
    }

    return suggestions.sorted { $0.additionalCost == $1.additionalCost ? $0.id < $1.id : $0.additionalCost < $1.additionalCost }
}

/// 이 레시피만으로 구매량까지 끝까지 계산되는지. 실제 장보기 계산기를 그대로 써서 판정한다.
func isFullyCalculable(_ recipe: Recipe) -> Bool {
    let draft = PlannedMealDraft(recipeID: recipe.id, date: isoDateString(), mealSlot: recipe.mealSlots.first ?? .dinner, reason: "", reusedIngredientIDs: [], newPurchaseCount: 0)
    let items = calculateShoppingPlan(requirements: aggregateRequirements(for: [draft], recipes: [recipe]), inventory: [])
    return !items.isEmpty && items.allSatisfy { $0.precision != .manual }
}

/// 목록 필터에서 매번 다시 계산하지 않도록 한 번만 판정한다.
let fullyCalculableRecipeIDs: Set<String> = Set(recipes.filter(isFullyCalculable).map(\.id))

func shoppingSignature(_ items: [ShoppingPlanItem], quantityOverrides: [String: Double] = [:]) -> String {
    items.sorted { $0.id < $1.id }.map { item in
        let count = purchasePackageCount(quantityOverrides[item.id], fallback: item.purchaseQuantity)
        return "\(item.id)=\(count)"
    }.joined(separator: "|")
}
