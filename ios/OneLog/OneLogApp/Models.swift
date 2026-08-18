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
    /// F22 미취식. 재료를 차감하지 않고 그 끼니만 쉬어 간다(피그마 `식단 관리 4`의 `오늘만 비활성화`).
    case skipped

    var label: String {
        switch self {
        case .planned: return "예정"
        case .cooked: return "완료"
        case .skipped: return "건너뜀"
        }
    }
}

enum CookingTool: String, CaseIterable, Codable, Identifiable, Hashable {
    case pan = "프라이팬"
    case pot = "냄비"
    case microwave = "전자레인지"
    case airfryer = "에어프라이어"
    case oven = "오븐"
    case blender = "믹서기"
    case knife = "칼"
    case bowl = "볼"

    /// 피그마 `첫가입 / 2. 조리도구`(350:2304)에 놓인 6개. 칼·볼은 화면에 없고 항상 보유로 둔다.
    static let selectable: [CookingTool] = [.pan, .microwave, .airfryer, .oven, .pot, .blender]

    var id: String { rawValue }
    var symbolName: String {
        switch self {
        case .pan: return "frying.pan"
        case .pot: return "cooktop"
        case .microwave: return "microwave"
        case .airfryer: return "wind"
        case .oven: return "oven"
        case .blender: return "blender"
        case .knife: return "fork.knife"
        case .bowl: return "takeoutbag.and.cup.and.straw"
        }
    }

    /// 피그마에서 내려받은 아이콘. 화면에 없는 도구는 값이 없다.
    var assetName: String? {
        switch self {
        case .pan: return "ToolPan"
        case .microwave: return "ToolMicrowave"
        case .airfryer: return "ToolAirfryer"
        case .oven: return "ToolOven"
        case .pot: return "ToolPot"
        case .blender: return "ToolBlender"
        case .knife, .bowl: return nil
        }
    }
}

/// 피그마 `기본정보 / 요리 숙련도`(350:2282) 칩.
enum CookingSkill: String, CaseIterable, Codable, Identifiable, Hashable {
    case beginner = "하수"
    case intermediate = "중수"
    case advanced = "고수"

    var id: String { rawValue }
}

/// 피그마 `기본정보 / 선호 조리 시간`(350:2291) 칩.
enum CookTimePreference: String, CaseIterable, Codable, Identifiable, Hashable {
    case under10 = "10분 이하"
    case under20 = "20분 이하"
    case over30 = "30분 이상"
    case any = "상관없어요"

    var id: String { rawValue }
}

/// 피그마 `첫가입 / 3. 불호 재료`(368:24) 칩 목록.
let dislikedIngredientChoices = ["오이", "버섯", "가지", "고수", "당근", "대파", "양파"]

/// 피그마 `첫가입 / 4. 알레르기 재료`(370:60) 칩 목록.
let allergyChoices = ["해산물", "유제품", "견과류", "계란", "밀(글루텐)", "갑각류"]

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
    /// 원본에 완성 사진이 있는 경우에만 값이 있다. 큐레이션 레시피에는 없다.
    var imageURL: String? = nil

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
/// 동네는 F26 동네 나눔에서 쓰는 사용자 자기입력 문자열이다. 좌표는 F25의
/// WhenInUse 1회 측정 결과를 약 100m 격자로 반올림한 값만 저장한다.
struct UserProfile: Codable, Hashable {
    var nickname: String = ""
    var age: Int?
    var neighborhood: String = ""
    /// 피그마 `기본정보 / 생년월일`. `YYYY-MM-DD` 문자열이고 비어 있으면 미입력이다.
    var birthDate: String = ""
    /// F25 위치. **2026-08-18 사용자 확정**으로 GPS를 쓴다. 약 100m 격자로 반올림한 값만 담는다.
    var coordinate: ShareCoordinate?

    private enum CodingKeys: String, CodingKey {
        case nickname
        case age
        case neighborhood
        case birthDate
        case coordinate
    }

    // 커스텀 이니셜라이저가 생기면 멤버와이즈 이니셜라이저가 사라지므로 직접 둔다.
    init(nickname: String = "", age: Int? = nil, neighborhood: String = "", birthDate: String = "", coordinate: ShareCoordinate? = nil) {
        self.nickname = nickname
        self.age = age
        self.neighborhood = neighborhood
        self.birthDate = birthDate
        self.coordinate = coordinate
    }

    // 기본값만으로는 예전 저장 데이터가 디코딩되지 않으므로 키 단위로 복구한다.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        age = try container.decodeIfPresent(Int.self, forKey: .age)
        neighborhood = try container.decodeIfPresent(String.self, forKey: .neighborhood) ?? ""
        birthDate = try container.decodeIfPresent(String.self, forKey: .birthDate) ?? ""
        coordinate = try container.decodeIfPresent(ShareCoordinate.self, forKey: .coordinate)
    }
}

struct AppPreferences: Codable, Hashable {
    var dislikedIngredientIDs: Set<String> = []
    var dislikedRecipeIDs: Set<String> = []
    var availableTools: Set<CookingTool> = Set(CookingTool.allCases)
    /// 알레르기·못 먹는 재료. 불호와 달리 추천에서 완전히 제외한다.
    var allergyIngredientIDs: Set<String> = []
    /// 재료 사전에 없는 칩과 직접 입력값은 이름 그대로 남긴다.
    var customDislikedNames: Set<String> = []
    var customAllergyNames: Set<String> = []
    var cookingSkill: CookingSkill?
    var preferredCookTime: CookTimePreference?

    private enum CodingKeys: String, CodingKey {
        case dislikedIngredientIDs
        case dislikedRecipeIDs
        case availableTools
        case allergyIngredientIDs
        case customDislikedNames
        case customAllergyNames
        case cookingSkill
        case preferredCookTime
    }

    init() {}

    // 기본값만으로는 예전 저장 데이터가 디코딩되지 않으므로 키 단위로 복구한다.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dislikedIngredientIDs = try container.decodeIfPresent(Set<String>.self, forKey: .dislikedIngredientIDs) ?? []
        dislikedRecipeIDs = try container.decodeIfPresent(Set<String>.self, forKey: .dislikedRecipeIDs) ?? []
        // 저장된 도구 목록에 모르는 값이 있어도 설정 전체를 잃지 않는다.
        let toolNames = try container.decodeIfPresent(Set<String>.self, forKey: .availableTools)
        availableTools = toolNames.map { Set($0.compactMap(CookingTool.init(rawValue:))) } ?? Set(CookingTool.allCases)
        allergyIngredientIDs = try container.decodeIfPresent(Set<String>.self, forKey: .allergyIngredientIDs) ?? []
        customDislikedNames = try container.decodeIfPresent(Set<String>.self, forKey: .customDislikedNames) ?? []
        customAllergyNames = try container.decodeIfPresent(Set<String>.self, forKey: .customAllergyNames) ?? []
        cookingSkill = try container.decodeIfPresent(String.self, forKey: .cookingSkill).flatMap(CookingSkill.init(rawValue:))
        preferredCookTime = try container.decodeIfPresent(String.self, forKey: .preferredCookTime).flatMap(CookTimePreference.init(rawValue:))
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
    /// 확정한 식단의 목표 예산. 식단관리 화면이 남은 예산을 보여줄 때 쓴다. 0이면 아직 정하지 않은 상태다.
    var targetBudget = 0

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
        case targetBudget
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
        targetBudget = try container.decodeIfPresent(Int.self, forKey: .targetBudget) ?? 0
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
        try container.encode(targetBudget, forKey: .targetBudget)
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
    /// 식단 생성 중에도 사용자가 확인한 판매 단위를 같은 계산기에 전달한다.
    var packageOverrides: [String: PackageSize] = [:]
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
