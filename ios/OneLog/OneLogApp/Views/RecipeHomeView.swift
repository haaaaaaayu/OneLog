import SwiftUI

struct RecipeHomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var search = ""
    @State private var selectedMealSlot: MealSlot?
    @State private var selectedRecipe: Recipe?
    @State private var selectedDate = Date()
    @State private var addSlot: MealSlot = .dinner
    @State private var showingPreferences = false
    @State private var showingMyPage = false
    @State private var onlyCalculable = false

    private var filteredRecipes: [Recipe] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return recipes.filter { recipe in
            let matchesSlot = selectedMealSlot == nil || recipe.mealSlots.contains(selectedMealSlot!)
            let matchesCalculable = !onlyCalculable || fullyCalculableRecipeIDs.contains(recipe.id)
            let searchable = ([recipe.title, recipe.description] + recipe.tags + recipe.ingredients.compactMap { ingredient(for: $0.ingredientID)?.name }).joined(separator: " ").lowercased()
            return matchesSlot && matchesCalculable && (query.isEmpty || searchable.contains(query))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    quickStatus
                    addPlanControls
                    recipeExplorer
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
            .background(Color.oneLogCream)
            .navigationTitle("한끼로그")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingPreferences = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("추천 설정")
                }
                // 아이폰 탭 바는 5개까지만 직접 보여주므로 마이페이지는 툴바에 둔다.
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingMyPage = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("마이페이지")
                    .accessibilityIdentifier("home.myPage")
                }
            }
            .sheet(item: $selectedRecipe) { recipe in
                RecipeDetailView(recipe: recipe, defaultDate: selectedDate, defaultSlot: addSlot)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingPreferences) {
                NavigationStack {
                    PreferencesView()
                }
            }
            .sheet(isPresented: $showingMyPage) {
                MyPageView()
                    .environmentObject(store)
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "남아서 버리는 식재료를, 다음 한 끼로.")
            Text(store.state.profile.nickname.isEmpty ? "오늘 먹고 싶은 메뉴를\n먼저 골라요." : "\(store.state.profile.nickname)님,\n오늘 먹고 싶은 메뉴를 골라요.")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(Color.oneLogInk)
                .fixedSize(horizontal: false, vertical: true)
            Text("선택한 메뉴를 기준으로 필요한 재료와 구매량, 남은 재료로 이어질 다음 메뉴까지 계산해요.")
                .font(.subheadline)
                .foregroundStyle(Color.oneLogMuted)
                .lineSpacing(3)
        }
        .oneLogCard(fill: Color.oneLogPaleGreen)
    }

    private var quickStatus: some View {
        HStack(spacing: 10) {
            NavigationLink {
                MealsView()
                    .environmentObject(store)
            } label: {
                StatusSummary(title: "내 식사", value: store.plannedMeals.filter { $0.status == .planned }.count, caption: "요리 전 계획", tint: .oneLogGreen)
            }
            .buttonStyle(.plain)
            NavigationLink {
                ShoppingView()
                    .environmentObject(store)
            } label: {
                StatusSummary(title: "장보기", value: store.currentShoppingItems.filter { $0.purchaseQuantity > 0 }.count, caption: "추가 구매 품목", tint: .oneLogOrange)
            }
            .buttonStyle(.plain)
            NavigationLink {
                FridgeView()
                    .environmentObject(store)
            } label: {
                StatusSummary(title: "냉장고", value: store.state.inventory.count, caption: "기록한 재료", tint: .oneLogGreen)
            }
            .buttonStyle(.plain)
        }
    }

    private var addPlanControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("바로 내 식사로 담기", subtitle: "레시피 카드에서 원하는 메뉴를 고른 뒤 날짜와 끼니를 정해요.")
            HStack(spacing: 10) {
                DatePicker("날짜", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                Picker("끼니", selection: $addSlot) {
                    ForEach(MealSlot.allCases) { slot in
                        Text(slot.rawValue).tag(slot)
                    }
                }
                .pickerStyle(.menu)
                .tint(.oneLogGreen)
            }
            .oneLogCard()
        }
    }

    private var recipeExplorer: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading("먹고 싶은 메뉴를 찾아보세요", subtitle: "\(recipes.count)개 중 \(fullyCalculableRecipeIDs.count)개는 살 양까지 바로 계산돼요.")
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.oneLogMuted)
                TextField("메뉴나 재료로 검색", text: $search)
                    .textInputAutocapitalization(.never)
            }
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.oneLogLine, lineWidth: 1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterButton(title: "전체", isSelected: selectedMealSlot == nil) { selectedMealSlot = nil }
                    ForEach(MealSlot.allCases) { slot in
                        filterButton(title: slot.rawValue, isSelected: selectedMealSlot == slot) { selectedMealSlot = slot }
                    }
                    Divider().frame(height: 22)
                    filterButton(title: "구매량 계산 가능", isSelected: onlyCalculable) { onlyCalculable.toggle() }
                        .accessibilityIdentifier("home.calculableFilter")
                }
            }

            if filteredRecipes.isEmpty {
                EmptyState(symbol: "fork.knife.circle", title: "조건에 맞는 레시피가 없어요", message: "검색어를 지우거나 다른 끼니를 선택해 보세요.")
                    .oneLogCard()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredRecipes) { recipe in
                        RecipeCard(recipe: recipe, isFavorite: store.state.favorites.contains(recipe.id), addDate: selectedDate, addSlot: addSlot) {
                            store.toggleFavorite(recipe.id)
                        } onDetail: {
                            selectedRecipe = recipe
                        } onAdd: {
                            store.addPlannedMeal(recipeID: recipe.id, date: isoDateString(selectedDate), slot: addSlot)
                        }
                    }
                }
            }
        }
    }

    private func filterButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isSelected ? .white : Color.oneLogGreen)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isSelected ? Color.oneLogGreen : Color.oneLogPaleGreen, in: Capsule())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct StatusSummary: View {
    let title: String
    let value: Int
    let caption: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.oneLogMuted)
            Text("\(value)")
                .font(.title2.weight(.black))
                .foregroundStyle(tint)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(Color.oneLogMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .oneLogCard()
    }
}

private struct RecipeCard: View {
    let recipe: Recipe
    let isFavorite: Bool
    let addDate: Date
    let addSlot: MealSlot
    let onFavorite: () -> Void
    let onDetail: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Text(recipe.symbolName)
                    .font(.system(size: 42))
                    .frame(width: 68, height: 68)
                    .background(Color.oneLogPaleGreen, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(recipe.title)
                            .font(.headline.weight(.black))
                            .foregroundStyle(Color.oneLogInk)
                        Spacer()
                        Button(action: onFavorite) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .foregroundStyle(isFavorite ? Color.oneLogOrange : Color.oneLogMuted)
                                .font(.title3)
                        }
                        .accessibilityLabel(isFavorite ? "찜 해제" : "찜하기")
                    }
                    Text(recipe.description)
                        .font(.subheadline)
                        .foregroundStyle(Color.oneLogMuted)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        StatusPill(text: recipe.cookTimeText, tint: .oneLogGreen)
                        if let difficulty = recipe.difficultyText { StatusPill(text: difficulty, tint: .oneLogOrange) }
                        if recipe.isLightBreakfast { StatusPill(text: "가벼운 아침", tint: .oneLogGreen) }
                        if fullyCalculableRecipeIDs.contains(recipe.id) { StatusPill(text: "구매량 계산", tint: .oneLogGreen) }
                    }
                }
            }
            HStack(spacing: 8) {
                ForEach(recipe.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .foregroundStyle(Color.oneLogMuted)
                }
            }
            HStack(spacing: 10) {
                Button("상세 보기", action: onDetail)
                    .buttonStyle(SecondaryButtonStyle())
                Button("\(displayDate(isoDateString(addDate))) \(addSlot.rawValue)에 담기", action: onAdd)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .oneLogCard()
    }
}

struct RecipeDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    let defaultDate: Date
    let defaultSlot: MealSlot

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        Text(recipe.symbolName).font(.system(size: 54))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.title).font(.title2.weight(.black)).foregroundStyle(Color.oneLogInk)
                            Text([recipe.cookTimeText, "\(recipe.servings)인분", recipe.difficultyText].compactMap { $0 }.joined(separator: " · "))
                                .font(.subheadline).foregroundStyle(Color.oneLogMuted)
                        }
                    }
                    Text(recipe.description).font(.body).foregroundStyle(Color.oneLogMuted).lineSpacing(4)

                    VStack(alignment: .leading, spacing: 4) {
                        SectionHeading("재료", subtitle: "1인분 기준 · 단위는 임의로 환산하지 않아요.")
                        ForEach(recipe.ingredients) { item in
                            IngredientLine(name: item.rawName, value: formatQuantity(item.quantity, unit: item.unit), note: item.preparation)
                            Divider().overlay(Color.oneLogLine)
                        }
                    }
                    .oneLogCard()

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeading("조리 순서")
                        ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(Color.oneLogGreen)
                                    .frame(width: 25, height: 25)
                                    .background(Color.oneLogPaleGreen, in: Circle())
                                Text(step).font(.subheadline).foregroundStyle(Color.oneLogInk).lineSpacing(3)
                            }
                        }
                    }
                    .oneLogCard()

                    Button("\(displayDate(isoDateString(defaultDate))) · \(defaultSlot.rawValue)에 식사로 담기") {
                        store.addPlannedMeal(recipeID: recipe.id, date: isoDateString(defaultDate), slot: defaultSlot)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(16)
            }
            .background(Color.oneLogCream)
            .navigationTitle("레시피 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}
