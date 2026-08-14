import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var store: AppStore
    @State private var stage: PlanStage = .setup
    @State private var startDate = Date()
    @State private var days = 3
    @State private var targetBudget = "30000"
    @State private var selectedSlots: Set<PlanSlotKey> = []
    @State private var options: [MealPlanOption] = []
    @State private var selectedOption: MealPlanOption?
    @State private var optionBeingEditedID: String?
    @State private var swappingDraft: PlannedMealDraft?
    @State private var validationMessage: String?
    @State private var showingPreferences = false

    private var dates: [String] {
        (0..<days).map { dateByAddingDays(isoDateString(startDate), $0) }
    }

    private var budgetValue: Int {
        Int(targetBudget.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .setup:
                    setupView
                case .options:
                    optionsView
                case .budgetReview:
                    budgetReviewView
                }
            }
            .background(Color.oneLogCream)
            .navigationTitle(stage == .setup ? "식단 만들기" : stage == .options ? "식단안 비교" : "예산 확인")
            .toolbar {
                if stage != .setup {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            stage = stage == .budgetReview ? .options : .setup
                        } label: {
                            Label("이전", systemImage: "chevron.left")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingPreferences = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("추천 설정")
                }
            }
            .sheet(isPresented: $showingPreferences) {
                NavigationStack { PreferencesView() }
            }
            .sheet(item: $swappingDraft) { draft in
                RecipeSwapView(draft: draft, preferences: store.state.preferences) { recipe in
                    replaceDraft(draft.id, with: recipe.id)
                    swappingDraft = nil
                }
            }
            .onAppear { rebuildSelectedSlotsIfNeeded() }
            .onChange(of: days) { _, _ in rebuildSelectedSlotsIfNeeded() }
            .onChange(of: startDate) { _, _ in rebuildSelectedSlotsIfNeeded() }
        }
    }

    private var setupView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "01 · 계획 입력")
                    Text("먹을 날짜와 끼니를\n직접 고르세요.")
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .foregroundStyle(Color.oneLogInk)
                    Text("찜한 메뉴와 보유 재료를 먼저 고려하고, 확인 가능한 가격 안에서 여러 식단안을 만들어요.")
                        .font(.subheadline)
                        .foregroundStyle(Color.oneLogMuted)
                        .lineSpacing(3)
                }
                .oneLogCard(fill: Color.oneLogPaleGreen)

                VStack(alignment: .leading, spacing: 13) {
                    SectionHeading("기간과 예산", subtitle: "예산은 필수 입력이지만, 가격 근거가 없으면 확정 금액으로 표시하지 않아요.")
                    HStack {
                        DatePicker("시작일", selection: $startDate, displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "ko_KR"))
                        Spacer()
                        Stepper(value: $days, in: 1...7) {
                            Text("\(days)일")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.oneLogGreen)
                        }
                        .fixedSize()
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "wonsign.circle")
                            .foregroundStyle(Color.oneLogGreen)
                        TextField("목표 예산", text: $targetBudget)
                            .keyboardType(.numberPad)
                        Text("원")
                            .foregroundStyle(Color.oneLogMuted)
                    }
                    .padding(12)
                    .background(Color.oneLogCream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .oneLogCard()

                VStack(alignment: .leading, spacing: 13) {
                    SectionHeading("날짜별로 먹을 끼니", subtitle: "먹지 않을 끼니는 선택하지 않아도 돼요.")
                    ForEach(dates, id: \.self) { date in
                        VStack(alignment: .leading, spacing: 9) {
                            Text(displayDate(date))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.oneLogInk)
                            HStack(spacing: 8) {
                                ForEach(MealSlot.allCases) { slot in
                                    Toggle(isOn: binding(for: PlanSlotKey(date: date, slot: slot))) {
                                        Label(slot.rawValue, systemImage: slot.symbolName)
                                            .font(.caption.weight(.bold))
                                    }
                                    .toggleStyle(.button)
                                    .tint(.oneLogGreen)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        if date != dates.last { Divider().overlay(Color.oneLogLine) }
                    }
                }
                .oneLogCard()

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(Color.oneLogGreen)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("추천 조건: 불호 재료 \(store.state.preferences.dislikedIngredientIDs.count)개 · 불호 메뉴 \(store.state.preferences.dislikedRecipeIDs.count)개")
                            .font(.subheadline.weight(.bold))
                        Text("조리도구와 불호 재료·메뉴는 자동 추천에서 제외돼요. 직접 메뉴를 고른 경우에는 삭제하지 않고 경고합니다.")
                            .font(.caption)
                            .foregroundStyle(Color.oneLogMuted)
                    }
                    Spacer()
                    Button("수정") { showingPreferences = true }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.oneLogGreen)
                }
                .oneLogCard()

                if let validationMessage {
                    Text(validationMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.oneLogOrange)
                        .padding(.horizontal, 4)
                }

                Button {
                    generateOptions()
                } label: {
                    Label("여러 식단안 제안받기", systemImage: "sparkles")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(16)
        }
    }

    private var optionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: "02 · 선택지 비교")
                    Text("내 식단안을 비교해 보세요.")
                        .font(.title2.weight(.black))
                        .foregroundStyle(Color.oneLogInk)
                    Text("추천은 선택지일 뿐이에요. 메뉴를 바꾸거나 모두 버리고 직접 담을 수도 있어요.")
                        .font(.subheadline)
                        .foregroundStyle(Color.oneLogMuted)
                }
                ForEach(options) { option in
                    PlanOptionCard(option: option, isPreferred: option.id == options.first?.id) {
                        selectedOption = option
                        stage = .budgetReview
                    } onSwap: { draft in
                        optionBeingEditedID = option.id
                        swappingDraft = draft
                    }
                }
                Button {
                    options = []
                    selectedOption = nil
                    stage = .setup
                } label: {
                    Text("추천을 버리고 직접 구성하기")
                }
                .buttonStyle(SecondaryButtonStyle())
                .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
    }

    private var budgetReviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let option = selectedOption {
                    let estimate = store.estimate(for: option.drafts, targetBudget: budgetValue)
                    let request = makeRequest()
                    VStack(alignment: .leading, spacing: 7) {
                        Eyebrow(text: "03 · 재료와 예산")
                        Text(option.title)
                            .font(.title2.weight(.black))
                            .foregroundStyle(Color.oneLogInk)
                        Text("\(option.drafts.count)끼니 · \(option.sharedIngredientNames.isEmpty ? "공유 재료 없음" : "재사용: \(option.sharedIngredientNames.joined(separator: ", "))")")
                            .font(.subheadline)
                            .foregroundStyle(Color.oneLogMuted)
                    }

                    budgetSummary(estimate)

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeading("이번 식단에 필요한 재료", subtitle: "보유량을 제외한 추가 필요량과 판매 단위 기준 구매량이에요.")
                        ForEach(option.drafts) { draft in
                            if let recipe = recipe(for: draft.recipeID) {
                                HStack(spacing: 8) {
                                    Image(systemName: draft.mealSlot.symbolName)
                                        .foregroundStyle(Color.oneLogGreen)
                                    Text("\(displayDate(draft.date)) · \(draft.mealSlot.rawValue)")
                                        .font(.caption.weight(.bold))
                                    Spacer()
                                    Text(recipe.title)
                                        .font(.caption)
                                        .foregroundStyle(Color.oneLogMuted)
                                }
                            }
                        }
                        Divider().overlay(Color.oneLogLine)
                        ForEach(estimate.lineItems) { line in
                            BudgetLineRow(line: line)
                            PriceEditorRow(item: line.shoppingItem, existingPrice: line.price)
                        }
                    }
                    .oneLogCard()

                    let upgrades = upgradeSuggestions(for: option, request: request)
                    if !upgrades.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeading("남은 예산으로 업그레이드", subtitle: "수락하면 식단·재료·구매량·예산을 모두 다시 계산해요.")
                            ForEach(upgrades) { suggestion in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(Color.oneLogOrange)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("\(recipe(for: suggestion.replacementRecipeID)?.title ?? "메뉴") · 추가 \(won(suggestion.additionalCost))")
                                            .font(.subheadline.weight(.bold))
                                        Text(suggestion.reason)
                                            .font(.caption)
                                            .foregroundStyle(Color.oneLogMuted)
                                    }
                                    Spacer()
                                    Button("적용") { applyUpgrade(suggestion) }
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.oneLogGreen)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .oneLogCard(fill: Color(red: 1, green: 0.96, blue: 0.90))
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.oneLogGreen)
                        Text(estimate.isComplete ? "모든 추가 구매 품목의 가격 근거가 있어요." : "가격이 없는 품목은 예상 비용과 잔여 예산에서 제외했어요. 가격을 확인해 입력하면 더 정확해져요.")
                            .font(.caption)
                            .foregroundStyle(Color.oneLogMuted)
                    }
                    .padding(.horizontal, 4)

                    Button {
                        guard let option = selectedOption else { return }
                        store.applyPlan(option)
                        selectedOption = nil
                        options = []
                        stage = .setup
                    } label: {
                        Label("이 식단을 확정하고 내 식사에 담기", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    EmptyState(symbol: "calendar.badge.exclamationmark", title: "식단안을 먼저 골라 주세요", message: "이전 단계에서 제안받은 식단안을 선택해 주세요.")
                }
            }
            .padding(16)
        }
    }

    private func budgetSummary(_ estimate: BudgetEstimate) -> some View {
        HStack(spacing: 8) {
            BudgetMetric(title: "목표 예산", value: won(estimate.targetBudget), tint: .oneLogGreen)
            BudgetMetric(title: "확인된 예상 지출", value: won(estimate.knownPurchaseCost), tint: .oneLogOrange)
            BudgetMetric(title: "보유 재료 절감", value: won(estimate.confirmedInventorySavings), tint: .oneLogGreen)
        }
        .oneLogCard(fill: Color.white)
        .overlay(alignment: .bottomLeading) {
            if let remaining = estimate.remainingBudget {
                Text(remaining >= 0 ? "확인된 잔여 예산 \(won(remaining))" : "확인된 예산을 \(won(abs(remaining))) 초과했어요")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(remaining >= 0 ? Color.oneLogGreen : Color.oneLogOrange)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 5)
            } else {
                Text("가격 미확인 품목이 있어 잔여 예산을 확정하지 않았어요")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.oneLogMuted)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 5)
            }
        }
    }

    private func generateOptions() {
        validationMessage = nil
        guard budgetValue >= 0 else {
            validationMessage = "목표 예산을 0원 이상 입력해 주세요."
            return
        }
        let request = makeRequest()
        guard request.slotsByDate.values.contains(where: { !$0.isEmpty }) else {
            validationMessage = "하루 이상 한 끼를 선택해 주세요."
            return
        }
        let generated = generateMealPlanOptions(request: request)
        guard !generated.isEmpty, generated.contains(where: { !$0.drafts.isEmpty }) else {
            validationMessage = "조건에 맞는 식단을 만들지 못했어요. 불호 재료나 조리도구 설정을 조금 완화해 보세요."
            return
        }
        options = generated
        selectedOption = nil
        stage = .options
    }

    private func makeRequest() -> PlanRequest {
        var slotsByDate: [String: Set<MealSlot>] = [:]
        for date in dates {
            slotsByDate[date] = Set(MealSlot.allCases.filter { selectedSlots.contains(PlanSlotKey(date: date, slot: $0)) })
        }
        return PlanRequest(startDate: isoDateString(startDate), days: days, slotsByDate: slotsByDate, targetBudget: budgetValue, favorites: Set(store.state.favorites), inventory: store.state.inventory, prices: store.state.prices, preferences: store.state.preferences)
    }

    private func rebuildSelectedSlotsIfNeeded() {
        let validKeys = Set(dates.flatMap { date in MealSlot.allCases.map { PlanSlotKey(date: date, slot: $0) } })
        selectedSlots = selectedSlots.intersection(validKeys)
        if selectedSlots.isEmpty {
            selectedSlots = Set(dates.flatMap { date in MealSlot.allCases.map { PlanSlotKey(date: date, slot: $0) } })
        }
    }

    private func binding(for key: PlanSlotKey) -> Binding<Bool> {
        Binding {
            selectedSlots.contains(key)
        } set: { isSelected in
            if isSelected { selectedSlots.insert(key) }
            else { selectedSlots.remove(key) }
        }
    }

    private func replaceDraft(_ draftID: String, with recipeID: String) {
        let editingID = optionBeingEditedID ?? selectedOption?.id
        guard let editingID,
              var option = options.first(where: { $0.id == editingID }) ?? selectedOption,
              let index = option.drafts.firstIndex(where: { $0.id == draftID }) else { return }
        let draft = option.drafts[index]
        option.drafts[index] = PlannedMealDraft(recipeID: recipeID, date: draft.date, mealSlot: draft.mealSlot, reason: "", reusedIngredientIDs: [], newPurchaseCount: 0)
        let updated = recomputePlanOption(option, request: makeRequest())
        options = options.map { $0.id == editingID ? updated : $0 }
        if selectedOption?.id == editingID { selectedOption = updated }
        optionBeingEditedID = nil
    }

    private func applyUpgrade(_ suggestion: UpgradeSuggestion) {
        guard var option = selectedOption, let index = option.drafts.firstIndex(where: { $0.id == "\(suggestion.date):\(suggestion.mealSlot.rawValue)" }) else { return }
        let draft = option.drafts[index]
        option.drafts[index] = PlannedMealDraft(recipeID: suggestion.replacementRecipeID, date: draft.date, mealSlot: draft.mealSlot, reason: "", reusedIngredientIDs: [], newPurchaseCount: 0)
        selectedOption = recomputePlanOption(option, request: makeRequest())
    }
}

private struct BudgetMetric: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(Color.oneLogMuted).lineLimit(2)
            Text(value).font(.subheadline.weight(.black)).foregroundStyle(tint).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BudgetLineRow: View {
    let line: BudgetLineItem

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(line.shoppingItem.ingredientName)
                    .font(.subheadline.weight(.bold))
                Spacer()
                if let knownCost = line.knownCost {
                    Text(won(knownCost)).font(.subheadline.weight(.bold)).foregroundStyle(Color.oneLogOrange)
                } else if line.shoppingItem.purchaseQuantity == 0 {
                    StatusPill(text: "추가 구매 없음", tint: .oneLogGreen)
                } else {
                    StatusPill(text: "가격 확인 필요", tint: .oneLogOrange)
                }
            }
            HStack(spacing: 10) {
                Text("필요 \(formatQuantity(line.shoppingItem.quantity, unit: line.shoppingItem.unit))")
                Text("보유 \(formatQuantity(line.shoppingItem.availableQuantity, unit: line.shoppingItem.unit))")
                Text("구매 \(line.shoppingItem.purchaseQuantity)포장")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(Color.oneLogMuted)
            if let note = line.shoppingItem.note {
                Text(note).font(.caption2).foregroundStyle(Color.oneLogOrange)
            }
            if line.avoidedPackageCount > 0, let price = line.price {
                Text("보유 재료로 \(line.avoidedPackageCount)포장 절약 · \(won(line.avoidedPackageCount * price.price))")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.oneLogGreen)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct PriceEditorRow: View {
    @EnvironmentObject private var store: AppStore
    let item: ShoppingPlanItem
    let existingPrice: IngredientPrice?
    @State private var priceText = ""
    @State private var amountText = ""

    var body: some View {
        HStack(spacing: 8) {
            Text("확인한 포장 가격")
                .font(.caption)
                .foregroundStyle(Color.oneLogMuted)
            TextField("금액", text: $priceText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 84)
            Text("원 /")
                .font(.caption)
                .foregroundStyle(Color.oneLogMuted)
            TextField(formatQuantity(item.packageSize.amount), text: $amountText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 62)
            Text(item.unit.rawValue)
                .font(.caption)
                .foregroundStyle(Color.oneLogMuted)
            Button("저장") {
                let price = Int(priceText.replacingOccurrences(of: ",", with: "")) ?? 0
                let amount = Double(amountText) ?? item.packageSize.amount
                store.setPrice(ingredientID: item.ingredientID, price: price, packageAmount: amount, unit: item.unit)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.oneLogGreen)
        }
        .onAppear {
            priceText = existingPrice.map { String($0.price) } ?? ""
            amountText = existingPrice.map { formatQuantity($0.packageAmount) } ?? formatQuantity(item.packageSize.amount)
        }
    }
}

private struct PlanOptionCard: View {
    let option: MealPlanOption
    let isPreferred: Bool
    let onSelect: () -> Void
    let onSwap: (PlannedMealDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(option.title).font(.headline.weight(.black)).foregroundStyle(Color.oneLogInk)
                        if isPreferred { StatusPill(text: "추천", tint: .oneLogGreen) }
                    }
                    Text(option.subtitle).font(.subheadline).foregroundStyle(Color.oneLogMuted)
                }
                Spacer()
                Text("\(option.drafts.count)끼니").font(.caption.weight(.bold)).foregroundStyle(Color.oneLogGreen)
            }
            Text(option.reason).font(.caption).foregroundStyle(Color.oneLogMuted)
            if !option.sharedIngredientNames.isEmpty {
                Text("재사용 재료 · \(option.sharedIngredientNames.joined(separator: ", "))")
                    .font(.caption.weight(.bold)).foregroundStyle(Color.oneLogGreen)
            }
            VStack(spacing: 0) {
                ForEach(option.drafts) { draft in
                    HStack(spacing: 9) {
                        Image(systemName: draft.mealSlot.symbolName).foregroundStyle(Color.oneLogGreen)
                        Text("\(displayDate(draft.date)) · \(draft.mealSlot.rawValue)").font(.caption.weight(.bold)).frame(width: 130, alignment: .leading)
                        Text(recipe(for: draft.recipeID)?.title ?? "메뉴 없음").font(.caption).lineLimit(1)
                        Spacer()
                        Button("교체") { onSwap(draft) }.font(.caption.weight(.bold)).foregroundStyle(Color.oneLogGreen)
                    }
                    .padding(.vertical, 7)
                    if draft.id != option.drafts.last?.id { Divider().overlay(Color.oneLogLine) }
                }
            }
            Button("이 식단안을 선택하고 재료·예산 확인", action: onSelect)
                .buttonStyle(PrimaryButtonStyle())
        }
        .oneLogCard()
    }
}

private struct RecipeSwapView: View {
    @Environment(\.dismiss) private var dismiss
    let draft: PlannedMealDraft
    let preferences: AppPreferences
    let onSelect: (Recipe) -> Void

    var body: some View {
        NavigationStack {
            List(planCandidates(for: draft.mealSlot, preferences: preferences)) { recipe in
                Button {
                    onSelect(recipe)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text(recipe.symbolName).font(.title2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(recipe.title).font(.subheadline.weight(.bold)).foregroundStyle(Color.oneLogInk)
                            Text("\(recipe.cookTimeText) · \(recipe.description)").font(.caption).foregroundStyle(Color.oneLogMuted).lineLimit(2)
                        }
                    }
                }
            }
            .navigationTitle("\(draft.mealSlot.rawValue) 메뉴 교체")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } }
            }
        }
    }
}
