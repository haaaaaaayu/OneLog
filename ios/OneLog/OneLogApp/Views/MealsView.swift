import SwiftUI

/// F03·F08·F22 식단관리. 피그마 `식단 관리 1 / 메인`(454:29) 좌표를 그대로 옮긴다.
/// 시안 프레임은 393x852이고 본문은 좌우 20, 폭 353, 상태바(34) 아래 18에서 시작한다.
///
/// 이어지는 화면도 시안대로다: 식단 변경(467:117), 요리 완료(467:161), 남은 재료 활용(467:205),
/// 지난 식단 기록(467:249).
struct MealsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedDate: String?
    @State private var cookingMeal: PlannedMeal?
    @State private var changingMeal: PlannedMeal?
    @State private var isLeftoverPresented = false
    @State private var showingMyPage = false
    @State private var viewingRecipeID: String?

    private var planned: [PlannedMeal] { store.plannedMeals.filter { $0.status == .planned } }
    private var cooked: [PlannedMeal] { store.plannedMeals.filter { $0.status == .cooked } }
    private var allMeals: [PlannedMeal] { store.plannedMeals }

    /// 계획에 들어 있는 날짜들. 시안은 5칸이지만 실제 식단 길이에 맞춰 늘고 준다.
    private var planDates: [String] {
        Array(Set(allMeals.map(\.date))).sorted()
    }

    private var activeDate: String {
        selectedDate ?? planDates.first { $0 >= isoDateString() } ?? planDates.first ?? isoDateString()
    }

    private var mealsOnActiveDate: [PlannedMeal] {
        allMeals.filter { $0.date == activeDate }
    }

    private var upcomingMeals: [PlannedMeal] {
        planned.filter { $0.date > activeDate }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    brandHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                    if planDates.isEmpty {
                        emptyPlanCard
                            .padding(.horizontal, 20)
                            .padding(.top, 15)
                    } else {
                        dateStrip
                            .padding(.horizontal, 20)
                            .padding(.top, 15)
                        summarySection
                            .padding(.leading, 13) // 723:753
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 20)
                        sectionHeading("\(nickname)님의 오늘 식단", trailing: "전체 보기 ›")
                            .padding(.horizontal, 21)
                            .padding(.top, 24)
                        mealCardsRow
                            .padding(.horizontal, 17)
                            .padding(.top, 12)
                        shoppingEntry
                            .padding(.horizontal, 20)
                            .padding(.top, 15)
                        if !upcomingMeals.isEmpty {
                            sectionHeading("다음 식단", trailing: remainingDaysText)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                            upcomingList
                                .padding(.horizontal, 20)
                        }
                    }
                    historyEntry
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                    Color.clear.frame(height: 24)
                }
            }
            // 시안 `Header Gradient`(723:599)는 캔버스 **위**에 얹힌다.
            // `.background(canvas).background(gradient)` 순서로 쌓으면 불투명한 캔버스가 그라데이션을 덮는다.
            .background(alignment: .top) {
                ZStack(alignment: .top) {
                    CarePalette.canvas
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: 0xFFDC4C), location: 0),
                            .init(color: Color(hex: 0xFFE580), location: 0.5),
                            .init(color: Color(hex: 0xFFFAD9).opacity(0), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 208) // 723:599
                }
                .ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(item: $cookingMeal) { meal in
                CookingView(meal: meal) {
                    cookingMeal = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isLeftoverPresented = true
                    }
                }
                .environmentObject(store)
            }
            .fullScreenCover(item: $changingMeal) { meal in
                MealChangeView(meal: meal).environmentObject(store)
            }
            .fullScreenCover(isPresented: $showingMyPage) {
                MyPageView().environmentObject(store)
            }
            .sheet(isPresented: Binding(get: { viewingRecipeID != nil }, set: { if !$0 { viewingRecipeID = nil } })) {
                if let viewingRecipeID {
                    NavigationStack {
                        RecipeDetailView(recipeID: viewingRecipeID).environmentObject(store)
                    }
                }
            }
            .navigationDestination(isPresented: $isLeftoverPresented) {
                LeftoverUseView().environmentObject(store)
            }
        }
    }

    private var nickname: String {
        let value = store.state.profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "회원" : value
    }

    // MARK: - 브랜드 헤더 (739:2508)

    private var brandHeader: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Image("BrandWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 93, height: 33)
                Text("내 취향 한끼부터, 남은 재료까지")
                    .figmaText(7)
                    .foregroundStyle(CarePalette.muted)
            }
            Spacer(minLength: 8)
            Button {
                showingMyPage = true
            } label: {
                Image("IconProfile")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundStyle(CarePalette.ink)
            }
            .accessibilityLabel("마이페이지")
        }
    }

    // MARK: - 날짜 선택 (723:689)

    private var dateStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(planDates, id: \.self) { date in
                    let isSelected = date == activeDate
                    let isToday = date == isoDateString()
                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 3) {
                            Text(dayText(date))
                                .figmaText(20, .bold)
                                .foregroundStyle(isSelected ? CarePalette.ink : Color(hex: 0x332B1A))
                            Text(isToday ? "오늘" : weekdayText(date))
                                .figmaText(11, .medium)
                                .foregroundStyle(isSelected ? CarePalette.ink : Color(hex: 0x6B5C3D))
                        }
                        .frame(width: 64, height: 64)
                        .background(isSelected ? .white : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white, lineWidth: 1)
                            }
                        }
                        .shadow(color: .black.opacity(isSelected ? 0.1 : 0), radius: 5, y: 3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(displayDate(date)) 식단 보기")
                    .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
                }
            }
        }
    }

    // MARK: - 요약 (723:753)

    private var summarySection: some View {
        let total = allMeals.count
        let done = cooked.count

        // 시안 723:753 — 왼쪽 카드 열 171.5, 오른쪽 문구·마스코트 열 173, 사이 23.5.
        return HStack(alignment: .top, spacing: 23.5) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("이번 식단")
                        .figmaText(11, .medium)
                        .foregroundStyle(CarePalette.muted)
                    Text("\(done) / \(total)끼 완료")
                        .figmaText(16, .bold)
                        .foregroundStyle(CarePalette.ink)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(CarePalette.track)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(CarePalette.brand)
                                .frame(width: total > 0 ? proxy.size.width * CGFloat(done) / CGFloat(total) : 0)
                        }
                    }
                    .frame(height: 7)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(height: 78)
                .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .oneLogCardShadow()

                Button {
                    isLeftoverPresented = true
                } label: {
                    // 723:759 — `보러가기 ›`는 개수 아래가 아니라 오른쪽 아래에 붙는다(x115, y48).
                    VStack(alignment: .leading, spacing: 0) {
                        Text("남은 재료")
                            .figmaText(11, .medium)
                            .foregroundStyle(CarePalette.muted)
                        HStack(alignment: .bottom, spacing: 8) {
                            Text("\(store.state.inventory.count)개")
                                .figmaText(24, .bold)
                                .foregroundStyle(CarePalette.ink)
                            Spacer(minLength: 4)
                            Text("보러가기 ›")
                                .figmaText(11, .bold)
                                .foregroundStyle(Color(hex: 0xB8800D))
                                .padding(.bottom, 2)
                        }
                        .padding(.top, 6)
                    }
                    .padding(16)
                    .frame(height: 78, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .oneLogCardShadow()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("meals.leftover")
            }
            .frame(width: 171.5) // 723:754

            VStack(alignment: .leading, spacing: 6) {
                Text("\(nickname)님,")
                    .figmaText(21, .bold)
                    .foregroundStyle(CarePalette.ink)
                // 723:763 — 시안은 한 줄로 흘려보낸다(whitespace-nowrap). 좁은 칸에서 접히면 마스코트가 밀린다.
                Text(planEncouragement)
                    .figmaText(16, .bold)
                    .foregroundStyle(CarePalette.ink)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.top, 4)
                Text("“\(nextMealHint)”")
                    .figmaText(11, .medium)
                    .foregroundStyle(CarePalette.bannerBody)
                    .fixedSize(horizontal: true, vertical: false)

                Image("HomeMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 173)
                    .frame(width: 173, height: 136, alignment: .top)
                    .clipped()
                    .padding(.top, 4)
            }
            .frame(width: 173, alignment: .leading) // 723:752
        }
    }

    /// 계획한 만큼 요리했는지에 따라 문구를 고른다. 숫자는 실제 상태에서만 가져온다(AGENTS 8절).
    private var planEncouragement: String {
        let total = allMeals.count
        guard total > 0 else { return "식단을 만들어볼까요?" }
        return cooked.count >= total ? "이번 식단을 다 완료했어요!" : "계획대로 잘하고 있어요!"
    }

    private var nextMealHint: String {
        guard let next = mealsOnActiveDate.first(where: { $0.status == .planned }) else {
            return "오늘 남은 끼니가 없어요"
        }
        return "오늘 \(next.mealSlot.rawValue)도 계획대로 준비해봐요!"
    }

    private var plannedDrafts: [PlannedMealDraft] {
        planned.map { PlannedMealDraft(recipeID: $0.recipeID, date: $0.date, mealSlot: $0.mealSlot, reason: "", reusedIngredientIDs: [], newPurchaseCount: 0) }
    }

    // MARK: - 오늘 식단 카드 (723:568)

    private var mealCardsRow: some View {
        Group {
            if mealsOnActiveDate.isEmpty {
                Text("이 날짜에는 계획한 식사가 없어요.")
                    .figmaText(13, .medium)
                    .foregroundStyle(CarePalette.muted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(mealsOnActiveDate) { meal in
                            MealsPhotoCard(meal: meal) {
                                if meal.status == .cooked {
                                    viewingRecipeID = meal.recipeID
                                } else if meal.status == .planned {
                                    cookingMeal = meal
                                } else {
                                    changingMeal = meal
                                }
                            }
                            .contextMenu {
                                if meal.status != .cooked {
                                    Button("일정 변경") { changingMeal = meal }
                                    Button("삭제", role: .destructive) { store.removeMeal(meal.id) }
                                }
                            }
                            .accessibilityIdentifier("meals.card.\(meal.id)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - 장보기 진입 (723:560)

    private var shoppingEntry: some View {
        let items = store.currentShoppingItems
        let checked = items.filter { store.state.purchaseChecks[$0.id] == true }.count

        return NavigationLink {
            ShoppingView().environmentObject(store)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("장보기 리스트")
                        .figmaText(16, .bold)
                        .foregroundStyle(CarePalette.ink)
                    Spacer(minLength: 8)
                    HStack(spacing: 6) {
                        Text(items.isEmpty ? "준비할 재료 없음" : "\(checked) / \(items.count)개 준비")
                            .figmaText(12)
                            .foregroundStyle(Color(hex: 0x918A7D))
                        Text("›")
                            .figmaText(18)
                            .foregroundStyle(Color(hex: 0x918A7D))
                    }
                }
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(CarePalette.track)
                    .frame(height: 6)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .fill(CarePalette.brand)
                                .frame(width: items.isEmpty ? 0 : proxy.size.width * CGFloat(checked) / CGFloat(items.count))
                        }
                    }
            }
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: 0xEBE3D4), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("meals.shopping")
    }

    // MARK: - 섹션 제목 (518:72)

    private func sectionHeading(_ title: String, trailing: String) -> some View {
        HStack {
            Text(title)
                .figmaText(16, .bold)
                .foregroundStyle(CarePalette.ink)
            Spacer(minLength: 8)
            Text(trailing)
                .figmaText(11, .medium)
                .foregroundStyle(CarePalette.muted)
        }
        .frame(height: 22)
    }

    private var remainingDaysText: String {
        guard let last = planDates.last else { return "" }
        let days = daysBetween(isoDateString(), last)
        return days > 0 ? "\(days)일 남음" : "오늘까지"
    }

    // MARK: - 다음 식단 목록 (518:101)

    private var upcomingList: some View {
        CareCard(padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)) {
            VStack(spacing: 0) {
                ForEach(Array(upcomingMeals.enumerated()), id: \.element.id) { index, meal in
                    Button {
                        selectedDate = meal.date
                    } label: {
                        HStack(spacing: 8) {
                            Text(shortWeekdayDay(meal.date))
                                .figmaText(16, .bold)
                                .foregroundStyle(CarePalette.ink)
                            Text("\(meal.mealSlot.rawValue) · \(recipe(for: meal.recipeID)?.title ?? "삭제된 메뉴")")
                                .figmaText(13, .medium)
                                .foregroundStyle(CarePalette.muted)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(recipe(for: meal.recipeID)?.cookTimeText ?? "")
                                .figmaText(11, .medium)
                                .foregroundStyle(CarePalette.muted)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(height: 40)
                    }
                    .buttonStyle(.plain)

                    if index < upcomingMeals.count - 1 {
                        Rectangle()
                            .fill(CarePalette.divider)
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    // MARK: - 지난 식단 기록 (518:114)

    private var historyEntry: some View {
        NavigationLink {
            MealHistoryView().environmentObject(store)
        } label: {
            CareCard(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("지난 식단 기록")
                            .figmaText(16, .bold)
                            .foregroundStyle(CarePalette.ink)
                        Text(cooked.isEmpty ? "완료한 식단이 아직 없어요" : "완료한 식단과 절약 금액 확인")
                            .figmaText(11, .medium)
                            .foregroundStyle(CarePalette.muted)
                    }
                    Spacer(minLength: 8)
                    Text("›")
                        .figmaText(24, .bold)
                        .foregroundStyle(CarePalette.ink)
                }
                .frame(height: 36)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("meals.history")
    }

    private var emptyPlanCard: some View {
        CareCard(padding: EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16)) {
            VStack(alignment: .leading, spacing: 6) {
                Text("아직 계획한 식단이 없어요")
                    .figmaText(16, .bold)
                    .foregroundStyle(CarePalette.ink)
                Text("오른쪽 위 설정 버튼으로 식단을 만들면 이 화면에서 이어서 관리할 수 있어요.")
                    .figmaText(11, .medium)
                    .foregroundStyle(CarePalette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 시안 값

/// 피그마 `식단 관리` 화면의 색. 다른 화면과 1씩 달라도 시안 그대로 둔다.
enum CarePalette {
    static let canvas = Color(hex: 0xFEFCF6)
    static let ink = Color(hex: 0x141412)
    static let dayInk = Color(hex: 0x14120D)
    static let muted = Color(hex: 0x998C78)
    static let brand = Color(hex: 0xFFC914)
    static let daySelected = Color(hex: 0xFFE29A)
    static let track = Color(hex: 0xEFE7D6)
    static let divider = Color(hex: 0xEFE7D6)
    static let line = Color(hex: 0xDED4B5)
    static let thumb = Color(hex: 0xFFF4C9)
    static let dark = Color(hex: 0x2C2C2C)
    static let onDark = Color(hex: 0xF5F5F5)
    static let bannerBody = Color(hex: 0x574F40)
    static let itemText = Color(hex: 0x574F40)
    static let back = Color(hex: 0xFFF4C9)
}

/// 시안 카드: 흰 배경, radius 20, `0 4 16 rgba(0,0,0,0.06)` 그림자.
struct CareCard<Content: View>: View {
    var padding = EdgeInsets()
    var fill: Color = .white
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .oneLogCardShadow()
    }
}

/// 시안 `Meal/아침·점심·저녁`(723:569). 홈 탭과 같은 사진 카드로 오늘 식단을 보여준다.
private struct MealsPhotoCard: View {
    let meal: PlannedMeal
    let onTap: () -> Void

    private var item: Recipe? { recipe(for: meal.recipeID) }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.oneLogPhoto)
                    .overlay {
                        if let urlString = item?.imageURL, let url = URL(string: urlString) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.clear
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            Text(item?.symbolName ?? "🍚")
                                .figmaText(40)
                        }
                    }

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0), location: 0),
                        .init(color: .black.opacity(0.05), location: 0.4),
                        .init(color: .black.opacity(0.85), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack(spacing: 0) {
                    pill(meal.mealSlot.rawValue, foreground: .oneLogInk, background: .white, border: .oneLogChipLine)
                    Spacer(minLength: 4)
                    if meal.status == .cooked {
                        pill("완료", foreground: .oneLogSuccess, background: .oneLogSuccessBackground, border: nil)
                    } else if meal.status == .skipped {
                        pill("건너뜀", foreground: .oneLogOrange, background: .oneLogChip, border: nil)
                    } else {
                        pill("예정", foreground: .oneLogFaint, background: .oneLogChip, border: nil)
                    }
                }
                .padding(8)

                VStack(alignment: .leading, spacing: 5) {
                    Text(item?.title ?? "삭제된 메뉴")
                        .figmaText(13, .bold, lineHeight: 18)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .frame(width: 130, alignment: .leading)
                    Text("재료 \(item?.ingredients.count ?? 0)개 · \(item?.cookTimeText ?? "조리시간 미확인")")
                        .figmaText(11)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .frame(width: 150, height: 153, alignment: .bottomLeading)
            }
            .frame(width: 150, height: 153)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .oneLogCardShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item?.title ?? "메뉴") \(meal.mealSlot.rawValue)")
    }

    private func pill(_ text: String, foreground: Color, background: Color, border: Color?) -> some View {
        Text(text)
            .figmaText(10, .bold)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
            .overlay {
                if let border {
                    Capsule().stroke(border, lineWidth: 1)
                }
            }
    }
}

/// 시안 `Meal Plan / Header`(479:37)와 같은 형태. ‹ + 가운데 제목 + 오른쪽 보조 문구.
struct CareHeader: View {
    let title: String
    var trailing: String?
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .figmaText(18, .bold)
                .foregroundStyle(CarePalette.ink)

            HStack {
                Button(action: onBack) {
                    Image("IconBack")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(CarePalette.ink)
                        .frame(width: 36, height: 36)
                        .background(.white, in: Circle())
                        .overlay { Circle().stroke(Color(hex: 0xE3D9BF), lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로")
                Spacer()
                if let trailing {
                    Text(trailing)
                        .figmaText(11, .medium)
                        .foregroundStyle(CarePalette.muted)
                }
            }
        }
        .frame(height: 46)
    }
}

// MARK: - 날짜 표기

private func weekdayText(_ iso: String) -> String {
    koreanFormatter("E").string(from: dateFromISO(iso))
}

private func dayText(_ iso: String) -> String {
    koreanFormatter("d").string(from: dateFromISO(iso))
}

func shortWeekdayDay(_ iso: String) -> String {
    koreanFormatter("E d").string(from: dateFromISO(iso))
}

private func shortDate(_ iso: String, includeMonth: Bool = true) -> String {
    koreanFormatter(includeMonth ? "M월 d일" : "d일").string(from: dateFromISO(iso))
}

private func daysBetween(_ from: String, _ to: String) -> Int {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
    let start = calendar.startOfDay(for: dateFromISO(from))
    let end = calendar.startOfDay(for: dateFromISO(to))
    return calendar.dateComponents([.day], from: start, to: end).day ?? 0
}

private func koreanFormatter(_ format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    formatter.dateFormat = format
    return formatter
}

// MARK: - 시안 3~5가 나오기 전까지 쓰는 기존 시트

private struct MealReplaceView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let meal: PlannedMeal

    private var candidates: [Recipe] {
        recipes.filter { $0.mealSlots.contains(meal.mealSlot) }
    }

    var body: some View {
        NavigationStack {
            List(candidates) { candidate in
                Button {
                    store.replaceMeal(meal.id, recipeID: candidate.id)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text(candidate.symbolName).font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 7) {
                                Text(candidate.title).figmaText(14, .bold).foregroundStyle(CarePalette.ink)
                                if !isRecommendable(candidate, preferences: store.state.preferences) {
                                    StatusPill(text: "추천 제외 조건", tint: .oneLogOrange)
                                }
                            }
                            Text("\(candidate.cookTimeText) · \(candidate.description)")
                                .figmaText(11)
                                .foregroundStyle(CarePalette.muted)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .navigationTitle("\(meal.mealSlot.rawValue) 메뉴 바꾸기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
        }
    }
}

private struct MealMoveView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let meal: PlannedMeal
    @State private var date: Date
    @State private var slot: MealSlot

    init(meal: PlannedMeal) {
        self.meal = meal
        _date = State(initialValue: dateFromISO(meal.date))
        _slot = State(initialValue: meal.mealSlot)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("먹지 않은 식사를 옮기면 해당 날짜의 사용 예정일과 보관 주의를 다시 계산할 수 있어요.")
                        .font(.footnote)
                        .foregroundStyle(CarePalette.muted)
                }
                Section("새 일정") {
                    DatePicker("날짜", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    Picker("끼니", selection: $slot) {
                        ForEach(MealSlot.allCases) { slot in Text(slot.rawValue).tag(slot) }
                    }
                }
                if let recipe = recipe(for: meal.recipeID) {
                    Section("보관 주의") {
                        ForEach(recipe.ingredients.compactMap { item -> String? in
                            guard let canonical = ingredient(for: item.ingredientID), let note = canonical.storageNote else { return nil }
                            return "\(canonical.name): \(note)"
                        }, id: \.self) { text in
                            Text(text).font(.footnote).foregroundStyle(Color.oneLogOrange)
                        }
                    }
                }
                Section {
                    Button("이 일정으로 옮기기") {
                        store.moveMeal(meal.id, date: isoDateString(date), slot: slot)
                        dismiss()
                    }
                    .font(.body.weight(.bold))
                    .foregroundStyle(CarePalette.ink)
                }
            }
            .navigationTitle("식사 일정 옮기기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
        }
    }
}

private struct CookingView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let meal: PlannedMeal
    let onUseLeftovers: () -> Void
    @State private var doneConsumptions: [CookingConsumption]?
    @State private var isChangingMeal = false

    private var recipeModel: Recipe? { recipe(for: meal.recipeID) }

    var body: some View {
        NavigationStack {
            Group {
                if let doneConsumptions {
                    CookingDoneView(consumptions: doneConsumptions, onUseLeftovers: onUseLeftovers)
                        .environmentObject(store)
                } else if isChangingMeal {
                    MealChangeView(meal: meal).environmentObject(store)
                } else if meal.status != .planned {
                    VStack(alignment: .leading, spacing: 14) {
                        EmptyState(
                            symbol: meal.status == .cooked ? "checkmark.circle" : "pause.circle",
                            title: meal.status == .cooked ? "이미 요리한 식사예요" : "건너뛴 식사예요",
                            message: meal.status == .cooked ? "재고를 다시 차감하지 않도록 완료 상태를 유지해요." : "식단 변경에서 다시 예정으로 되돌린 뒤 요리할 수 있어요."
                        )
                        if meal.status == .skipped {
                            Button("다시 예정으로 되돌리기") {
                                store.setMealSkipped(meal.id, skipped: false)
                                dismiss()
                            }
                            .font(.body.weight(.bold))
                            .foregroundStyle(CarePalette.ink)
                        }
                    }
                    .padding(20)
                } else {
                    RecipeDetailView(
                        recipeID: meal.recipeID,
                        actionTitle: "요리 완료하기",
                        onAddToPlan: completeWithPlannedQuantities,
                        actionFill: Color(hex: 0x2C2C2C),
                        actionForeground: Color(hex: 0xF5F5F5),
                        actionHeight: 48,
                        dismissesAfterAction: false,
                        secondaryActionTitle: "오늘 요리하기 어려워요",
                        onSecondaryAction: { isChangingMeal = true }
                    )
                    .environmentObject(store)
                }
            }
            .navigationTitle("요리하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
        }
    }

    /// Figma에는 별도의 사용량 입력 단계가 없다. 레시피 상세에 표시된 계획 수량을 그대로
    /// 멱등 재고 차감에 사용하고 곧바로 `요리 완료` 화면으로 이동한다.
    private func completeWithPlannedQuantities() {
        guard let recipeModel else { return }
        let recipe = recipeModel
        let consumptions = mergedCookingIngredients(recipe.ingredients).map { item in
            CookingConsumption(
                ingredientID: item.ingredientID,
                unit: item.unit,
                expectedQuantity: item.quantity,
                actualQuantity: item.quantity,
                remainingQuantity: nil
            )
        }
        if store.completeMeal(meal.id, consumptions: consumptions) { doneConsumptions = consumptions }
    }
}

private func dateFromISO(_ value: String) -> Date {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value) ?? Date()
}

// MARK: - 식단 변경 (467:117)

/// 시안 `식단 관리 4 / 일정 변경`. 네 갈래를 한 화면에서 고른다.
private struct MealChangeView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let meal: PlannedMeal

    @State private var isMovePresented = false
    @State private var isReplacePresented = false
    @State private var isDeleteConfirmPresented = false

    private var title: String { recipe(for: meal.recipeID)?.title ?? "이 메뉴" }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    CareHeader(title: "식단 변경") { dismiss() }

                    Text("\(title)\(objectParticle) 어떻게 할까요?")
                        .figmaText(24, .bold)
                        .foregroundStyle(CarePalette.ink)
                        .padding(.top, 29)

                    Text("재료와 남은 예산은 선택에 맞춰 다시 계산돼요.")
                        .figmaText(13, .medium)
                        .foregroundStyle(CarePalette.muted)
                        .padding(.top, 13)

                    if meal.status == .cooked {
                        CareCard(padding: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16), fill: CarePalette.thumb) {
                            Text("완료한 식사는 재고 차감 기록을 보호하기 위해 일정을 바꿀 수 없어요.")
                                .figmaText(12, .medium, lineHeight: 18)
                                .foregroundStyle(CarePalette.ink)
                        }
                    } else {
                        VStack(spacing: 8) {
                            option("다른 날로 미루기", "\(planDayCount)일 식단 안의 빈 끼니로 이동") { isMovePresented = true }
                            option("다른 메뉴로 바꾸기", "예산과 재료가 비슷한 메뉴 추천") { isReplacePresented = true }
                            option(meal.status == .skipped ? "다시 예정으로 되돌리기" : "오늘만 비활성화",
                                   "재료는 차감하지 않고 그대로 보관") {
                                store.setMealSkipped(meal.id, skipped: meal.status != .skipped)
                                dismiss()
                            }
                            option("식단에서 삭제", "남은 예산과 장보기 목록 다시 계산") { isDeleteConfirmPresented = true }
                        }
                        .padding(.top, 31)
                    }

                    Button { dismiss() } label: {
                        Text("변경 완료")
                            .figmaText(16, .bold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(hex: 0x12120F), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 34)
                }
                .padding(.horizontal, 20)
                .padding(.top, 42)
                .padding(.bottom, 24)
            }
            .ignoresSafeArea(edges: .top)
            .background(CarePalette.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isMovePresented) {
                MealMoveView(meal: meal).environmentObject(store)
            }
            .sheet(isPresented: $isReplacePresented) {
                MealReplaceView(meal: meal).environmentObject(store)
            }
            .confirmationDialog("이 식사를 삭제할까요?", isPresented: $isDeleteConfirmPresented, titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    store.removeMeal(meal.id)
                    dismiss()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("남은 예산과 장보기 목록을 다시 계산해요.")
            }
        }
    }

    private var objectParticle: String {
        guard let scalar = title.unicodeScalars.last?.value,
              (0xAC00...0xD7A3).contains(scalar) else { return "을" }
        return (scalar - 0xAC00) % 28 == 0 ? "를" : "을"
    }

    private var planDayCount: Int {
        max(Set(store.plannedMeals.map(\.date)).count, 1)
    }

    private func option(_ title: String, _ caption: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).figmaText(16, .bold).foregroundStyle(CarePalette.ink)
                    Text(caption).figmaText(11, .medium).foregroundStyle(CarePalette.muted)
                }
                Spacer(minLength: 8)
                Text("›").figmaText(24, .bold).foregroundStyle(CarePalette.ink)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(height: 56)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(CarePalette.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 요리 완료 (467:161)

/// 시안 `식단 관리 5 / 요리 완료`. 조리 후 재고가 얼마나 남았는지 보여준다.
struct CookingDoneView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let consumptions: [CookingConsumption]
    let onUseLeftovers: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                CareHeader(title: "요리 완료") { dismiss() }

                ZStack(alignment: .top) {
                    Image("CookingDoneMascot")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 217, height: 132)
                        .padding(.top, 29)
                    Text("한 끼를 완성했어요!")
                        .figmaText(20, .bold)
                        .foregroundStyle(CarePalette.ink)
                        .padding(.top, 176)
                    Text("사용한 재료를 냉장고에서 자동으로 차감했어요.")
                        .figmaText(10, .medium)
                        .foregroundStyle(CarePalette.muted)
                        .padding(.top, 210)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .frame(height: 286, alignment: .top)

                CareCard(padding: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("재료 사용 결과")
                            .figmaText(16, .bold)
                            .foregroundStyle(CarePalette.ink)

                        VStack(spacing: 0) {
                            ForEach(Array(consumptions.enumerated()), id: \.offset) { index, consumption in
                                HStack {
                                    Text("\(ingredient(for: consumption.ingredientID)?.name ?? "재료") \(formatQuantity(consumption.actualQuantity, unit: consumption.unit))")
                                        .figmaText(13, .medium)
                                        .foregroundStyle(CarePalette.itemText)
                                    Spacer(minLength: 8)
                                    Text(remainingText(consumption))
                                        .figmaText(14, .bold)
                                        .foregroundStyle(CarePalette.ink)
                                }
                                .padding(.vertical, 11)
                                .frame(height: 44)

                                if index < consumptions.count - 1 {
                                    Rectangle().fill(CarePalette.divider).frame(height: 1)
                                }
                            }
                        }
                        .padding(.top, 9)
                    }
                }

                Button(action: onUseLeftovers) {
                    Text("남은 재료 활용하기")
                        .figmaText(16, .bold)
                        .foregroundStyle(CarePalette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(hex: 0xFFDF5A), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cooking.useLeftovers")
                .padding(.top, 31)

                Button { dismiss() } label: {
                    Text("식단관리로 돌아가기")
                        .figmaText(16, .bold)
                        .foregroundStyle(CarePalette.itemText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(CarePalette.line, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .padding(.top, 11)
            }
            .padding(.horizontal, 20)
            .padding(.top, 42)
            .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .top)
        .background(CarePalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
    }

    /// 남은 양은 냉장고에 실제로 기록된 값만 보여준다. 없으면 지어내지 않는다.
    private func remainingText(_ consumption: CookingConsumption) -> String {
        let stock = store.state.inventory.first {
            $0.ingredientID == consumption.ingredientID && $0.unit == consumption.unit && $0.quantityStatus == .exact
        }
        guard let quantity = stock?.quantity else { return "남은 양 미확인" }
        return "\(formatQuantity(quantity, unit: consumption.unit)) 남음"
    }
}

// MARK: - 남은 재료 활용 (467:205)

/// 시안 `식단 관리 6 / 남은 재료 활용`.
struct LeftoverUseView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var addingRecipe: Recipe?

    private var leftovers: [InventoryItem] {
        store.state.inventory
            .filter { ($0.quantity ?? 0) > 0 || $0.quantityStatus == .unknown }
            .sorted { ($0.quantity ?? 0) > ($1.quantity ?? 0) }
    }

    private var recommendations: [LeftoverRecommendation] {
        Array(leftoverRecommendations(inventory: store.state.inventory, preferences: store.state.preferences).prefix(5))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                CareHeader(title: "남은 재료 활용") { dismiss() }
                    .padding(.bottom, 4)

                CareCard(padding: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("먼저 사용하면 좋은 재료")
                            .figmaText(16, .bold)
                            .foregroundStyle(CarePalette.ink)

                        if leftovers.isEmpty {
                            Text("냉장고에 기록된 재료가 없어요.")
                                .figmaText(11, .medium)
                                .foregroundStyle(CarePalette.muted)
                                .padding(.vertical, 12)
                        }

                        ForEach(Array(leftovers.prefix(6).enumerated()), id: \.element.id) { index, item in
                            HStack {
                                Text(ingredient(for: item.ingredientID)?.name ?? item.ingredientID)
                                    .figmaText(13, .medium)
                                    .foregroundStyle(CarePalette.itemText)
                                Spacer(minLength: 8)
                                Text(leftoverText(item))
                                    .figmaText(16, .bold)
                                    .foregroundStyle(CarePalette.ink)
                            }
                            .padding(.vertical, 10)
                            .frame(height: 42)

                            if index < min(leftovers.count, 6) - 1 {
                                Rectangle().fill(CarePalette.divider).frame(height: 1)
                            }
                        }
                    }
                }

                HStack {
                    Text("다음 한 끼 추천").figmaText(16, .bold).foregroundStyle(CarePalette.ink)
                    Spacer(minLength: 8)
                    Text("남은 재료 기준").figmaText(11, .medium).foregroundStyle(CarePalette.muted)
                }
                .frame(height: 22)

                if recommendations.isEmpty {
                    CareCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                        Text("추천할 메뉴가 아직 없어요. 냉장고에 남은 재료를 기록해 보세요.")
                            .figmaText(11, .medium)
                            .foregroundStyle(CarePalette.muted)
                    }
                }

                ForEach(recommendations, id: \.recipe.id) { recommendation in
                    recommendationCard(recommendation)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 42)
            .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .top)
        .background(CarePalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $addingRecipe) { recipe in
            LeftoverAddView(recipe: recipe).environmentObject(store)
        }
    }

    private func leftoverText(_ item: InventoryItem) -> String {
        guard item.quantityStatus == .exact, let quantity = item.quantity else { return "수량 미상" }
        var text = formatQuantity(quantity, unit: item.unit)
        if let note = ingredient(for: item.ingredientID)?.storageNote { text += " · \(note)" }
        return text
    }

    private func recommendationCard(_ recommendation: LeftoverRecommendation) -> some View {
        CareCard(padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)) {
            HStack(spacing: 12) {
                RecipePhoto(recipe: recommendation.recipe)
                    .frame(width: 80, height: 72)
                    .clipped()
                    .background(CarePalette.thumb, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(recommendation.additionalPurchaseItems.isEmpty ? "추가 구매 없음" : "\(recommendation.additionalPurchaseItems.count)가지만 더 사면 돼요")
                        .figmaText(11, .medium)
                        .foregroundStyle(CarePalette.itemText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(CarePalette.daySelected, in: Capsule())

                    Text(recommendation.recipe.title)
                        .figmaText(16, .bold)
                        .foregroundStyle(CarePalette.ink)
                        .lineLimit(1)

                    Text(metaText(recommendation.recipe))
                        .figmaText(11, .medium)
                        .foregroundStyle(CarePalette.muted)

                    HStack(spacing: 6) {
                        NavigationLink {
                            // 시안 `식단 관리 3 / 레시피 상세`는 레시피 탭 상세(391:598 계열)와 같은 화면을 쓴다.
                            RecipeDetailView(recipeID: recommendation.recipe.id)
                                .environmentObject(store)
                        } label: {
                            Text("레시피 보기")
                                .figmaText(11, .medium)
                                .foregroundStyle(CarePalette.itemText)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(.white, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .strokeBorder(CarePalette.line, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)

                        Button {
                            addingRecipe = recommendation.recipe
                        } label: {
                            Text("식단에 추가")
                                .figmaText(11, .medium)
                                .foregroundStyle(CarePalette.ink)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(CarePalette.brand, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func metaText(_ item: Recipe) -> String {
        if let label = recipeDifficultyLabel(item) { return "\(label) · \(item.cookTimeText)" }
        return item.cookTimeText
    }
}

/// 남은 재료 추천을 실제 식단에 넣는 작은 시트. 날짜·끼니만 고른다.
private struct LeftoverAddView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe

    @State private var date = Date()
    @State private var slot: MealSlot = .dinner

    var body: some View {
        NavigationStack {
            Form {
                Section("메뉴") {
                    LabeledContent(recipe.title, value: recipe.cookTimeText)
                }
                Section("언제 먹을까요?") {
                    DatePicker("날짜", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    Picker("끼니", selection: $slot) {
                        ForEach(recipe.mealSlots) { slot in Text(slot.rawValue).tag(slot) }
                    }
                }
            }
            .navigationTitle("식단에 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        _ = store.addPlannedMeal(recipeID: recipe.id, date: isoDateString(date), slot: slot)
                        dismiss()
                    }
                }
            }
            .onAppear { slot = recipe.mealSlots.first ?? .dinner }
        }
    }
}

// MARK: - 지난 식단 기록 (467:249)

/// 시안 `식단 관리 7 / 지난 식단 기록`. 연속된 날짜를 한 식단으로 묶는다.
struct MealHistoryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var cooked: [PlannedMeal] { store.plannedMeals.filter { $0.status == .cooked } }

    /// 완료한 끼니를 날짜가 이어지는 덩어리로 묶는다(하루 이상 비면 다른 식단으로 본다).
    private var periods: [(dates: [String], meals: [PlannedMeal])] {
        let sorted = cooked.sorted { $0.date < $1.date }
        var groups: [[PlannedMeal]] = []
        for meal in sorted {
            if var last = groups.last, let lastDate = last.last?.date, daysBetweenDates(lastDate, meal.date) <= 1 {
                last.append(meal)
                groups[groups.count - 1] = last
            } else {
                groups.append([meal])
            }
        }
        return groups.reversed().map { group in
            (Array(Set(group.map(\.date))).sorted(), group)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                CareHeader(title: "지난 식단 기록") { dismiss() }

                HStack(spacing: 10) {
                    CareCard(padding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("누적 완료").figmaText(11, .medium).foregroundStyle(CarePalette.muted)
                            Text("\(cooked.count)끼").figmaText(24, .bold).foregroundStyle(CarePalette.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    CareCard(padding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14), fill: CarePalette.thumb) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("이번 달 절약").figmaText(11, .medium).foregroundStyle(CarePalette.muted)
                            Text(won(store.monthlyConfirmedSavings))
                                .figmaText(24, .bold)
                                .foregroundStyle(CarePalette.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(height: 82)

                if periods.isEmpty {
                    CareCard(padding: EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16)) {
                        Text("아직 완료한 식사가 없어요.")
                            .figmaText(13, .medium)
                            .foregroundStyle(CarePalette.muted)
                    }
                } else {
                    CareCard(padding: EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)) {
                        VStack(spacing: 0) {
                            ForEach(Array(periods.enumerated()), id: \.offset) { index, period in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(periodTitle(period.dates))
                                            .figmaText(16, .bold)
                                            .foregroundStyle(CarePalette.ink)
                                        Text("\(period.dates.count)일 식단 · \(period.meals.count)끼 완료")
                                            .figmaText(11, .medium)
                                            .foregroundStyle(CarePalette.muted)
                                    }
                                    Spacer(minLength: 8)
                                }
                                .padding(.vertical, 12)
                                .frame(height: 66)

                                if index < periods.count - 1 {
                                    Rectangle().fill(CarePalette.divider).frame(height: 1)
                                }
                            }
                        }
                    }
                }

                Button { dismiss() } label: {
                    Text("현재 식단으로 돌아가기")
                        .figmaText(16, .bold)
                        .foregroundStyle(CarePalette.onDark)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(CarePalette.dark, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(CarePalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func periodTitle(_ dates: [String]) -> String {
        guard let first = dates.first, let last = dates.last else { return "" }
        return first == last ? displayDate(first) : "\(displayDate(first)) - \(displayDate(last))"
    }
}

func daysBetweenDates(_ from: String, _ to: String) -> Int {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
    let start = calendar.startOfDay(for: isoDate(from))
    let end = calendar.startOfDay(for: isoDate(to))
    return abs(calendar.dateComponents([.day], from: start, to: end).day ?? 0)
}

func isoDate(_ value: String) -> Date {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value) ?? Date()
}
