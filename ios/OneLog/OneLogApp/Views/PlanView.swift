import SwiftUI

/// F13·F20·F21 식단 만들기. 피그마 `식단 만들기 1~8`(350:1551, 350:1586, 350:1645, 350:1690,
/// 350:1729, 350:1779, 350:1832, 438:23)을 좌표 그대로 옮긴다. 시안 프레임은 393x852이고
/// 상태바 아래 34pt를 기준으로 헤더 42 / 프로그레스 94 / 본문 116 / 푸터 772에 놓인다.
///
struct PlanView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var step = 1
    @State private var startDate = Date()
    @State private var calendarMonth = Date()
    @State private var showingDurationSheet = false
    @State private var isGeneratingOptions = false
    @State private var previewCheckedIngredientIDs: Set<String> = []
    @State private var days = 5
    @State private var targetBudget = "30000"
    @State private var selectedSlots: Set<PlanSlotKey> = []
    @State private var options: [MealPlanOption] = []
    @State private var selectedOptionID: String?
    @State private var optionBeingEditedID: String?
    @State private var swappingDraft: PlannedMealDraft?
    @State private var validationMessage: String?
    @State private var showingAIChat = false
    /// 실제 흐름은 기간부터 업그레이드까지 11단계다.
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

    private var koreanCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
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
        .sheet(item: $swappingDraft) { draft in
            RecipeSwapView(draft: draft, preferences: store.state.preferences) { recipe in
                replaceDraft(draft.id, with: recipe.id)
                swappingDraft = nil
            }
        }
        .fullScreenCover(isPresented: $showingAIChat) {
            AIPlanChatView(
                summary: aiChatSummary,
                contextProvider: { message in aiChatContext(for: message) },
                onApply: applyAIRecipe
            )
            .environmentObject(store)
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
            case 9: inventoryStep
            case 10: priceStep
            case 11: shoppingListStep
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

    // MARK: - 1 / 기간 (719:730)

    private var durationStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlanIntroCard(
                step: 1,
                title: "며칠 동안 준비할까요?",
                titleSize: 21,
                subtitle: "시작일과 기간(최대 7일)을 골라 주세요.",
                textWidth: 200,
                mascot: PlanMascot(name: "PlanMascotDuration", x: 232.44, y: 16, width: 115.12, height: 102.89, scaleX: 1.6293, scaleY: 1.3404, offsetRatioX: -0.3017)
            )

            durationCalendarCard
                .padding(.top, 22)

            Text("시작일과 기간(최대 7일)을 골라 주세요.")
                .figmaText(11)
                .foregroundStyle(PlanPalette.caption)
                .padding(.top, 15)
        }
        .frame(width: PlanPalette.contentWidth, alignment: .topLeading)
    }

    /// 시안 `Duration / Calendar Card`(719:754). 시작일 원(#FFC914) + 이어지는 일수(#FFEDB8)로 범위를 보여준다.
    private var durationCalendarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("기간")
                    .figmaText(14, .bold)
                    .foregroundStyle(PlanPalette.ink)

                Button {
                    showingDurationSheet = true
                } label: {
                    HStack {
                        Text("\(days)일")
                            .figmaText(15, .medium)
                            .foregroundStyle(PlanPalette.ink)
                        Spacer(minLength: 8)
                        Text("⌄")
                            .figmaText(16, .medium)
                            .foregroundStyle(PlanPalette.subtle)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(PlanPalette.inputFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("plan.duration")
                .sheet(isPresented: $showingDurationSheet) {
                    DurationPickerSheet(days: $days)
                        .presentationDetents([.height(324)])
                        .presentationDragIndicator(.hidden)
                }
            }

            Rectangle().fill(PlanPalette.cardBorderStrong).frame(height: 1)

            HStack {
                Button {
                    calendarMonth = koreanCalendar.date(byAdding: .month, value: -1, to: calendarMonth) ?? calendarMonth
                } label: {
                    Text("‹").figmaText(18, .bold).foregroundStyle(PlanPalette.subtle)
                }
                .accessibilityLabel("이전 달")
                Spacer()
                Text(monthTitle)
                    .figmaText(15, .bold)
                    .foregroundStyle(PlanPalette.ink)
                Spacer()
                Button {
                    calendarMonth = koreanCalendar.date(byAdding: .month, value: 1, to: calendarMonth) ?? calendarMonth
                } label: {
                    Text("›").figmaText(18, .bold).foregroundStyle(PlanPalette.subtle)
                }
                .accessibilityLabel("다음 달")
            }

            DurationCalendarGrid(month: calendarMonth, startDate: startDate, days: days) { picked in
                startDate = picked
            }

            HStack(spacing: 6) {
                Text(rangeSummaryText)
                    .figmaText(13, .bold)
                    .foregroundStyle(Color(hex: 0x2B2418))
                Spacer(minLength: 8)
                Text(rangeEndShortText)
                    .figmaText(12, .medium)
                    .foregroundStyle(PlanPalette.subtle)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(hex: 0xFFF4C9), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.horizontal, 18)
        .padding(.top, 32) // 719:755
        .padding(.bottom, 18)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(PlanPalette.cardBorder, lineWidth: 1)
        }
        .onAppear { calendarMonth = startDate }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = koreanCalendar
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: calendarMonth)
    }

    private var rangeSummaryText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = koreanCalendar
        formatter.dateFormat = "M월 d일(E)부터"
        return "\(formatter.string(from: startDate)) \(days)일간"
    }

    private var rangeEndShortText: String {
        guard let end = koreanCalendar.date(byAdding: .day, value: days - 1, to: startDate) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = koreanCalendar
        formatter.dateFormat = "~ M.d"
        return formatter.string(from: end)
    }

    // MARK: - 2 / 끼니 (350:1586)

    private var mealsStep: some View {
        // 719:603은 5일 기준 카드 310. 1일차 줄이 64에서 시작하고 한 줄 44, 아래 여백 26이다.
        let rowsHeight = 44 * CGFloat(days)
        let cardHeight = 64 + rowsHeight + 26

        return ZStack(alignment: .topLeading) {
            PlanIntroCard(
                step: 2,
                title: "몇 끼 드실 거예요?",
                titleSize: 21,
                subtitle: "일차마다 아침·점심·저녁을 선택해 주세요.",
                textWidth: 195,
                mascot: PlanMascot(name: "PlanMascotMeals", x: 236, y: 23, width: 91, height: 93, scaleX: 1.0083, scaleY: 1.2796, offsetRatioX: -0.0041)
            )

            PlanWhiteCard(height: cardHeight, radius: 18) {
                Text("일차별 끼니")
                    .figmaText(13, .bold)
                    .foregroundStyle(PlanPalette.cardTitle)
                    .offset(x: 18, y: 16)

                ForEach(Array(MealSlot.allCases.enumerated()), id: \.element) { index, slot in
                    Text(slot.rawValue)
                        .figmaText(10, .medium)
                        .foregroundStyle(PlanPalette.subtle)
                        .offset(x: 132 + CGFloat(index) * 70, y: 43)
                }

                ForEach(Array(dates.enumerated()), id: \.element) { index, date in
                    let top = 64 + CGFloat(index) * 44

                    Text("\(index + 1)일차")
                        .figmaText(12, .medium)
                        .foregroundStyle(PlanPalette.cardLabel)
                        .offset(x: 18, y: top + 12)

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
                        .offset(x: 128 + CGFloat(column) * 70, y: top + 8)
                    }

                    if index < days - 1 {
                        Rectangle()
                            .fill(PlanPalette.rowDivider)
                            .frame(width: 317, height: 1)
                            .offset(x: 18, y: top + 44)
                    }
                }
            }
            .offset(y: 119) // 719:603

            Text(slotSummaryText)
                .figmaText(10)
                .foregroundStyle(PlanPalette.caption)
                .offset(x: 4, y: 119 + cardHeight + 12) // 719:633 y441
        }
        .frame(width: PlanPalette.contentWidth, height: 119 + cardHeight + 37, alignment: .topLeading)
    }

    private var slotSummaryText: String {
        let counts = MealSlot.allCases.map { slot in
            selectedSlots.filter { $0.slot == slot }.count
        }
        return "아침 \(counts[0])회 · 점심 \(counts[1])회 · 저녁 \(counts[2])회로 선택했어요."
    }

    // MARK: - 3 / 예산 (719:638)

    private var budgetStep: some View {
        ZStack(alignment: .topLeading) {
            // 719:655 `Budget / Intro`는 본문 y14에서 시작한다(문구는 y42).
            PlanIntroCard(
                step: 3,
                title: "장보기를 알려주세요",
                titleSize: 21,
                subtitle: "장보기 예산에 맞춰 식단을 구성해줄게요.",
                textWidth: 218,
                mascot: PlanMascot(name: "PlanMascotBudget", x: 219, y: 8, width: 140, height: 101, scaleX: 1, scaleY: 1.3913, offsetRatioX: 0)
            )
            .offset(y: 14)

            PlanWhiteCard(height: 118, radius: 18) {
                Text("전체 예산")
                    .figmaText(12, .bold)
                    .foregroundStyle(PlanPalette.cardLabel)
                    .offset(x: 18, y: 16)

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
                        .offset(x: 16, y: 11)
                    Text("원")
                        .figmaText(13, .medium)
                        .foregroundStyle(PlanPalette.subtle)
                        .offset(x: 280, y: 17)
                }
                .frame(width: 317, height: 54, alignment: .topLeading)
                .offset(x: 18, y: 46)
            }
            .offset(y: 123) // 719:661

            Text("빠른 선택")
                .figmaText(11, .bold)
                .foregroundStyle(PlanPalette.quickLabel)
                .offset(x: 3.5, y: 258.73) // 719:666

            // 719:667~671. x는 -0.5 / 97 / 197.5, 폭도 86 / 86 / 85로 다르다.
            // 시안은 칸 이름이 3만원·2만원·4만원 순으로 뒤섞여 있어 금액은 오름차순으로 둔다.
            ForEach(Array(PlanPalette.budgetPresets.enumerated()), id: \.offset) { index, preset in
                let geometry: (x: CGFloat, width: CGFloat) = [(-0.5, 86), (97, 86), (197.5, 85)][index]
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
                .offset(x: geometry.x, y: 283.73)
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

    // MARK: - 4 / 분석 (713:1880)

    /// 개정 시안은 마스코트(54.12) → 문구(202.41 / 264.41) → 반영 카드(326) 순서다. 후광 이미지는 빠졌다.
    private var analyzingStep: some View {
        ZStack(alignment: .topLeading) {
            Image("PlanMascotAnalyzing")
                .resizable()
                .scaledToFit()
                .frame(width: 128.98, height: 135.801)
                .offset(x: 112, y: 54.116)

            Text("취향에 맞는 식단을\n조합하고 있어요")
                .figmaText(22, .bold, lineHeight: 24) // 713:1897 h48(2줄)
                .multilineTextAlignment(.center)
                .foregroundStyle(PlanPalette.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 250)
                .offset(x: 52, y: 202.41)

            HStack(spacing: 7) {
                if isGeneratingOptions {
                    ProgressView()
                        .controlSize(.small)
                        .tint(PlanPalette.rowIcon)
                        .accessibilityLabel("식단 계산 중")
                }
                Text(isGeneratingOptions ? "찜한 레시피와 선택한 조건을 함께 분석해요." : "분석을 마쳤어요. 식단안을 확인해 주세요.")
                    .figmaText(11)
                    .foregroundStyle(PlanPalette.subtle)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 250)
            .offset(x: 52, y: 264.41)

            PlanWhiteCard(height: 190, radius: 20) {
                Text("이렇게 반영하고 있어요")
                    .figmaText(13, .bold)
                    .foregroundStyle(PlanPalette.cardTitle)
                    .offset(x: 18, y: 16)

                ForEach(Array(analysisRows.enumerated()), id: \.offset) { index, row in
                    let top = 52 + CGFloat(index) * 43
                    Image(systemName: row.symbol)
                        .font(.figma(19))
                        .foregroundStyle(PlanPalette.rowIcon)
                        .frame(width: 19, height: 23)
                        .offset(x: 18, y: top)
                    Text(row.title)
                        .figmaText(11, .bold)
                        .foregroundStyle(PlanPalette.rowTitle)
                        .offset(x: 50, y: top + 5)
                    Text(row.value)
                        .figmaText(9)
                        .foregroundStyle(PlanPalette.rowValue)
                        .offset(x: 205, y: top + 9)
                }
            }
            .offset(x: 4, y: 326) // 713:1900
        }
        .frame(width: PlanPalette.contentWidth, height: 516, alignment: .topLeading)
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

    // MARK: - 5 / 식단안 선택 (719:682)

    /// 719:699 인트로는 배경 없이 STEP 5 · 제목 · 도움말과 마스코트만 둔다(본문 y18에서 시작).
    private var optionsStep: some View {
        ZStack(alignment: .topLeading) {
            Group {
                Image("PlanMascotOptions")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 95.016, height: 88.55)
                    .offset(x: 247.23, y: 3.45)

                Text("STEP 5")
                    .figmaText(10, .bold)
                    .foregroundStyle(PlanPalette.stepLabel)
                    .offset(x: 21, y: 13)

                Text("식단안 \(options.count)개를 만들었어요")
                    .figmaText(21, .bold)
                    .foregroundStyle(PlanPalette.ink)
                    .frame(width: 218, alignment: .leading)
                    .offset(x: 19, y: 33)

                Text("예산과 재료 활용 방식이 조금씩 달라요.")
                    .figmaText(11)
                    .foregroundStyle(PlanPalette.introBody)
                    .offset(x: 21, y: 66)
            }
            .offset(y: 18)

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
        let chatEntryY = 142 + cardHeight + 70

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

            PlanAIChatEntry {
                showingAIChat = true
            }
            .offset(y: chatEntryY)
        }
        .frame(width: PlanPalette.contentWidth, height: chatEntryY + 78, alignment: .topLeading)
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

    private var aiChatSummary: AIChatPlanSummary {
        let mealCount = selectedOption?.drafts.count ?? 0
        let start = dates.first.map(displayDate) ?? displayDate(isoDateString())
        return AIChatPlanSummary(
            title: selectedOption?.title ?? "내 식단",
            subtitle: "\(days)일 식단 · 총 \(mealCount)끼 · 시작 \(start)"
        )
    }

    private func aiChatContext(for message: String) -> AIChatPlanContext {
        let drafts = selectedOption?.drafts ?? []
        let planMeals = drafts.compactMap { draft -> AIChatMealContext? in
            guard let recipe = recipe(for: draft.recipeID) else { return nil }
            return AIChatMealContext(date: draft.date, slot: draft.mealSlot, recipeID: recipe.id, title: recipe.title)
        }
        let candidates = aiCandidateRecipes(
            for: message,
            drafts: drafts,
            preferences: store.state.preferences,
            favorites: Set(store.state.favorites)
        )
        let inventory = store.state.inventory.map { item in
            AIChatInventoryContext(
                name: ingredient(for: item.ingredientID)?.name ?? item.ingredientID,
                quantity: item.quantityStatus == .exact ? formatQuantity(item.quantity) : "수량 미상",
                unit: item.unit.rawValue
            )
        }
        return AIChatPlanContext(
            title: selectedOption?.title ?? "내 식단",
            startDate: dates.first ?? isoDateString(startDate),
            days: days,
            targetBudget: budgetValue,
            meals: planMeals,
            dislikedIngredients: store.dislikedIngredientNames.sorted(),
            allergyIngredients: store.allergyIngredientNames.sorted(),
            availableTools: store.state.preferences.availableTools.map(\.rawValue).sorted(),
            inventory: inventory,
            candidateRecipes: candidates.map { AIChatRecipeContext(recipe: $0) }
        )
    }

    @discardableResult
    private func applyAIRecipe(_ suggestion: AIRecipeSuggestion) -> Bool {
        guard let editingOptionID = selectedOptionID,
              var option = options.first(where: { $0.id == editingOptionID }),
              let recipe = recipe(for: suggestion.recipeID),
              let slot = suggestion.targetSlot else {
            validationMessage = "AI가 제안한 메뉴를 식단에 적용하지 못했어요."
            return false
        }

        let suggestedDate = dates.contains(suggestion.targetDate)
            ? suggestion.targetDate
            : option.drafts.first?.date ?? dates.first ?? isoDateString(startDate)

        // AI가 저녁 전용 메뉴를 아침 칸에 제안하는 일이 있다. 그때마다 실패로 끝내면
        // 제안 카드가 눌리기만 하고 아무 일도 안 난다. 그 메뉴를 넣을 수 있는 칸이
        // 식단 안에 있으면 그리로 옮겨 담는다.
        let target: (date: String, slot: MealSlot)
        if recipe.mealSlots.contains(slot) {
            target = (suggestedDate, slot)
        } else if let fallback = option.drafts.first(where: { recipe.mealSlots.contains($0.mealSlot) }) {
            target = (fallback.date, fallback.mealSlot)
        } else {
            validationMessage = "이 레시피는 지금 식단의 어느 끼니에도 넣을 수 없어요."
            return false
        }
        let targetDate = target.date
        let targetSlot = target.slot

        let newDraft = PlannedMealDraft(
            recipeID: recipe.id,
            date: targetDate,
            mealSlot: targetSlot,
            reason: "AI 채팅에서 선택한 메뉴예요.",
            reusedIngredientIDs: [],
            newPurchaseCount: 0
        )
        if let index = option.drafts.firstIndex(where: { $0.date == targetDate && $0.mealSlot == targetSlot }) {
            guard suggestion.action != "add" else {
                validationMessage = "그 날짜와 끼니에는 이미 메뉴가 있어요. 변경으로 적용해 주세요."
                return false
            }
            option.drafts[index] = newDraft
        } else {
            option.drafts.append(newDraft)
        }

        let updated = recomputePlanOption(option, request: makeRequest())
        options = options.map { $0.id == editingOptionID ? updated : $0 }
        selectedOptionID = editingOptionID
        validationMessage = nil
        return true
    }

    // MARK: - 7 / 최종 확인 (713:2036)

    private var finalStep: some View {
        ZStack(alignment: .topLeading) {
            Image("PlanMascotFinal")
                .resizable()
                .scaledToFit()
                .frame(width: 201.236, height: 93.018)
                .offset(x: 76, y: 33)

            Text("이 식단으로 확정할까요?")
                .figmaText(20, .bold)
                .foregroundStyle(PlanPalette.ink)
                .frame(width: PlanPalette.contentWidth)
                .offset(y: 138)

            Text("남는 재료를 돌려 쓰는 \(days)일 식단이에요.")
                .figmaText(10)
                .foregroundStyle(PlanPalette.introBody)
                .frame(width: PlanPalette.contentWidth)
                .offset(y: 168)

            PlanWhiteCard(height: 174, radius: 20) {
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
        .frame(width: PlanPalette.contentWidth, height: 368, alignment: .topLeading)
    }

    private var finalRows: [(symbol: String, label: String, value: String)] {
        let counts = MealSlot.allCases.map { slot in (selectedOption?.drafts ?? []).filter { $0.mealSlot == slot }.count }
        return [
            ("calendar", "식단 기간", "\(days)일"),
            ("fork.knife", "선택 끼니", "아침 \(counts[0]) · 점심 \(counts[1]) · 저녁 \(counts[2])"),
            ("banknote", "전체 예산", won(budgetValue)),
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

    // MARK: - 9 / 보유 재료 확인 (713:2492)

    /// 체크·수량 입력을 실제 냉장고 재고(`store.state.inventory`)에 바로 쓴다. 다음 단계의 예산 계산은
    /// `AppStore.estimate`가 같은 재고를 읽어서 자동으로 반영한다 — 이 화면만의 임시 상태를 따로 두지 않는다.
    private var inventoryStep: some View {
        let items = planShoppingItems
        let groups = PlanIngredientGroup.grouped(items)

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("보유한 재료를 확인해 주세요")
                    .figmaText(16, .bold, lineHeight: 22)
                    .foregroundStyle(PlanPalette.ink)
                Text("체크한 재료는 보유량을 입력해요.")
                    .figmaText(12, .medium, lineHeight: 18)
                    .foregroundStyle(PlanPalette.headerBody)
            }
            .padding(16)
            .frame(width: PlanPalette.contentWidth, alignment: .leading)
            .background(PlanPalette.listHeaderFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 0) {
                    Text(group.title)
                        .figmaText(14, .bold)
                        .foregroundStyle(PlanPalette.ink)
                        .padding(.bottom, 6)

                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                        InventoryCheckRow(item: item, owned: ownedQuantity(for: item)) { quantity in
                            if let quantity {
                                store.setInventory(ingredientID: item.ingredientID, quantity: quantity, unit: item.unit, status: .exact)
                            } else if let existing = store.state.inventory.first(where: { $0.ingredientID == item.ingredientID && $0.unit == item.unit }) {
                                store.removeInventory(existing)
                            }
                        }
                        .padding(.vertical, 10)

                        if index < group.items.count - 1 {
                            Rectangle().fill(PlanPalette.listDivider).frame(height: 1)
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
        }
        .frame(width: PlanPalette.contentWidth, alignment: .leading)
    }

    private func ownedQuantity(for item: ShoppingPlanItem) -> Double? {
        store.state.inventory.first { $0.ingredientID == item.ingredientID && $0.unit == item.unit }?.quantity
    }

    // MARK: - 10 / 구매 재료·가격 (713:2088)

    @ViewBuilder private var priceStep: some View {
        if let option = selectedOption {
            let estimate = store.estimate(for: option.drafts, targetBudget: budgetValue)
            let purchaseLines = estimate.lineItems.filter { $0.shoppingItem.purchaseQuantity > 0 }
            let reusedCount = estimate.lineItems.filter { $0.avoidedPackageCount > 0 || $0.shoppingItem.purchaseQuantity == 0 }.count

            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(PlanPalette.listHeaderFill)
                        .frame(width: PlanPalette.contentWidth, height: 72)

                    Text("보유 재료 덕분에")
                        .figmaText(13, .medium)
                        .foregroundStyle(PlanPalette.headerBody)
                        .offset(x: 20, y: 16.5)
                    Text("\(reusedCount)개 재료를 활용했어요")
                        .figmaText(16, .bold)
                        .foregroundStyle(PlanPalette.ink)
                        .offset(x: 20, y: 36.5)

                    Image("PlanCareMascot")
                        .resizable()
                        .frame(width: 136.381, height: 136.381)
                        .frame(width: 136.381, height: 66.641, alignment: .top)
                        .clipped()
                        .offset(x: 203.93, y: 5.36)
                        .accessibilityHidden(true)
                }
                .frame(width: PlanPalette.contentWidth, height: 72, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("사야 할 재료")
                            .figmaText(14, .bold)
                            .foregroundStyle(PlanPalette.ink)
                        Spacer()
                        Text("\(purchaseLines.count)개")
                            .figmaText(12, .medium)
                            .foregroundStyle(PlanPalette.listMuted)
                    }
                    .frame(height: 35)

                    Rectangle().fill(PlanPalette.listDivider).frame(height: 1)

                    ForEach(Array(purchaseLines.enumerated()), id: \.element.id) { index, line in
                        HStack(spacing: 10) {
                            Text(line.shoppingItem.ingredientName)
                                .figmaText(15, .medium)
                                .foregroundStyle(PlanPalette.listName)
                            Text(purchasePackageText(for: line.shoppingItem))
                                .figmaText(12)
                                .foregroundStyle(PlanPalette.listMuted)
                            Spacer(minLength: 8)
                            Text(won(line.knownCost ?? 0))
                                .figmaText(14, .bold)
                                .foregroundStyle(PlanPalette.ink)
                        }
                        .frame(height: 38)
                        Rectangle().fill(PlanPalette.listDivider).frame(height: 1)
                    }

                    HStack {
                        Text("구매 예상")
                            .figmaText(14, .bold)
                        Spacer()
                        Text(won(estimate.knownPurchaseCost))
                            .figmaText(16, .bold)
                    }
                    .foregroundStyle(PlanPalette.ink)
                    .frame(height: 58)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .frame(width: PlanPalette.contentWidth, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(PlanPalette.cardBorderStrong, lineWidth: 1) }

                HStack {
                    Text("계획 예산 \(won(estimate.targetBudget))")
                        .figmaText(12, .medium)
                        .foregroundStyle(PlanPalette.listMuted)
                    Spacer()
                    Text(estimate.remainingBudget.map { "잔여 \(won($0))" } ?? "잔여 미확정")
                        .figmaText(12, .bold)
                        .foregroundStyle(PlanPalette.headerBody)
                }
                .padding(.horizontal, 4)
            }
            .frame(width: PlanPalette.contentWidth, alignment: .leading)
        } else {
            EmptyState(symbol: "calendar.badge.exclamationmark", title: "식단안을 먼저 골라 주세요", message: "이전 단계에서 제안받은 식단안을 선택해 주세요.")
        }
    }

    // MARK: - 11 / 최종 장보기 목록 (713:2162)

    @ViewBuilder private var shoppingListStep: some View {
        if let option = selectedOption {
            let estimate = store.estimate(for: option.drafts, targetBudget: budgetValue)
            let lines = estimate.lineItems.filter { $0.shoppingItem.purchaseQuantity > 0 }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("장보기 리스트가 완성됐어요")
                        .figmaText(16, .bold, lineHeight: 22)
                        .foregroundStyle(PlanPalette.ink)
                    Text("현재 식단의 \(lines.count)개 구매 재료를 판매 단위로 담았어요.")
                        .figmaText(12, .medium, lineHeight: 18)
                        .foregroundStyle(PlanPalette.headerBody)
                }
                .padding(16)
                .frame(width: PlanPalette.contentWidth, alignment: .leading)
                .background(PlanPalette.listHeaderFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        let item = line.shoppingItem
                        Button {
                            if previewCheckedIngredientIDs.contains(item.ingredientID) {
                                previewCheckedIngredientIDs.remove(item.ingredientID)
                            } else {
                                previewCheckedIngredientIDs.insert(item.ingredientID)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(.white)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .strokeBorder(
                                                    previewCheckedIngredientIDs.contains(item.ingredientID) ? PlanPalette.yellow : PlanPalette.cardBorderStrong,
                                                    lineWidth: 1.5
                                                )
                                        }
                                    if previewCheckedIngredientIDs.contains(item.ingredientID) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(PlanPalette.rowIcon)
                                    }
                                }
                                .frame(width: 22, height: 22)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text(item.ingredientName)
                                            .figmaText(15, .bold)
                                            .foregroundStyle(PlanPalette.ink)
                                        Text("\(formatQuantity(item.quantity, unit: item.unit)) 필요")
                                            .figmaText(12)
                                            .foregroundStyle(PlanPalette.listMuted)
                                    }
                                    HStack(spacing: 6) {
                                        Text("구매 \(purchasePackageText(for: item))")
                                            .figmaText(12, .medium)
                                            .foregroundStyle(PlanPalette.headerBody)
                                        if let badge = shoppingBadgeText(for: item) {
                                            Text(badge)
                                                .figmaText(10, .bold)
                                                .foregroundStyle(PlanPalette.listName)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(PlanPalette.badgeFill, in: Capsule())
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 62)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("plan.shopping.\(item.ingredientID)")
                        if index < lines.count - 1 {
                            Rectangle().fill(PlanPalette.listDivider).frame(height: 1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .frame(width: PlanPalette.contentWidth, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(PlanPalette.cardBorderStrong, lineWidth: 1) }

                if !leftoverIngredientNames(in: lines).isEmpty {
                    Text("남은 \(leftoverIngredientNames(in: lines).joined(separator: "과 "))은 다음 식단에 이어서 활용해요.")
                        .figmaText(12, .medium)
                        .foregroundStyle(PlanPalette.listMuted)
                        .frame(width: PlanPalette.contentWidth, alignment: .leading)
                }
            }
            .frame(width: PlanPalette.contentWidth, alignment: .leading)
        } else {
            EmptyState(symbol: "calendar.badge.exclamationmark", title: "식단안을 먼저 골라 주세요", message: "이전 단계에서 제안받은 식단안을 선택해 주세요.")
        }
    }

    private func purchasePackageText(for item: ShoppingPlanItem) -> String {
        let label = item.packageSize.label
            .replacingOccurrences(of: item.ingredientName, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let unitText = label.isEmpty ? formatQuantity(item.packageSize.amount, unit: item.packageSize.unit) : label
        return item.purchaseQuantity > 1 ? "\(unitText) × \(item.purchaseQuantity)" : unitText
    }

    private func shoppingBadgeText(for item: ShoppingPlanItem) -> String? {
        let needed = max(item.quantity - (item.availableQuantity ?? 0), 0)
        let purchased = Double(item.purchaseQuantity) * item.packageSize.amount
        let remainder = max(purchased - needed, 0)
        guard remainder >= 0.000_001 else { return nil }
        if item.ingredientName.contains("식빵") { return "남은 빵 냉동" }
        return "\(formatQuantity(remainder, unit: item.unit)) 남아요"
    }

    private func leftoverIngredientNames(in lines: [BudgetLineItem]) -> [String] {
        lines.compactMap { line in
            shoppingBadgeText(for: line.shoppingItem) == nil ? nil : line.shoppingItem.ingredientName
        }
    }

    // MARK: - 푸터 버튼

    private var cta: PlanFlowCTA {
        switch step {
        case 4:
            return PlanFlowCTA(
                title: isGeneratingOptions ? "계산 중…" : "식단안 보기",
                style: .yellow,
                isEnabled: !isGeneratingOptions && !options.isEmpty
            ) { step = 5 }
        case 5:
            return PlanFlowCTA(title: "이 식단 선택", style: .dark, isEnabled: selectedOptionID != nil) { step = 6 }
        case 7:
            return PlanFlowCTA(title: "이 식단으로 확정", style: .yellow, isEnabled: selectedOption != nil, action: confirmPlan)
        case 11...:
            return PlanFlowCTA(title: "확인", style: .dark, isEnabled: true, action: finishFlow)
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
        if step == 3 {
            step = 4
            generateOptions()
        } else {
            step += 1
        }
    }

    private func confirmPlan() {
        guard selectedOption != nil else { return }
        // 최종 확인 뒤에도 실제 식단 반영은 마지막 `확인`에서 한 번만 한다.
        step = 8
    }

    private func finishFlow() {
        guard let option = selectedOption else {
            validationMessage = "식단안을 먼저 선택해 주세요."
            return
        }
        store.applyPlan(option, targetBudget: budgetValue)
        options = []
        selectedOptionID = nil
        validationMessage = nil
        step = 1
        dismiss()
    }

    private func generateOptions() {
        guard !isGeneratingOptions else { return }
        validationMessage = nil
        let request = makeRequest()
        guard request.slotsByDate.values.contains(where: { !$0.isEmpty }) else {
            validationMessage = "하루 이상 한 끼를 선택해 주세요."
            return
        }
        options = []
        selectedOptionID = nil
        isGeneratingOptions = true

        Task {
            let generated = await Task.detached(priority: .userInitiated) {
                generateMealPlanOptions(request: request)
            }.value
            // 계산이 매우 빨라도 사용자가 로딩 상태를 인지할 수 있는 최소 시간만 확보한다.
            try? await Task.sleep(for: .milliseconds(450))
            guard step == 4 else {
                isGeneratingOptions = false
                return
            }
            isGeneratingOptions = false
            guard !generated.isEmpty, generated.contains(where: { !$0.drafts.isEmpty }) else {
                validationMessage = "조건에 맞는 식단을 만들지 못했어요. 불호 재료나 조리도구 설정을 조금 완화해 보세요."
                return
            }
            options = generated
            selectedOptionID = generated.first?.id
        }
    }

    private func makeRequest() -> PlanRequest {
        var slotsByDate: [String: Set<MealSlot>] = [:]
        for date in dates {
            slotsByDate[date] = Set(MealSlot.allCases.filter { selectedSlots.contains(PlanSlotKey(date: date, slot: $0)) })
        }
        return PlanRequest(
            startDate: isoDateString(startDate),
            days: days,
            slotsByDate: slotsByDate,
            targetBudget: budgetValue,
            favorites: Set(store.state.favorites),
            inventory: store.state.inventory,
            prices: store.ingredientPrices,
            preferences: store.state.preferences,
            packageOverrides: store.state.packageOverrides
        )
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

    /// 719:667~671.
    static let budgetPresets: [(label: String, amount: Int)] = [("2만원", 20000), ("3만원", 30000), ("4만원", 40000)]
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
                // 772:210 — 흰 원에 #E3D9BF 테두리. 연노랑 원은 이전 시안 값이다.
                Button(action: onBack) {
                    Text("‹")
                        .figmaText(25, .medium)
                        .foregroundStyle(PlanPalette.ink)
                        .frame(width: 36, height: 36)
                        .background(.white, in: Circle())
                        .overlay { Circle().strokeBorder(Color(hex: 0xE3D9BF), lineWidth: 1) }
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
            // 719:747 `Duration / Intro`는 배경이 없다. 노란 칸으로 칠하면 시안보다 무거워진다.
            Color.clear
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
            .offset(x: 18, y: 28) // 719:748 / 719:599
        }
        .frame(width: PlanPalette.contentWidth, height: 97, alignment: .topLeading)
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

/// 시안 `식단 기간 선택 / 드롭다운`(713:2072). 선택한 값은 노란 강조 + 체크로 보여준다.
private struct DurationPickerSheet: View {
    @Binding var days: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ForEach(1...7, id: \.self) { value in
                Button {
                    days = value
                    dismiss()
                } label: {
                    HStack {
                        if value == days {
                            Text("✓").figmaText(13, .bold).foregroundStyle(PlanPalette.ink)
                        }
                        Text("\(value)일")
                            .figmaText(15, value == days ? .bold : .medium)
                            .foregroundStyle(PlanPalette.ink)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 44)
                    .background(value == days ? Color(hex: 0xFFF4C9) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("plan.duration.option.\(value)")
            }
        }
        .padding(12)
        .padding(.top, 8)
        .presentationBackground(.white)
    }
}

/// 시안 `Calendar Grid`(719:765). 일요일 시작, 시작일은 원(#FFC914), 이어지는 일수는 이어진 배경(#FFEDB8).
/// ponytail: 범위가 다음 달로 넘어가면 이번 달 칸만 칠한다. 여러 달에 걸친 강조가 필요해지면 그때 확장한다.
private struct DurationCalendarGrid: View {
    let month: Date
    let startDate: Date
    let days: Int
    let onPick: (Date) -> Void

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }

    private var weekdaySymbols: [(text: String, color: Color)] {
        [("일", Color(hex: 0xD95454)), ("월", PlanPalette.subtle), ("화", PlanPalette.subtle),
         ("수", PlanPalette.subtle), ("목", PlanPalette.subtle), ("금", PlanPalette.subtle), ("토", Color(hex: 0x5478CC))]
    }

    /// 월 첫 주 앞의 빈 칸을 포함해, 6주 그리드에 필요한 날짜(또는 nil)를 만든다.
    private var cells: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else { return [] }
        let leading = calendar.component(.weekday, from: firstOfMonth) - 1 // 1=일요일
        var result: [Date?] = Array(repeating: nil, count: leading)
        result += range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: firstOfMonth) }
        return result
    }

    private var rangeDays: Set<DateComponents> {
        Set((0..<days).compactMap { offset -> DateComponents? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            return calendar.dateComponents([.year, .month, .day], from: date)
        })
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, item in
                    Text(item.text)
                        .figmaText(11, .medium)
                        .foregroundStyle(item.color)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let weekday = calendar.component(.weekday, from: date)
        let isStart = calendar.isDate(date, inSameDayAs: startDate)
        let isInRange = rangeDays.contains(comps)
        let textColor: Color = isStart ? PlanPalette.ink : (weekday == 1 ? Color(hex: 0xD95454) : (weekday == 7 ? Color(hex: 0x5478CC) : PlanPalette.ink))

        return Button {
            onPick(date)
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .figmaText(14, isStart ? .bold : .medium)
                .foregroundStyle(textColor)
                .frame(width: 34, height: 34)
                .background {
                    if isStart {
                        Circle().fill(Color(hex: 0xFFC914))
                    } else if isInRange {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: 0xFFEDB8))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(calendar.component(.month, from: date))월 \(calendar.component(.day, from: date))일")
    }
}

/// 시안 `713:2492`의 체크·수량 행. 체크하면 필요량을 기본값으로 채우고, ± 로 실제 보유량에 맞게 조정한다.
private struct InventoryCheckRow: View {
    let item: ShoppingPlanItem
    let owned: Double?
    let onChange: (Double?) -> Void

    @State private var isChecked: Bool
    @State private var quantity: Double

    init(item: ShoppingPlanItem, owned: Double?, onChange: @escaping (Double?) -> Void) {
        self.item = item
        self.owned = owned
        self.onChange = onChange
        _isChecked = State(initialValue: (owned ?? 0) > 0)
        _quantity = State(initialValue: owned.map { $0 > 0 ? $0 : item.quantity } ?? item.quantity)
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                isChecked.toggle()
                onChange(isChecked ? quantity : nil)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isChecked ? PlanPalette.yellow : .white)
                        .frame(width: 22, height: 22)
                        .overlay {
                            if !isChecked {
                                RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(PlanPalette.cardBorderStrong, lineWidth: 1.5)
                            }
                        }
                    if isChecked {
                        Text("✓").figmaText(11, .bold).foregroundStyle(PlanPalette.ink)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.ingredientName) 보유 여부")
            .accessibilityAddTraits(isChecked ? [.isSelected, .isButton] : .isButton)

            // 713:2492 — 체크하면 `이름 · 필요 n`이 한 줄로 붙고, 안 하면 필요량이 오른쪽으로 빠진다.
            if isChecked {
                Text("\(item.ingredientName) · 필요 \(formatQuantity(item.quantity, unit: item.unit))")
                    .figmaText(14, .medium)
                    .foregroundStyle(PlanPalette.listName)
                    .lineLimit(1)
                Spacer(minLength: 8)
            } else {
                Text(item.ingredientName)
                    .figmaText(14, .medium)
                    .foregroundStyle(PlanPalette.listName)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("필요 \(formatQuantity(item.quantity, unit: item.unit))")
                    .figmaText(13, .medium)
                    .foregroundStyle(PlanPalette.listMuted)
                    .lineLimit(1)
            }

            if isChecked {
                HStack(spacing: 10) {
                    Button {
                        quantity = max(0, quantity - 1)
                        onChange(quantity)
                    } label: {
                        Text("－").figmaText(14, .bold).foregroundStyle(PlanPalette.ink)
                    }
                    Text(formatQuantity(quantity, unit: item.unit))
                        .figmaText(13, .bold)
                        .foregroundStyle(PlanPalette.ink)
                        .frame(minWidth: 44)
                    Button {
                        quantity += 1
                        onChange(quantity)
                    } label: {
                        Text("＋").figmaText(14, .bold).foregroundStyle(PlanPalette.ink)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(PlanPalette.introFill, in: Capsule())
            }
        }
    }
}

/// 피그마 `AI 챗봇 진입`(713:2027). 식단안 수정 화면에서만 노출한다.
private struct PlanAIChatEntry: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    Image("PlanMascotAnalyzing")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 94, height: 70)
                }
                .frame(width: 121, height: 78)

                VStack(alignment: .leading, spacing: 3) {
                    Text("식단 수정이 필요하신가요?")
                        .figmaText(13, .medium)
                        .foregroundStyle(Color(hex: 0x574F40))
                    Text("클릭해서 채팅을 시작해보세요")
                        .figmaText(14, .bold, lineHeight: 20)
                        .foregroundStyle(PlanPalette.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: PlanPalette.contentWidth, height: 78, alignment: .leading)
            .background(Color(hex: 0xFFF4C9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(hex: 0xF5D973), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("식단 수정 AI 채팅")
        .accessibilityIdentifier("plan.aiChatEntry")
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
                    .frame(width: 22, height: 26)
                    .offset(x: 18, y: 17)

                Text(option.title)
                    .figmaText(15, .bold)
                    .foregroundStyle(PlanPalette.optionTitle)
                    .offset(x: 54, y: 16)

                if isRecommended {
                    Text("AI 추천")
                        .figmaText(10, .bold)
                        .foregroundStyle(PlanPalette.badgeText)
                        .frame(width: 57, height: 26)
                        .background(PlanPalette.yellow, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .offset(x: 276, y: 14)
                }

                Text(option.subtitle)
                    .figmaText(10)
                    .foregroundStyle(PlanPalette.subtle)
                    .lineLimit(1)
                    .frame(width: 215, alignment: .leading)
                    .offset(x: 54, y: 46)

                Text(costText)
                    .figmaText(13, .bold)
                    .foregroundStyle(PlanPalette.optionCost)
                    .offset(x: 18, y: 82)

                Text(metaText)
                    .figmaText(10)
                    .foregroundStyle(PlanPalette.rowValue)
                    .offset(x: 18, y: 105)

                Text("›")
                    .figmaText(22, .medium)
                    .foregroundStyle(PlanPalette.optionChevron)
                    .offset(x: 322, y: 91)
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
