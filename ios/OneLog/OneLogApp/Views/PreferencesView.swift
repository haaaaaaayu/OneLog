import SwiftUI

/// 불호 재료·불호 메뉴·조리도구 편집 섹션. 온보딩과 마이페이지가 함께 사용한다.
/// 재료 1,400여 종과 레시피 950여 건을 전부 토글로 그리지 않고 검색으로 좁힌다.
struct PreferenceSections: View {
    @Binding var dislikedIngredients: Set<String>
    @Binding var dislikedRecipes: Set<String>
    @Binding var availableTools: Set<CookingTool>
    @State private var query = ""

    private static let listLimit = 30

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// 검색어가 없으면 판매 단위가 확인된 기본 재료와 이미 고른 재료만 보여준다.
    private var visibleIngredients: [CanonicalIngredient] {
        if normalizedQuery.isEmpty {
            return ingredients.filter { curatedIngredientIDs.contains($0.id) || dislikedIngredients.contains($0.id) }
        }
        return Array(ingredients.filter { $0.name.lowercased().contains(normalizedQuery) }.prefix(Self.listLimit))
    }

    private var visibleRecipes: [Recipe] {
        if normalizedQuery.isEmpty {
            return recipes.filter { dislikedRecipes.contains($0.id) }
        }
        return Array(recipes.filter { $0.title.lowercased().contains(normalizedQuery) }.prefix(Self.listLimit))
    }

    var body: some View {
        Section {
            TextField("재료나 메뉴 이름으로 검색", text: $query)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("preferences.search")
        } footer: {
            Text("재료 \(ingredients.count)종, 메뉴 \(recipes.count)개 중에서 찾아요.")
        }

        Section("자동 추천에서 제외할 재료") {
            if visibleIngredients.isEmpty {
                Text(normalizedQuery.isEmpty ? "제외한 재료가 없어요." : "검색 결과가 없어요.")
                    .font(.footnote)
                    .foregroundStyle(Color.oneLogMuted)
            }
            ForEach(visibleIngredients) { item in
                Toggle(isOn: binding(dislikedIngredients.contains(item.id)) { selected in
                    if selected { dislikedIngredients.insert(item.id) } else { dislikedIngredients.remove(item.id) }
                }) {
                    Text(item.name)
                }
            }
        }

        Section("자동 추천에서 제외할 메뉴") {
            if visibleRecipes.isEmpty {
                Text(normalizedQuery.isEmpty ? "제외한 메뉴가 없어요. 위에서 검색해 고를 수 있어요." : "검색 결과가 없어요.")
                    .font(.footnote)
                    .foregroundStyle(Color.oneLogMuted)
            }
            ForEach(visibleRecipes) { recipe in
                Toggle(isOn: binding(dislikedRecipes.contains(recipe.id)) { selected in
                    if selected { dislikedRecipes.insert(recipe.id) } else { dislikedRecipes.remove(recipe.id) }
                }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(recipe.symbolName) \(recipe.title)")
                        Text(recipe.mealSlots.map(\.rawValue).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(Color.oneLogMuted)
                    }
                }
            }
        }

        Section("사용할 수 있는 조리도구") {
            ForEach(CookingTool.allCases) { tool in
                Toggle(isOn: binding(availableTools.contains(tool)) { selected in
                    if selected { availableTools.insert(tool) } else { availableTools.remove(tool) }
                }) {
                    Label(tool.rawValue, systemImage: tool.symbolName)
                }
            }
        }
    }

    private func binding(_ value: Bool, set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding { value } set: { set($0) }
    }
}

struct PreferencesView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var dislikedIngredients: Set<String> = []
    @State private var dislikedRecipes: Set<String> = []
    @State private var availableTools: Set<CookingTool> = Set(CookingTool.allCases)

    var body: some View {
        Form {
            Section {
                Text("이 설정은 식단 제안에서만 사용해요. 직접 고른 레시피를 조용히 삭제하지 않고 주의 문구로 알려드려요.")
                    .font(.footnote)
                    .foregroundStyle(Color.oneLogMuted)
            }

            PreferenceSections(dislikedIngredients: $dislikedIngredients, dislikedRecipes: $dislikedRecipes, availableTools: $availableTools)

            Section {
                Button("추천 설정 저장") {
                    store.setPreferences(dislikedIngredientIDs: dislikedIngredients, dislikedRecipeIDs: dislikedRecipes, availableTools: availableTools)
                    dismiss()
                }
                .font(.body.weight(.bold))
                .foregroundStyle(Color.oneLogGreen)
                .accessibilityIdentifier("preferences.save")
            }
        }
        .navigationTitle("추천 설정")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            dislikedIngredients = store.state.preferences.dislikedIngredientIDs
            dislikedRecipes = store.state.preferences.dislikedRecipeIDs
            availableTools = store.state.preferences.availableTools
        }
    }
}
