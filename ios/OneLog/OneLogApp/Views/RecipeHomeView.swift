import SwiftUI

/// 레시피 탭. 피그마 `레시피 탭 1`(391:58) → `레시피 탭 2`(350:1119) → `레시피 탭 3`(391:598).
struct RecipeHomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var search = ""
    @State private var quickFilter: QuickFilter = .recommended
    @State private var typeFilter: TypeFilter?
    @State private var path: [RecipeRoute] = []

    enum RecipeRoute: Hashable {
        case favorites
        case detail(String)
    }

    enum QuickFilter: String, CaseIterable, Identifiable {
        case recommended = "추천"
        case under15 = "15분 이내"
        case simple = "간단"
        case rice = "밥요리"
        case soup = "국물요리"
        case spicy = "매운요리"
        case diet = "다이어트"

        var id: String { rawValue }
    }

    enum TypeFilter: String, CaseIterable, Identifiable {
        case breakfast = "아침"
        case lunch = "점심"
        case dinner = "저녁"
        case korean = "한식"
        case western = "양식"

        var id: String { rawValue }
    }

    private var results: [Recipe] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return recipes.filter { recipe in
            matchesQuick(recipe) && matchesType(recipe) && (query.isEmpty || searchable(recipe).contains(query))
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            explore
                .navigationDestination(for: RecipeRoute.self) { route in
                    switch route {
                    case .favorites:
                        FavoritesView(path: $path).environmentObject(store)
                    case .detail(let id):
                        RecipeDetailView(recipeID: id).environmentObject(store)
                    }
                }
        }
    }

    // MARK: - 레시피 탭 1 (391:58)

    private var explore: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                HStack(spacing: 7) {
                    Text("오늘은 어떤 요리를 할까요?")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.oneLogInk)
                        .frame(width: 273, alignment: .leading)
                    Image("HeroVeggies")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 109, height: 55)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                .padding(.top, 2)

                searchBar
                    .padding(.top, 24)

                categories
                    .padding(.horizontal, 20)
                    .padding(.top, 13)

                resultsHeading
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 12) {
                    ForEach(results.prefix(40)) { recipe in
                        RecipeGridCard(recipe: recipe, isFavorite: store.state.favorites.contains(recipe.id)) {
                            store.toggleFavorite(recipe.id)
                        } onOpen: {
                            path.append(.detail(recipe.id))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 13)

                if results.isEmpty {
                    Text("조건에 맞는 레시피가 없어요. 필터를 바꿔 보세요.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.oneLogMuted)
                        .padding(.top, 40)
                }

                Color.clear.frame(height: 24)
            }
        }
        .background(Color(hex: 0xFFF9E8))
    }

    private var header: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Image("BrandWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 93, height: 33)
                Text("내 취향 한끼부터, 남은 재료까지")
                    .font(.system(size: 7))
                    .foregroundStyle(Color.oneLogMuted)
                    .offset(x: 5, y: 31)
            }
            .frame(height: 41, alignment: .top)
            Spacer(minLength: 8)
            Button {
                path.append(.favorites)
            } label: {
                Image("IconHeartFilled")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .frame(width: 32, height: 32)
                    .background(Color.oneLogBrand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 2.5, y: 2)
            }
            .accessibilityLabel("찜한 레시피")
            .accessibilityIdentifier("recipe.favorites")
        }
        .frame(height: 52)
    }

    private var searchBar: some View {
        HStack(spacing: 12.5) {
            HStack(spacing: 10) {
                Image("IconSearch")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color(hex: 0x726D63))
                TextField("", text: $search, prompt: Text("레시피나 재료를 검색해보세요").foregroundColor(Color(hex: 0x736E63)))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.oneLogInk)
                    .accessibilityIdentifier("recipe.search")
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(hex: 0xDBD4C2), lineWidth: 1)
            }

            Image("IconMicrophone")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.oneLogInk, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color(red: 31 / 255, green: 26 / 255, blue: 13 / 255).opacity(0.12), radius: 4, y: 3)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 13)
        .frame(height: 76)
        .frame(maxWidth: .infinity)
        .background(Color.oneLogBrand)
    }

    private var categories: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 7) {
                Text("빠르게 찾기")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.oneLogMuted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(QuickFilter.allCases) { filter in
                            filterChip(filter.rawValue, isOn: quickFilter == filter, horizontalPadding: 9) {
                                quickFilter = filter
                            }
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("종류와 끼니")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.oneLogMuted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(TypeFilter.allCases) { filter in
                            filterChip(filter.rawValue, isOn: typeFilter == filter, horizontalPadding: 11) {
                                typeFilter = typeFilter == filter ? nil : filter
                            }
                        }
                    }
                }
            }
        }
    }

    private func filterChip(_ title: String, isOn: Bool, horizontalPadding: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.oneLogInk)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 6)
                .background(isOn ? Color.oneLogBrandDeep : .white, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay {
                    if !isOn {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color(hex: 0xDBD4C2), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var resultsHeading: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text("취향을 더 알아볼게요")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.oneLogInk)
                Text("먹고 싶은 레시피에 하트를 눌러주세요")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.oneLogMuted)
            }
            Spacer(minLength: 8)
            Text("추천 \(results.count)개")
                .font(.system(size: 11))
                .foregroundStyle(Color.oneLogMuted)
        }
        .frame(height: 42)
    }

    // MARK: - 필터

    private func searchable(_ recipe: Recipe) -> String {
        ([recipe.title, recipe.description] + recipe.tags + recipe.ingredients.compactMap { ingredient(for: $0.ingredientID)?.name })
            .joined(separator: " ")
            .lowercased()
    }

    private func matchesQuick(_ recipe: Recipe) -> Bool {
        switch quickFilter {
        case .recommended: return isRecommendable(recipe, preferences: store.state.preferences)
        case .under15: return (recipe.cookTime ?? .max) <= 15
        case .simple: return (recipe.difficulty ?? 5) <= 1
        case .rice: return recipeCategory(recipe) == "밥 요리"
        case .soup: return recipeCategory(recipe) == "국물 요리"
        case .spicy: return searchable(recipe).contains("매운") || searchable(recipe).contains("김치") || searchable(recipe).contains("고추")
        case .diet: return recipe.isLightBreakfast
        }
    }

    private func matchesType(_ recipe: Recipe) -> Bool {
        guard let typeFilter else { return true }
        switch typeFilter {
        case .breakfast: return recipe.mealSlots.contains(.breakfast)
        case .lunch: return recipe.mealSlots.contains(.lunch)
        case .dinner: return recipe.mealSlots.contains(.dinner)
        case .korean: return recipeCuisine(recipe) == "한식"
        case .western: return recipeCuisine(recipe) == "양식"
        }
    }
}

// MARK: - 레시피 분류

/// ponytail: 레시피 데이터에 요리 종류 필드가 없어 제목·태그 키워드로 나눈다. 데이터에 종류가 생기면 이 함수만 지운다.
func recipeCuisine(_ recipe: Recipe) -> String {
    let text = ([recipe.title] + recipe.tags).joined(separator: " ")
    let western = ["파스타", "피자", "그라탕", "리조또", "스프", "수프", "샌드위치", "토스트", "오믈렛", "스테이크", "샐러드"]
    let japanese = ["덮밥", "규동", "우동", "라멘", "돈부리", "가라아게", "오코노미"]
    let chinese = ["짜장", "짬뽕", "마파", "볶음면", "탕수"]
    if western.contains(where: text.contains) { return "양식" }
    if chinese.contains(where: text.contains) { return "중식" }
    if japanese.contains(where: text.contains) { return "일식" }
    return "한식"
}

func recipeCategory(_ recipe: Recipe) -> String {
    let text = ([recipe.title] + recipe.tags).joined(separator: " ")
    if ["국", "찌개", "탕", "전골", "스프", "수프"].contains(where: text.contains) { return "국물 요리" }
    if ["밥", "덮밥", "볶음밥", "솥밥", "리조또"].contains(where: text.contains) { return "밥 요리" }
    if ["면", "파스타", "우동", "라멘"].contains(where: text.contains) { return "면 요리" }
    return "한 그릇"
}

func recipeDifficultyLabel(_ recipe: Recipe) -> String? {
    guard let difficulty = recipe.difficulty else { return nil }
    switch difficulty {
    case ...1: return "난이도 하수"
    case 2...3: return "난이도 중수"
    default: return "난이도 고수"
    }
}

func recipeDifficultyColors(_ recipe: Recipe) -> (background: Color, foreground: Color) {
    switch recipe.difficulty ?? 3 {
    case ...1: return (Color(hex: 0xE8F5DE), Color(hex: 0x406E33))
    case 2...3: return (Color(hex: 0xFFEDBF), Color(hex: 0x9E5705))
    default: return (Color(hex: 0xFCE6E1), Color(hex: 0x9E2626))
    }
}

/// 사진이 없을 때 쓰는 자리(#E0DDD1 + `사진`).
struct RecipePhoto: View {
    let recipe: Recipe

    var body: some View {
        ZStack {
            Color.oneLogPhoto
            if let urlString = recipe.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
            } else {
                Text("사진")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: 0xB3B3B3))
            }
        }
    }
}

/// 피그마 `Recipe Card`(391:128). 169.5x220.
private struct RecipeGridCard: View {
    let recipe: Recipe
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            ZStack(alignment: .topLeading) {
                RecipePhoto(recipe: recipe)

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0), location: 0),
                        .init(color: .black.opacity(0.05), location: 0.45),
                        .init(color: .black.opacity(0.82), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Button(action: onToggleFavorite) {
                    Image(isFavorite ? "IconHeartFilled" : "IconHeart")
                        .resizable()
                        .renderingMode(isFavorite ? .original : .template)
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color(hex: 0x151512))
                        .frame(width: 32, height: 32)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 2.5, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite ? "\(recipe.title) 찜 해제" : "\(recipe.title) 찜하기")
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 10)
                .padding(.top, 10)

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(recipe.mealSlots.first?.rawValue ?? "한 끼") · \(recipeCuisine(recipe))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(recipe.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Image("MetaDot")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 7, height: 7)
                        Text("\(recipe.cookTimeText) · 상세 보기 ›")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color(red: 41 / 255, green: 31 / 255, blue: 5 / 255).opacity(0.08), radius: 6, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 레시피 탭 3 (391:598)

private struct FavoritesView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var path: [RecipeHomeView.RecipeRoute]

    private var favorites: [Recipe] { store.state.favorites.compactMap { recipe(for: $0) } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Button {
                        path.removeLast()
                    } label: {
                        Image("IconBack")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(Color(hex: 0x151512))
                            .frame(width: 34, height: 34)
                            .background(.white, in: Circle())
                            .overlay { Circle().stroke(Color(hex: 0xDBD4C2), lineWidth: 1) }
                    }
                    .accessibilityLabel("뒤로")
                    VStack(alignment: .leading, spacing: 1) {
                        Text("찜한 레시피")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.oneLogInk)
                        Text("내 취향과 나중에 만들고 싶은 한 끼를 모아뒀어요")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.oneLogMuted)
                    }
                }
                .frame(height: 52)
                .padding(.top, 14)

                tasteNote
                    .padding(.top, 16)

                HStack {
                    Text("찜한 레시피")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.oneLogInk)
                    Spacer()
                    Text("\(favorites.count)개")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.oneLogMuted)
                }
                .frame(height: 38)
                .padding(.top, 20)

                if favorites.isEmpty {
                    Text("아직 찜한 레시피가 없어요. 레시피 카드의 하트를 눌러보세요.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.oneLogMuted)
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 10) {
                        ForEach(favorites) { item in
                            favoriteRow(item)
                        }
                    }
                    .padding(.top, 10)
                }

                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, 20)
        }
        .background(Color(hex: 0xFFF9E8))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    /// 피그마 `AI Taste Post / Note`(391:712). 찜한 레시피에서 실제로 센 값만 보여준다.
    private var tasteNote: some View {
        VStack(spacing: 0) {
            HStack {
                Text("✦ AI 취향 노트")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: 0x292414))
                Spacer()
                Text("찜 \(favorites.count)개 분석 · \(todayLabel)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: 0x544A2B).opacity(0.82))
            }
            .padding(.horizontal, 15)
            .frame(height: 40)
            .background(Color.oneLogBrand)

            ZStack(alignment: .topLeading) {
                Color(hex: 0xFFFEF6)

                Color.clear
                    .frame(width: 186, height: 63)
                    .overlay(alignment: .topLeading) {
                        Image("TasteNoteMascot")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 286, height: 190)
                            .offset(x: -45)
                    }
                    .clipped()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 3)
                    .offset(y: 55)

                VStack(alignment: .leading, spacing: 10) {
                    Text(noteHeadline)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: 0x14120D))
                        .frame(width: 250, alignment: .leading)
                    Text("다음 식단 추천에 이 취향을 반영할게요")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: 0x574D36))
                        .frame(width: 250, alignment: .leading)
                }
                .padding(.leading, 14)
                .padding(.top, 12)

                HStack(spacing: 6) {
                    ForEach(noteTags, id: \.self) { tag in
                        Text("# \(tag)")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: 0x5C4A1F))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color(hex: 0xFFF2C4), in: Capsule())
                    }
                }
                .padding(.leading, 14)
                .offset(y: 78)
            }
            .frame(height: 120)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: 0xE8DBB2).opacity(0.8), lineWidth: 1)
        }
        .shadow(color: Color(red: 48 / 255, green: 38 / 255, blue: 18 / 255).opacity(0.1), radius: 8, y: 5)
    }

    private var todayLabel: String {
        let parts = isoDateString().split(separator: "-")
        guard parts.count == 3 else { return isoDateString() }
        return "\(Int(parts[1]) ?? 0)월 \(Int(parts[2]) ?? 0)일"
    }

    private var noteHeadline: String {
        guard !favorites.isEmpty else { return "찜을 하면 취향을 정리해드려요" }
        let cuisine = mostCommon(favorites.map(recipeCuisine)) ?? "한식"
        let category = mostCommon(favorites.map(recipeCategory)) ?? "한 그릇"
        return "\(cuisine) · \(category)를 자주 골랐어요"
    }

    private var noteTags: [String] {
        guard !favorites.isEmpty else { return [] }
        let times = favorites.compactMap(\.cookTime)
        let average = times.isEmpty ? nil : times.reduce(0, +) / times.count
        return [
            mostCommon(favorites.map(recipeCuisine)) ?? "한식",
            average.map { "\($0)분 안팎" } ?? "조리시간 미확인",
            mostCommon(favorites.map(recipeCategory)) ?? "한 그릇"
        ]
    }

    private func mostCommon(_ values: [String]) -> String? {
        Dictionary(grouping: values, by: { $0 })
            .max { ($0.value.count, $0.key) < ($1.value.count, $1.key) }?
            .key
    }

    /// 피그마 `찜 레시피`(391:613) 행. 353x99.
    private func favoriteRow(_ item: Recipe) -> some View {
        Button {
            path.append(.detail(item.id))
        } label: {
            HStack(spacing: 12) {
                RecipePhoto(recipe: item)
                    .frame(width: 78, height: 79)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 9) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.oneLogInk)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        if let label = recipeDifficultyLabel(item) {
                            Text(label)
                                .font(.system(size: 10))
                                .foregroundStyle(recipeDifficultyColors(item).foreground)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(recipeDifficultyColors(item).background, in: Capsule())
                        }
                        Text("\(recipeCuisine(item)) · \(recipeCategory(item)) · \(item.cookTimeText)")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.oneLogMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                Text("♥")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: 0xE37A1F))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(hex: 0xFFF5D4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(10)
            .frame(height: 99)
            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color(red: 48 / 255, green: 38 / 255, blue: 18 / 255).opacity(0.08), radius: 7, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 레시피 탭 2 (350:1119)

struct RecipeDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let recipeID: String

    private var recipeValue: Recipe? { recipe(for: recipeID) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if let item = recipeValue {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    photoCard(item)
                        .padding(.horizontal, 3)
                        .padding(.top, 7)
                    ingredientSection(item)
                        .padding(.top, 13)
                    Rectangle()
                        .fill(Color(hex: 0xE3D9BF))
                        .frame(height: 1)
                        .padding(.top, 22)
                    Text("조리 순서")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.oneLogInk)
                        .padding(.top, 10)
                    stepSection(item)
                        .padding(.top, 12)
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color(hex: 0xFFF9E8))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image("IconBack")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color(hex: 0x151512))
                    .frame(width: 36, height: 36)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(hex: 0xE3D9BF), lineWidth: 1)
                    }
            }
            .accessibilityLabel("뒤로")
            Text("레시피 상세")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.oneLogInk)
            Spacer()
        }
        .frame(height: 36)
        .padding(.top, 14)
    }

    private func photoCard(_ item: Recipe) -> some View {
        ZStack(alignment: .topLeading) {
            RecipePhoto(recipe: item)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0), location: 0),
                    .init(color: .black.opacity(0.05), location: 0.45),
                    .init(color: .black.opacity(0.82), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Button {
                store.toggleFavorite(item.id)
            } label: {
                let isFavorite = store.state.favorites.contains(item.id)
                Image(isFavorite ? "IconHeartFilled" : "IconHeart")
                    .resizable()
                    .renderingMode(isFavorite ? .original : .template)
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color(hex: 0x151512))
                    .frame(width: 32, height: 32)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 2.5, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("찜하기")
            .accessibilityIdentifier("recipe.detail.favorite")
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 17)
            .padding(.top, 10)

            VStack(alignment: .leading, spacing: 5) {
                if let label = recipeDifficultyLabel(item) {
                    Text(label)
                        .font(.system(size: 10))
                        .foregroundStyle(recipeDifficultyColors(item).foreground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(recipeDifficultyColors(item).background, in: Capsule())
                }
                Text(item.title)
                    .font(.system(size: 29, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(item.mealSlots.first?.rawValue ?? "한 끼") · \(recipeCuisine(item)) · \(item.cookTimeText) · \(item.servings)인분")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 19)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(height: 293)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color(red: 41 / 255, green: 31 / 255, blue: 5 / 255).opacity(0.08), radius: 6, y: 4)
    }

    private func ingredientSection(_ item: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("필요한 재료")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.oneLogInk)
                Spacer()
                Text("\(item.servings)인분 기준")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.oneLogMuted)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 14) {
                ForEach(item.ingredients) { line in
                    HStack(spacing: 0) {
                        Circle()
                            .fill(Color.oneLogBrandDeep)
                            .frame(width: 6, height: 6)
                        Text(ingredient(for: line.ingredientID)?.name ?? line.rawName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.oneLogInk)
                            .padding(.leading, 7)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(formatQuantity(line.quantity, unit: line.unit))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.oneLogMuted)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.top, 24)
        }
    }

    private func stepSection(_ item: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(item.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.oneLogInk)
                        .frame(width: 26, height: 26)
                        .background(index == 0 ? Color.oneLogBrandDeep : .white, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay {
                            if index > 0 {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(Color(hex: 0xE3D9BF), lineWidth: 1)
                            }
                        }
                    Text(step)
                        .font(.system(size: 10))
                        .lineSpacing(5)
                        .foregroundStyle(Color.oneLogInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }
            }
        }
    }
}
