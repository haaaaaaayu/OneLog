import SwiftUI

/// 레시피 탭. 피그마 `최종본` 캔버스의 `레시피 탭 4`(707:881, 목록) → `레시피 탭 2`(713:1689, 상세) → `레시피 탭 3`(713:1562, 찜).
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
        let filtered = recipes.filter { recipe in
            if !query.isEmpty { return searchable(recipe).contains(query) }
            return matchesQuick(recipe) && matchesType(recipe)
        }
        // 707:908 — 기본 `추천` 상태는 디자인처럼 4개만 노출한다.
        // 검색이나 명시적 필터를 선택하면 전체 적합 결과를 그대로 반환한다.
        if query.isEmpty, quickFilter == .recommended, typeFilter == nil {
            return Array(filtered.prefix(4))
        }
        return filtered
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

    // MARK: - 레시피 탭 4 (707:881)

    private var explore: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color(hex: 0xFFFEFB)

                // 707:885 — x20, y48, 353×52.
                header
                    .frame(width: 353, height: 52)
                    .offset(x: 20, y: 48)

                // 707:1043 — x20, y102, 354×131.
                tasteHeroCard
                    .frame(width: 354, height: 131)
                    .offset(x: 20, y: 102)

                if normalizedSearch.isEmpty {
                    // 707:1011 — x25.13, y252.87, 372×112.
                    categories
                        .frame(width: 372, height: 112, alignment: .topLeading)
                        .offset(x: 25.13, y: 252.87)
                }

                if results.isEmpty, !normalizedSearch.isEmpty {
                    emptySearchState
                        .frame(width: 353)
                        .offset(x: 20, y: 363.87)
                } else {
                    recipeResults
                        .frame(width: 393, height: max(0, proxy.size.height - 363.87), alignment: .topLeading)
                        .offset(x: 0, y: 363.87)
                }
            }
            .frame(width: 393, height: proxy.size.height, alignment: .topLeading)
            .background(Color(hex: 0xFFFEFB))
        }
        // Figma 프레임이 실제 상태바를 포함한 393×852 좌표를 쓰므로 상단까지 같은 캔버스로 사용한다.
        .ignoresSafeArea(edges: .top)
    }

    /// 707:903. 상단 탐색·필터는 고정하고 결과 영역만 스크롤한다.
    private var recipeResults: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                resultsHeading
                    .frame(width: 353, height: 42)
                    .padding(.top, 1.13)

                LazyVGrid(
                    columns: [GridItem(.fixed(169.5), spacing: 14), GridItem(.fixed(169.5), spacing: 14)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(results.prefix(40)) { recipe in
                        RecipeGridCard(recipe: recipe, isFavorite: store.state.favorites.contains(recipe.id)) {
                            store.toggleFavorite(recipe.id)
                        } onOpen: {
                            path.append(.detail(recipe.id))
                        }
                    }
                }
                .padding(.top, 12)

                Color.clear.frame(height: 24)
            }
            // 707:904/909 — 결과 영역 전체 글로벌 x21.5.
            .padding(.leading, 21.5)
        }
        .background(Color.white)
    }

    private var header: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Image("BrandWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 93, height: 33)
                Text("내 취향 한끼부터, 남은 재료까지")
                    .figmaText(7)
                    .foregroundStyle(Color.oneLogMuted)
                    .offset(x: 5, y: 31)
            }
            .frame(height: 41, alignment: .top)
            Spacer(minLength: 8)
            Button {
                path.append(.favorites)
            } label: {
                // 769:45 — 노란 원 위에 채운 하트. 흰 외곽선 하트를 쓰면 노란 배경에 묻힌다.
                Image("IconHeartFilled")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .frame(width: 32, height: 32)
                    .background(Color.oneLogBrandDeep, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 2.5, y: 2)
            }
            .accessibilityLabel("찜한 레시피")
            .accessibilityIdentifier("recipe.favorites")
        }
        .frame(height: 52)
    }

    /// 피그마 `Taste Analysis / Card`(707:1043). 헤드라인 + 검색창 + 마스코트를 한 카드에 담는다.
    private var tasteHeroCard: some View {
        ZStack(alignment: .topLeading) {
            Color.oneLogBrandDeep

            // 자식 좌표는 시안 절대값: 제목(21,29) · 부제(21,54) · 검색창(14,80.22,319×39) · 마스코트(224,25.22,109×55).
            Image("HeroVeggies")
                .resizable()
                .scaledToFill()
                .frame(width: 109, height: 109)
                .frame(width: 109, height: 55, alignment: .top)
                .clipped()
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(x: -21, y: 25.22)

            Text("찜으로 알아가는 나의 입맛")
                .figmaText(17, .bold)
                .foregroundStyle(Color.oneLogInk)
                .fixedSize()
                .offset(x: 21, y: 29)

            Text("찜할수록 취향 키워드가 구체화돼요")
                .figmaText(10)
                .foregroundStyle(Color(hex: 0x403B2E))
                .fixedSize()
                .offset(x: 21, y: 54)

            HStack(spacing: 10) {
                Image("IconSearch")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color(hex: 0x726D63))
                TextField("", text: $search, prompt: Text("레시피나 재료를 검색해보세요").foregroundColor(Color(hex: 0x736E63)))
                    .font(.figma(12))
                    .foregroundStyle(Color.oneLogInk)
                    .accessibilityIdentifier("recipe.search")
            }
            .padding(.horizontal, 13)
            .frame(width: 319, height: 39)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(hex: 0xDBD4C2), lineWidth: 1)
            }
            .offset(x: 14, y: 80.22)
        }
        .frame(height: 131)
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
    }

    /// 391:233. 라벨은 좌측 20pt에 맞추고, 칩 줄은 시안(w372)처럼 오른쪽 화면 끝까지 흘려보낸다.
    private var categories: some View {
        VStack(alignment: .leading, spacing: 8) {
            categoryRow(title: "빠르게 찾기") {
                ForEach(QuickFilter.allCases) { filter in
                    filterChip(filter.rawValue, isOn: quickFilter == filter, horizontalPadding: 9) {
                        quickFilter = filter
                    }
                }
            }
            categoryRow(title: "종류와 끼니") {
                ForEach(TypeFilter.allCases) { filter in
                    filterChip(filter.rawValue, isOn: typeFilter == filter, horizontalPadding: 11) {
                        typeFilter = typeFilter == filter ? nil : filter
                    }
                }
            }
        }
    }

    private func categoryRow<Chips: View>(title: String, @ViewBuilder chips: () -> Chips) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .figmaText(10, .medium)
                .foregroundStyle(Color.oneLogMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chips()
                }
                .padding(.trailing, 20)
            }
        }
        .frame(height: 48, alignment: .top)
    }

    private func filterChip(_ title: String, isOn: Bool, horizontalPadding: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .figmaText(10, .medium)
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
                Text(normalizedSearch.isEmpty ? "취향을 더 알아볼게요" : "'\(normalizedSearch)' 검색 결과 \(results.count)개")
                    .figmaText(17, .bold)
                    .foregroundStyle(Color.oneLogInk)
                if normalizedSearch.isEmpty {
                    Text("먹고 싶은 레시피에 하트를 눌러주세요")
                        .figmaText(10)
                        .foregroundStyle(Color.oneLogMuted)
                }
            }
            Spacer(minLength: 8)
            if normalizedSearch.isEmpty {
                Text("추천 \(results.count)개")
                    .figmaText(11)
                    .foregroundStyle(Color.oneLogMuted)
            }
        }
        .frame(height: 42)
    }

    /// 최종본 805:17. 결과가 없을 때도 검색 컨텍스트는 유지하고, 재검색용 추천어만 제공한다.
    private var emptySearchState: some View {
        VStack(spacing: 0) {
            Image("EmptySearchMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 92)

            Text("'\(normalizedSearch)' 검색 결과가 없어요")
                .figmaText(22, .bold, lineHeight: 28)
                .foregroundStyle(Color.oneLogInk)
                .padding(.top, 22)

            Text("다른 재료나 메뉴로 검색해보거나,\n아래 추천을 확인해보세요.")
                .figmaText(13, .medium, lineHeight: 22)
                .foregroundStyle(Color.oneLogFaint)
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            HStack(spacing: 8) {
                ForEach(["두부", "계란", "김치", "15분 이내", "한식"], id: \.self) { suggestion in
                    Button {
                        if suggestion == "15분 이내" {
                            search = ""
                            quickFilter = .under15
                        } else if suggestion == "한식" {
                            search = ""
                            typeFilter = .korean
                        } else {
                            search = suggestion
                        }
                    } label: {
                        Text(suggestion)
                            .figmaText(12, .bold)
                            .foregroundStyle(Color.oneLogBody)
                            .padding(.horizontal, 13)
                            .frame(height: 32)
                            .background(Color.oneLogPaleGreen, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 27)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("recipe.emptySearch")
    }

    // MARK: - 필터

    private func searchable(_ recipe: Recipe) -> String {
        ([recipe.title, recipe.description] + recipe.tags + recipe.ingredients.compactMap { ingredient(for: $0.ingredientID)?.name })
            .joined(separator: " ")
            .lowercased()
    }

    private var normalizedSearch: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
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
            if let assetName = bundledRecipeImageAssets[recipe.id] {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else if let urlString = recipe.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
            } else {
                Text("사진")
                    .figmaText(11, .bold)
                    .foregroundStyle(Color(hex: 0xB3B3B3))
            }
        }
    }
}

/// 앱에서 직접 큐레이션한 레시피는 공공 데이터 사진 URL이 없으므로
/// 카드와 상세가 같은 번들 사진을 사용한다.
private let bundledRecipeImageAssets: [String: String] = [
    "chicken-donburi": "RecipeChickenDonburi",
    "tofu-kimchi": "RecipeTofuKimchi",
    "tuna-mayo-rice": "RecipeTunaMayoRice",
    "cabbage-egg-stir-fry": "RecipeCabbageEgg",
    "cucumber-tuna-bowl": "RecipeCucumberTuna",
    "kimchi-fried-rice": "RecipeKimchiFriedRice",
]

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
                    .frame(width: 169.5, height: 220)
                    .clipped()

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0), location: 0),
                        .init(color: .black.opacity(0.05), location: 0.45),
                        .init(color: .black.opacity(0.82), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 169.5, height: 220)

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
                .offset(x: 127.5, y: 10)

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(recipe.mealSlots.first?.rawValue ?? "한 끼") · \(recipeCuisine(recipe))")
                        .figmaText(10, .bold)
                        .foregroundStyle(.white.opacity(0.9))
                    Text(recipe.title)
                        .figmaText(14, .bold, lineHeight: 22) // 707:918
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Image("MetaDot")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 7, height: 7)
                        Text("\(recipe.cookTimeText) · 상세 보기 ›")
                            .figmaText(11)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 11)
                .padding(.bottom, 10)
                // 707:916 — 카드 아래가 아니라 y120에서 시작하는 102 높이 블록이다.
                .frame(width: 169.5, height: 102, alignment: .topLeading)
                .offset(y: 120)
            }
            .frame(width: 169.5, height: 220)
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
                            .figmaText(20, .bold)
                            .foregroundStyle(Color.oneLogInk)
                        Text("내 취향과 나중에 만들고 싶은 한 끼를 모아뒀어요")
                            .figmaText(11)
                            .foregroundStyle(Color.oneLogMuted)
                    }
                }
                .frame(height: 52)
                .padding(.top, 14)

                tasteNote
                    .padding(.top, 16)

                HStack {
                    Text("찜한 레시피")
                        .figmaText(17, .bold)
                        .foregroundStyle(Color.oneLogInk)
                    Spacer()
                    Text("\(favorites.count)개")
                        .figmaText(11)
                        .foregroundStyle(Color.oneLogMuted)
                }
                .frame(height: 38)
                .padding(.top, 20)

                if favorites.isEmpty {
                    Text("아직 찜한 레시피가 없어요. 레시피 카드의 하트를 눌러보세요.")
                        .figmaText(12)
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
        .background(Color(hex: 0xFFFEFB))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    /// 피그마 `AI Taste Post / Note`(391:712). 찜한 레시피에서 실제로 센 값만 보여준다.
    private var tasteNote: some View {
        VStack(spacing: 0) {
            HStack {
                Text("✦ AI 취향 노트")
                    .figmaText(12, .bold)
                    .foregroundStyle(Color(hex: 0x292414))
                Spacer()
                Text("찜 \(favorites.count)개 분석 · \(todayLabel)")
                    .figmaText(10)
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
                        .figmaText(18, .bold, lineHeight: 20)
                        .foregroundStyle(Color(hex: 0x14120D))
                        .frame(width: 250, alignment: .leading)
                    Text("다음 식단 추천에 이 취향을 반영할게요")
                        .figmaText(10)
                        .foregroundStyle(Color(hex: 0x574D36))
                        .frame(width: 250, alignment: .leading)
                }
                .padding(.leading, 14)
                .padding(.top, 12)

                HStack(spacing: 6) {
                    ForEach(noteTags, id: \.self) { tag in
                        Text("# \(tag)")
                            .figmaText(9)
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
            HStack(alignment: .top, spacing: 12) {
                RecipePhoto(recipe: item)
                    .frame(width: 78, height: 79)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // 713:1582 제목 y27 · 713:1584 난이도 배지 y52 · 713:1583 메타 y56(배지 오른쪽 2).
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .figmaText(16, .bold)
                        .foregroundStyle(Color.oneLogInk)
                        .lineLimit(1)
                    HStack(spacing: 2) {
                        if let label = recipeDifficultyLabel(item) {
                            Text(label)
                                .figmaText(10)
                                .foregroundStyle(recipeDifficultyColors(item).foreground)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(recipeDifficultyColors(item).background, in: Capsule())
                        }
                        Text("\(recipeCuisine(item)) · \(recipeCategory(item)) · \(item.cookTimeText)")
                            .figmaText(10)
                            .foregroundStyle(Color.oneLogMuted)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 17)

                Spacer(minLength: 4)

                // 707:900 — 카드 안쪽 여백 밖(309, 7)에 놓인 32 노란 하트.
                Image("IconHeartFilled")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .frame(width: 32, height: 32)
                    .background(Color.oneLogBrandDeep, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 2.5, y: 2)
                    .offset(x: 2, y: -3)
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
    let actionTitle: String
    let onAddToPlan: (() -> Void)?
    let actionFill: Color
    let actionForeground: Color
    let actionHeight: CGFloat
    let dismissesAfterAction: Bool
    let secondaryActionTitle: String?
    let onSecondaryAction: (() -> Void)?
    @State private var isMealPickerPresented = false

    init(
        recipeID: String,
        actionTitle: String = "식사에 담기",
        onAddToPlan: (() -> Void)? = nil,
        actionFill: Color = .oneLogBrand,
        actionForeground: Color = .oneLogInk,
        actionHeight: CGFloat = 50,
        dismissesAfterAction: Bool = true,
        secondaryActionTitle: String? = nil,
        onSecondaryAction: (() -> Void)? = nil
    ) {
        self.recipeID = recipeID
        self.actionTitle = actionTitle
        self.onAddToPlan = onAddToPlan
        self.actionFill = actionFill
        self.actionForeground = actionForeground
        self.actionHeight = actionHeight
        self.dismissesAfterAction = dismissesAfterAction
        self.secondaryActionTitle = secondaryActionTitle
        self.onSecondaryAction = onSecondaryAction
    }

    private var recipeValue: Recipe? { recipe(for: recipeID) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if let item = recipeValue {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    // 391:824 — 카드는 x23..367(w344), 좌우 여백이 3/6으로 다르다.
                    photoCard(item)
                        .padding(.leading, 3)
                        .padding(.trailing, 6)
                        .padding(.top, 7)
                    ingredientSection(item)
                        .padding(.top, 13)
                    Rectangle()
                        .fill(Color(hex: 0xE3D9BF))
                        .frame(height: 1)
                        .padding(.top, 26) // 713:1717 y544
                    Text("조리 순서")
                        .figmaText(16, .bold)
                        .foregroundStyle(Color.oneLogInk)
                        .padding(.top, 9)
                    stepSection(item)
                        .padding(.top, 9) // 713:1719 y582
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color(hex: 0xFEFCF6)) // 713:1689
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if recipeValue != nil {
                VStack(spacing: 0) {
                    Button {
                        if let onAddToPlan {
                            onAddToPlan()
                            if dismissesAfterAction { dismiss() }
                        } else {
                            isMealPickerPresented = true
                        }
                    } label: {
                        Text(actionTitle)
                            .figmaText(15, .bold)
                            .foregroundStyle(actionForeground)
                            .frame(maxWidth: .infinity)
                            .frame(height: actionHeight)
                            .background(actionFill, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recipe.detail.addMeal")

                    if let secondaryActionTitle, let onSecondaryAction {
                        Button(action: onSecondaryAction) {
                            Text(secondaryActionTitle)
                                .figmaText(15, .bold)
                                .foregroundStyle(Color(hex: 0x574F40))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color(hex: 0xDED4B5), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("recipe.detail.secondaryAction")
                        .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(hex: 0xFEFCF6).opacity(0.96))
            }
        }
        .sheet(isPresented: $isMealPickerPresented) {
            if let recipeValue {
                RecipeMealPicker(recipe: recipeValue).environmentObject(store)
            }
        }
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
                .figmaText(20, .bold)
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
                        .figmaText(10)
                        .foregroundStyle(recipeDifficultyColors(item).foreground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(recipeDifficultyColors(item).background, in: Capsule())
                }
                Text(item.title)
                    .figmaText(29, .bold, lineHeight: 36) // 713:1775
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(item.mealSlots.first?.rawValue ?? "한 끼") · \(recipeCuisine(item)) · \(item.cookTimeText) · \(item.servings)인분")
                    .figmaText(11)
                    .foregroundStyle(.white.opacity(0.9))
            }
            // 713:1772 — 카드 아래가 아니라 (19, 170)에서 시작하는 252 너비 블록, 위아래 11 여백.
            .padding(.vertical, 11)
            .frame(width: 252, alignment: .topLeading)
            .offset(x: 19, y: 170)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: 293)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color(red: 41 / 255, green: 31 / 255, blue: 5 / 255).opacity(0.08), radius: 6, y: 4)
    }

    private func ingredientSection(_ item: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("필요한 재료")
                    .figmaText(16, .bold)
                    .foregroundStyle(Color.oneLogInk)
                Spacer()
                Text("\(item.servings)인분 기준")
                    .figmaText(10)
                    .foregroundStyle(Color.oneLogMuted)
            }

            // 350:1140~ — 행 간격은 텍스트 top 435/470/505(피치 35)에서 역산한 17.6.
            // 713:1699~1704 — 한 칸 안에서 불릿 0 · 이름 13 · 수량 112, 행 피치 35(높이 15 + 간격 20).
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 20) {
                ForEach(Array(item.ingredients.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 0) {
                        Circle()
                            .fill(Color.oneLogBrandDeep)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)
                        Text(ingredient(for: line.ingredientID)?.name ?? line.rawName)
                            .figmaText(12, .medium)
                            .foregroundStyle(Color.oneLogInk)
                            .lineLimit(1)
                            .padding(.leading, 7)
                            .frame(width: 99, alignment: .leading)
                        Text(formatQuantity(line.quantity, unit: line.unit))
                            .figmaText(11)
                            .foregroundStyle(Color.oneLogMuted)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .frame(height: 15)
                }
            }
            .padding(.top, 19)
        }
    }

    private func stepSection(_ item: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(item.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .figmaText(11, .bold)
                        .foregroundStyle(Color.oneLogInk)
                        .frame(width: 26, height: 26)
                        .background(.white, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(Color(hex: 0xE3D9BF), lineWidth: 1)
                        }
                    Text(step)
                        .figmaText(10, lineHeight: 15)
                        .foregroundStyle(Color.oneLogInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }
            }
        }
    }
}

/// 레시피 상세에서 직접 날짜·끼니를 고르는 F03 경로.
private struct RecipeMealPicker: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe

    @State private var date = Date()
    @State private var slot: MealSlot
    @State private var errorMessage: String?

    init(recipe: Recipe) {
        self.recipe = recipe
        _slot = State(initialValue: recipe.mealSlots.first ?? .dinner)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("담을 메뉴") {
                    LabeledContent("레시피", value: recipe.title)
                    LabeledContent("기준", value: "\(recipe.servings)인분 · \(recipe.cookTimeText)")
                }

                Section("먹을 일정") {
                    DatePicker("날짜", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                        .accessibilityIdentifier("recipe.mealDate")
                    Picker("끼니", selection: $slot) {
                        ForEach(recipe.mealSlots) { slot in
                            Text(slot.rawValue).tag(slot)
                        }
                    }
                    .accessibilityIdentifier("recipe.mealSlot")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.oneLogOrange)
                }

                Section {
                    Button("식사에 담기") {
                        if store.addPlannedMeal(recipeID: recipe.id, date: isoDateString(date), slot: slot) {
                            dismiss()
                        } else {
                            errorMessage = store.notice ?? "같은 날짜와 끼니에 이미 다른 메뉴가 담겨 있어요."
                        }
                    }
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.oneLogInk)
                    .accessibilityIdentifier("recipe.meal.confirm")
                }
            }
            .navigationTitle("식사에 담기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}
