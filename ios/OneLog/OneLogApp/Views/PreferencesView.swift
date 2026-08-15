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

/// F24 마이페이지. 프로필, 계정, 추천 설정, 데이터 삭제 경로를 한곳에서 관리한다.
struct MyPageView: View {
    @EnvironmentObject private var store: AppStore
    @State private var nickname = ""
    @State private var ageText = ""
    @State private var showingDeleteConfirm = false
    @State private var showingUnlinkConfirm = false

    private var preferences: AppPreferences { store.state.preferences }

    var body: some View {
        NavigationStack {
            Form {
                Section("프로필") {
                    TextField("닉네임 (선택)", text: $nickname)
                        .accessibilityIdentifier("mypage.nickname")
                    TextField("나이 (선택)", text: $ageText)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("mypage.age")
                    Button("프로필 저장") {
                        store.setProfile(nickname: nickname, age: Int(ageText))
                    }
                    .foregroundStyle(Color.oneLogGreen)
                    .accessibilityIdentifier("mypage.saveProfile")
                    Text("닉네임과 나이는 앱 안내 문구에만 쓰고, 비워서 저장하면 지워져요.")
                        .font(.caption)
                        .foregroundStyle(Color.oneLogMuted)
                }

                Section("계정") {
                    if let account = store.state.account {
                        LabeledContent("연결 상태", value: account.provider.label)
                        if let email = account.email {
                            LabeledContent("이메일", value: email)
                        }
                        if account.provider == .deviceOnly {
                            Button("Google 계정 연결하기") { store.signInWithGoogle() }
                                .foregroundStyle(Color.oneLogGreen)
                        }
                        Button("계정 연결 해제") { showingUnlinkConfirm = true }
                            .foregroundStyle(Color.oneLogOrange)
                    } else {
                        Text("연결한 계정이 없어요. 이 기기에만 저장하고 있어요.")
                            .font(.footnote)
                            .foregroundStyle(Color.oneLogMuted)
                        Button("Google 계정 연결하기") { store.signInWithGoogle() }
                            .foregroundStyle(Color.oneLogGreen)
                        Button("이 기기에만 저장하기") { store.useDeviceOnlyAccount() }
                            .foregroundStyle(Color.oneLogGreen)
                    }
                    if let error = store.accountError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Color.oneLogOrange)
                    }
                }

                Section("추천 설정") {
                    NavigationLink {
                        PreferencesView()
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("불호 재료·메뉴와 조리도구")
                            Text("제외 재료 \(preferences.dislikedIngredientIDs.count)개 · 제외 메뉴 \(preferences.dislikedRecipeIDs.count)개 · 조리도구 \(preferences.availableTools.count)개")
                                .font(.caption)
                                .foregroundStyle(Color.oneLogMuted)
                        }
                    }
                    .accessibilityIdentifier("mypage.preferences")
                }

                if !externalDataSources.isEmpty {
                    Section("레시피 데이터 출처") {
                        ForEach(externalDataSources, id: \.self) { source in
                            Text(source)
                                .font(.caption)
                                .foregroundStyle(Color.oneLogMuted)
                        }
                        Text("판매 단위가 확인되지 않은 재료는 구매량과 금액을 계산하지 않고 확인 품목으로 표시해요.")
                            .font(.caption)
                            .foregroundStyle(Color.oneLogMuted)
                    }
                }

                Section("저장한 데이터") {
                    LabeledContent("식사 계획", value: "\(store.state.plannedMeals.count)개")
                    LabeledContent("냉장고 재료", value: "\(store.state.inventory.count)개")
                    Text("모든 데이터는 이 기기에만 저장돼요. 위치 정보와 결제 정보는 수집하지 않아요.")
                        .font(.caption)
                        .foregroundStyle(Color.oneLogMuted)
                    Button("계정 탈퇴하고 데이터 모두 지우기", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                    .accessibilityIdentifier("mypage.deleteAll")
                }
            }
            .navigationTitle("마이페이지")
            .onAppear {
                nickname = store.state.profile.nickname
                ageText = store.state.profile.age.map(String.init) ?? ""
            }
            .confirmationDialog("계정 연결을 해제할까요?", isPresented: $showingUnlinkConfirm, titleVisibility: .visible) {
                Button("연결 해제", role: .destructive) { store.unlinkAccount() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("이 기기에 저장한 식단과 재고는 그대로 남아요.")
            }
            .confirmationDialog("정말 모두 지울까요?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("모두 지우기", role: .destructive) { store.deleteAllData() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("식단, 재고, 장보기 기록, 프로필이 모두 사라지고 되돌릴 수 없어요.")
            }
        }
    }
}
