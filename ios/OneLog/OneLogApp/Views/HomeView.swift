import SwiftUI

/// 피그마 `유진) 수정완료 / Home 화면_식단O`(383:236)과 `Home 화면_식단X`(383:86)를 그대로 옮긴 홈 탭.
/// 좌표와 색은 디자인 값을 우선한다. 숫자는 저장된 상태에서만 계산하고 임의로 만들지 않는다(AGENTS 8절).
struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selectedTab: Int
    @State private var showingPlan = false
    @State private var showingMyPage = false
    @State private var showingFridge = false

    private var nickname: String {
        let value = store.state.profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "회원" : value
    }

    private var todaysMeals: [PlannedMeal] {
        let today = isoDateString()
        return store.plannedMeals.filter { $0.date == today }
    }

    var body: some View {
        // 히어로는 상태바 뒤까지 노란색을 깔되, 내용은 실제 safe area 아래로 내린다.
        // 시안은 상태바를 34pt로 그렸는데 iPhone 16/17은 59pt라, 그대로 두면 워드마크가 상태바에 물린다.
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    hero(topInset: proxy.safeAreaInsets.top)
                    statsCard
                        .padding(.horizontal, 20)
                        .padding(.top, -6)
                    todayHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    mealBand
                        .padding(.top, 5)
                    leftoverCard
                        .padding(.horizontal, 20)
                        .padding(.top, 7)
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
        .sheet(isPresented: $showingFridge) {
            FridgeView().environmentObject(store)
        }
    }

    // MARK: - 히어로 (383:239)

    /// 시안 383:239. 좌표는 상태바(34pt) 아래 기준으로 다시 잡고, `topInset`으로 실기기 safe area에 맞춘다.
    private func hero(topInset: CGFloat) -> some View {
        let y: (CGFloat) -> CGFloat = { topInset + $0 - 34 }
        return ZStack(alignment: .topLeading) {
            Color.oneLogBrand

            // 시안은 폭 215에 맞춰 늘린 뒤 위에서 168만 보여준다(h 135.12%).
            Image("HomeMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 215)
                .frame(width: 215, height: 168, alignment: .top)
                .clipped()
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(x: 23, y: y(100))

            Image("BrandWordmark")
                .resizable()
                .scaledToFit()
                .frame(width: 93, height: 33)
                .offset(x: 16, y: y(47))

            Text("내 취향 한끼부터, 남은 재료까지")
                .figmaText(7)
                .foregroundStyle(Color.oneLogMuted)
                .offset(x: 20, y: y(76))

            Button {
                showingMyPage = true
            } label: {
                Image("IconProfile")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                    .foregroundStyle(Color.oneLogInk)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 19)
            .offset(y: y(47))
            .accessibilityLabel("마이페이지")

            (Text(nickname + "님").font(.figma(24, .bold))
                + Text(", ").font(.figma(20, .bold))
                + Text("안녕하세요.").font(.figma(20, .medium)))
                .foregroundStyle(Color.oneLogInk)
                .figmaLineHeight(30, size: 24, weight: .bold) // 383:248
                .frame(width: 222, alignment: .leading)
                .offset(x: 20, y: y(122))

            Text(heroSubtitle)
                .figmaText(10)
                .foregroundStyle(Color(hex: 0x403B2E))
                .frame(width: 220, alignment: .leading)
                .offset(x: 20, y: y(162))

            Button {
                if todaysMeals.isEmpty { showingPlan = true } else { selectedTab = 2 }
            } label: {
                Text(todaysMeals.isEmpty ? "새 식단 만들기" : "요리하러 가기")
                    .figmaText(15, .bold)
                    .foregroundStyle(.white)
                    .frame(width: 199, height: 48)
                    .background(Color.oneLogInk, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .accessibilityIdentifier("home.createPlan")
            .offset(x: 16, y: y(195))
        }
        .frame(height: topInset + 238) // 시안 272 = 상태바 34 + 내용 238
        .clipped()
    }

    private var heroSubtitle: String {
        guard let next = todaysMeals.first(where: { $0.status == .planned }) ?? todaysMeals.first else {
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

    // MARK: - 절약 요약 (383:328)

    private var statsCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("이번 달 한끼로그로")
                    .figmaText(13, .medium, lineHeight: 16)
                    .foregroundStyle(Color.oneLogMuted)
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(won(store.monthlyConfirmedSavings))
                        .figmaText(29, .bold)
                        .foregroundStyle(Color.oneLogInk)
                        .background(alignment: .bottom) {
                            Capsule()
                                .fill(Color.oneLogBrand)
                                .frame(height: 7)
                                .padding(.horizontal, -4)
                                .offset(y: -2)
                        }
                    Text("절약했어요")
                        .figmaText(16, .bold)
                        .foregroundStyle(Color.oneLogInk)
                }
            }
            Spacer(minLength: 8)
            Rectangle()
                .fill(Color(hex: 0xE5DECC))
                .frame(width: 1, height: 34)
            VStack(spacing: 5) {
                Text("\(store.cookedMealsThisMonth)끼")
                    .figmaText(17, .bold)
                    .foregroundStyle(Color.oneLogInk)
                Text("요리 완료")
                    .figmaText(11, .medium)
                    .foregroundStyle(Color.oneLogFaint)
            }
            .frame(width: 84)
        }
        .padding(.horizontal, 14)
        .frame(height: 85)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .oneLogCardShadow()
    }

    // MARK: - 오늘 식단 (383:338 / 383:341)

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

    private var mealBand: some View {
        ZStack {
            Color.oneLogBand
            if todaysMeals.isEmpty {
                Text("아직 식단을 계획하지 않았어요!")
                    .figmaText(15, .medium) // 384:14
                    .foregroundStyle(Color(hex: 0xB3B3B3))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(todaysMeals) { meal in
                            MealCard(meal: meal)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .frame(height: 186)
    }

    // MARK: - 남은 재료 (383:366)

    private var leftoverCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Text("남은 재료")
                    .figmaText(15, .bold)
                    .foregroundStyle(Color.oneLogInk)
                Spacer(minLength: 8)
                Button {
                    showingFridge = true
                } label: {
                    Text("전체 보기 ›")
                        .figmaText(12, .medium)
                        .foregroundStyle(Color.oneLogFaint)
                }
            }

            if store.state.inventory.isEmpty {
                Text("아직 기록한 재료가 없어요. 냉장고에서 남은 재료를 적어 주세요.")
                    .figmaText(13, .medium)
                    .foregroundStyle(Color.oneLogFaint)
                    .padding(.vertical, 5)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.state.inventory.prefix(3).enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Rectangle().fill(Color.oneLogDivider).frame(height: 1)
                        }
                        HStack(spacing: 10) {
                            Text(ingredient(for: item.ingredientID)?.name ?? "재료")
                                .figmaText(14, .medium)
                                .foregroundStyle(Color.oneLogBody)
                            Spacer(minLength: 10)
                            Text(item.quantityStatus == .unknown ? "수량 미상" : formatQuantity(item.quantity, unit: item.unit))
                                .figmaText(13, .medium)
                                .foregroundStyle(Color.oneLogFaint)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }

            Button {
                selectedTab = 1
            } label: {
                HStack(spacing: 6) {
                    Text("레시피 보러가기")
                    Text("→")
                }
                .font(.figma(14, .bold))
                .foregroundStyle(Color.oneLogInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.oneLogPaleGreen, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .oneLogCardShadow()
    }
}

/// 피그마 `Meal/아침·점심·저녁`(383:342) 카드.
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
                } else {
                    pill("예정", foreground: .oneLogFaint, background: .oneLogChip, border: nil)
                }
            }
            .padding(8)

            VStack(alignment: .leading, spacing: 5) {
                Text(recipeValue?.title ?? "메뉴")
                    .figmaText(13, .bold, lineHeight: 18) // 383:348
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
