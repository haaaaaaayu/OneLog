import SwiftUI

/// F13·F20·F21 식단 만들기. 피그마 `식단 만들기 1~8`(350:1551, 350:1586, 350:1645, 350:1690,
/// 350:1729, 350:1779, 350:1832, 438:23)을 좌표 그대로 옮긴다. 시안 프레임은 393x852이고
/// 상태바 아래 34pt를 기준으로 헤더 42 / 프로그레스 94 / 본문 116 / 푸터 772에 놓인다.
///
/// 시안에 없는 마지막 단계(가격·예산 확인)는 기존 화면을 그대로 이어 붙인다. 디자인이 `미사용 / 구버전`
/// 으로 표시한 9·10단계 대체 시안이 나오면 그 자리에 넣는다.
struct PlanView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var step = 1
    @State private var startDate = Date()
    @State private var days = 5
    @State private var targetBudget = "30000"
    @State private var selectedSlots: Set<PlanSlotKey> = []
    @State private var options: [MealPlanOption] = []
    @State private var selectedOptionID: String?
    @State private var optionBeingEditedID: String?
    @State private var swappingDraft: PlannedMealDraft?
    @State private var validationMessage: String?
    /// 시안 `식단 만들기 11 / 계란 구매 단위 선택`(430:23)을 여는 품목.
    @State private var unitPickerItem: ShoppingPlanItem?

    /// 시안 `n / 11`. 9·10단계 시안이 아직 없어 마지막 가격 확인을 9로 쓴다.
    private let totalSteps = 11

    private var dates: [String] {
        (0..<days).map { dateByAddingDays(isoDateString(startDate), $0) }
    }

    private var budgetValue: Int {
        Int(targetBudget.filter(\.isNumber)) ?? 0
    }

    /// 시안은 `30,000`처럼 천 단위 구분이 들어간다. 입력 중에도 같은 표기를 유지한다.
    private func formatBudgetInput() {
        let digits = targetBudget.filter(\.isNumber)
        guard !digits.isEmpty else {
            if targetBudget != "" { targetBudget = "" }
            return
        }
        let formatted = won(Int(digits) ?? 0).replacingOccurrences(of: "원", with: "")
        if formatted != targetBudget { targetBudget = formatted }
    }

    private var selectedOption: MealPlanOption? {
        options.first { $0.id == selectedOptionID }
    }

    var body: some View {
        PlanFlowScaffold(
            step: step,
            total: totalSteps,
            showsBack: true,
            cta: cta,
            onBack: goBack
        ) {
            stepContent
        }
        .background(PlanPalette.canvas)
        // 홈에서는 시트, 내 식사에서는 푸시로 열린다. 두 경우 다 시안 헤더만 보여준다.
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $unitPickerItem) { item in
            PurchaseUnitPicker(item: item).environmentObject(store)
        }
        .sheet(item: $swappingDraft) { draft in
            RecipeSwapView(draft: draft, preferences: store.state.preferences) { recipe in
                replaceDraft(draft.id, with: recipe.id)
                swappingDraft = nil
            }
        }
        .onAppear {
            rebuildSelectedSlotsIfNeeded()
            formatBudgetInput()
        }
        .onChange(of: targetBudget) { _, _ in formatBudgetInput() }
        .onChange(of: days) { _, _ in rebuildSelectedSlotsIfNeeded() }
        .onChange(of: startDate) { _, _ in rebuildSelectedSlotsIfNeeded() }
    }

    // MARK: - 단계별 본문

    @ViewBuilder private var stepContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch step {
            case 1: durationStep
            case 2: mealsStep
            case 3: budgetStep
            case 4: analyzingStep
            case 5: optionsStep
            case 6: reviewStep
            case 7: finalStep
            case 8: ingredientsStep
            default: priceStep
            }

            if let validationMessage {
                Text(validationMessage)
                    .figmaText(11, .bold)
                    .foregroundStyle(PlanPalette.warning)
                    .padding(.top, 14)
                    .padding(.leading, 4)
            }
        }
        .frame(width: PlanPalette.contentWidth, alignment: .topLeading)
    }

    // MARK: - 1 / 기간 (350:1551)

    private var durationStep: some View {
        ZStack(alignment: .topLeading) {
            PlanIntroCard(
                step: 1,
                title: "며칠 동안 준비할까요?",
                titleSize: 21,
                subtitle: "준비할 식단 기간을 선택해 주세요.",
                textWidth: 200,
                mascot: PlanMascot(name: "PlanMascotDuration", x: 229, y: 3, width: 116, height: 94, scaleX: 1.6293, scaleY: 1.3404, offsetRatioX: -0.3017)
            )

            PlanWhiteCard(height: 112, radius: 18) {
                Text("식단 기간")
                    .figmaText(12, .bold)
                    .foregroundStyle(PlanPalette.cardLabel)
                    .offset(x: 17, y: 15)

                Menu {
                    ForEach(1...7, id: \.self) { value in
                        Button("\(value)일") { days = value }
                    }
                } label: {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(PlanPalette.inputFill)
                            .frame(width: 317, height: 48)
                        Text("\(days)일")
                            .figmaText(15, .bold)
                            .foregroundStyle(PlanPalette.ink)
                            .offset(x: 16, y: 13)
                        Text("⌄")
                            .figmaText(18, .medium)
                            .foregroundStyle(PlanPalette.inputChevron)
                            .offset(x: 282, y: 10)
                    }
                    .frame(width: 317, height: 48, alignment: .topLeading)
                }
                .accessibilityIdentifier("plan.duration")
                .offset(x: 17, y: 45)
            }
            .offset(y: 119)

            Text("최대 7일까지 한 번에 계획할 수 있어요.")
                .figmaText(11)
                .foregroundStyle(PlanPalette.caption)
                .offset(x: 4, y: 251)
        }
        .frame(width: PlanPalette.contentWidth, height: 272, alignment: .topLeading)
    }

    // MARK: - 2 / 끼니 (350:1586)

    private var mealsStep: some View {
        // 시안은 5일 기준 카드 310. 1일차 줄이 63에서 시작하고 한 줄 44, 아래 여백 27이다.
        let rowsHeight = 44 * CGFloat(days)
        let cardHeight = 63 + rowsHeight + 27

        return ZStack(alignment: .topLeading) {
            PlanIntroCard(
                step: 2,
                title: "몇 끼 드실 거예요?",
                titleSize: 20,
                subtitle: "일차마다 아침·점심·저녁을 선택해 주세요.",
                textWidth: 195,
                mascot: PlanMascot(name: "PlanMascotMeals", x: 236, y: 4, width: 91, height: 93, scaleX: 1.0083, scaleY: 1.2796, offsetRatioX: -0.0041)
            )

            PlanWhiteCard(height: cardHeight, radius: 18) {
                Text("일차별 끼니")
                    .figmaText(13, .bold)
                    .foregroundStyle(PlanPalette.cardTitle)
                    .offset(x: 17, y: 15)

                ForEach(Array(MealSlot.allCases.enumerated()), id: \.element) { index, slot in
                    Text(slot.rawValue)
                        .figmaText(10, .medium)
                        .foregroundStyle(PlanPalette.subtle)
                        .offset(x: 131 + CGFloat(index) * 70, y: 42)
                }

                ForEach(Array(dates.enumerated()), id: \.element) { index, date in
                    let top = 63 + CGFloat(index) * 44

                    Text("\(index + 1)일차")
                        .figmaText(12, .medium)
                        .foregroundStyle(PlanPalette.cardLabel)
                        .offset(x: 17, y: top + 12)

                    ForEach(Array(MealSlot.allCases.enumerated()), id: \.element) { column, slot in
                        let key = PlanSlotKey(date: date, slot: slot)
                        let isOn = selectedSlots.contains(key)
                        Button {
                            if isOn { selectedSlots.remove(key) } else { selectedSlots.insert(key) }
                        } label: {
                            Image(systemName: isOn ? "checkmark.circle" : "circle")
                                .font(.figma(22))
                                .foregroundStyle(isOn ? PlanPalette.check : PlanPalette.uncheck)
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(index + 1)일차 \(slot.rawValue)")
                        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
                        .offset(x: 127 + CGFloat(column) * 70, y: top + 8)
                    }

                    if index < days - 1 {
                        Rectangle()
                            .fill(PlanPalette.rowDivider)
                            .frame(width: 317, height: 1)
                            .offset(x: 17, y: top + 44)
                    }
                }
            }
            .offset(y: 116)

            Text(slotSummaryText)
                .figmaText(10)
                .foregroundStyle(PlanPalette.caption)
                .offset(x: 4, y: 116 + cardHeight + 15)
        }
        .frame(width: PlanPalette.contentWidth, height: 116 + cardHeight + 40, alignment: .topLeading)
    }

    private var slotSummaryText: String {
        let counts = MealSlot.allCases.map { slot in
            selectedSlots.filter { $0.slot == slot }.count
        }
        return "아침 \(counts[0])회 · 점심 \(counts[1])회 · 저녁 \(counts[2])회로 선택했어요."
    }

    // MARK: - 3 / 예산 (350:1645)

    private var budgetStep: some View {
        ZStack(alignment: .topLeading) {
            PlanIntroCard(
                step: 3,
                title: "장보기를 알려주세요",
                titleSize: 21,
                subtitle: "장보기 예산에 맞춰 식단을 구성해줄게요.",
                textWidth: 218,
                mascot: PlanMascot(name: "PlanMascotBudget", x: 219, y: 5, width: 128, height: 92, scaleX: 1, scaleY: 1.3913, offsetRatioX: 0)
            )

            PlanWhiteCard(height: 118, radius: 18) {
                Text("전체 예산")
                    .figmaText(12, .bold)
                    .foregroundStyle(PlanPalette.cardLabel)
                    .offset(x: 17, y: 15)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(PlanPalette.inputFill)
                        .frame(width: 317, height: 54)
                    TextField("", text: $targetBudget, prompt: Text("30,000").foregroundColor(PlanPalette.subtle))
                        .font(.figma(22, .bold))
                        .foregroundStyle(PlanPalette.ink)
                        .keyboardType(.numberPad)
                        .frame(width: 250, alignment: .leading)
                        .accessibilityIdentifier("plan.budget")
                        .offset(x: 16, y: 13)
                    Text("원")
                        .figmaText(13, .medium)
                        .foregroundStyle(PlanPalette.subtle)
                        .offset(x: 280, y: 17)
                }
                .frame(width: 317, height: 54, alignment: .topLeading)
                .offset(x: 17, y: 45)
            }
            .offset(y: 111)

            Text("빠른 선택")
                .figmaText(11, .bold)
                .foregroundStyle(PlanPalette.quickLabel)
                .offset(x: 4, y: 253)

            // 시안 좌표(-3 / 94.5 / 195)를 그대로 쓴다. 폭도 86 / 86 / 85로 다르다.
            ForEach(Array(PlanPalette.budgetPresets.enumerated()), id: \.offset) { index, preset in
                let geometry: (x: CGFloat, width: CGFloat) = [(-3, 86), (94.5, 86), (195, 85)][index]
                let isSelected = budgetValue == preset.amount
                Button {
                    targetBudget = String(preset.amount)
                } label: {
                    Text(preset.label)
                        .figmaText(12, isSelected ? .bold : .medium)
                        .foregroundStyle(PlanPalette.presetText)
                        .frame(width: geometry.width, height: 42)
                        .background(isSelected ? PlanPalette.presetSelected : .white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(isSelected ? PlanPalette.yellow : PlanPalette.presetBorder, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .offset(x: geometry.x, y: 279)
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PlanPalette.infoFill)
                    .frame(width: PlanPalette.contentWidth, height: 66)
                Image(systemName: "banknote")
                    .font(.figma(20))
                    .foregroundStyle(PlanPalette.infoIcon)
                    .frame(width: 24, height: 24)
                    .offset(x: 18, y: 21)
                Text("실제 구매 비용은 더 낮아질 수 있어요")
                    .figmaText(12, .bold)
                    .foregroundStyle(PlanPalette.infoTitle)
                    .offset(x: 50, y: 18)
                Text("보유 재료를 확인한 뒤 남은 예산까지 계산해요.")
                    .figmaText(10)
                    .foregroundStyle(PlanPalette.infoBody)
                    .offset(x: 50, y: 36)
            }
            .frame(width: PlanPalette.contentWidth, height: 66, alignment: .topLeading)
            .offset(y: 347)
        }
        .frame(width: PlanPalette.contentWidth, height: 413, alignment: .topLeading)
    }

    // MARK: - 4 / 분석 (350:1690)

    private var analyzingStep: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Text("취향에 맞는 식단을\n조합하고 있어요")
                    .figmaText(22, .bold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PlanPalette.ink)
            }
            .frame(width: PlanPalette.contentWidth)
            .offset(y: 12)

            Text("찜한 레시피와 선택한 조건을 함께 분석해요.")
                .figmaText(11)
                .foregroundStyle(PlanPalette.subtle)
                .frame(width: PlanPalette.contentWidth)
                .offset(y: 74)

            Image("PlanAiHalo")
                .resizable()
                .scaledToFit()
                .frame(width: 141, height: 141)
                .offset(x: 106, y: 112)

            Image("PlanMascotAnalyzing")
                .resizable()
                .scaledToFit()
                .frame(width: 143.179, height: 150.751)
                .offset(x: 108.52, y: 125.32)

            PlanWhiteCard(height: 190, radius: 20) {
                Text("이렇게 반영하고 있어요")
                    .figmaText(13, .bold)
                    .foregroundStyle(PlanPalette.cardTitle)
                    .offset(x: 17, y: 15)

                ForEach(Array(analysisRows.enumerated()), id: \.offset) { index, row in
                    let top = 51 + CGFloat(index) * 43
                    Image(systemName: row.symbol)
                        .font(.figma(19))
                        .foregroundStyle(PlanPalette.rowIcon)
                        .frame(width: 22, height: 22)
                        .offset(x: 17, y: top)
                    Text(row.title)
                        .figmaText(11, .bold)
                        .foregroundStyle(PlanPalette.rowTitle)
                        .offset(x: 49, y: top)
                    Text(row.value)
                        .figmaText(9)
                        .foregroundStyle(PlanPalette.rowValue)
                        .offset(x: 204, y: top + 2)
                }
            }
            .offset(y: 284)
        }
        .frame(width: PlanPalette.contentWidth, height: 474, alignment: .topLeading)
    }

    private var analysisRows: [(symbol: String, title: String, value: String)] {
        let favorites = store.state.favorites.count
        let tools = store.state.preferences.availableTools.count
        return [
            ("heart", "찜한 레시피와 취향", favorites > 0 ? "찜한 \(favorites)개 우선" : "찜 없음 · 균형 우선"),
            ("sun.max", "가벼운 아침 메뉴", "부담 없는 메뉴 우선"),
            ("banknote", "\(won(budgetValue)) 예산", "조리도구 \(tools)개 반영"),
        ]
    }

    // MARK: - 5 / 식단안 선택 (350:1729)

    private var optionsStep: some View {
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PlanPalette.introFill)
                    .frame(width: PlanPalette.contentWidth, height: 92)
                Text("식단안 \(options.count)개를 만들었어요")
                    .figmaText(18, .bold)
                    .foregroundStyle(PlanPalette.ink)
                    .offset(x: 18, y: 18)
                Text("예산과 재료 활용 방식이 조금씩 달라요.")
                    .figmaText(10)
                    .foregroundStyle(PlanPalette.introBody)
                    .offset(x: 18, y: 52)
            }
            .frame(width: PlanPalette.contentWidth, height: 92, alignment: .topLeading)

            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                PlanOptionCard(
                    option: option,
                    isSelected: option.id == selectedOptionID,
                    isRecommended: index == 0,
                    costText: costText(for: option),
                    metaText: metaText(for: option),
                    onSelect: { selectedOptionID = option.id }
                )
                .accessibilityIdentifier("plan.option.\(index)")
                .offset(y: 110 + CGFloat(index) * 145)
            }
        }
        .frame(width: PlanPalette.contentWidth, height: 110 + CGFloat(max(options.count, 1)) * 145, alignment: .topLeading)
    }

    private func costText(for option: MealPlanOption) -> String {
        let estimate = store.estimate(for: option.drafts, targetBudget: budgetValue)
        if estimate.isComplete { return "예상 \(won(estimate.knownPurchaseCost))" }
        if estimate.knownPurchaseCost > 0 { return "확인된 금액 \(won(estimate.knownPurchaseCost))" }
        return "가격 확인 전"
    }

    private func metaText(for option: MealPlanOption) -> String {
        let counts = MealSlot.allCases.map { slot in option.drafts.filter { $0.mealSlot == slot }.count }
        return "아침 \(counts[0]) · 점심 \(counts[1]) · 저녁 \(counts[2])"
    }

    // MARK: - 6 / 확인·수정 (350:1779)

    private var reviewStep: some View {
        let groups = dayGroups
        let cardHeight = groups.reduce(0) { $0 + PlanDayBlock.height(mealCount: $1.meals.count) } + CGFloat(max(groups.count - 1, 0))

        return ZStack(alignment: .topLeading) {
            Text("\(days)일 식단")
                .figmaText(16, .bold)
                .foregroundStyle(PlanPalette.ink)
                .offset(y: 110)
            Text("총 \(selectedOption?.drafts.count ?? 0)끼")
                .figmaText(11, .medium)
                .foregroundStyle(PlanPalette.summaryText)
                .frame(width: PlanPalette.contentWidth, alignment: .trailing)
                .offset(y: 114)

            VStack(spacing: 0) {
                ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                    PlanDayBlock(index: index, group: group) { draft in
                        optionBeingEditedID = selectedOptionID
                        swappingDraft = draft
                    }
                    if index < groups.count - 1 {
                        Rectangle()
                            .fill(PlanPalette.dayDivider)
                            .frame(width: 321, height: 1)
                    }
                }
            }
            .frame(width: PlanPalette.contentWidth, alignment: .topLeading)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(PlanPalette.cardBorderStrong, lineWidth: 1)
            }
            .offset(y: 142)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(PlanPalette.summaryFill)
                    .frame(width: PlanPalette.contentWidth, height: 44)
                Text(reviewSummaryText)
                    .figmaText(12, .medium)
                    .foregroundStyle(PlanPalette.ink)
                    .offset(x: 16, y: 13)
                Text(selectedOption.map(costText) ?? "")
                    .figmaText(10, .bold)
                    .foregroundStyle(PlanPalette.ink)
                    .frame(width: 105, height: 28)
                    .background(PlanPalette.badgeFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .offset(x: 232, y: 8)
            }
            .frame(width: PlanPalette.contentWidth, height: 44, alignment: .topLeading)
            .offset(y: 142 + cardHeight + 16)
        }
        .frame(width: PlanPalette.contentWidth, height: 142 + cardHeight + 76, alignment: .topLeading)
    }

    private var reviewSummaryText: String {
        let drafts = selectedOption?.drafts ?? []
        let parts = MealSlot.allCases.compactMap { slot -> String? in
            let count = drafts.filter { $0.mealSlot == slot }.count
            return count > 0 ? "\(slot.rawValue) \(count)회" : nil
        }
        return parts.isEmpty ? "선택한 끼니가 없어요" : parts.joined(separator: " · ")
    }

    private var dayGroups: [PlanDayGroup] {
        let drafts = selectedOption?.drafts ?? []
        return dates.compactMap { date in
            let meals = MealSlot.allCases.compactMap { slot in
                drafts.first { $0.date == date && $0.mealSlot == slot }
            }
            return meals.isEmpty ? nil : PlanDayGroup(date: date, meals: meals)
        }
    }

    // MARK: - 7 / 최종 확인 (350:1832)

    private var finalStep: some View {
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(PlanPalette.introFill)
                    .frame(width: PlanPalette.contentWidth, height: 174)
                Text("이 식단으로 확정할까요?")
                    .figmaText(20, .bold)
                    .foregroundStyle(PlanPalette.ink)
                    .frame(width: PlanPalette.contentWidth)
                    .offset(y: 112)
                Text(selectedOption?.reason ?? "선택한 식단을 확정해요.")
                    .figmaText(10)
                    .foregroundStyle(PlanPalette.introBody)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 300)
                    .offset(x: 26.5, y: 144)
            }
            .frame(width: PlanPalette.contentWidth, height: 174, alignment: .topLeading)

            PlanWhiteCard(height: 224, radius: 20) {
                Text("선택 내용")
                    .figmaText(13, .bold)
                    .foregroundStyle(PlanPalette.cardTitle)
                    .offset(x: 17, y: 16)

                ForEach(Array(finalRows.enumerated()), id: \.offset) { index, row in
                    let top = 53 + CGFloat(index) * 40
                    Image(systemName: row.symbol)
                        .font(.figma(19))
                        .foregroundStyle(PlanPalette.rowIcon)
                        .frame(width: 22, height: 22)
                        .offset(x: 17, y: top)
                    Text(row.label)
                        .figmaText(10, .medium)
                        .foregroundStyle(PlanPalette.rowLabel)
                        .offset(x: 49, y: top + 1)
                    Text(row.value)
                        .figmaText(11, .bold)
                        .foregroundStyle(PlanPalette.cardTitle)
                        .frame(width: 319, alignment: .trailing)
                        .offset(x: 17, y: top)
                }
            }
            .offset(y: 194)
        }
        .frame(width: PlanPalette.contentWidth, height: 418, alignment: .topLeading)
    }

    private var finalRows: [(symbol: String, label: String, value: String)] {
        let counts = MealSlot.allCases.map { slot in (selectedOption?.drafts ?? []).filter { $0.mealSlot == slot }.count }
        return [
            ("calendar", "식단 기간", "\(days)일"),
            ("fork.knife", "선택 끼니", "아침 \(counts[0]) · 점심 \(counts[1]) · 저녁 \(counts[2])"),
            ("banknote", "전체 예산", won(budgetValue)),
            ("heart", "취향 반영", selectedOption?.title ?? "-"),
        ]
    }

    // MARK: - 8 / 전체 재료 목록 (438:23)

    private var ingredientsStep: some View {
        let items = planShoppingItems
        let groups = PlanIngredientGroup.grouped(items)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("이번 식단에 필요한 재료예요")
                        .figmaText(16, .bold, lineHeight: 22)
                        .foregroundStyle(PlanPalette.ink)
                    Text("\(days)일치 식단 · 총 \(items.count)가지 핵심 재료를 모았어요.")
                        .figmaText(12, .medium, lineHeight: 18)
                        .foregroundStyle(PlanPalette.headerBody)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("📋")
                    .figmaText(26)
            }
            .padding(16)
            .frame(width: PlanPalette.contentWidth, alignment: .leading)
            .background(PlanPalette.listHeaderFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text(group.title)
                            .figmaText(14, .bold)
                            .foregroundStyle(PlanPalette.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(group.items.count)가지")
                            .figmaText(12, .medium)
                            .foregroundStyle(PlanPalette.listMuted)
                    }
                    .padding(.bottom, 6)

                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 10) {
                            Text(item.ingredientName)
                                .figmaText(14, .medium)
                                .foregroundStyle(PlanPalette.listName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(formatQuantity(item.quantity, unit: item.unit))
                                .figmaText(13, .medium)
                                .foregroundStyle(PlanPalette.listMuted)
                        }
                        .padding(.vertical, 10)

                        if index < group.items.count - 1 {
                            Rectangle()
                                .fill(PlanPalette.listDivider)
                                .frame(height: 1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(width: PlanPalette.contentWidth, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(PlanPalette.cardBorderStrong, lineWidth: 1)
                }
            }

            Text("이미 있는 재료는 다음 단계에서 체크해 주세요.")
                .figmaText(12, .medium)
                .foregroundStyle(PlanPalette.listMuted)
        }
        .frame(width: PlanPalette.contentWidth, alignment: .leading)
    }

    private var planShoppingItems: [ShoppingPlanItem] {
        guard let option = selectedOption else { return [] }
        return calculateShoppingPlan(
            requirements: aggregateRequirements(for: option.drafts),
            inventory: [],
            packageOverrides: store.state.packageOverrides
        )
    }

    // MARK: - 9 / 가격·예산 확인 (시안 없음. 기존 화면 유지)

    @ViewBuilder private var priceStep: some View {
        if let option = selectedOption {
            let estimate = store.estimate(for: option.drafts, targetBudget: budgetValue)
            let request = makeRequest()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("가격과 판매 단위 확인")
                        .figmaText(18, .bold)
                        .foregroundStyle(PlanPalette.ink)
                    Text("판매 단위를 확인하면 구매량이, 가격까지 넣으면 예상 지출과 잔여 예산이 계산돼요.")
                        .figmaText(12, .medium, lineHeight: 18)
                        .foregroundStyle(PlanPalette.headerBody)
                }

                budgetSummary(estimate)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(estimate.lineItems) { line in
                        Button {
                            unitPickerItem = line.shoppingItem
                        } label: {
                            BudgetLineRow(line: line)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("구매 단위를 비교해서 고를 수 있어요")
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
                    .oneLogCard(fill: PlanPalette.infoFill)
                }
            }
            .frame(width: PlanPalette.contentWidth, alignment: .leading)
        } else {
            EmptyState(symbol: "calendar.badge.exclamationmark", title: "식단안을 먼저 골라 주세요", message: "이전 단계에서 제안받은 식단안을 선택해 주세요.")
        }
    }

    private func budgetSummary(_ estimate: BudgetEstimate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                BudgetMetric(title: "목표 예산", value: won(estimate.targetBudget), tint: .oneLogInk)
                BudgetMetric(title: "확인된 예상 지출", value: won(estimate.knownPurchaseCost), tint: .oneLogOrange)
                BudgetMetric(title: "보유 재료 절감", value: won(estimate.confirmedInventorySavings), tint: .oneLogSuccess)
            }
            if let remaining = estimate.remainingBudget {
                Text(remaining >= 0 ? "확인된 잔여 예산 \(won(remaining))" : "확인된 예산을 \(won(abs(remaining))) 초과했어요")
                    .figmaText(11, .bold)
                    .foregroundStyle(remaining >= 0 ? Color.oneLogSuccess : Color.oneLogOrange)
            } else {
                Text("가격 미확인 품목이 있어 잔여 예산을 확정하지 않았어요")
                    .figmaText(11, .bold)
                    .foregroundStyle(PlanPalette.summaryText)
            }
        }
        .oneLogCard()
    }

    // MARK: - 푸터 버튼

    private var cta: PlanFlowCTA {
        switch step {
        case 4:
            return PlanFlowCTA(title: "식단안 보기", style: .yellow, isEnabled: true, action: generateOptions)
        case 5:
            return PlanFlowCTA(title: "이 식단 선택", style: .dark, isEnabled: selectedOptionID != nil) { step = 6 }
        case 7:
            return PlanFlowCTA(title: "이 식단으로 확정", style: .yellow, isEnabled: selectedOption != nil, action: confirmPlan)
        case 9:
            return PlanFlowCTA(title: "완료", style: .yellow, isEnabled: true, action: finishFlow)
        default:
            return PlanFlowCTA(title: "다음", style: .dark, isEnabled: true, action: advance)
        }
    }

    /// 1단계의 ‹는 흐름을 나간다(시트 닫기 또는 푸시 되돌리기).
    private func goBack() {
        validationMessage = nil
        if step > 1 { step -= 1 } else { dismiss() }
    }

    private func advance() {
        validationMessage = nil
        if step == 2, !selectedSlots.contains(where: { dates.contains($0.date) }) {
            validationMessage = "하루 이상 한 끼를 선택해 주세요."
            return
        }
        if step == 3, budgetValue <= 0 {
            validationMessage = "목표 예산을 1원 이상 입력해 주세요."
            return
        }
        step += 1
    }

    private func confirmPlan() {
        guard let option = selectedOption else { return }
        store.applyPlan(option, targetBudget: budgetValue)
        step = 8
    }

    private func finishFlow() {
        options = []
        selectedOptionID = nil
        validationMessage = nil
        step = 1
        dismiss()
    }

    private func generateOptions() {
        validationMessage = nil
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
        selectedOptionID = generated.first?.id
        step = 5
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

    private func replaceDraft(_ draftID: String, with recipeID: String) {
        let editingID = optionBeingEditedID ?? selectedOptionID
        guard let editingID,
              var option = options.first(where: { $0.id == editingID }),
              let index = option.drafts.firstIndex(where: { $0.id == draftID }) else { return }
        let draft = option.drafts[index]
        option.drafts[index] = PlannedMealDraft(recipeID: recipeID, date: draft.date, mealSlot: draft.mealSlot, reason: "", reusedIngredientIDs: [], newPurchaseCount: 0)
        let updated = recomputePlanOption(option, request: makeRequest())
        options = options.map { $0.id == editingID ? updated : $0 }
        optionBeingEditedID = nil
    }

    private func applyUpgrade(_ suggestion: UpgradeSuggestion) {
        guard var option = selectedOption,
              let index = option.drafts.firstIndex(where: { $0.id == "\(suggestion.date):\(suggestion.mealSlot.rawValue)" }) else { return }
        let draft = option.drafts[index]
        option.drafts[index] = PlannedMealDraft(recipeID: suggestion.replacementRecipeID, date: draft.date, mealSlot: draft.mealSlot, reason: "", reusedIngredientIDs: [], newPurchaseCount: 0)
        let updated = recomputePlanOption(option, request: makeRequest())
        options = options.map { $0.id == updated.id ? updated : $0 }
    }
}

// MARK: - 시안 팔레트와 치수

/// 피그마 `식단 만들기` 프레임의 값. 다른 화면과 값이 1씩 달라도 시안 그대로 둔다.
private enum PlanPalette {
    static let contentWidth: CGFloat = 353

    static let canvas = Color(hex: 0xFFFEFB)
    static let ink = Color(hex: 0x141411)
    static let yellow = Color(hex: 0xFFCA12)
    static let introFill = Color(hex: 0xFFF7D0)
    static let introBody = Color(hex: 0x685E3D)
    static let stepLabel = Color(hex: 0x745B00)
    static let headerStep = Color(hex: 0x7A7468)
    static let backFill = Color(hex: 0xFFF8DC)
    static let progressTrack = Color(hex: 0xF1EBDD)
    static let footerDivider = Color(hex: 0xEFE7D9)
    static let cardBorder = Color(hex: 0xEFE7D7)
    static let cardBorderStrong = Color(hex: 0xE5DECC)
    static let cardLabel = Color(hex: 0x3B3730)
    static let cardTitle = Color(hex: 0x39352E)
    static let inputFill = Color(hex: 0xF8F5EE)
    static let inputChevron = Color(hex: 0x797163)
    static let caption = Color(hex: 0x827A6D)
    static let subtle = Color(hex: 0x7A7468)
    static let check = Color(hex: 0xFFB400)
    static let uncheck = Color(hex: 0xC4BEB3)
    static let rowDivider = Color(hex: 0xF3EDE2)
    static let quickLabel = Color(hex: 0x595349)
    static let presetSelected = Color(hex: 0xFFF3C9)
    static let presetBorder = Color(hex: 0xE8DECC)
    static let presetText = Color(hex: 0x302C26)
    static let infoFill = Color(hex: 0xFFFBE8)
    static let infoIcon = Color(hex: 0xA97E00)
    static let infoTitle = Color(hex: 0x534618)
    static let infoBody = Color(hex: 0x76683A)
    static let rowIcon = Color(hex: 0xB48700)
    static let rowTitle = Color(hex: 0x464138)
    static let rowValue = Color(hex: 0x888072)
    static let rowLabel = Color(hex: 0x877F71)
    static let optionSelectedFill = Color(hex: 0xFFFCE8)
    static let optionTitle = Color(hex: 0x1E1D19)
    static let optionRadio = Color(hex: 0xBEB8AD)
    static let optionCost = Color(hex: 0x37332C)
    static let optionChevron = Color(hex: 0x91897B)
    static let badgeFill = Color(hex: 0xFFF3C9)
    static let badgeText = Color(hex: 0x221F18)
    static let summaryFill = Color(hex: 0xF9F4E8)
    static let summaryText = Color(hex: 0x8C8270)
    static let dayText = Color(hex: 0x141412)
    static let dayDivider = Color(hex: 0xEBE3D4)
    static let listHeaderFill = Color(hex: 0xFFF4C9)
    static let headerBody = Color(hex: 0x574F40)
    static let listMuted = Color(hex: 0x998C78)
    static let listName = Color(hex: 0x2B2418)
    static let listDivider = Color(hex: 0xEFE7D6)
    static let warning = Color(hex: 0xC4761F)

    static let budgetPresets: [(label: String, amount: Int)] = [("3만원", 30000), ("4만원", 40000), ("5만원", 50000)]
}

private enum PlanCTAStyle {
    case dark
    case yellow
}

private struct PlanFlowCTA {
    let title: String
    let style: PlanCTAStyle
    let isEnabled: Bool
    let action: () -> Void
}

/// 시안 공통 골격: 헤더(42) · 프로그레스(94) · 본문(116) · 푸터(772, 높이 80).
/// 좌표는 시안 상태바 아래(34pt) 기준이라 실기기 safe area 아래 8pt에서 시작한다.
private struct PlanFlowScaffold<Content: View>: View {
    let step: Int
    let total: Int
    let showsBack: Bool
    let cta: PlanFlowCTA
    let onBack: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 8)
            progress
                .padding(.top, 6)
            ScrollView {
                content
                    .padding(.top, 17)
                    .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        ZStack {
            Text("식단 만들기")
                .figmaText(18, .bold)
                .foregroundStyle(PlanPalette.ink)

            HStack(spacing: 0) {
                Button(action: onBack) {
                    Text("‹")
                        .figmaText(25, .medium)
                        .foregroundStyle(PlanPalette.ink)
                        .frame(width: 38, height: 38)
                        .background(PlanPalette.backFill, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("이전 단계")
                .opacity(showsBack ? 1 : 0)
                .disabled(!showsBack)

                Spacer()

                Text("\(step) / \(total)")
                    .figmaText(11, .medium)
                    .foregroundStyle(PlanPalette.headerStep)
                    .accessibilityIdentifier("plan.step")
            }
        }
        .frame(width: PlanPalette.contentWidth, height: 46)
    }

    private var progress: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(PlanPalette.progressTrack)
                .frame(width: PlanPalette.contentWidth, height: 5)
            Capsule()
                .fill(PlanPalette.yellow)
                .frame(width: PlanPalette.contentWidth * CGFloat(step) / CGFloat(total), height: 5)
        }
        .frame(width: PlanPalette.contentWidth, height: 5)
        .accessibilityHidden(true)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(PlanPalette.footerDivider)
                .frame(height: 1)
            Button(action: cta.action) {
                Text(cta.title)
                    .figmaText(14, .bold)
                    .foregroundStyle(cta.style == .dark ? .white : PlanPalette.ink)
                    .frame(width: PlanPalette.contentWidth, height: 48)
                    .background(
                        (cta.style == .dark ? PlanPalette.ink : PlanPalette.yellow).opacity(cta.isEnabled ? 1 : 0.4),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!cta.isEnabled)
            .accessibilityIdentifier("plan.next")
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
        .background(.white)
    }
}

/// 시안 STEP 안내 카드(353x97, radius 20, #FFF7D0)와 오른쪽 마스코트.
private struct PlanIntroCard: View {
    let step: Int
    let title: String
    let titleSize: CGFloat
    let subtitle: String
    let textWidth: CGFloat
    let mascot: PlanMascot

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(PlanPalette.introFill)
                .frame(width: PlanPalette.contentWidth, height: 97)

            mascot

            VStack(alignment: .leading, spacing: 8) {
                Text("STEP \(step)")
                    .figmaText(10, .bold)
                    .foregroundStyle(PlanPalette.stepLabel)
                Text(title)
                    .figmaText(titleSize, .bold)
                    .foregroundStyle(PlanPalette.ink)
                Text(subtitle)
                    .figmaText(11)
                    .foregroundStyle(PlanPalette.introBody)
            }
            .frame(width: textWidth, alignment: .leading)
            .offset(x: 18, y: 16)
        }
        .frame(width: PlanPalette.contentWidth, height: 97, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// 시안이 마스코트를 확대·이동해 잘라 쓰기 때문에 그 비율(`w/h %`, `left %`)을 그대로 옮긴다.
private struct PlanMascot: View {
    let name: String
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let scaleX: CGFloat
    let scaleY: CGFloat
    let offsetRatioX: CGFloat

    var body: some View {
        Image(name)
            .resizable()
            .frame(width: width * scaleX, height: height * scaleY)
            .offset(x: width * offsetRatioX)
            .frame(width: width, height: height, alignment: .topLeading)
            .clipped()
            .offset(x: x, y: y)
            .accessibilityHidden(true)
    }
}

/// 시안 흰 카드(테두리 #EFE7D7). 안쪽은 좌표 그대로 놓는다.
private struct PlanWhiteCard<Content: View>: View {
    let height: CGFloat
    let radius: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.white)
                .frame(width: PlanPalette.contentWidth, height: height)
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(PlanPalette.cardBorder, lineWidth: 1)
                }
            content
        }
        .frame(width: PlanPalette.contentWidth, height: height, alignment: .topLeading)
    }
}

/// 시안 `Plans / Option`(350:1750). 선택된 카드만 노랑 2pt 테두리를 쓴다.
private struct PlanOptionCard: View {
    let option: MealPlanOption
    let isSelected: Bool
    let isRecommended: Bool
    let costText: String
    let metaText: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? PlanPalette.optionSelectedFill : .white)
                    .frame(width: PlanPalette.contentWidth, height: 130)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(isSelected ? PlanPalette.yellow : PlanPalette.cardBorder, lineWidth: isSelected ? 2 : 1)
                    }

                Image(systemName: isSelected ? "checkmark.circle" : "circle")
                    .font(.figma(22))
                    .foregroundStyle(isSelected ? PlanPalette.check : PlanPalette.optionRadio)
                    .frame(width: 22, height: 22)
                    .offset(x: 16, y: 15)

                Text(option.title)
                    .figmaText(15, .bold)
                    .foregroundStyle(PlanPalette.optionTitle)
                    .offset(x: 52, y: 14)

                if isRecommended {
                    Text("AI 추천")
                        .figmaText(10, .bold)
                        .foregroundStyle(PlanPalette.badgeText)
                        .frame(width: 57, height: 26)
                        .background(PlanPalette.yellow, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .offset(x: 274, y: 12)
                }

                Text(option.subtitle)
                    .figmaText(10)
                    .foregroundStyle(PlanPalette.subtle)
                    .lineLimit(1)
                    .frame(width: 215, alignment: .leading)
                    .offset(x: 52, y: 44)

                Text(costText)
                    .figmaText(13, .bold)
                    .foregroundStyle(PlanPalette.optionCost)
                    .offset(x: 16, y: 80)

                Text(metaText)
                    .figmaText(10)
                    .foregroundStyle(PlanPalette.rowValue)
                    .offset(x: 16, y: 103)

                Text("›")
                    .figmaText(22, .medium)
                    .foregroundStyle(PlanPalette.optionChevron)
                    .offset(x: 320, y: 89)
            }
            .frame(width: PlanPalette.contentWidth, height: 130, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

private struct PlanDayGroup {
    let date: String
    let meals: [PlannedMealDraft]
}

/// 시안 `Review / n일차`. 한 끼면 78, 두 끼부터는 58 + 36 × 끼니 수.
private struct PlanDayBlock: View {
    let index: Int
    let group: PlanDayGroup
    let onEdit: (PlannedMealDraft) -> Void

    static func height(mealCount: Int) -> CGFloat {
        max(78, 58 + 36 * CGFloat(mealCount - 1))
    }

    private var isCompact: Bool { group.meals.count == 1 }

    var body: some View {
        let height = Self.height(mealCount: group.meals.count)
        let firstTop: CGFloat = isCompact ? 28 : 15

        return ZStack(alignment: .topLeading) {
            Text("\(index + 1)일차")
                .figmaText(10, .bold)
                .foregroundStyle(PlanPalette.dayText)
                .frame(width: 52, height: 24)
                .background(PlanPalette.badgeFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .offset(x: 16, y: isCompact ? 27 : 14)

            Button {
                if let first = group.meals.first { onEdit(first) }
            } label: {
                Text("수정")
                    .figmaText(10, .medium)
                    .foregroundStyle(PlanPalette.summaryText)
                    .frame(width: 44, height: 26)
                    .background(PlanPalette.summaryFill, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(index + 1)일차 메뉴 수정")
            .offset(x: 293, y: isCompact ? 26 : 14)

            ForEach(Array(group.meals.enumerated()), id: \.element.id) { position, draft in
                let top = firstTop + CGFloat(position) * 36

                Text(draft.mealSlot.rawValue)
                    .figmaText(10, .medium)
                    .foregroundStyle(PlanPalette.summaryText)
                    .frame(width: 36, height: 22)
                    .background(draft.mealSlot == .breakfast ? PlanPalette.badgeFill : PlanPalette.summaryFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .offset(x: 84, y: top)

                Text(recipe(for: draft.recipeID)?.title ?? "메뉴 없음")
                    .figmaText(12, .medium)
                    .foregroundStyle(PlanPalette.dayText)
                    .lineLimit(1)
                    .frame(width: 155, alignment: .leading)
                    .offset(x: 132, y: top + 2)
            }
        }
        .frame(width: PlanPalette.contentWidth, height: height, alignment: .topLeading)
    }
}

/// 시안 8단계는 재료를 `채소 / 단백질·유제품 / 곡물·양념`으로 묶는다. 재료 사전에 분류 정보가 없어
/// 이름으로 나눈다. ponytail: 휴리스틱. 분류 데이터가 생기면 그 값을 쓰고 이 함수는 지운다.
private struct PlanIngredientGroup: Identifiable {
    let title: String
    let items: [ShoppingPlanItem]

    var id: String { title }

    static func grouped(_ items: [ShoppingPlanItem]) -> [PlanIngredientGroup] {
        var buckets: [String: [ShoppingPlanItem]] = [:]
        for item in items {
            buckets[category(of: item.ingredientName), default: []].append(item)
        }
        return ["채소", "단백질 · 유제품", "곡물 · 양념", "기타"].compactMap { title in
            guard let items = buckets[title], !items.isEmpty else { return nil }
            return PlanIngredientGroup(title: title, items: items)
        }
    }

    private static func category(of name: String) -> String {
        let vegetables = ["배추", "양파", "파", "당근", "무", "버섯", "호박", "오이", "고추", "마늘", "감자", "고구마", "나물", "채소", "상추", "깻잎", "토마토", "파프리카", "피망", "부추", "시금치", "브로콜리", "김치", "미역", "다시마"]
        let proteins = ["고기", "살", "갈비", "닭", "돼지", "소고기", "쇠고기", "계란", "달걀", "두부", "치즈", "우유", "요거트", "요구르트", "새우", "오징어", "낙지", "생선", "고등어", "참치", "연어", "햄", "베이컨", "소시지", "어묵", "조개", "굴"]
        let grains = ["쌀", "밥", "면", "국수", "빵", "떡", "가루", "장", "간장", "된장", "고추장", "기름", "설탕", "소금", "식초", "소스", "육수", "당면", "파스타"]

        if vegetables.contains(where: name.contains) { return "채소" }
        if proteins.contains(where: name.contains) { return "단백질 · 유제품" }
        if grains.contains(where: name.contains) { return "곡물 · 양념" }
        return "기타"
    }
}

private struct BudgetMetric: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .figmaText(10, .medium)
                .foregroundStyle(PlanPalette.rowValue)
                .lineLimit(2)
            Text(value)
                .figmaText(14, .bold)
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
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
                    .figmaText(14, .bold)
                    .foregroundStyle(PlanPalette.listName)
                Spacer()
                if let knownCost = line.knownCost {
                    Text(won(knownCost))
                        .figmaText(14, .bold)
                        .foregroundStyle(Color.oneLogOrange)
                } else if line.shoppingItem.precision == .manual {
                    StatusPill(text: "판매 단위 확인 필요", tint: .oneLogOrange)
                } else if line.shoppingItem.purchaseQuantity == 0 {
                    StatusPill(text: "추가 구매 없음", tint: .oneLogSuccess)
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
            .figmaText(11)
            .foregroundStyle(PlanPalette.listMuted)
            if let note = line.shoppingItem.note {
                Text(note)
                    .figmaText(10)
                    .foregroundStyle(Color.oneLogOrange)
            }
            if line.avoidedPackageCount > 0, let price = line.price {
                Text("보유 재료로 \(line.avoidedPackageCount)포장 절약 · \(won(line.avoidedPackageCount * price.price))")
                    .figmaText(10, .bold)
                    .foregroundStyle(Color.oneLogSuccess)
            }
        }
        .padding(.vertical, 6)
    }
}

/// 판매 단위가 확인되지 않은 품목은 가격을 받아도 예산에 반영되지 않는다.
/// 그래서 판매 단위 확인 → 그 포장의 가격 순서로만 입력을 받는다.
private struct PriceEditorRow: View {
    @EnvironmentObject private var store: AppStore
    let item: ShoppingPlanItem
    let existingPrice: IngredientPrice?
    @State private var priceText = ""
    @State private var packageText = ""

    private var needsPackage: Bool { item.precision == .manual }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if needsPackage {
                HStack(spacing: 8) {
                    Text("판매 단위 확인")
                        .figmaText(11)
                        .foregroundStyle(PlanPalette.listMuted)
                    TextField(formatQuantity(item.packageSize.amount), text: $packageText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 68)
                    Text(item.unit.rawValue)
                        .figmaText(11)
                        .foregroundStyle(PlanPalette.listMuted)
                    Button("단위 적용") {
                        guard let amount = Double(packageText), amount > 0 else { return }
                        store.setPackageOverride(ingredientID: item.ingredientID, package: PackageSize(amount: amount, unit: item.unit, label: "\(formatQuantity(amount))\(item.unit.rawValue) 포장"))
                    }
                    .figmaText(11, .bold)
                    .foregroundStyle(Color.oneLogSuccess)
                    Spacer()
                }
                Text("마트에서 파는 한 포장의 양을 적으면 구매량과 예상 지출을 계산해요.")
                    .figmaText(10)
                    .foregroundStyle(PlanPalette.listMuted)
            } else {
                HStack(spacing: 8) {
                    // 가격은 계산에 쓰는 포장 크기에 그대로 붙인다. 둘이 어긋나면
                    // 저장은 되는데 예산에 반영되지 않아 사용자가 이유를 알 수 없다.
                    Text("\(formatQuantity(item.packageSize.amount, unit: item.unit)) 포장 가격")
                        .figmaText(11)
                        .foregroundStyle(PlanPalette.listMuted)
                    TextField("금액", text: $priceText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 84)
                    Text("원")
                        .figmaText(11)
                        .foregroundStyle(PlanPalette.listMuted)
                    Button("저장") {
                        let price = Int(priceText.replacingOccurrences(of: ",", with: "")) ?? 0
                        store.setPrice(ingredientID: item.ingredientID, price: price, packageAmount: item.packageSize.amount, unit: item.unit)
                    }
                    .figmaText(11, .bold)
                    .foregroundStyle(Color.oneLogSuccess)
                    Spacer()
                }
                if let price = existingPrice, abs(price.packageAmount - item.packageSize.amount) >= 0.000001 || price.unit != item.unit {
                    Text("저장된 가격이 \(formatQuantity(price.packageAmount, unit: price.unit)) 기준이라 지금 포장에는 쓰지 않았어요. 다시 저장해 주세요.")
                        .figmaText(10)
                        .foregroundStyle(Color.oneLogOrange)
                }
            }
        }
        .onAppear {
            priceText = existingPrice.map { String($0.price) } ?? ""
            packageText = formatQuantity(item.packageSize.amount)
        }
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
                            Text(recipe.title).figmaText(14, .bold).foregroundStyle(PlanPalette.ink)
                            Text("\(recipe.cookTimeText) · \(recipe.description)").figmaText(11).foregroundStyle(PlanPalette.listMuted).lineLimit(2)
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

/// 피그마 `식단 만들기 11 / 계란 구매 단위 선택`(430:23).
/// 대표 판매 단위와 `부족분만 딱 채우는 단위`를 나란히 놓고 고른다.
/// 가격은 확인된 값이 있을 때만 총액·개당 단가를 보여준다(AGENTS 8절).
private struct PurchaseUnitPicker: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let item: ShoppingPlanItem

    private var price: IngredientPrice? {
        guard let price = store.state.prices[item.ingredientID], price.unit == item.unit else { return nil }
        return price
    }

    /// 대표 단위: 시안의 `추천 구매 단위 · 장기 절약`.
    private var recommended: (amount: Double, count: Int, remaining: Double) {
        let amount = item.packageSize.amount
        let count = max(item.purchaseQuantity, item.additionalNeeded > 0 ? 1 : 0)
        let remaining = max(item.availableQuantity ?? 0 + Double(count) * amount - item.quantity, 0)
        return (amount, count, remaining)
    }

    /// 부족분만 채우는 단위: 시안의 `예산 우선`.
    private var budgetFirst: (amount: Double, count: Int, remaining: Double)? {
        guard item.additionalNeeded > 0 else { return nil }
        let amount = (item.additionalNeeded * 10).rounded(.up) / 10
        guard amount > 0, abs(amount - item.packageSize.amount) > 0.000001 else { return nil }
        return (amount, 1, 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 0) {
                            Text("이번 식단 필요량 ")
                                .figmaText(13, .medium)
                                .foregroundStyle(PlanPalette.headerBody)
                            Text(formatQuantity(item.quantity, unit: item.unit))
                                .figmaText(15, .bold)
                                .foregroundStyle(PlanPalette.listMuted)
                        }
                        Text("\(item.ingredientName)을(를) 어떤 단위로 살까요?")
                            .figmaText(16, .bold, lineHeight: 22)
                            .foregroundStyle(PlanPalette.ink)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PlanPalette.listHeaderFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    unitCard(
                        caption: "추천 구매 단위 · 장기 절약",
                        title: "\(item.ingredientName) \(formatQuantity(recommended.amount, unit: item.unit)) \(recommended.count)개",
                        detail: detailText(recommended),
                        priceText: priceText(recommended),
                        buttonTitle: "이 단위로 두기 ✓",
                        isPrimary: true
                    ) {
                        store.setPackageOverride(
                            ingredientID: item.ingredientID,
                            package: PackageSize(amount: recommended.amount, unit: item.unit, label: item.packageSize.label)
                        )
                        dismiss()
                    }

                    if let budgetFirst {
                        unitCard(
                            caption: "예산 우선 · 남는 양 없음",
                            title: "\(item.ingredientName) \(formatQuantity(budgetFirst.amount, unit: item.unit)) 1개",
                            detail: detailText(budgetFirst),
                            priceText: priceText(budgetFirst),
                            buttonTitle: "\(formatQuantity(budgetFirst.amount, unit: item.unit))로 변경",
                            isPrimary: false
                        ) {
                            store.setPackageOverride(
                                ingredientID: item.ingredientID,
                                package: PackageSize(amount: budgetFirst.amount, unit: item.unit, label: "\(formatQuantity(budgetFirst.amount))\(item.unit.rawValue) 포장")
                            )
                            dismiss()
                        }
                    }

                    if let unitPrice = unitPriceText() {
                        Text(unitPrice)
                            .figmaText(12, .medium)
                            .foregroundStyle(PlanPalette.listMuted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(PlanPalette.canvas)
            .navigationTitle("구매 단위 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
        }
    }

    private func detailText(_ option: (amount: Double, count: Int, remaining: Double)) -> String {
        let have = item.availableQuantity ?? 0
        let havePart = have > 0 ? "보유 \(formatQuantity(have, unit: item.unit)) + " : ""
        let remaining = option.remaining > 0 ? "\(formatQuantity(option.remaining, unit: item.unit)) 남음" : "남는 양 없음"
        return "\(havePart)구매 \(formatQuantity(Double(option.count) * option.amount, unit: item.unit)) · \(remaining)"
    }

    private func priceText(_ option: (amount: Double, count: Int, remaining: Double)) -> String {
        guard let price, abs(price.packageAmount - option.amount) < 0.000001 else { return "가격 확인 전" }
        return won(price.price * option.count)
    }

    private func unitPriceText() -> String? {
        guard let price, price.packageAmount > 0 else { return nil }
        let perUnit = Int((Double(price.price) / price.packageAmount).rounded())
        return "\(formatQuantity(price.packageAmount, unit: item.unit)) 기준 \(item.unit.rawValue)당 약 \(won(perUnit))이에요."
    }

    private func unitCard(
        caption: String,
        title: String,
        detail: String,
        priceText: String,
        buttonTitle: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(caption)
                .figmaText(12, .medium)
                .foregroundStyle(PlanPalette.listMuted)
            Text(title)
                .figmaText(13, .medium)
                .foregroundStyle(PlanPalette.listMuted)

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(isPrimary ? "✓" : "↔")
                        .figmaText(14, .bold)
                        .foregroundStyle(PlanPalette.yellow)
                    Text(detail)
                        .figmaText(15, .bold)
                        .foregroundStyle(PlanPalette.ink)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(priceText)
                    .figmaText(12, .bold)
                    .foregroundStyle(PlanPalette.listName)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(PlanPalette.badgeFill, in: Capsule())
            }

            Button(action: action) {
                Text(buttonTitle)
                    .figmaText(13, .bold)
                    .foregroundStyle(isPrimary ? Color(hex: 0xF5F5F5) : PlanPalette.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(isPrimary ? PlanPalette.ink : .white, in: Capsule())
                    .overlay {
                        if !isPrimary { Capsule().strokeBorder(PlanPalette.cardBorderStrong, lineWidth: 1) }
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isPrimary ? PlanPalette.yellow : PlanPalette.cardBorderStrong, lineWidth: isPrimary ? 1.5 : 1)
        }
    }
}
