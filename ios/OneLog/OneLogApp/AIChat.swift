import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFunctions
import Foundation
import OSLog

enum AIChatRole: String, Hashable {
    case user
    case assistant
}

struct AIChatMessage: Identifiable, Hashable {
    let id: UUID
    let role: AIChatRole
    let text: String

    init(id: UUID = UUID(), role: AIChatRole, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

struct AIChatMealContext: Hashable {
    let date: String
    let slot: MealSlot
    let recipeID: String
    let title: String
}

struct AIChatRecipeContext: Hashable {
    let id: String
    let title: String
    let description: String
    let mealSlots: [MealSlot]
    let cookTime: Int
    let isLightBreakfast: Bool
    let ingredients: [String]
    let tags: [String]

    init(recipe: Recipe) {
        id = recipe.id
        title = recipe.title
        description = recipe.description
        mealSlots = recipe.mealSlots
        cookTime = recipe.cookTime ?? 0
        isLightBreakfast = recipe.isLightBreakfast
        ingredients = recipe.ingredients.map { ingredient(for: $0.ingredientID)?.name ?? $0.rawName }
        tags = recipe.tags
    }
}

struct AIChatInventoryContext: Hashable {
    let name: String
    let quantity: String
    let unit: String
}

struct AIChatPlanContext: Hashable {
    let title: String
    let startDate: String
    let days: Int
    let targetBudget: Int
    let meals: [AIChatMealContext]
    let dislikedIngredients: [String]
    let allergyIngredients: [String]
    let availableTools: [String]
    let inventory: [AIChatInventoryContext]
    let candidateRecipes: [AIChatRecipeContext]

    func callablePayload(message: String, history: [AIChatMessage]) -> [String: Any] {
        [
            "message": message,
            "history": history.suffix(12).map { [
                "role": $0.role.rawValue,
                "text": $0.text
            ] },
            "plan": [
                "title": title,
                "startDate": startDate,
                "days": days,
                "targetBudget": targetBudget,
                "meals": meals.map { [
                    "date": $0.date,
                    "slot": $0.slot.rawValue,
                    "recipeID": $0.recipeID,
                    "title": $0.title
                ] }
            ],
            "preferences": [
                "disliked": dislikedIngredients,
                "allergies": allergyIngredients,
                "tools": availableTools
            ],
            "inventory": inventory.map {
                [
                    "name": $0.name,
                    "quantity": $0.quantity,
                    "unit": $0.unit
                ]
            },
            "candidateRecipes": candidateRecipes.map { recipe in
                [
                    "id": recipe.id,
                    "title": recipe.title,
                    "description": recipe.description,
                    "mealSlots": recipe.mealSlots.map(\.rawValue),
                    "cookTime": recipe.cookTime,
                    "isLightBreakfast": recipe.isLightBreakfast,
                    "ingredients": recipe.ingredients,
                    "tags": recipe.tags
                ]
            }
        ]
    }
}

struct AIRecipeSuggestion: Identifiable, Hashable, Decodable {
    let recipeID: String
    let title: String
    let reason: String
    let action: String
    let targetDate: String
    let targetMealSlot: String
    let cookTimeMinutes: Int
    let ingredientCount: Int

    var id: String { "\(recipeID):\(targetDate):\(targetMealSlot)" }
    var targetSlot: MealSlot? { MealSlot(rawValue: targetMealSlot) }
    var actionTitle: String { action == "add" ? "식단에 추가" : "이 메뉴로 변경" }
    var metaText: String {
        let time = cookTimeMinutes > 0 ? "\(cookTimeMinutes)분" : "조리시간 확인 필요"
        return "\(time) · 재료 \(ingredientCount)개"
    }
}

struct AIChatResponse: Hashable, Decodable {
    let reply: String
    let suggestions: [AIRecipeSuggestion]
}

struct AIChatPlanSummary: Hashable {
    let title: String
    let subtitle: String
}

enum AIChatError: LocalizedError {
    case firebaseNotConfigured
    case emptyResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            return "AI 서버 연결을 준비하지 못했어요. Firebase 설정을 확인해 주세요."
        case .emptyResponse:
            return "AI 응답이 비어 있어요. 잠시 후 다시 시도해 주세요."
        case let .server(message):
            return message
        }
    }
}

protocol AIChatServing {
    func send(message: String, history: [AIChatMessage], context: AIChatPlanContext) async throws -> AIChatResponse
}

final class OpenAIChatService: AIChatServing {
    private static let logger = Logger(subsystem: "com.onelog.native", category: "AIChat")
    private let functions: Functions?

    init() {
        functions = FirebaseApp.app() == nil ? nil : Functions.functions(region: "us-central1")
    }

    func send(message: String, history: [AIChatMessage], context: AIChatPlanContext) async throws -> AIChatResponse {
        // 네트워크에 의존하지 않는 UI 스모크 테스트용 응답이다. 실제 앱에서는 callable 함수로 간다.
        if ProcessInfo.processInfo.arguments.contains("-uiTestAIChat") {
            return fixtureResponse(for: context)
        }

        guard let functions else { throw AIChatError.firebaseNotConfigured }
        try await ensureSignedIn()

        let result: HTTPSCallableResult
        do {
            result = try await functions
                .httpsCallable("aiChat")
                .call(context.callablePayload(message: message, history: history))
        } catch {
            let nsError = error as NSError
            Self.logger.error("Callable failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public) message=\(nsError.localizedDescription, privacy: .public)")
            throw Self.userFacingError(for: nsError)
        }

        guard let dictionary = result.data as? [String: Any] else {
            throw AIChatError.emptyResponse
        }
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        return try JSONDecoder().decode(AIChatResponse.self, from: data)
    }

    private func ensureSignedIn() async throws {
        guard Auth.auth().currentUser == nil else { return }
        _ = try await Auth.auth().signInAnonymously()
    }

    private static func userFacingError(for error: NSError) -> AIChatError {
        guard error.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: error.code) else {
            return .server("네트워크 연결을 확인한 뒤 다시 시도해 주세요.")
        }

        switch code {
        case .unauthenticated, .permissionDenied:
            return .server("앱 인증을 확인하지 못했어요. 앱을 다시 실행한 뒤 시도해 주세요.")
        case .resourceExhausted:
            return .server("AI 요청이 잠시 제한됐어요. 잠시 후 다시 시도해 주세요.")
        case .invalidArgument, .failedPrecondition:
            return .server(error.localizedDescription)
        case .deadlineExceeded, .unavailable:
            return .server("AI 서버 응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.")
        default:
            return .server("AI 응답을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
    }

    private func fixtureResponse(for context: AIChatPlanContext) -> AIChatResponse {
        guard let meal = context.meals.first else {
            return AIChatResponse(reply: "현재 식단에서 바꿀 수 있는 후보를 찾지 못했어요.", suggestions: [])
        }
        let candidate = context.candidateRecipes.first ?? recipes
            .first(where: { $0.mealSlots.contains(meal.slot) && $0.id != meal.recipeID })
            .map(AIChatRecipeContext.init)
        guard let candidate else {
            return AIChatResponse(reply: "현재 식단에서 바꿀 수 있는 후보를 찾지 못했어요.", suggestions: [])
        }
        return AIChatResponse(
            reply: "네, 그렇다면 ‘\(candidate.title)’은 어떠신가요?",
            suggestions: [AIRecipeSuggestion(
                recipeID: candidate.id,
                title: candidate.title,
                reason: "현재 식단의 끼니와 조리도구 조건에 맞는 후보예요.",
                action: "replace",
                targetDate: meal.date,
                targetMealSlot: meal.slot.rawValue,
                cookTimeMinutes: candidate.cookTime,
                ingredientCount: candidate.ingredients.count
            )]
        )
    }
}

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published private(set) var messages: [AIChatMessage] = [
        AIChatMessage(role: .assistant, text: "안녕하세요! 어떤 식사를 바꿔드릴까요? 😊")
    ]
    @Published private(set) var suggestions: [AIRecipeSuggestion] = []
    @Published private(set) var isSending = false
    @Published var errorMessage: String?

    private let service: AIChatServing
    private var failedRequest: (message: String, history: [AIChatMessage], context: AIChatPlanContext)?

    init(service: AIChatServing = OpenAIChatService()) {
        self.service = service
    }

    func send(message: String, context: AIChatPlanContext) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        let previousMessages = messages
        messages.append(AIChatMessage(role: .user, text: trimmed))
        suggestions = []
        errorMessage = nil
        isSending = true

        performSend(message: trimmed, history: previousMessages, context: context)
    }

    func retry() {
        guard !isSending, let failedRequest else { return }
        errorMessage = nil
        suggestions = []
        isSending = true
        performSend(
            message: failedRequest.message,
            history: failedRequest.history,
            context: failedRequest.context
        )
    }

    private func performSend(message: String, history: [AIChatMessage], context: AIChatPlanContext) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let response = try await service.send(message: message, history: history, context: context)
                messages.append(AIChatMessage(role: .assistant, text: response.reply))
                suggestions = response.suggestions
                failedRequest = nil
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "AI에게 연결하지 못했어요. 잠시 후 다시 시도해 주세요."
                failedRequest = (message, history, context)
            }
            isSending = false
        }
    }

    func markApplied(_ suggestion: AIRecipeSuggestion) {
        suggestions.removeAll { $0.id == suggestion.id }
        messages.append(AIChatMessage(role: .assistant, text: "‘\(suggestion.title)’ 메뉴를 식단에 반영했어요. 다른 끼니도 바꾸고 싶으면 말해 주세요."))
    }
}

/// 대화에서 보낼 후보를 로컬 카탈로그에서 고른다. AI에게 전체 레시피 JSON을 보내지 않고,
/// 사용자의 문장·찜·현재 식단과 가까운 후보만 보낸다. 계산 결과는 여전히 Swift 도메인 코드가 만든다.
func aiCandidateRecipes(
    for message: String,
    drafts: [PlannedMealDraft],
    preferences: AppPreferences,
    favorites: Set<String> = [],
    limit: Int = 80
) -> [Recipe] {
    let currentIDs = Set(drafts.map(\.recipeID))
    let query = message.lowercased()
    let terms = query
        .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == "·" })
        .map(String.init)
        .filter { $0.count >= 2 }
    let wantsLight = ["가벼", "부담", "간단", "빠르", "라이트"].contains { query.contains($0) }
    let wantsBreakfast = query.contains("아침")
    // 지금 식단에 있는 끼니에 넣을 수 없는 메뉴를 제안하면 적용 단계에서 되돌아온다.
    // 후보 단계에서 미리 걸러 둔다.
    let planSlots = Set(drafts.map(\.mealSlot))

    // 현재 식단에 이미 든 메뉴도 새 제안 후보가 되려면 같은 안전 필터를 통과해야 한다.
    let eligible = recipes.filter { candidate in
        guard isRecommendable(candidate, preferences: preferences) else { return false }
        guard fullyCalculableRecipeIDs.contains(candidate.id),
              candidate.ingredients.allSatisfy({ bundledIngredientPrices[$0.ingredientID] != nil }) else { return false }
        guard !planSlots.isEmpty else { return true }
        return !planSlots.isDisjoint(with: Set(candidate.mealSlots))
    }
    let ranked = eligible.sorted { lhs, rhs in
        score(lhs) > score(rhs)
    }
    return Array(ranked.prefix(max(1, limit)))

    func score(_ recipe: Recipe) -> Int {
        let searchable = ([recipe.title, recipe.description] + recipe.tags + recipe.ingredients.map { ingredient(for: $0.ingredientID)?.name ?? $0.rawName })
            .joined(separator: " ")
            .lowercased()
        var value = 0
        if currentIDs.contains(recipe.id) { value += 80 }
        if favorites.contains(recipe.id) { value += 22 }
        value += terms.reduce(0) { $0 + (searchable.contains($1.lowercased()) ? 18 : 0) }
        if wantsLight {
            if let cookTime = recipe.cookTime, cookTime <= 20 { value += 18 }
            if recipe.ingredients.count <= 6 { value += 10 }
        }
        if wantsBreakfast && recipe.isLightBreakfast { value += 14 }
        if let cookTime = recipe.cookTime { value += max(0, 12 - min(cookTime, 12)) }
        return value
    }
}
