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
        ScrollView {
            VStack(spacing: 0) {
                hero
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
        .sheet(isPresented: $showingPlan) {
            NavigationStack { PlanView().environmentObject(store) }
        }
        .fullScreenCover(isPresented: $showingMyPage) {
            MyPageView().environmentObject(store)
        }
        .sheet(isPresented: $showingFridge) {
            FridgeView().environmentObject(store)
        }
    }

    // MARK: - 히어로 (383:239)

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            Color.oneLogBrand

            Image("HomeMascot")
                .resizable()
                .scaledToFill()
                .frame(width: 215, height: 168)
                .clipped()
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(x: 23, y: 100)

            Image("BrandWordmark")
                .resizable()
                .scaledToFit()
                .frame(width: 93, height: 33)
                .offset(x: 16, y: 47)

            Text("내 취향 한끼부터, 남은 재료까지")
                .font(.system(size: 7))
                .foregroundStyle(Color.oneLogMuted)
                .offset(x: 20, y: 76)

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
            .offset(y: 47)
            .accessibilityLabel("마이페이지")

            (Text(nickname + "님").font(.system(size: 24, weight: .bold))
                + Text(", ").font(.system(size: 20, weight: .bold))
                + Text("안녕하세요.").font(.system(size: 20, weight: .medium)))
                .foregroundStyle(Color.oneLogInk)
                .lineSpacing(4)
                .frame(width: 222, alignment: .leading)
                .offset(x: 20, y: 122)

            Text(heroSubtitle)
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: 0x403B2E))
                .frame(width: 220, alignment: .leading)
                .offset(x: 20, y: 162)

            Button {
                if todaysMeals.isEmpty { showingPlan = true } else { selectedTab = 2 }
            } label: {
                Text(todaysMeals.isEmpty ? "새 식단 만들기" : "요리하러 가기")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 199, height: 48)
                    .background(Color.oneLogInk, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .offset(x: 16, y: 195)
        }
        .frame(height: 272)
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
            VStack(alignment: .leading, spacing: 2) {
                Text("이번 달 한끼로그로")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.oneLogMuted)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(won(store.monthlyConfirmedSavings))
                        .font(.system(size: 29, weight: .bold))
                        .foregroundStyle(Color.oneLogInk)
                        .background(alignment: .bottom) {
                            Capsule()
                                .fill(Color.oneLogBrand)
                                .frame(height: 7)
                                .padding(.horizontal, -4)
                                .offset(y: -2)
                        }
                    Text("절약했어요")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.oneLogInk)
                }
            }
            Spacer(minLength: 8)
            Rectangle()
                .fill(Color(hex: 0xE5DECC))
                .frame(width: 1, height: 34)
            VStack(spacing: 5) {
                Text("\(store.cookedMealsThisMonth)끼")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.oneLogInk)
                Text("요리 완료")
                    .font(.system(size: 11, weight: .medium))
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
            (Text(nickname + "님").font(.system(size: 16, weight: .bold))
                + Text("의 오늘 식단").font(.system(size: 16, weight: .medium)))
                .foregroundStyle(Color.oneLogInk)
            Spacer(minLength: 8)
            Button {
                selectedTab = 2
            } label: {
                Text("전체 보기 ›")
                    .font(.system(size: 13, weight: .medium))
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
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.oneLogFaint)
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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.oneLogInk)
                Spacer(minLength: 8)
                Button {
                    showingFridge = true
                } label: {
                    Text("전체 보기 ›")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.oneLogFaint)
                }
            }

            if store.state.inventory.isEmpty {
                Text("아직 기록한 재료가 없어요. 냉장고에서 남은 재료를 적어 주세요.")
                    .font(.system(size: 13, weight: .medium))
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
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.oneLogBody)
                            Spacer(minLength: 10)
                            Text(item.quantityStatus == .unknown ? "수량 미상" : formatQuantity(item.quantity, unit: item.unit))
                                .font(.system(size: 13, weight: .medium))
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
                .font(.system(size: 14, weight: .bold))
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
                            .font(.system(size: 40))
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
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text("재료 \(recipeValue?.ingredients.count ?? 0)개 · \(recipeValue?.cookTimeText ?? "조리시간 미확인")")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 13)
            .frame(width: 150, height: 153, alignment: .bottomLeading)
        }
        .frame(width: 150, height: 153)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .oneLogCardShadow()
    }

    private func pill(_ text: String, foreground: Color, background: Color, border: Color?) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
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
