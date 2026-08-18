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
        // 2026-08-17 기준 956건 중 719건. 판매 단위 표를 손대다 크게 줄면 잡는 하한선이다.
        XCTAssertGreaterThanOrEqual(calculable.count, 700, "구매량까지 계산되는 레시피가 \(calculable.count)건뿐입니다")
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

    /// 예산 화면의 입력 순서(판매 단위 확인 → 그 포장 가격)가 실제로 예산을 완성시키는지 본다.
    func testConfirmingSaleUnitThenPriceCompletesBudget() {
        guard let recipeID = recipes.first(where: { recipe in
            recipe.ingredients.contains { ingredient(for: $0.ingredientID)?.representativeSaleUnit == nil }
        })?.id else {
            return XCTFail("판매 단위 미확인 재료를 쓰는 레시피가 없습니다")
        }
        let draft = PlannedMealDraft(recipeID: recipeID, date: "2026-08-17", mealSlot: .dinner, reason: "", reusedIngredientIDs: [], newPurchaseCount: 0)
        XCTAssertFalse(budgetEstimate(drafts: [draft], targetBudget: 30000, inventory: [], prices: [:]).isComplete)

        // 1) 사용자가 확인한 판매 단위를 넣는다.
        var overrides: [String: PackageSize] = [:]
        for line in budgetEstimate(drafts: [draft], targetBudget: 30000, inventory: [], prices: [:]).lineItems
        where line.shoppingItem.precision == .manual {
            overrides[line.shoppingItem.ingredientID] = PackageSize(amount: 100, unit: line.shoppingItem.unit, label: "100 포장")
        }

        // 2) 그 포장 그대로의 가격을 넣는다. 화면이 저장하는 값과 같은 조합이다.
        var prices: [String: IngredientPrice] = [:]
        for line in budgetEstimate(drafts: [draft], targetBudget: 30000, inventory: [], prices: [:], packageOverrides: overrides).lineItems {
            let item = line.shoppingItem
            prices[item.ingredientID] = IngredientPrice(price: 1000, packageAmount: item.packageSize.amount, unit: item.unit, confirmedAt: "2026-08-17T00:00:00Z", source: "user")
        }

        let completed = budgetEstimate(drafts: [draft], targetBudget: 30000, inventory: [], prices: prices, packageOverrides: overrides)
        XCTAssertTrue(completed.isComplete, "판매 단위와 가격을 다 확인했는데 예산이 미확정입니다")
        XCTAssertNotNil(completed.remainingBudget)

        // 포장 크기가 어긋난 가격은 금액으로 쓰지 않는다. 화면도 그래서 따로 알려 준다.
        let drifted = prices.mapValues { IngredientPrice(price: $0.price, packageAmount: $0.packageAmount + 7, unit: $0.unit, confirmedAt: $0.confirmedAt, source: $0.source) }
        XCTAssertFalse(budgetEstimate(drafts: [draft], targetBudget: 30000, inventory: [], prices: drifted, packageOverrides: overrides).isComplete)
    }

    /// F25 도보 시간. 좌표가 없으면 표시하지 않고, 있으면 직선 거리 ÷ 75m/분으로 센다.
    func testWalkingMinutesNeedsBothCoordinates() {
        let seongsu = ShareCoordinate(latitude: 37.544, longitude: 127.056)
        let nearby = ShareCoordinate(latitude: 37.548, longitude: 127.056) // 약 445m 북쪽

        XCTAssertNil(walkingMinutes(from: seongsu, to: nil))
        XCTAssertNil(walkingMinutes(from: nil, to: nearby))

        XCTAssertEqual(walkingMinutes(from: seongsu, to: nearby), 6, "445m면 도보 6분이어야 합니다")
        XCTAssertEqual(walkingText(from: seongsu, to: nearby), "도보 약 6분")

        // 같은 자리여도 0분이 아니라 최소 1분으로 보여준다.
        XCTAssertEqual(walkingMinutes(from: seongsu, to: seongsu), 1)
    }

    /// 좌표는 약 100m 격자로만 저장한다. 집 주소가 그대로 남으면 안 된다.
    func testCoordinateIsRoundedAndValidated() {
        let rounded = ShareCoordinate.rounded(latitude: 37.5442891, longitude: 127.0563123)
        XCTAssertEqual(rounded?.latitude, 37.544)
        XCTAssertEqual(rounded?.longitude, 127.056)

        XCTAssertNil(ShareCoordinate.rounded(latitude: 91, longitude: 127))
        XCTAssertNil(ShareCoordinate.rounded(latitude: .nan, longitude: 127))
    }

    /// 좌표 필드가 없던 예전 글도 그대로 읽혀야 한다.
    func testSharePostDecodesWithoutCoordinate() throws {
        let json = Data(#"{"id":"p1","kind":"split","ingredientID":"egg","ingredientName":"계란","amount":5,"unit":"개","neighborhood":"성수동","meetupNote":"","authorID":"u1","authorNickname":"퍼핌","participantIDs":[],"capacity":2,"status":"open","createdAt":0,"expiresAt":1}"#.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let post = try decoder.decode(SharePost.self, from: json)
        XCTAssertNil(post.coordinate)
        XCTAssertEqual(post.ingredientName, "계란")
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

    /// 동네를 추가하기 전에 저장된 프로필도 그대로 열려야 한다.
    func testProfileDecodesWithoutNeighborhood() throws {
        let legacy = Data(#"{"profile":{"nickname":"준","age":24}}"#.utf8)
        let state = try JSONDecoder().decode(AppState.self, from: legacy)
        XCTAssertEqual(state.profile.nickname, "준")
        XCTAssertEqual(state.profile.neighborhood, "")
    }

    // MARK: - F26 공동구매·소분

    private func planItem(_ ingredientID: String, needed: Double, remaining: Double?, precision: ShoppingPlanItem.Precision = .exact) -> ShoppingPlanItem {
        let requirement = IngredientRequirement(key: "\(ingredientID):개", ingredientID: ingredientID, ingredientName: ingredientID, quantity: needed, unit: .count, recipeIDs: [], unitConflict: false)
        return ShoppingPlanItem(requirement: requirement, availableQuantity: 0, quantityStatus: .exact, additionalNeeded: needed, packageSize: PackageSize(amount: needed + (remaining ?? 0), unit: .count, label: "봉"), purchaseQuantity: 1, purchaseTotal: needed + (remaining ?? 0), expectedRemaining: remaining, precision: precision, note: nil)
    }

    private func post(_ id: String, _ ingredientID: String, kind: ShareKind = .split, author: String = "other", capacity: Int = 2, participants: [String] = [], status: ShareStatus = .open, expiresIn: TimeInterval = 7 * 24 * 60 * 60) -> SharePost {
        SharePost(id: id, kind: kind, ingredientID: ingredientID, ingredientName: ingredientID, amount: 1, unit: .count, neighborhood: "성수동", meetupNote: "", pricePerShare: nil, authorID: author, authorNickname: "이웃", participantIDs: participants, capacity: capacity, status: status, createdAt: Date(), expiresAt: Date().addingTimeInterval(expiresIn))
    }

    /// 한 포장이 필요량보다 많으면 같이 사기, 조금만 남으면 나눠 쓰기.
    /// 판매 단위가 확인되지 않은 재료는 남는 양 자체가 미상이라 제안하지 않는다.
    func testShareDraftsSplitByLeftoverSize() {
        let drafts = shareDrafts(from: [
            planItem("onion", needed: 1, remaining: 3),
            planItem("egg", needed: 10, remaining: 2),
            planItem("tofu", needed: 1, remaining: 5, precision: .manual),
            planItem("milk", needed: 1, remaining: 0),
        ])

        XCTAssertEqual(drafts.map(\.ingredientID), ["egg", "onion"])
        XCTAssertEqual(drafts.first { $0.ingredientID == "onion" }?.kind, .groupBuy)
        XCTAssertEqual(drafts.first { $0.ingredientID == "egg" }?.kind, .split)
    }

    /// 순위 근거는 "이번 장보기에서 살 재료인가" 하나뿐이고, 내 글·불호 재료·마감된 글은 빠진다.
    func testRankSharePostsPrefersIngredientsIStillNeed() {
        let posts = [
            post("p1", "onion"),
            post("p2", "carrot"),
            post("p3", "onion", author: "me"),
            post("p4", "pork"),
            post("p5", "onion", status: .closed),
            post("p6", "egg", expiresIn: 60 * 60),
        ]
        let matches = rankSharePosts(
            posts,
            shoppingItems: [planItem("onion", needed: 1, remaining: 0), planItem("egg", needed: 2, remaining: 0)],
            dislikedIngredientIDs: ["pork"],
            myUserID: "me"
        )

        XCTAssertEqual(matches.map(\.id), ["p6", "p1", "p2"])
        XCTAssertEqual(matches.first?.score, 60, "마감이 24시간 안이면 가점이 붙는다")
        XCTAssertFalse(matches.last!.isRelevant)
    }

    func testCanJoinRejectsFullAndOwnAndDuplicatePosts() {
        XCTAssertTrue(post("p1", "onion").canJoin(userID: "me"))
        XCTAssertFalse(post("p1", "onion", author: "me").canJoin(userID: "me"), "내 글에는 참여하지 않는다")
        XCTAssertFalse(post("p1", "onion", participants: ["me"]).canJoin(userID: "me"), "이미 참여했다")
        XCTAssertFalse(post("p1", "onion", capacity: 2, participants: ["x"]).canJoin(userID: "me"), "작성자 포함 정원이 찼다")
        XCTAssertFalse(post("p1", "onion", expiresIn: -60).canJoin(userID: "me"), "기간이 지났다")
    }

    /// 채팅은 작성자와 참여자만 본다. 서버 규칙(`ios/firestore.rules`)도 같은 조건을 막는다.
    func testOnlyMembersSeeChat() {
        let target = post("p1", "onion", author: "author", participants: ["joined"])
        XCTAssertTrue(target.isMember("author"))
        XCTAssertTrue(target.isMember("joined"))
        XCTAssertFalse(target.isMember("stranger"))
    }

    func testMeetupPreservesScheduledDateAndPlaceThroughCodable() throws {
        let meetup = ShareMeetup(
            scheduledAt: Date(timeIntervalSince1970: 1_800_000_000),
            placeNote: "성수역 2번 출구 앞",
            updatedBy: "member-1",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let decoded = try JSONDecoder().decode(ShareMeetup.self, from: JSONEncoder().encode(meetup))
        XCTAssertEqual(decoded, meetup)
    }
}
