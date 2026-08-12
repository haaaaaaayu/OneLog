import Foundation

enum MealSlot: String, CaseIterable, Codable, Identifiable, Hashable {
    case breakfast = "아침"
    case lunch = "점심"
    case dinner = "저녁"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        }
    }
}

enum Unit: String, CaseIterable, Codable, Identifiable, Hashable {
    case gram = "g"
    case milliliter = "ml"
    case count = "개"
    case tablespoon = "큰술"
    case teaspoon = "작은술"
    case sheet = "장"
    case bag = "봉"
    case pack = "팩"

    var id: String { rawValue }
}

enum QuantityStatus: String, Codable, Hashable {
    case exact
    case unknown
}

enum MealStatus: String, Codable, Hashable {
    case planned
    case cooked
}

enum CookingTool: String, CaseIterable, Codable, Identifiable, Hashable {
    case pan = "프라이팬"
    case pot = "냄비"
    case microwave = "전자레인지"
    case knife = "칼"
    case bowl = "볼"

    var id: String { rawValue }
    var symbolName: String {
        switch self {
        case .pan: return "frying.pan"
        case .pot: return "cooktop"
        case .microwave: return "microwave"
        case .knife: return "fork.knife"
        case .bowl: return "takeoutbag.and.cup.and.straw"
        }
    }
}

struct PackageSize: Codable, Hashable {
    var amount: Double
    var unit: Unit
    var label: String
}

struct CanonicalIngredient: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let aliases: [String]
    let defaultUnit: Unit
    /// 마트 판매 단위가 확인된 재료만 값이 있다. 없으면 구매량을 계산하지 않고 사용자에게 확인을 요청한다.
    let representativeSaleUnit: PackageSize?
    let storageNote: String?
    /// 이 재료에 한해 확인된 단위별 무게(g). 여기 적힌 단위끼리만 환산한다.
    /// 예: 양파 ["개": 200, "g": 1]. 근거 없는 질량↔부피↔개수 환산은 하지 않는다(AGENTS 8절).
    let unitGrams: [String: Double]?
}

struct RecipeIngredient: Codable, Hashable, Identifiable {
    let ingredientID: String
    let rawName: String
    let quantity: Double
    let unit: Unit
    let preparation: String?

    var id: String { "\(ingredientID):\(unit.rawValue):\(rawName)" }
}

struct Recipe: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let description: String
    let mealSlots: [MealSlot]
    /// 원본 데이터에 명시된 경우에만 값이 있다. 없으면 추천에서 보조 기준으로 쓰지 않는다(AGENTS 8절).
    let difficulty: Int?
    let cookTime: Int?
    let servings: Int
    let symbolName: String
    let ingredients: [RecipeIngredient]
    let steps: [String]
    let tags: [String]
    let isLightBreakfast: Bool
    let requiredTools: Set<CookingTool>

    var cookTimeText: String { cookTime.map { "\($0)분" } ?? "조리시간 미확인" }
    var difficultyText: String? { difficulty.map { "난이도 " + String(repeating: "★", count: max(1, min($0, 5))) } }
}

struct PlannedMeal: Codable, Hashable, Identifiable {
    let id: String
    var recipeID: String
    var date: String
    var mealSlot: MealSlot
    var status: MealStatus
    let createdAt: String
}

struct InventoryItem: Codable, Hashable, Identifiable {
    let ingredientID: String
    var quantity: Double?
    let unit: Unit
    var quantityStatus: QuantityStatus
    var updatedAt: String

    var id: String { "\(ingredientID):\(unit.rawValue)" }
}

struct CookingConsumption: Codable, Hashable {
    let ingredientID: String
    let unit: Unit
    let expectedQuantity: Double
    let actualQuantity: Double
    let remainingQuantity: Double?
}

struct CookingCompletion: Codable, Hashable, Identifiable {
    let plannedMealID: String
    let recipeID: String
    let completedAt: String
    let consumptions: [CookingConsumption]

    var id: String { plannedMealID }
}

struct IngredientPrice: Codable, Hashable {
    let price: Int
    let packageAmount: Double
    let unit: Unit
    let confirmedAt: String
    let source: String
}

enum ShoppingEventAction: String, Codable, Hashable {
    case itemChecked
    case quantityAdjusted
    case purchaseConfirmed
    case listCopied
    case listShared
}

struct ShoppingEvent: Codable, Hashable, Identifiable {
    let id: String
    let action: ShoppingEventAction
    let itemIDs: [String]
    let createdAt: String
}

enum AccountProvider: String, Codable, Hashable {
    case google
    case deviceOnly

    var label: String {
        switch self {
        case .google: return "Google 계정"
        case .deviceOnly: return "이 기기에만 저장"
        }
    }
}

struct UserAccount: Codable, Hashable {
    let provider: AccountProvider
    let userID: String
    let email: String?
    let displayName: String?
    let linkedAt: String
}

/// 목적에 필요한 최소 범위만 수집한다(AGENTS 11절). 나이는 선택 입력이며 비우면 저장하지 않는다.
struct UserProfile: Codable, Hashable {
    var nickname: String = ""
    var age: Int?
}

struct AppPreferences: Codable, Hashable {
    var dislikedIngredientIDs: Set<String> = []
    var dislikedRecipeIDs: Set<String> = []
    var availableTools: Set<CookingTool> = Set(CookingTool.allCases)

    private enum CodingKeys: String, CodingKey {
        case dislikedIngredientIDs
        case dislikedRecipeIDs
        case availableTools
    }

    init() {}

    // 기본값만으로는 예전 저장 데이터가 디코딩되지 않으므로 키 단위로 복구한다.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dislikedIngredientIDs = try container.decodeIfPresent(Set<String>.self, forKey: .dislikedIngredientIDs) ?? []
        dislikedRecipeIDs = try container.decodeIfPresent(Set<String>.self, forKey: .dislikedRecipeIDs) ?? []
        availableTools = try container.decodeIfPresent(Set<CookingTool>.self, forKey: .availableTools) ?? Set(CookingTool.allCases)
    }
}

struct AppState: Codable {
    var hasCompletedOnboarding = false
    var account: UserAccount?
    var profile = UserProfile()
    var favorites: [String] = []
    var plannedMeals: [PlannedMeal] = []
    var inventory: [InventoryItem] = []
    var packageOverrides: [String: PackageSize] = [:]
    var completions: [CookingCompletion] = []
    var prices: [String: IngredientPrice] = [:]
    var purchaseChecks: [String: Bool] = [:]
    var purchaseQuantityOverrides: [String: Double] = [:]
    var appliedPurchaseSignatures: [String] = []
    var preferences = AppPreferences()
    var shoppingEvents: [ShoppingEvent] = []

    private enum CodingKeys: String, CodingKey {
        case hasCompletedOnboarding
        case account
        case profile
        case favorites
        case plannedMeals
        case inventory
        case packageOverrides
        case completions
        case prices
        case purchaseChecks
        case purchaseQuantityOverrides
        case appliedPurchaseSignatures
        case preferences
        case shoppingEvents
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        account = try container.decodeIfPresent(UserAccount.self, forKey: .account)
        profile = try container.decodeIfPresent(UserProfile.self, forKey: .profile) ?? UserProfile()
        favorites = try container.decodeIfPresent([String].self, forKey: .favorites) ?? []
        plannedMeals = try container.decodeIfPresent([PlannedMeal].self, forKey: .plannedMeals) ?? []
        inventory = try container.decodeIfPresent([InventoryItem].self, forKey: .inventory) ?? []
        packageOverrides = try container.decodeIfPresent([String: PackageSize].self, forKey: .packageOverrides) ?? [:]
        completions = try container.decodeIfPresent([CookingCompletion].self, forKey: .completions) ?? []
        prices = try container.decodeIfPresent([String: IngredientPrice].self, forKey: .prices) ?? [:]
        purchaseChecks = try container.decodeIfPresent([String: Bool].self, forKey: .purchaseChecks) ?? [:]
        purchaseQuantityOverrides = try container.decodeIfPresent([String: Double].self, forKey: .purchaseQuantityOverrides) ?? [:]
        appliedPurchaseSignatures = try container.decodeIfPresent([String].self, forKey: .appliedPurchaseSignatures) ?? []
        preferences = try container.decodeIfPresent(AppPreferences.self, forKey: .preferences) ?? AppPreferences()
        shoppingEvents = try container.decodeIfPresent([ShoppingEvent].self, forKey: .shoppingEvents) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encodeIfPresent(account, forKey: .account)
        try container.encode(profile, forKey: .profile)
        try container.encode(favorites, forKey: .favorites)
        try container.encode(plannedMeals, forKey: .plannedMeals)
        try container.encode(inventory, forKey: .inventory)
        try container.encode(packageOverrides, forKey: .packageOverrides)
        try container.encode(completions, forKey: .completions)
        try container.encode(prices, forKey: .prices)
        try container.encode(purchaseChecks, forKey: .purchaseChecks)
        try container.encode(purchaseQuantityOverrides, forKey: .purchaseQuantityOverrides)
        try container.encode(appliedPurchaseSignatures, forKey: .appliedPurchaseSignatures)
        try container.encode(preferences, forKey: .preferences)
        try container.encode(shoppingEvents, forKey: .shoppingEvents)
    }
}

struct IngredientRequirement: Identifiable, Hashable {
    let key: String
    let ingredientID: String
    let ingredientName: String
    var quantity: Double
    let unit: Unit
    var recipeIDs: [String]
    let unitConflict: Bool

    var id: String { key }
}

struct ShoppingPlanItem: Identifiable, Hashable {
    let requirement: IngredientRequirement
    let availableQuantity: Double?
    let quantityStatus: QuantityStatus
    let additionalNeeded: Double
    let packageSize: PackageSize
    let purchaseQuantity: Int
    let purchaseTotal: Double
    let expectedRemaining: Double?
    let precision: Precision
    let note: String?

    enum Precision: String, Hashable {
        case exact
        case estimated
        case manual
    }

    var id: String { requirement.key }
    var ingredientID: String { requirement.ingredientID }
    var ingredientName: String { requirement.ingredientName }
    var quantity: Double { requirement.quantity }
    var unit: Unit { requirement.unit }
}

struct BudgetLineItem: Identifiable, Hashable {
    let shoppingItem: ShoppingPlanItem
    let price: IngredientPrice?
    let knownCost: Int?
    let avoidedPackageCount: Int

    var id: String { shoppingItem.id }
}

struct BudgetEstimate: Hashable {
    let targetBudget: Int
    let lineItems: [BudgetLineItem]
    let knownPurchaseCost: Int
    let confirmedInventorySavings: Int
    let unknownCostIngredientIDs: [String]

    var isComplete: Bool { unknownCostIngredientIDs.isEmpty }
    var remainingBudget: Int? { isComplete ? targetBudget - knownPurchaseCost : nil }
}

struct PlannedMealDraft: Identifiable, Hashable {
    let recipeID: String
    let date: String
    let mealSlot: MealSlot
    var reason: String
    var reusedIngredientIDs: [String]
    var newPurchaseCount: Int

    var id: String { "\(date):\(mealSlot.rawValue)" }
}

struct MealPlanOption: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    var drafts: [PlannedMealDraft]
    let reason: String
    let sharedIngredientNames: [String]
    let unfilledSlots: Int
}

struct PlanRequest {
    let startDate: String
    let days: Int
    let slotsByDate: [String: Set<MealSlot>]
    let targetBudget: Int
    let favorites: Set<String>
    let inventory: [InventoryItem]
    let prices: [String: IngredientPrice]
    let preferences: AppPreferences
}

struct LeftoverRecommendation: Identifiable, Hashable {
    let recipe: Recipe
    let usedIngredientIDs: [String]
    let additionalPurchaseItems: [ShoppingPlanItem]
    let reason: String
    let score: Int

    var id: String { recipe.id }
}

struct UpgradeSuggestion: Identifiable, Hashable {
    let id: String
    let originalRecipeID: String
    let replacementRecipeID: String
    let date: String
    let mealSlot: MealSlot
    let additionalCost: Int
    let reason: String
}

enum PlanStage: Equatable {
    case setup
    case options
    case budgetReview
}

struct PlanSlotKey: Hashable, Identifiable {
    let date: String
    let slot: MealSlot
    var id: String { "\(date):\(slot.rawValue)" }
}

func formatQuantity(_ value: Double?, unit: Unit? = nil) -> String {
    guard let value else { return "수량 미상" }
    guard value.isFinite else { return "확인 필요" }
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = false
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 3
    let number = formatter.string(from: NSNumber(value: value)) ?? String(value)
    return unit.map { "\(number)\($0.rawValue)" } ?? number
}

func won(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "ko_KR")
    return "\(formatter.string(from: NSNumber(value: value)) ?? String(value))원"
}

private var koreanCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
    return calendar
}

func isoDateString(_ date: Date = Date()) -> String {
    let components = koreanCalendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
}

func dateByAddingDays(_ dateString: String, _ days: Int) -> String {
    let formatter = DateFormatter()
    formatter.calendar = koreanCalendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: dateString), let result = koreanCalendar.date(byAdding: .day, value: days, to: date) else {
        return dateString
    }
    return formatter.string(from: result)
}

func displayDate(_ dateString: String) -> String {
    let formatter = DateFormatter()
    formatter.calendar = koreanCalendar
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일 (E)"
    let input = DateFormatter()
    input.calendar = koreanCalendar
    input.locale = Locale(identifier: "en_US_POSIX")
    input.dateFormat = "yyyy-MM-dd"
    guard let date = input.date(from: dateString) else { return dateString }
    return formatter.string(from: date)
}
