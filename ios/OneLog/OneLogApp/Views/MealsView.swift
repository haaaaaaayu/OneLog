import SwiftUI

struct MealsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var cookingMeal: PlannedMeal?
    @State private var movingMeal: PlannedMeal?
    @State private var replacingMeal: PlannedMeal?

    private var planned: [PlannedMeal] { store.plannedMeals.filter { $0.status == .planned } }
    private var cooked: [PlannedMeal] { store.plannedMeals.filter { $0.status == .cooked } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "내 식사")
                        Text("계획한 한 끼를\n실제로 이어가요.")
                            .font(.system(size: 31, weight: .black, design: .rounded))
                            .foregroundStyle(Color.oneLogInk)
                        Text("먹지 않은 식사는 삭제하거나 다른 날짜·끼니로 옮길 수 있어요. 이동하면 재료와 보관 주의를 다시 확인해 주세요.")
                            .font(.subheadline)
                            .foregroundStyle(Color.oneLogMuted)
                            .lineSpacing(3)
                    }
                    .oneLogCard(fill: Color.oneLogPaleGreen)

                    if planned.isEmpty && cooked.isEmpty {
                        EmptyState(symbol: "calendar.badge.plus", title: "아직 계획한 식사가 없어요", message: "탐색에서 메뉴를 담거나 식단 만들기에서 여러 날짜를 한 번에 계획해 보세요.")
                            .oneLogCard()
                    }

                    if !planned.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeading("요리할 식사", subtitle: "완료하면 실제 사용량을 확인하고 냉장고에서 차감해요.")
                            ForEach(planned) { meal in
                                MealRow(meal: meal, onCook: { cookingMeal = meal }, onMove: { movingMeal = meal }, onReplace: { replacingMeal = meal }, onDelete: { store.removeMeal(meal.id) })
                            }
                        }
                    }

                    if !cooked.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeading("요리 완료", subtitle: "완료한 식사는 멱등 처리되어 재고가 다시 차감되지 않아요.")
                            ForEach(cooked) { meal in
                                MealRow(meal: meal, onCook: nil, onMove: nil, onReplace: nil, onDelete: { store.removeMeal(meal.id) })
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.oneLogCream)
            .navigationTitle("내 식사")
            // 피그마에 없는 화면(장보기·냉장고·추천 설정)은 식단관리 탭에서 이어간다.
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ShoppingView()
                            .environmentObject(store)
                    } label: {
                        Image(systemName: "cart")
                    }
                    .accessibilityLabel("장보기")
                    .accessibilityIdentifier("meals.shopping")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        FridgeView()
                            .environmentObject(store)
                    } label: {
                        Image(systemName: "refrigerator")
                    }
                    .accessibilityLabel("냉장고")
                    .accessibilityIdentifier("meals.fridge")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        PlanView()
                            .environmentObject(store)
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                    }
                    .accessibilityLabel("식단 만들기")
                }
            }
            .sheet(item: $cookingMeal) { meal in
                CookingView(meal: meal)
                    .environmentObject(store)
            }
            .sheet(item: $movingMeal) { meal in
                MealMoveView(meal: meal)
                    .environmentObject(store)
            }
            .sheet(item: $replacingMeal) { meal in
                MealReplaceView(meal: meal)
                    .environmentObject(store)
            }
        }
    }
}

private struct MealRow: View {
    let meal: PlannedMeal
    let onCook: (() -> Void)?
    let onMove: (() -> Void)?
    let onReplace: (() -> Void)?
    let onDelete: () -> Void

    private var recipeModel: Recipe? { recipe(for: meal.recipeID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 12) {
                Text(recipeModel?.symbolName ?? "🍚")
                    .font(.title2)
                    .frame(width: 48, height: 48)
                    .background(Color.oneLogPaleGreen, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipeModel?.title ?? "삭제된 메뉴")
                        .font(.headline.weight(.black))
                        .foregroundStyle(Color.oneLogInk)
                    Text("\(displayDate(meal.date)) · \(meal.mealSlot.rawValue) · \(recipeModel?.cookTimeText ?? "조리시간 미확인")")
                        .font(.caption)
                        .foregroundStyle(Color.oneLogMuted)
                }
                Spacer()
                StatusPill(text: meal.status == .cooked ? "완료" : "예정", tint: meal.status == .cooked ? .oneLogGreen : .oneLogOrange)
            }
            HStack(spacing: 8) {
                if let onCook {
                    Button("요리 시작", action: onCook)
                        .buttonStyle(PrimaryButtonStyle())
                }
                if let onMove {
                    Button("일정 옮기기", action: onMove)
                        .buttonStyle(SecondaryButtonStyle())
                }
                Menu {
                    if let onReplace {
                        Button("메뉴 바꾸기", action: onReplace)
                    }
                    if onMove != nil {
                        Button("먹지 않았어요 — 삭제", role: .destructive, action: onDelete)
                    } else {
                        Button("기록 삭제", role: .destructive, action: onDelete)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(Color.oneLogMuted)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("식사 관리")
            }
        }
        .oneLogCard()
    }
}

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
                                Text(candidate.title).font(.subheadline.weight(.bold)).foregroundStyle(Color.oneLogInk)
                                if !isRecommendable(candidate, preferences: store.state.preferences) {
                                    StatusPill(text: "추천 제외 조건", tint: .oneLogOrange)
                                }
                            }
                            Text("\(candidate.cookTimeText) · \(candidate.description)")
                                .font(.caption)
                                .foregroundStyle(Color.oneLogMuted)
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
                        .foregroundStyle(Color.oneLogMuted)
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
                    .foregroundStyle(Color.oneLogGreen)
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
                            Eyebrow(text: "요리 중 · 실제 사용량 확인")
                            Text(recipeModel.title).font(.title2.weight(.black)).foregroundStyle(Color.oneLogInk)
                            Text("예상량을 그대로 쓰거나 실제 사용량으로 바꿔 주세요. 수량 미상 재료는 남은 양을 입력해야 정확한 재고가 됩니다.")
                                .font(.subheadline).foregroundStyle(Color.oneLogMuted).lineSpacing(3)
                        }
                        .oneLogCard(fill: Color.oneLogPaleGreen)

                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeading("사용량")
                            ForEach(recipeModel.ingredients) { item in
                                let key = ingredientKey(item.ingredientID, item.unit)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(item.rawName).font(.subheadline.weight(.bold)).foregroundStyle(Color.oneLogInk)
                                        Spacer()
                                        Text("예상 \(formatQuantity(item.quantity, unit: item.unit))").font(.caption).foregroundStyle(Color.oneLogMuted)
                                    }
                                    HStack(spacing: 8) {
                                        TextField(formatQuantity(item.quantity), text: actualBinding(for: key, defaultValue: item.quantity))
                                            .keyboardType(.decimalPad)
                                            .textFieldStyle(.roundedBorder)
                                        Text(item.unit.rawValue).font(.caption).foregroundStyle(Color.oneLogMuted)
                                        Text("실제 사용")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.oneLogGreen)
                                    }
                                    Toggle("요리 후 남은 양을 직접 기록", isOn: remainingToggle(for: key))
                                        .font(.caption)
                                        .tint(.oneLogGreen)
                                    if recordsRemaining.contains(key) {
                                        HStack(spacing: 8) {
                                            TextField("남은 수량", text: remainingBinding(for: key))
                                                .keyboardType(.decimalPad)
                                                .textFieldStyle(.roundedBorder)
                                            Text(item.unit.rawValue).font(.caption).foregroundStyle(Color.oneLogMuted)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                if item.id != recipeModel.ingredients.last?.id { Divider().overlay(Color.oneLogLine) }
                            }
                        }
                        .oneLogCard()

                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeading("조리 순서")
                            ForEach(Array(recipeModel.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1)").font(.caption.weight(.black)).foregroundStyle(Color.oneLogGreen).frame(width: 24, height: 24).background(Color.oneLogPaleGreen, in: Circle())
                                    Text(step).font(.subheadline).foregroundStyle(Color.oneLogInk)
                                }
                            }
                        }
                        .oneLogCard()

                        Button {
                            complete(recipe: recipeModel)
                        } label: {
                            Label("요리 완료하고 재고 반영", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else {
                        EmptyState(symbol: "exclamationmark.triangle", title: "레시피를 찾을 수 없어요", message: "이 식사를 삭제하고 다시 메뉴를 담아 주세요.")
                    }
                }
                .padding(16)
            }
            .background(Color.oneLogCream)
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
