import SwiftUI

/// F03·F08·F22 식단관리. 피그마 `식단 관리 1 / 메인`(454:29) 좌표를 그대로 옮긴다.
/// 시안 프레임은 393x852이고 본문은 좌우 20, 폭 353, 상태바(34) 아래 18에서 시작한다.
///
/// 시안 3~5(레시피 상세·일정 변경·요리 완료)는 아직 없어서 기존 시트를 그대로 쓴다.
struct MealsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedDate: String?
    @State private var cookingMeal: PlannedMeal?
    @State private var movingMeal: PlannedMeal?
    @State private var replacingMeal: PlannedMeal?

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
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if planDates.isEmpty {
                        emptyPlanCard
                    } else {
                        dayStrip
                        summaryRow
                        shoppingEntry
                        sectionHeading("오늘 먹을 식단", trailing: "\(mealsOnActiveDate.count)끼")
                        if mealsOnActiveDate.isEmpty {
                            CareCard {
                                Text("이 날짜에는 계획한 식사가 없어요.")
                                    .figmaText(13, .medium)
                                    .foregroundStyle(CarePalette.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
                            }
                        }
                        ForEach(mealsOnActiveDate) { meal in
                            mealCard(meal)
                        }
                        if !upcomingMeals.isEmpty {
                            sectionHeading("다음 식단", trailing: remainingDaysText)
                            upcomingList
                        }
                    }
                    historyEntry
                    mascotBanner
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .background(CarePalette.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $cookingMeal) { meal in
                CookingView(meal: meal).environmentObject(store)
            }
            .sheet(item: $movingMeal) { meal in
                MealMoveView(meal: meal).environmentObject(store)
            }
            .sheet(item: $replacingMeal) { meal in
                MealReplaceView(meal: meal).environmentObject(store)
            }
        }
    }

    // MARK: - 헤더 (518:30)

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(periodText)
                    .figmaText(11, .medium)
                    .foregroundStyle(CarePalette.muted)
                Text("식단관리")
                    .figmaText(24, .bold)
                    .foregroundStyle(CarePalette.ink)
            }
            Spacer(minLength: 8)
            NavigationLink {
                PlanView().environmentObject(store)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.figma(17, .medium))
                    .foregroundStyle(CarePalette.ink)
                    .frame(width: 36, height: 36)
                    .background(CarePalette.brand, in: Circle())
                    .overlay { Circle().strokeBorder(CarePalette.ink, lineWidth: 1.5) }
            }
            .accessibilityLabel("식단 설정")
            .accessibilityIdentifier("meals.planSettings")
        }
        .frame(height: 48)
    }

    private var periodText: String {
        guard let first = planDates.first, let last = planDates.last else { return "계획한 식단이 없어요" }
        return first == last ? shortDate(first) : "\(shortDate(first)) - \(shortDate(last, includeMonth: false))"
    }

    // MARK: - 날짜 선택 (518:36)

    private var dayStrip: some View {
        CareCard(padding: EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(planDates, id: \.self) { date in
                        let isSelected = date == activeDate
                        Button {
                            selectedDate = date
                        } label: {
                            VStack(spacing: 1) {
                                Text(weekdayText(date))
                                    .figmaText(11, .medium)
                                    .foregroundStyle(CarePalette.muted)
                                Text(dayText(date))
                                    .figmaText(16, .bold)
                                    .foregroundStyle(CarePalette.dayInk)
                                Text("\(allMeals.filter { $0.date == date }.count)끼")
                                    .figmaText(11, .medium)
                                    .foregroundStyle(CarePalette.muted)
                            }
                            .padding(.horizontal, 3)
                            .padding(.vertical, 7)
                            .frame(width: 64, height: 64)
                            .background(isSelected ? CarePalette.daySelected : .clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(displayDate(date)) 식단 보기")
                        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
                    }
                }
            }
            .frame(height: 64)
        }
    }

    // MARK: - 요약 2카드 (518:57)

    private var summaryRow: some View {
        let total = allMeals.count
        let done = cooked.count
        let estimate = store.estimate(for: plannedDrafts, targetBudget: store.state.targetBudget)

        return HStack(spacing: 10) {
            CareCard(padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("이번 식단")
                        .figmaText(11, .medium)
                        .foregroundStyle(CarePalette.muted)
                    Text("\(done) / \(total)끼 완료")
                        .figmaText(16, .bold)
                        .foregroundStyle(CarePalette.ink)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(CarePalette.track)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(CarePalette.brand)
                                .frame(width: total > 0 ? proxy.size.width * CGFloat(done) / CGFloat(total) : 0)
                        }
                    }
                    .frame(height: 7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            CareCard(padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("남은 예산")
                        .figmaText(11, .medium)
                        .foregroundStyle(CarePalette.muted)
                    Text(remainingBudgetText(estimate))
                        .figmaText(16, .bold)
                        .foregroundStyle(CarePalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(budgetCaption(estimate))
                        .figmaText(11, .medium)
                        .foregroundStyle(CarePalette.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 78)
    }

    private var plannedDrafts: [PlannedMealDraft] {
        planned.map { PlannedMealDraft(recipeID: $0.recipeID, date: $0.date, mealSlot: $0.mealSlot, reason: "", reusedIngredientIDs: [], newPurchaseCount: 0) }
    }

    /// 목표 예산이 없거나 가격이 덜 확인됐으면 금액을 지어내지 않는다(AGENTS 8절).
    private func remainingBudgetText(_ estimate: BudgetEstimate) -> String {
        guard store.state.targetBudget > 0 else { return "예산 미설정" }
        guard let remaining = estimate.remainingBudget else { return "확인 전" }
        return won(remaining)
    }

    private func budgetCaption(_ estimate: BudgetEstimate) -> String {
        guard store.state.targetBudget > 0 else { return "식단 만들기에서 정해요" }
        guard estimate.remainingBudget != nil else { return "가격 확인 후 계산해요" }
        return "\(won(estimate.knownPurchaseCost)) 사용 예정"
    }

    // MARK: - 장보기 진입 (518:67)

    private var shoppingEntry: some View {
        let items = store.currentShoppingItems
        let checked = items.filter { store.state.purchaseChecks[$0.id] == true }.count

        return NavigationLink {
            ShoppingView().environmentObject(store)
        } label: {
            CareCard(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("장보기 리스트")
                            .figmaText(16, .bold)
                            .foregroundStyle(CarePalette.ink)
                        Text(items.isEmpty ? "이번 식단에 필요한 재료를 모아요" : "\(items.count)개 중 \(checked)개 준비 완료")
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

    // MARK: - 식사 카드 (518:84)

    private func mealCard(_ meal: PlannedMeal) -> some View {
        let item = recipe(for: meal.recipeID)

        return CareCard(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)) {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    cookingMeal = meal
                } label: {
                    HStack(spacing: 10) {
                        Text(item?.symbolName ?? "🍚")
                            .figmaText(24, .bold)
                            .frame(width: 52, height: 52)
                            .background(CarePalette.thumb, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(meal.mealSlot.rawValue) · \(meal.status == .cooked ? "완료" : "예정")")
                                .figmaText(11, .medium)
                                .foregroundStyle(CarePalette.muted)
                            Text(item?.title ?? "삭제된 메뉴")
                                .figmaText(16, .bold)
                                .foregroundStyle(CarePalette.ink)
                                .lineLimit(1)
                            Text(metaText(item))
                                .figmaText(11, .medium)
                                .foregroundStyle(CarePalette.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text("›")
                            .figmaText(16, .bold)
                            .foregroundStyle(CarePalette.ink)
                    }
                    .frame(height: 52)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item?.title ?? "메뉴") 요리하기")

                HStack(spacing: 8) {
                    Button {
                        movingMeal = meal
                    } label: {
                        Text("일정 변경")
                            .figmaText(11, .medium)
                            .foregroundStyle(CarePalette.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(CarePalette.line, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(meal.status == .cooked)

                    Button {
                        cookingMeal = meal
                    } label: {
                        Text("레시피 보기")
                            .figmaText(11, .medium)
                            .foregroundStyle(CarePalette.onDark)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(CarePalette.dark, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 34)
            }
        }
        // 시안에 없는 메뉴 교체·삭제(F22)는 길게 눌러 쓴다.
        .contextMenu {
            if meal.status == .planned {
                Button("메뉴 바꾸기") { replacingMeal = meal }
                Button("먹지 않았어요 — 삭제", role: .destructive) { store.removeMeal(meal.id) }
            } else {
                Button("기록 삭제", role: .destructive) { store.removeMeal(meal.id) }
            }
        }
        .accessibilityAction(named: "메뉴 바꾸기") { if meal.status == .planned { replacingMeal = meal } }
        .accessibilityAction(named: "식사 삭제") { store.removeMeal(meal.id) }
    }

    private func metaText(_ item: Recipe?) -> String {
        guard let item else { return "레시피 정보 없음" }
        if let label = recipeDifficultyLabel(item) { return "\(label) · \(item.cookTimeText)" }
        return item.cookTimeText
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

    // MARK: - 마스코트 배너 (518:119)

    private var mascotBanner: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(CarePalette.daySelected)
                .frame(height: 82)
                .oneLogCardShadow()

            Image("PlanCareMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 74, height: 74)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 14)
                .padding(.top, 4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(bannerTitle)
                    .figmaText(16, .bold)
                    .foregroundStyle(CarePalette.ink)
                Text(bannerBody)
                    .figmaText(11, .medium)
                    .foregroundStyle(CarePalette.bannerBody)
            }
            .padding(.leading, 18)
            .padding(.trailing, 100)
            .frame(height: 82, alignment: .center)
        }
        .frame(height: 82)
    }

    private var bannerTitle: String {
        if allMeals.isEmpty { return "첫 식단을 만들어 볼까요?" }
        return cooked.isEmpty ? "오늘 한 끼부터 시작해요!" : "계획대로 잘하고 있어요!"
    }

    private var bannerBody: String {
        if allMeals.isEmpty { return "“식단 만들기에서 한 번에 계획해요.”" }
        guard let next = mealsOnActiveDate.first(where: { $0.status == .planned }) ?? planned.first else {
            return "“이번 식단을 모두 마쳤어요.”"
        }
        return "“\(next.mealSlot.rawValue)도 계획대로 준비해봐요!”"
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

// MARK: - 지난 식단 기록 (시안 `식단 관리 7`은 아직 없어 최소 화면으로 둔다)

private struct MealHistoryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var cooked: [PlannedMeal] { store.plannedMeals.filter { $0.status == .cooked } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                CareHeader(title: "지난 식단 기록", trailing: "\(cooked.count)끼") { dismiss() }

                CareCard(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("이번 달 아낀 금액")
                            .figmaText(11, .medium)
                            .foregroundStyle(CarePalette.muted)
                        Text(won(store.monthlyConfirmedSavings))
                            .figmaText(16, .bold)
                            .foregroundStyle(CarePalette.ink)
                        Text("확인한 가격이 있는 품목만 셌어요.")
                            .figmaText(11, .medium)
                            .foregroundStyle(CarePalette.muted)
                    }
                }

                if cooked.isEmpty {
                    CareCard(padding: EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16)) {
                        Text("아직 완료한 식사가 없어요.")
                            .figmaText(13, .medium)
                            .foregroundStyle(CarePalette.muted)
                    }
                } else {
                    CareCard {
                        VStack(spacing: 0) {
                            ForEach(Array(cooked.enumerated()), id: \.element.id) { index, meal in
                                HStack(spacing: 8) {
                                    Text(shortWeekdayDay(meal.date))
                                        .figmaText(16, .bold)
                                        .foregroundStyle(CarePalette.ink)
                                    Text("\(meal.mealSlot.rawValue) · \(recipe(for: meal.recipeID)?.title ?? "삭제된 메뉴")")
                                        .figmaText(13, .medium)
                                        .foregroundStyle(CarePalette.muted)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("완료")
                                        .figmaText(11, .medium)
                                        .foregroundStyle(CarePalette.muted)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(height: 40)

                                if index < cooked.count - 1 {
                                    Rectangle().fill(CarePalette.divider).frame(height: 1)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(CarePalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
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
                    Text("‹")
                        .figmaText(25, .medium)
                        .foregroundStyle(CarePalette.ink)
                        .frame(width: 38, height: 38)
                        .background(CarePalette.back, in: Circle())
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
    @State private var actualQuantities: [String: String] = [:]
    @State private var remainingQuantities: [String: String] = [:]
    @State private var recordsRemaining: Set<String> = []

    private var recipeModel: Recipe? { recipe(for: meal.recipeID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let recipeModel {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(recipeModel.title).figmaText(20, .bold).foregroundStyle(CarePalette.ink)
                            Text("예상량을 그대로 쓰거나 실제 사용량으로 바꿔 주세요. 수량 미상 재료는 남은 양을 입력해야 정확한 재고가 됩니다.")
                                .figmaText(12, .medium, lineHeight: 18)
                                .foregroundStyle(CarePalette.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .oneLogCard(fill: CarePalette.thumb)

                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeading("사용량")
                            ForEach(recipeModel.ingredients) { item in
                                let key = ingredientKey(item.ingredientID, item.unit)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(item.rawName).figmaText(14, .bold).foregroundStyle(CarePalette.ink)
                                        Spacer()
                                        Text("예상 \(formatQuantity(item.quantity, unit: item.unit))").figmaText(11).foregroundStyle(CarePalette.muted)
                                    }
                                    HStack(spacing: 8) {
                                        TextField(formatQuantity(item.quantity), text: actualBinding(for: key, defaultValue: item.quantity))
                                            .keyboardType(.decimalPad)
                                            .textFieldStyle(.roundedBorder)
                                        Text(item.unit.rawValue).figmaText(11).foregroundStyle(CarePalette.muted)
                                        Text("실제 사용")
                                            .figmaText(11, .bold)
                                            .foregroundStyle(Color.oneLogSuccess)
                                    }
                                    Toggle("요리 후 남은 양을 직접 기록", isOn: remainingToggle(for: key))
                                        .figmaText(11)
                                        .tint(CarePalette.brand)
                                    if recordsRemaining.contains(key) {
                                        HStack(spacing: 8) {
                                            TextField("남은 수량", text: remainingBinding(for: key))
                                                .keyboardType(.decimalPad)
                                                .textFieldStyle(.roundedBorder)
                                            Text(item.unit.rawValue).figmaText(11).foregroundStyle(CarePalette.muted)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                if item.id != recipeModel.ingredients.last?.id { Divider().overlay(CarePalette.divider) }
                            }
                        }
                        .oneLogCard()

                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeading("조리 순서")
                            ForEach(Array(recipeModel.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1)")
                                        .figmaText(11, .bold)
                                        .foregroundStyle(CarePalette.ink)
                                        .frame(width: 24, height: 24)
                                        .background(CarePalette.thumb, in: Circle())
                                    Text(step).figmaText(14).foregroundStyle(CarePalette.ink)
                                }
                            }
                        }
                        .oneLogCard()

                        Button {
                            complete(recipe: recipeModel)
                        } label: {
                            Text("요리 완료하고 재고 반영")
                                .figmaText(16, .bold)
                                .foregroundStyle(CarePalette.onDark)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(CarePalette.dark, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        EmptyState(symbol: "exclamationmark.triangle", title: "레시피를 찾을 수 없어요", message: "이 식사를 삭제하고 다시 메뉴를 담아 주세요.")
                    }
                }
                .padding(16)
            }
            .background(CarePalette.canvas)
            .navigationTitle("요리하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
            .onAppear {
                guard let recipeModel else { return }
                for item in recipeModel.ingredients {
                    let key = ingredientKey(item.ingredientID, item.unit)
                    if actualQuantities[key] == nil { actualQuantities[key] = formatQuantity(item.quantity) }
                }
            }
        }
    }

    private func actualBinding(for key: String, defaultValue: Double) -> Binding<String> {
        Binding {
            actualQuantities[key] ?? formatQuantity(defaultValue)
        } set: { actualQuantities[key] = $0 }
    }

    private func remainingBinding(for key: String) -> Binding<String> {
        Binding {
            remainingQuantities[key] ?? ""
        } set: { remainingQuantities[key] = $0 }
    }

    private func remainingToggle(for key: String) -> Binding<Bool> {
        Binding {
            recordsRemaining.contains(key)
        } set: { enabled in
            if enabled { recordsRemaining.insert(key) }
            else { recordsRemaining.remove(key) }
        }
    }

    private func complete(recipe: Recipe) {
        let consumptions = recipe.ingredients.map { item in
            let key = ingredientKey(item.ingredientID, item.unit)
            let actual = Double(actualQuantities[key] ?? "") ?? item.quantity
            let remaining = recordsRemaining.contains(key) ? Double(remainingQuantities[key] ?? "") : nil
            return CookingConsumption(ingredientID: item.ingredientID, unit: item.unit, expectedQuantity: item.quantity, actualQuantity: max(actual, 0), remainingQuantity: remaining)
        }
        if store.completeMeal(meal.id, consumptions: consumptions) { dismiss() }
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
