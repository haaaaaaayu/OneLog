import XCTest
@testable import OneLog

final class OneLogDomainTests: XCTestCase {
    private func meal(_ recipeID: String, _ date: String = "2026-08-14", _ slot: MealSlot = .dinner) -> PlannedMeal {
        PlannedMeal(id: UUID().uuidString, recipeID: recipeID, date: date, mealSlot: slot, status: .planned, createdAt: "2026-08-13T00:00:00Z")
    }

    func testIngredientAliasesNormalizeToCanonicalIngredient() {
        XCTAssertEqual(resolveIngredient("계란 노른자")?.id, "egg")
        XCTAssertEqual(resolveIngredient("송송 썬 대파")?.id, "green-onion")
    }

    func testRequirementsAggregateSameUnitAndFlagConflict() {
        let items = [
            RecipeIngredient(ingredientID: "egg", rawName: "계란", quantity: 2, unit: .count, preparation: nil),
            RecipeIngredient(ingredientID: "egg", rawName: "달걀", quantity: 1, unit: .count, preparation: nil),
        ]
        let testRecipe = Recipe(id: "test", title: "테스트", description: "", mealSlots: [.dinner], difficulty: 1, cookTime: 1, servings: 1, symbolName: "🍳", ingredients: items, steps: [], tags: [], isLightBreakfast: false, requiredTools: [])
        let result = aggregateRequirements(for: [meal("test")], recipes: [testRecipe])
        XCTAssertEqual(result.first?.quantity, 3)
        XCTAssertEqual(result.first?.unitConflict, false)
    }

    func testShoppingPlanSubtractsInventoryAndRoundsSalesUnit() {
        let result = calculateShoppingPlan(
            requirements: [IngredientRequirement(key: "egg:개", ingredientID: "egg", ingredientName: "계란", quantity: 11, unit: .count, recipeIDs: ["test"], unitConflict: false)],
            inventory: [InventoryItem(ingredientID: "egg", quantity: 2, unit: .count, quantityStatus: .exact, updatedAt: "2026-08-14")]
        )
        XCTAssertEqual(result.first?.additionalNeeded, 9)
        XCTAssertEqual(result.first?.purchaseQuantity, 1)
        XCTAssertEqual(result.first?.purchaseTotal, 10)
        XCTAssertEqual(result.first?.expectedRemaining, 1)
    }

    func testUnknownInventoryIsNotTreatedAsEnough() {
        let result = calculateShoppingPlan(
            requirements: [IngredientRequirement(key: "egg:개", ingredientID: "egg", ingredientName: "계란", quantity: 2, unit: .count, recipeIDs: ["test"], unitConflict: false)],
            inventory: [InventoryItem(ingredientID: "egg", quantity: nil, unit: .count, quantityStatus: .unknown, updatedAt: "2026-08-14")]
        )
        XCTAssertNil(result.first?.availableQuantity)
        XCTAssertEqual(result.first?.quantityStatus, .unknown)
        XCTAssertEqual(result.first?.precision, .estimated)
        XCTAssertEqual(result.first?.purchaseQuantity, 1)
    }

    func testBudgetDoesNotInventMissingPricesAndUsesConfirmedSavings() {
        let draft = PlannedMealDraft(recipeID: "cabbage-egg-stir-fry", date: "2026-08-14", mealSlot: .dinner, reason: "", reusedIngredientIDs: [], newPurchaseCount: 0)
        let price = IngredientPrice(price: 5000, packageAmount: 10, unit: .count, confirmedAt: "2026-08-14", source: "user")
        let estimate = budgetEstimate(drafts: [draft], targetBudget: 10000, inventory: [InventoryItem(ingredientID: "egg", quantity: 2, unit: .count, quantityStatus: .exact, updatedAt: "2026-08-14")], prices: ["egg": price])
        XCTAssertFalse(estimate.isComplete)
        XCTAssertNil(estimate.remainingBudget)
        XCTAssertEqual(estimate.confirmedInventorySavings, 5000)
        XCTAssertTrue(estimate.unknownCostIngredientIDs.contains("cabbage"))
    }

    func testPlanSupportsDateSpecificMealsAndReturnsMultipleOptions() {
        let start = "2026-08-14"
        let request = PlanRequest(
            startDate: start,
            days: 2,
            slotsByDate: [start: [.breakfast], dateByAddingDays(start, 1): [.dinner]],
            targetBudget: 30000,
            favorites: ["tuna-mayo-rice"],
            inventory: [],
            prices: [:],
            preferences: AppPreferences()
        )
        let options = generateMealPlanOptions(request: request)
        XCTAssertEqual(options.count, 3)
        XCTAssertTrue(options.allSatisfy { $0.drafts.count == 2 })
        XCTAssertGreaterThan(Set(options.map { $0.drafts.map(\.recipeID).joined(separator: ",") }).count, 1)
        XCTAssertTrue(options.allSatisfy { $0.drafts.contains(where: { $0.date == start && $0.mealSlot == .breakfast }) })
        XCTAssertTrue(options.allSatisfy { $0.drafts.contains(where: { $0.date == dateByAddingDays(start, 1) && $0.mealSlot == .dinner }) })
    }

    func testPlanFiltersDislikedIngredientsAndMissingTools() {
        var preferences = AppPreferences()
        preferences.dislikedIngredientIDs = ["egg"]
        preferences.availableTools = [.bowl]
        let request = PlanRequest(startDate: "2026-08-14", days: 1, slotsByDate: ["2026-08-14": [.breakfast]], targetBudget: 10000, favorites: [], inventory: [], prices: [:], preferences: preferences)
        let options = generateMealPlanOptions(request: request)
        XCTAssertTrue(options.allSatisfy { $0.drafts.allSatisfy { draft in
            guard let recipe = recipe(for: draft.recipeID) else { return false }
            return !recipe.ingredients.contains(where: { $0.ingredientID == "egg" }) && recipe.requiredTools.isSubset(of: preferences.availableTools) && recipe.isLightBreakfast
        }})
    }

    func testCookingAndPurchasingAreIdempotent() {
        let item = ShoppingPlanItem(
            requirement: IngredientRequirement(key: "egg:개", ingredientID: "egg", ingredientName: "계란", quantity: 2, unit: .count, recipeIDs: ["test"], unitConflict: false),
            availableQuantity: 0, quantityStatus: .exact, additionalNeeded: 2, packageSize: PackageSize(amount: 10, unit: .count, label: "10구"), purchaseQuantity: 1, purchaseTotal: 10, expectedRemaining: 8, precision: .exact, note: nil
        )
        let first = applyPurchases(inventory: [], shoppingItems: [item])
        let second = applyPurchases(inventory: first, shoppingItems: [])
        XCTAssertEqual(first.first?.quantity, 10)
        XCTAssertEqual(second.first?.quantity, 10)

        let consumption = [CookingConsumption(ingredientID: "egg", unit: .count, expectedQuantity: 2, actualQuantity: 2, remainingQuantity: nil)]
        let cooked = applyConsumption(inventory: first, consumptions: consumption)
        XCTAssertEqual(cooked.first?.quantity, 8)
    }

    func testLeftoverRecommendationIncludesActualAdditionalPurchase() {
        let result = leftoverRecommendations(inventory: [InventoryItem(ingredientID: "green-onion", quantity: 20, unit: .gram, quantityStatus: .exact, updatedAt: "2026-08-14")], preferences: AppPreferences())
        let match = result.first(where: { $0.recipe.id == "cabbage-egg-stir-fry" })
        XCTAssertNotNil(match)
        XCTAssertTrue(match?.additionalPurchaseItems.contains(where: { $0.ingredientID == "egg" }) == true)
    }

    func testPackageOverrideRoundsToMinimumSalesUnits() {
        let result = calculateShoppingPlan(
            requirements: [IngredientRequirement(key: "egg:개", ingredientID: "egg", ingredientName: "계란", quantity: 11, unit: .count, recipeIDs: ["test"], unitConflict: false)],
            inventory: [InventoryItem(ingredientID: "egg", quantity: 2, unit: .count, quantityStatus: .exact, updatedAt: "2026-08-14")],
            packageOverrides: ["egg": PackageSize(amount: 4, unit: .count, label: "계란 4구")]
        )
        XCTAssertEqual(result.first?.purchaseQuantity, 3)
        XCTAssertEqual(result.first?.purchaseTotal, 12)
        XCTAssertEqual(result.first?.expectedRemaining, 3)
    }

    func testUnitConflictRequiresManualConfirmation() {
        let result = calculateShoppingPlan(
            requirements: [IngredientRequirement(key: "egg:개", ingredientID: "egg", ingredientName: "계란", quantity: 2, unit: .count, recipeIDs: ["test"], unitConflict: true)],
            inventory: []
        )
        XCTAssertEqual(result.first?.precision, .manual)
        XCTAssertEqual(result.first?.purchaseQuantity, 0)
        XCTAssertNil(result.first?.expectedRemaining)
    }

    func testInvalidPlanRequestsReturnNoOptions() {
        let start = "2026-08-14"
        let requestWithTooManyDays = PlanRequest(startDate: start, days: 8, slotsByDate: [start: [.dinner]], targetBudget: 10000, favorites: [], inventory: [], prices: [:], preferences: AppPreferences())
        let requestWithoutMeals = PlanRequest(startDate: start, days: 1, slotsByDate: [start: []], targetBudget: 10000, favorites: [], inventory: [], prices: [:], preferences: AppPreferences())

        XCTAssertTrue(generateMealPlanOptions(request: requestWithTooManyDays).isEmpty)
        XCTAssertTrue(generateMealPlanOptions(request: requestWithoutMeals).isEmpty)
    }

    func testShoppingSignatureUsesComputedPurchaseQuantity() {
        let item = ShoppingPlanItem(
            requirement: IngredientRequirement(key: "egg:개", ingredientID: "egg", ingredientName: "계란", quantity: 2, unit: .count, recipeIDs: ["test"], unitConflict: false),
            availableQuantity: 0, quantityStatus: .exact, additionalNeeded: 2, packageSize: PackageSize(amount: 10, unit: .count, label: "10구"), purchaseQuantity: 1, purchaseTotal: 10, expectedRemaining: 8, precision: .exact, note: nil
        )
        XCTAssertEqual(shoppingSignature([item]), "egg:개=1")
    }

    func testPurchaseOverrideUsesWholePackagesForInventoryAndIdempotencySignature() {
        let item = ShoppingPlanItem(
            requirement: IngredientRequirement(key: "egg:개", ingredientID: "egg", ingredientName: "계란", quantity: 2, unit: .count, recipeIDs: ["test"], unitConflict: false),
            availableQuantity: 0, quantityStatus: .exact, additionalNeeded: 2, packageSize: PackageSize(amount: 10, unit: .count, label: "10구"), purchaseQuantity: 1, purchaseTotal: 10, expectedRemaining: 8, precision: .exact, note: nil
        )

        XCTAssertEqual(purchasePackageCount(2.9, fallback: 1), 2)
        XCTAssertEqual(purchasePackageCount(-1, fallback: 1), 1)
        XCTAssertEqual(purchasePackageCount(.nan, fallback: 1), 1)

        let purchased = applyPurchases(inventory: [], shoppingItems: [item], quantityOverrides: [item.id: 2.9])
        XCTAssertEqual(purchased.first?.quantity, 20)
        XCTAssertEqual(shoppingSignature([item], quantityOverrides: [item.id: 2.9]), "egg:개=2")
    }

    func testImportedRecipesLoadAndResolveEveryIngredient() {
        XCTAssertGreaterThan(recipes.count, 100, "번들 레시피가 로드되지 않았습니다")
        XCTAssertFalse(externalDataSources.isEmpty, "외부 데이터 출처 표기가 비어 있습니다")

        let unresolved = recipes.flatMap(\.ingredients).filter { ingredient(for: $0.ingredientID) == nil }
        XCTAssertTrue(unresolved.isEmpty, "재료표에 없는 참조 \(unresolved.count)건: \(unresolved.prefix(3).map(\.rawName))")

        XCTAssertTrue(recipes.allSatisfy { !$0.ingredients.isEmpty && !$0.steps.isEmpty })
        XCTAssertTrue(recipes.allSatisfy { $0.ingredients.allSatisfy { $0.quantity > 0 } })
        XCTAssertEqual(Set(recipes.map(\.id)).count, recipes.count, "레시피 ID가 중복됩니다")
        // 변환기가 아침 후보로 넣은 건 열량 기준을 통과한 것만이어야 한다.
        // (직접 큐레이션한 레시피는 무거운 아침도 허용하고 추천 점수에서만 불리하게 둔다.)
        let imported = recipes.filter { $0.id.hasPrefix("fsk-") }
        XCTAssertGreaterThan(imported.count, 100)
        XCTAssertTrue(imported.allSatisfy { !$0.mealSlots.contains(.breakfast) || $0.isLightBreakfast })
    }

    func testUnitConversionUsesDeclaredGramsOnly() {
        let onion = ingredient(for: "onion")
        // 양파 3개들이 = 600g. 레시피가 g로 적어도 구매량이 나와야 한다.
        XCTAssertEqual(convertQuantity(3, from: .count, to: .gram, using: onion), 600)
        XCTAssertEqual(convertQuantity(400, from: .gram, to: .count, using: onion), 2)
        // 환산 근거가 없는 재료는 환산하지 않는다.
        XCTAssertNil(convertQuantity(1, from: .count, to: .gram, using: ingredient(for: "carrot")))

        let requirement = IngredientRequirement(key: "onion:g", ingredientID: "onion", ingredientName: "양파", quantity: 250, unit: .gram, recipeIDs: ["r"], unitConflict: false)
        let item = calculateShoppingPlan(requirements: [requirement], inventory: []).first
        XCTAssertEqual(item?.precision, .exact)
        XCTAssertEqual(item?.purchaseQuantity, 1, "600g 한 묶음이면 250g을 덮는다")
        XCTAssertEqual(item?.expectedRemaining, 350)
    }

    func testInventoryInAnotherUnitCountsWhenConversionIsDeclared() {
        let requirement = IngredientRequirement(key: "onion:g", ingredientID: "onion", ingredientName: "양파", quantity: 250, unit: .gram, recipeIDs: ["r"], unitConflict: false)
        // 양파 2개(=400g)를 가지고 있으면 추가 구매가 필요 없다.
        let stocked = calculateShoppingPlan(
            requirements: [requirement],
            inventory: [InventoryItem(ingredientID: "onion", quantity: 2, unit: .count, quantityStatus: .exact, updatedAt: "2026-08-15")]
        ).first
        XCTAssertEqual(stocked?.availableQuantity, 400)
        XCTAssertEqual(stocked?.additionalNeeded, 0)
        XCTAssertEqual(stocked?.purchaseQuantity, 0)
    }

    func testEnoughImportedRecipesAreFullyCalculable() {
        let calculable = recipes.filter { fullyCalculableRecipeIDs.contains($0.id) }
        XCTAssertGreaterThanOrEqual(calculable.count, 100, "구매량까지 계산되는 레시피가 \(calculable.count)건뿐입니다")
        // 큐레이션 6건은 전부 계산 가능해야 한다.
        for id in ["chicken-donburi", "tofu-kimchi", "tuna-mayo-rice", "cabbage-egg-stir-fry", "cucumber-tuna-bowl", "kimchi-fried-rice"] {
            XCTAssertTrue(fullyCalculableRecipeIDs.contains(id), "\(id)가 계산 불가로 빠졌습니다")
        }
    }

    func testUnknownSaleUnitIsNotGuessedAndKeepsBudgetIncomplete() {
        guard let auto = ingredients.first(where: { $0.representativeSaleUnit == nil }) else {
            return XCTFail("판매 단위 미확인 재료가 없습니다")
        }
        let requirement = IngredientRequirement(key: ingredientKey(auto.id, auto.defaultUnit), ingredientID: auto.id, ingredientName: auto.name, quantity: 30, unit: auto.defaultUnit, recipeIDs: ["r"], unitConflict: false)
        let item = calculateShoppingPlan(requirements: [requirement], inventory: []).first

        XCTAssertEqual(item?.precision, .manual)
        XCTAssertEqual(item?.purchaseQuantity, 0, "판매 단위를 모르는데 구매량을 만들어냈습니다")
        XCTAssertNil(item?.expectedRemaining)

        // 이런 품목이 섞이면 잔여 예산을 확정으로 보여주면 안 된다.
        guard let recipeID = recipes.first(where: { $0.ingredients.contains { ingredient(for: $0.ingredientID)?.representativeSaleUnit == nil } })?.id else {
            return XCTFail("판매 단위 미확인 재료를 쓰는 레시피가 없습니다")
        }
        let draft = PlannedMealDraft(recipeID: recipeID, date: "2026-08-15", mealSlot: .dinner, reason: "", reusedIngredientIDs: [], newPurchaseCount: 0)
        let estimate = budgetEstimate(drafts: [draft], targetBudget: 30000, inventory: [], prices: [:])
        XCTAssertFalse(estimate.isComplete)
        XCTAssertNil(estimate.remainingBudget)
    }

    func testDislikedRecipeIsExcludedFromAutoRecommendationOnly() {
        var preferences = AppPreferences()
        preferences.dislikedRecipeIDs = ["tuna-mayo-rice"]

        XCTAssertFalse(planCandidates(for: .lunch, preferences: preferences).contains { $0.id == "tuna-mayo-rice" })
        XCTAssertFalse(leftoverRecommendations(inventory: [], preferences: preferences).contains { $0.recipe.id == "tuna-mayo-rice" })

        let request = PlanRequest(startDate: "2026-08-14", days: 1, slotsByDate: ["2026-08-14": [.lunch]], targetBudget: 10000, favorites: ["tuna-mayo-rice"], inventory: [], prices: [:], preferences: preferences)
        XCTAssertTrue(generateMealPlanOptions(request: request).allSatisfy { $0.drafts.allSatisfy { $0.recipeID != "tuna-mayo-rice" } })

        // 직접 고른 메뉴는 계속 선택할 수 있어야 한다.
        XCTAssertNotNil(recipe(for: "tuna-mayo-rice"))
    }

    func testPreferencesDecodeLegacyDataWithoutDislikedRecipes() {
        let legacy = Data(#"{"dislikedIngredientIDs":["egg"],"availableTools":["볼"]}"#.utf8)

        do {
            let preferences = try JSONDecoder().decode(AppPreferences.self, from: legacy)
            XCTAssertEqual(preferences.dislikedIngredientIDs, ["egg"])
            XCTAssertEqual(preferences.availableTools, [.bowl])
            XCTAssertTrue(preferences.dislikedRecipeIDs.isEmpty)
        } catch {
            XCTFail("기존 추천 설정 디코딩 실패: \(error)")
        }
    }

    func testAppStateDecodesLegacyDataWithoutAccountAndProfile() {
        let legacy = Data(#"{"favorites":["tuna-mayo-rice"],"preferences":{"dislikedIngredientIDs":[],"availableTools":["볼"]}}"#.utf8)

        do {
            let state = try JSONDecoder().decode(AppState.self, from: legacy)
            XCTAssertNil(state.account)
            XCTAssertEqual(state.profile.nickname, "")
            XCTAssertNil(state.profile.age)
            XCTAssertEqual(state.preferences.availableTools, [.bowl])
        } catch {
            XCTFail("계정·프로필 추가 전 데이터 디코딩 실패: \(error)")
        }
    }

    func testAccountAndProfileRoundTripThroughEncoding() throws {
        var state = AppState()
        state.account = UserAccount(provider: .deviceOnly, userID: "u1", email: nil, displayName: nil, linkedAt: "2026-08-15T00:00:00Z")
        state.profile = UserProfile(nickname: "준", age: 24)

        let decoded = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.account?.provider, .deviceOnly)
        XCTAssertEqual(decoded.profile.nickname, "준")
        XCTAssertEqual(decoded.profile.age, 24)
    }

    func testAppStateDecodesLegacyDataWithoutP1ShoppingFields() {
        let legacyData = Data(#"{"favorites":["tuna-mayo-rice"]}"#.utf8)

        do {
            let state = try JSONDecoder().decode(AppState.self, from: legacyData)
            XCTAssertFalse(state.hasCompletedOnboarding)
            XCTAssertEqual(state.favorites, ["tuna-mayo-rice"])
            XCTAssertTrue(state.purchaseChecks.isEmpty)
            XCTAssertTrue(state.purchaseQuantityOverrides.isEmpty)
            XCTAssertTrue(state.shoppingEvents.isEmpty)
        } catch {
            XCTFail("기존 저장 데이터 호환성 디코딩 실패: \(error)")
        }
    }

}
