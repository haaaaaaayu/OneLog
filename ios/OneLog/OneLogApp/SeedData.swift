import Foundation

private struct ImportedRecipeFile: Decodable {
    let source: String
    let recipes: [Recipe]
}

private struct ImportedIngredientFile: Decodable {
    let source: String
    let ingredients: [CanonicalIngredient]
}

/// 번들에 구운 변환 결과를 읽는다. 파일이 없거나 깨져도 앱은 큐레이션 데이터로 동작한다.
private func loadBundleFile<T: Decodable>(_ name: String) -> T? {
    guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
          let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
}

private let importedRecipeFile: ImportedRecipeFile? = loadBundleFile("imported_recipes")
private let importedIngredientFile: ImportedIngredientFile? = loadBundleFile("imported_ingredients")

/// 외부 데이터 출처. 공공누리 출처 표시 의무가 있어 마이페이지에 노출한다.
let externalDataSources: [String] = [importedRecipeFile?.source, importedIngredientFile?.source]
    .compactMap { $0 }
    .reduce(into: [String]()) { result, source in
        if !result.contains(source) { result.append(source) }
    }

private let curatedIngredients: [CanonicalIngredient] = [
    CanonicalIngredient(id: "egg", name: "계란", aliases: ["계란", "달걀", "계란 노른자", "달걀 노른자"], defaultUnit: .count, representativeSaleUnit: PackageSize(amount: 10, unit: .count, label: "계란 10구"), storageNote: "냉장 보관하고 깨진 계란은 먼저 사용하세요.", unitGrams: ["개": 50, "g": 1]),
    CanonicalIngredient(id: "onion", name: "양파", aliases: ["양파", "채 썬 양파", "다진 양파"], defaultUnit: .count, representativeSaleUnit: PackageSize(amount: 3, unit: .count, label: "양파 3개 묶음"), storageNote: "손질한 양파는 밀폐해 냉장 보관하세요.", unitGrams: ["개": 200, "g": 1]),
    CanonicalIngredient(id: "green-onion", name: "대파", aliases: ["대파", "다진 대파", "송송 썬 대파", "파"], defaultUnit: .gram, representativeSaleUnit: PackageSize(amount: 300, unit: .gram, label: "대파 300g"), storageNote: "손질 후 키친타월과 함께 밀폐해 냉장 보관하세요.", unitGrams: nil),
    CanonicalIngredient(id: "chicken-thigh", name: "닭다리살", aliases: ["닭다리살", "닭고기", "닭 허벅지살"], defaultUnit: .gram, representativeSaleUnit: PackageSize(amount: 500, unit: .gram, label: "닭다리살 500g"), storageNote: "구매 후 1~2일 안에 사용하고 오래 둘 때는 냉동하세요.", unitGrams: nil),
    CanonicalIngredient(id: "tofu", name: "두부", aliases: ["두부", "부침용 두부", "찌개용 두부"], defaultUnit: .pack, representativeSaleUnit: PackageSize(amount: 1, unit: .pack, label: "두부 1팩"), storageNote: "개봉 후 물에 담아 냉장 보관하고 가능한 빨리 사용하세요.", unitGrams: ["팩": 300, "g": 1]),
    CanonicalIngredient(id: "rice", name: "밥", aliases: ["밥", "즉석밥", "쌀밥"], defaultUnit: .gram, representativeSaleUnit: PackageSize(amount: 210, unit: .gram, label: "즉석밥 210g"), storageNote: "남은 밥은 식힌 뒤 밀폐해 냉장 또는 냉동 보관하세요.", unitGrams: nil),
    CanonicalIngredient(id: "kimchi", name: "김치", aliases: ["김치", "배추김치", "묵은지"], defaultUnit: .gram, representativeSaleUnit: PackageSize(amount: 500, unit: .gram, label: "김치 500g"), storageNote: "개봉 후 냉장 보관하고 덜어 먹는 집게를 사용하세요.", unitGrams: nil),
    CanonicalIngredient(id: "tuna", name: "참치캔", aliases: ["참치", "참치캔", "통조림 참치"], defaultUnit: .pack, representativeSaleUnit: PackageSize(amount: 1, unit: .pack, label: "참치캔 1개"), storageNote: "개봉 후에는 캔에서 꺼내 밀폐 냉장 보관하세요.", unitGrams: ["팩": 100, "g": 1]),
    CanonicalIngredient(id: "carrot", name: "당근", aliases: ["당근", "채 썬 당근"], defaultUnit: .gram, representativeSaleUnit: PackageSize(amount: 300, unit: .gram, label: "당근 300g"), storageNote: "물기를 닦고 밀폐해 냉장 보관하세요.", unitGrams: nil),
    CanonicalIngredient(id: "garlic", name: "다진 마늘", aliases: ["마늘", "다진 마늘", "간 마늘"], defaultUnit: .tablespoon, representativeSaleUnit: PackageSize(amount: 10, unit: .tablespoon, label: "다진 마늘 10큰술"), storageNote: "개봉한 다진 마늘은 냉장 또는 냉동 보관하세요.", unitGrams: ["큰술": 15, "g": 1]),
    CanonicalIngredient(id: "cabbage", name: "양배추", aliases: ["양배추", "채 썬 양배추"], defaultUnit: .gram, representativeSaleUnit: PackageSize(amount: 500, unit: .gram, label: "양배추 500g"), storageNote: "자른 단면을 랩으로 감싸 냉장 보관하세요.", unitGrams: nil),
    CanonicalIngredient(id: "soy-sauce", name: "간장", aliases: ["간장", "진간장", "양조간장"], defaultUnit: .tablespoon, representativeSaleUnit: PackageSize(amount: 30, unit: .tablespoon, label: "간장 30큰술"), storageNote: "직사광선을 피해 실온 보관하세요.", unitGrams: ["큰술": 18, "g": 1, "ml": 1]),
    CanonicalIngredient(id: "sesame-oil", name: "참기름", aliases: ["참기름"], defaultUnit: .tablespoon, representativeSaleUnit: PackageSize(amount: 20, unit: .tablespoon, label: "참기름 20큰술"), storageNote: "직사광선을 피해 서늘한 곳에 보관하세요.", unitGrams: ["큰술": 13, "g": 1, "ml": 1]),
    CanonicalIngredient(id: "seaweed", name: "김", aliases: ["김", "김가루", "조미김"], defaultUnit: .sheet, representativeSaleUnit: PackageSize(amount: 10, unit: .sheet, label: "김 10장"), storageNote: "습기를 피해 밀폐 보관하세요.", unitGrams: ["장": 2, "g": 1]),
    CanonicalIngredient(id: "cucumber", name: "오이", aliases: ["오이", "채 썬 오이"], defaultUnit: .count, representativeSaleUnit: PackageSize(amount: 3, unit: .count, label: "오이 3개"), storageNote: "물기를 닦고 냉장 보관하며 빨리 사용하세요.", unitGrams: ["개": 200, "g": 1]),
    CanonicalIngredient(id: "gochujang", name: "고추장", aliases: ["고추장"], defaultUnit: .tablespoon, representativeSaleUnit: PackageSize(amount: 25, unit: .tablespoon, label: "고추장 25큰술"), storageNote: "개봉 후 냉장 보관하세요.", unitGrams: ["큰술": 20, "g": 1]),
]

/// 판매 단위·보관 정보가 확인된 재료. 구매량과 예산을 정확히 계산할 수 있는 건 이쪽뿐이다.
let curatedIngredientIDs: Set<String> = Set(curatedIngredients.map(\.id))

let ingredients: [CanonicalIngredient] = {
    var seen = curatedIngredientIDs
    return curatedIngredients + (importedIngredientFile?.ingredients ?? []).filter { seen.insert($0.id).inserted }
}()

private func ingredient(_ ingredientID: String, _ rawName: String, _ quantity: Double, _ unit: Unit, _ preparation: String? = nil) -> RecipeIngredient {
    RecipeIngredient(ingredientID: ingredientID, rawName: rawName, quantity: quantity, unit: unit, preparation: preparation)
}

private let curatedRecipes: [Recipe] = [
    Recipe(
        id: "chicken-donburi",
        title: "간장 닭다리 덮밥",
        description: "닭다리살과 양파를 달큰한 간장 소스에 볶아 밥 위에 올려요.",
        mealSlots: [.lunch, .dinner], difficulty: 1, cookTime: 20, servings: 1, symbolName: "🥘",
        ingredients: [ingredient("chicken-thigh", "닭다리살", 200, .gram, "한입 크기"), ingredient("onion", "채 썬 양파", 0.5, .count), ingredient("rice", "밥", 210, .gram), ingredient("green-onion", "송송 썬 대파", 20, .gram), ingredient("soy-sauce", "간장", 1, .tablespoon), ingredient("garlic", "다진 마늘", 0.5, .tablespoon)],
        steps: ["닭다리살에 간장과 다진 마늘을 가볍게 버무려요.", "팬을 달군 뒤 닭다리살을 노릇하게 익혀요.", "양파와 대파를 넣고 숨이 죽을 때까지 볶아요.", "밥 위에 올리고 남은 소스를 끼얹어요."],
        tags: ["한 그릇", "초보 추천"], isLightBreakfast: false, requiredTools: [.pan, .knife, .bowl]
    ),
    Recipe(
        id: "tofu-kimchi",
        title: "두부 김치",
        description: "냉장고에 남은 김치와 두부로 빠르게 완성하는 든든한 한 접시예요.",
        mealSlots: [.lunch, .dinner], difficulty: 1, cookTime: 15, servings: 1, symbolName: "🍲",
        ingredients: [ingredient("tofu", "두부", 1, .pack), ingredient("kimchi", "김치", 200, .gram), ingredient("onion", "양파", 0.25, .count), ingredient("green-onion", "대파", 20, .gram), ingredient("sesame-oil", "참기름", 0.5, .tablespoon)],
        steps: ["두부를 먹기 좋은 크기로 썰어 데워요.", "팬에 참기름을 두르고 양파와 대파를 볶아요.", "김치를 넣고 5분 정도 볶아 두부와 함께 담아요."],
        tags: ["15분", "남은 재료"], isLightBreakfast: false, requiredTools: [.pan, .knife]
    ),
    Recipe(
        id: "tuna-mayo-rice",
        title: "참치마요 주먹밥",
        description: "참치캔과 밥, 김만 있으면 되는 간단한 아침 또는 도시락 메뉴예요.",
        mealSlots: [.breakfast, .lunch], difficulty: 1, cookTime: 10, servings: 1, symbolName: "🍙",
        ingredients: [ingredient("tuna", "참치캔", 1, .pack), ingredient("rice", "밥", 210, .gram), ingredient("seaweed", "김", 2, .sheet), ingredient("green-onion", "다진 대파", 10, .gram), ingredient("sesame-oil", "참기름", 0.5, .tablespoon)],
        steps: ["참치캔의 기름을 빼고 밥과 섞어요.", "대파와 참기름을 넣고 고루 섞어요.", "김을 부숴 넣거나 겉에 묻혀 주먹밥을 만들어요."],
        tags: ["10분", "불 없이"], isLightBreakfast: true, requiredTools: [.bowl]
    ),
    Recipe(
        id: "cabbage-egg-stir-fry",
        title: "양배추 계란 볶음",
        description: "양배추와 계란을 볶아 밥과 함께 먹는 가벼운 한 끼예요.",
        mealSlots: [.breakfast, .lunch, .dinner], difficulty: 1, cookTime: 12, servings: 1, symbolName: "🍳",
        ingredients: [ingredient("cabbage", "채 썬 양배추", 150, .gram), ingredient("egg", "달걀", 2, .count), ingredient("carrot", "당근", 50, .gram), ingredient("green-onion", "대파", 15, .gram), ingredient("soy-sauce", "간장", 0.5, .tablespoon)],
        steps: ["양배추와 당근을 얇게 썰어요.", "팬에 대파를 볶아 향을 낸 뒤 양배추와 당근을 넣어요.", "계란을 넣고 반숙 정도로 섞은 뒤 간장으로 간해요."],
        tags: ["냉장고 털기", "초보 추천"], isLightBreakfast: true, requiredTools: [.pan, .knife]
    ),
    Recipe(
        id: "cucumber-tuna-bowl",
        title: "오이 참치 비빔밥",
        description: "아삭한 오이와 참치, 김을 밥에 올려 불을 거의 쓰지 않고 만들어요.",
        mealSlots: [.breakfast, .lunch], difficulty: 1, cookTime: 8, servings: 1, symbolName: "🥗",
        ingredients: [ingredient("cucumber", "오이", 0.5, .count), ingredient("tuna", "참치캔", 1, .pack), ingredient("rice", "밥", 210, .gram), ingredient("seaweed", "김", 2, .sheet), ingredient("gochujang", "고추장", 0.5, .tablespoon)],
        steps: ["오이를 얇게 썰어요.", "밥 위에 오이와 참치를 올려요.", "김과 고추장을 곁들여 비벼 먹어요."],
        tags: ["8분", "남은 재료"], isLightBreakfast: true, requiredTools: [.knife, .bowl]
    ),
    Recipe(
        id: "kimchi-fried-rice",
        title: "김치 볶음밥",
        description: "남은 밥과 김치를 가장 빠르게 다음 한 끼로 바꾸는 메뉴예요.",
        mealSlots: [.breakfast, .lunch, .dinner], difficulty: 1, cookTime: 15, servings: 1, symbolName: "🍚",
        ingredients: [ingredient("rice", "밥", 210, .gram), ingredient("kimchi", "김치", 150, .gram), ingredient("egg", "계란", 1, .count), ingredient("green-onion", "대파", 20, .gram), ingredient("sesame-oil", "참기름", 0.5, .tablespoon)],
        steps: ["대파를 볶아 향을 내고 김치를 넣어요.", "밥을 넣고 김치와 고루 섞어 볶아요.", "계란을 곁들이고 참기름을 둘러 마무리해요."],
        tags: ["남은 밥", "15분"], isLightBreakfast: false, requiredTools: [.pan]
    ),
]

let recipes: [Recipe] = {
    var seen = Set(curatedRecipes.map(\.id))
    return curatedRecipes + (importedRecipeFile?.recipes ?? []).filter { seen.insert($0.id).inserted }
}()

// 950건 규모라 매번 선형 탐색하지 않는다.
private let ingredientIndex: [String: CanonicalIngredient] = Dictionary(ingredients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
private let recipeIndex: [String: Recipe] = Dictionary(recipes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

func ingredient(for id: String) -> CanonicalIngredient? {
    ingredientIndex[id]
}

func recipe(for id: String) -> Recipe? {
    recipeIndex[id]
}

func resolveIngredient(_ name: String) -> CanonicalIngredient? {
    let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: " ", with: "")
    return ingredients.first { item in
        ([item.name] + item.aliases).contains { alias in
            alias.lowercased().replacingOccurrences(of: " ", with: "") == normalized
        }
    }
}
