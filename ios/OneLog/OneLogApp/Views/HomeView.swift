import SwiftUI

/// 피그마 `최종본` 캔버스의 `메인 - 1`(713:884) / `메인 - 2`(713:1044)를 그대로 옮긴 홈 탭.
/// 좌표와 색은 디자인 값을 우선한다. 숫자는 저장된 상태에서만 계산하고 임의로 만들지 않는다(AGENTS 8절).
struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selectedTab: Int
    @State private var showingPlan = false
    @State private var showingMyPage = false
    @State private var selectedDate: String?

    private var nickname: String {
        let value = store.state.profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "회원" : value
    }

    /// 계획된 식사가 있는 날짜를 오름차순으로. 시안 `5일 날짜 선택`(713:924)의 데이터 소스.
    private var planDates: [String] {
        Array(Set(store.plannedMeals.map(\.date))).sorted()
    }

    private var currentDate: String {
        selectedDate ?? (planDates.contains(isoDateString()) ? isoDateString() : planDates.first) ?? isoDateString()
    }

    private var mealsForCurrentDate: [PlannedMeal] {
        store.plannedMeals.filter { $0.date == currentDate }
    }

    private var hasPlannedMealToday: Bool {
        store.plannedMeals.contains { $0.date == isoDateString() && $0.status == .planned }
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: proxy.safeAreaInsets.top)
                    brandHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 17)
                    heroCard
                        .padding(.horizontal, 20)
                        .padding(.top, 5)
                    statsCard
                        .padding(.horizontal, 20)
                        .padding(.top, 21)
                    todayHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 21)
                    if !planDates.isEmpty {
                        dateStrip
                            .padding(.horizontal, 20)
                            .padding(.top, 21)
                    }
                    mealCardsRow
                        .padding(.top, 21)
                    Color.clear.frame(height: 24)
                }
            }
            .background(Color.oneLogCream)
            .ignoresSafeArea(edges: .top)
        }
        // 시안 `식단 만들기`는 자체 헤더와 ‹를 가진 전체 화면이다. 시트로 띄우면 위가 잘린다.
        .fullScreenCover(isPresented: $showingPlan) {
            PlanView().environmentObject(store)
        }
        .fullScreenCover(isPresented: $showingMyPage) {
            MyPageView().environmentObject(store)
        }
    }

    // MARK: - 브랜드 헤더 (713:894)

    /// 769:23. 워드마크(-2.03, 6.54, 93.318×32.834)와 태그라인(1.61, 35.99)은 시안에서 서로 겹쳐 있어
    /// 스택 간격으로는 재현되지 않는다. 프로필 아이콘은 x318(오른쪽 여백 5).
    private var brandHeader: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            Image("BrandWordmark")
                .resizable()
                .scaledToFit()
                .frame(width: 93.318, height: 32.834)
                .offset(x: -2.026, y: 6.538)

            Text("내 취향 한끼부터, 남은 재료까지")
                .figmaText(7)
                .foregroundStyle(Color.oneLogMuted)
                .fixedSize()
                .offset(x: 1.609, y: 35.987)

            Button {
                showingMyPage = true
            } label: {
                Image("IconProfile")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundStyle(Color.oneLogInk)
            }
            .accessibilityLabel("마이페이지")
            .frame(maxWidth: .infinity, alignment: .trailing)
            .offset(x: -5, y: 11)
        }
        .frame(height: 52) // 713:894
    }

    // MARK: - 히어로 카드 (713:904)

    /// 713:904. 353×194, radius 24. 자식 좌표는 시안 절대값 그대로다.
    /// eyebrow(20,18) · 타이틀(16.45,45,w222,lh30) · 설명(20,93,w220) · CTA(16,128,321×48,r15) · 마스코트(214.65,19.89).
    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            Color.oneLogBrandDeep

            Image("HomeMascot")
                .resizable()
                .scaledToFill()
                .frame(width: 138.355, height: 108.110, alignment: .top)
                .clipped()
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(y: 19.890)

            Text("HANKKI LOG")
                .figmaText(10, .bold)
                .foregroundStyle(Color(hex: 0x403B2E))
                .fixedSize()
                .offset(x: 20, y: 18)

            (Text(nickname + "님").font(.figma(24, .bold))
                + Text(", ").font(.figma(20, .bold))
                + Text("안녕하세요.").font(.figma(20, .medium)))
                .foregroundStyle(Color.oneLogInk)
                .figmaLineHeight(30, size: 24, weight: .bold)
                .frame(width: 222, alignment: .leading)
                .offset(x: 16.447, y: 45)

            Text(heroSubtitle)
                .figmaText(10)
                .foregroundStyle(Color(hex: 0x403B2E))
                .frame(width: 220, alignment: .leading)
                .offset(x: 20, y: 93)

            Button {
                if hasPlannedMealToday { selectedTab = 2 } else { showingPlan = true }
            } label: {
                Text(hasPlannedMealToday ? "요리 만들러 가기" : "새 식단 만들기")
                    .figmaText(15, .bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.oneLogInk, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .accessibilityIdentifier("home.createPlan")
            .padding(.horizontal, 16)
            .offset(y: 128)
        }
        .frame(height: 194)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var heroSubtitle: String {
        let today = isoDateString()
        let todaysMeals = store.plannedMeals.filter { $0.date == today }
        guard let next = todaysMeals.first(where: { $0.status == .planned }) else {
            if todaysMeals.contains(where: { $0.status == .cooked }) { return "오늘 식사를 완료했어요. 다음 한 끼를 계획해볼까요?" }
            if todaysMeals.contains(where: { $0.status == .skipped }) { return "오늘은 건너뛴 끼니만 있어요. 새 식단을 계획할 수 있어요." }
            return "오늘은 어떤 한 끼를 계획해볼까요?"
        }
        let title = recipe(for: next.recipeID)?.title ?? "오늘의 메뉴"
        guard let day = planDayNumber() else {
            return "오늘은 \(title)를 만드는 날이에요!"
        }
        return "오늘은 식단 \(day)일차, \(title)를 만드는 날이에요!"
    }

    /// 계획한 식사 중 가장 이른 날짜를 1일차로 센다.
    /// ponytail: 60일까지만 센다. 더 긴 식단이 생기면 날짜 차이 계산으로 바꾼다.
    private func planDayNumber() -> Int? {
        guard var cursor = store.plannedMeals.map(\.date).min() else { return nil }
        let today = isoDateString()
        for day in 1...60 {
            if cursor == today { return day }
            cursor = dateByAddingDays(cursor, 1)
        }
        return nil
    }

    // MARK: - 절약 요약 (713:911)

    /// 713:911. 353×85, radius 20. 내부 프레임(713:912)이 (14, 9)에서 시작하므로 자식 좌표에 그만큼 더한다.
    /// 노랑 밑줄(713:914)은 시안에서 금액보다 좌우 7씩 넓고 금액 박스 상단에서 27 아래에 놓인다.
    private var statsCard: some View {
        ZStack(alignment: .topLeading) {
            Color.white

            Text("이번 달 한끼로그로")
                .figmaText(13, .medium, lineHeight: 16)
                .foregroundStyle(Color.oneLogMuted)
                .fixedSize()
                .offset(x: 18, y: 13)

            // 금액(713:915/1075)은 자리수와 무관하게 밑줄(135×7) 한가운데에 놓인다.
            Text(won(store.monthlyConfirmedSavings))
                .figmaText(29, .bold)
                .foregroundStyle(Color.oneLogInk)
                .frame(width: 135)
                .background(alignment: .bottom) {
                    Capsule()
                        .fill(Color.oneLogBrand)
                        .frame(width: 135, height: 7)
                        .offset(y: -1)
                }
                .offset(x: 14, y: 29)

            Text("절약했어요")
                .figmaText(16, .bold)
                .foregroundStyle(Color.oneLogInk)
                .fixedSize()
                .offset(x: 157, y: 42)

            Rectangle()
                .fill(Color(hex: 0xE5DECC))
                .frame(width: 1, height: 34)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(x: -101, y: 26)

            VStack(spacing: 5) {
                Text("\(store.cookedMealsThisMonth)끼")
                    .figmaText(17, .bold)
                    .foregroundStyle(Color.oneLogInk)
                Text("요리 완료")
                    .figmaText(11, .medium)
                    .foregroundStyle(Color.oneLogFaint)
            }
            .frame(width: 83.75)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .offset(x: -14.25, y: 22)
        }
        .frame(height: 85)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .oneLogCardShadow()
    }

    // MARK: - 오늘 식단 (713:921)

    private var todayHeader: some View {
        HStack(spacing: 0) {
            (Text(nickname + "님").font(.figma(16, .bold))
                + Text("의 오늘 식단").font(.figma(16, .medium)))
                .foregroundStyle(Color.oneLogInk)
            Spacer(minLength: 8)
            Button {
                selectedTab = 2
            } label: {
                Text("전체 보기 ›")
                    .figmaText(13, .medium)
                    .foregroundStyle(Color.oneLogFaint)
            }
        }
        .frame(height: 23, alignment: .bottom)
    }

    // MARK: - 날짜 선택 (713:924)

    private var dateStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(planDates, id: \.self) { date in
                    DateCell(date: date, count: store.plannedMeals.filter { $0.date == date }.count, isSelected: date == currentDate) {
                        selectedDate = date
                    }
                }
            }
            // 시안 713:924는 좌우 4만 두고 높이는 칸(64)에 딱 맞춘다. 위아래로도 4를 주면 8pt 높아진다.
            .padding(.horizontal, 4)
        }
        .frame(height: 64)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .oneLogCardShadow()
    }

    // MARK: - 오늘 식단 카드 (713:945)

    private var mealCardsRow: some View {
        Group {
            if mealsForCurrentDate.isEmpty {
                // 713:1105. 화면 가운데, 카드 자리보다 53 아래.
                Text("아직 식단을 계획하지 않았어요!")
                    .figmaText(15, .medium)
                    .foregroundStyle(Color.oneLogFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 53)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(mealsForCurrentDate) { meal in
                            MealCard(meal: meal)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

/// 시안 `5일 날짜 선택`(713:924)의 요일 칸.
private struct DateCell: View {
    let date: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    private var weekday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "E"
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let value = input.date(from: date) else { return "" }
        return formatter.string(from: value)
    }

    private var day: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d"
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let value = input.date(from: date) else { return "" }
        return formatter.string(from: value)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(weekday)
                    .figmaText(11, .medium)
                    .foregroundStyle(Color.oneLogFaint)
                Text(day)
                    .figmaText(16, .bold)
                    .foregroundStyle(Color(hex: 0x14120D))
                Text("\(count)끼")
                    .figmaText(11, .medium)
                    .foregroundStyle(Color.oneLogFaint)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 3)
            .frame(width: 64, height: 64)
            .background(isSelected ? Color.oneLogBrandDeep : .clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// 피그마 `Meal/아침·점심·저녁`(713:946) 카드.
private struct MealCard: View {
    let meal: PlannedMeal

    private var recipeValue: Recipe? { recipe(for: meal.recipeID) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.oneLogPhoto)
                .overlay {
                    if let urlString = recipeValue?.imageURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.clear
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        // 레시피 대표 이미지가 없으면 시드 데이터의 이모지를 쓴다.
                        Text(recipeValue?.symbolName ?? "🍚")
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
                Text(recipeValue?.title ?? "메뉴")
                    .figmaText(13, .bold, lineHeight: 18) // 713:954
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(width: 130, alignment: .leading)
                Text("재료 \(recipeValue?.ingredients.count ?? 0)개 · \(recipeValue?.cookTimeText ?? "조리시간 미확인")")
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
