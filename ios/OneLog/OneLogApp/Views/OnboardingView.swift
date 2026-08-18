import SwiftUI

/// F23 온보딩. 피그마 `유진) 수정완료`의 첫화면(350:1899) → Google 로그인(350:1905)
/// → 기본정보(350:2256) → 조리도구(350:2304) → 불호·알레르기(366:86 / 370:11) 순서를 그대로 따른다.
struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var step = 0
    @State private var nickname = ""
    @State private var birthDateText = ""
    @State private var neighborhood = ""
    @State private var skill: CookingSkill?
    @State private var cookTime: CookTimePreference?
    @State private var availableTools: Set<CookingTool> = Set(CookingTool.selectable)
    @State private var dislikedNames: Set<String> = []
    @State private var allergyNames: Set<String> = []
    @State private var isVerifyingNeighborhood = false

    var body: some View {
        switch step {
        case 0: welcome
        case 1: loginStep
        case 2: basicInfoStep
        case 3: toolStep
        default: tasteStep
        }
    }

    // MARK: - 첫화면 (350:1899)

    private var welcome: some View {
        GeometryReader { proxy in
            Image("OnboardingScreen")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { step = 1 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("한끼로그 시작 화면")
        .accessibilityHint("화면을 탭하면 시작 단계로 넘어갑니다.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { step = 1 }
    }

    // MARK: - Google 로그인 (350:1905)

    private var loginStep: some View {
        // 피그마 350:1905는 마스코트를 위, 버튼·약관을 아래에 고정한다. 사이 여백(219pt)만 화면 높이에 따라 줄인다.
        VStack(spacing: 0) {
            Color.clear.frame(height: 186)

            Image("LoginMascot")
                .resizable()
                .scaledToFill()
                .frame(width: 177.5, height: 177.5)
                .background(Color(hex: 0xFDEFC8), in: Circle())
                .clipShape(Circle())

            Text("한끼로그를 시작해볼까요?")
                .figmaText(22, .bold, lineHeight: 31)
                .foregroundStyle(Color.oneLogBody)
                .multilineTextAlignment(.center)
                .padding(.top, 12.74)

            Text("예산에 맞춰 식단부터 장보기,\n남은 재료 활용까지 계획해드려요.")
                .figmaText(13, lineHeight: 21)
                .foregroundStyle(Color(hex: 0x6C5F48))
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            Spacer(minLength: 0)

            if let error = store.accountError {
                VStack(alignment: .leading, spacing: 10) {
                    Text(error)
                        .figmaText(12)
                        .foregroundStyle(Color(hex: 0x9E2626))
                    Button("이 기기에만 저장하고 시작하기") {
                        store.useDeviceOnlyAccount()
                        step = 2
                    }
                    .font(.figma(13, .bold))
                    .foregroundStyle(Color.oneLogInk)
                    .accessibilityIdentifier("onboarding.deviceOnly")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(hex: 0xFCE6E1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.bottom, 14)
            }

            googleButton
            Text("계속하면 이용약관 및 개인정보처리방침에 동의하게 됩니다.")
                .figmaText(10, lineHeight: 16)
                .foregroundStyle(Color(hex: 0x61594A))
                .multilineTextAlignment(.center)
                .padding(.top, 17)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 29)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .onChange(of: store.state.account) { _, account in
            if account != nil { step = 2 }
        }
    }

    private var googleButton: some View {
        Button {
            Task { await store.signInWithGoogle() }
        } label: {
            HStack(spacing: 10) {
                Image("IconGoogle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text("Google 계정으로 시작하기")
                    .figmaText(15, .medium, lineHeight: 22)
                    .foregroundStyle(Color.oneLogInk)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(hex: 0xE0C785), lineWidth: 1)
            }
            .shadow(color: Color(red: 41 / 255, green: 31 / 255, blue: 10 / 255).opacity(0.1), radius: 4, y: 3)
        }
        .accessibilityIdentifier("onboarding.google")
    }

    // MARK: - 1. 기본정보 (350:2256)

    private var basicInfoStep: some View {
        stepScaffold(
            step: 1,
            primaryTitle: "다음",
            onBack: { step = 1 },
            onPrimary: {
                store.setBasicProfile(nickname: nickname, birthDate: birthDateText, neighborhood: neighborhood, skill: skill, cookTime: cookTime, notify: false)
                step = 3
            },
            skipIdentifier: "onboarding.skipProfile",
            onSkip: { step = 3 }
        ) {
            VStack(alignment: .leading, spacing: 20) {
                header(title: "기본 정보를 알려주세요", subtitle: "딱 맞는 식단을 추천하는 데 쓰는 정보예요.")

                FigmaField(label: "이름") {
                    FigmaTextInput(placeholder: "닉네임을 입력해 주세요", text: $nickname)
                        .accessibilityIdentifier("profile.nickname")
                }
                FigmaField(label: "생년월일") {
                    FigmaTextInput(placeholder: "YYYY . MM . DD", text: $birthDateText, keyboard: .numbersAndPunctuation)
                        .accessibilityIdentifier("profile.birthDate")
                }
                FigmaField(label: "거주지") {
                    FigmaNeighborhoodField(neighborhood: neighborhood) { isVerifyingNeighborhood = true }
                }
                FigmaField(label: "요리 숙련도") {
                    HStack(spacing: 8) {
                        ForEach(CookingSkill.allCases) { value in
                            FigmaChip(title: value.rawValue, isSelected: skill == value) {
                                skill = skill == value ? nil : value
                            }
                        }
                    }
                }
                FigmaField(label: "선호 조리 시간") {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(CookTimePreference.allCases) { value in
                            FigmaChip(title: value.rawValue, isSelected: cookTime == value) {
                                cookTime = cookTime == value ? nil : value
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isVerifyingNeighborhood) {
            NeighborhoodSheet(neighborhood: $neighborhood)
        }
    }

    // MARK: - 2. 조리도구 (350:2304)

    private var toolStep: some View {
        stepScaffold(
            step: 2,
            primaryTitle: "다음",
            onBack: { step = 2 },
            onPrimary: {
                store.setAvailableTools(availableTools, notify: false)
                step = 4
            },
            skipIdentifier: "onboarding.skipTools",
            onSkip: { step = 4 }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text("어떤 조리도구가 있나요?")
                    .figmaText(24, .bold, lineHeight: 34)
                    .foregroundStyle(Color.oneLogInk)
                Text("선택한 도구로 만들 수 있는 레시피만 추천해요.")
                    .figmaText(13, lineHeight: 21)
                    .foregroundStyle(Color(hex: 0x574F40))
                    .padding(.top, 8)

                HStack(spacing: 0) {
                    Text("\(availableTools.intersection(CookingTool.selectable).count)개 선택됨")
                        .figmaText(12, .medium, lineHeight: 18)
                        .foregroundStyle(Color(hex: 0x574F40))
                    Spacer(minLength: 8)
                    Button {
                        let all = Set(CookingTool.selectable)
                        availableTools = availableTools.isSuperset(of: all) ? [] : all
                    } label: {
                        Text("전체 선택")
                            .figmaText(12, .bold, lineHeight: 18)
                            .foregroundStyle(Color.oneLogInk)
                    }
                }
                .padding(.top, 23)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(CookingTool.selectable) { tool in
                        ToolCard(tool: tool, isSelected: availableTools.contains(tool)) {
                            if availableTools.contains(tool) {
                                availableTools.remove(tool)
                            } else {
                                availableTools.insert(tool)
                            }
                        }
                    }
                }
                .padding(.top, 18)
            }
        }
    }

    // MARK: - 3. 불호 재료 / 알레르기 (366:86, 370:11)

    private var tasteStep: some View {
        stepScaffold(
            step: 3,
            primaryTitle: "한끼로그 시작하기",
            contentTop: 25, // 366:86 본문은 y=120 (기본정보 123보다 3pt 위)
            onBack: { step = 3 },
            onPrimary: {
                store.setDislikedIngredientNames(dislikedNames, notify: false)
                store.setAllergyIngredientNames(allergyNames, notify: false)
                store.completeOnboarding()
            },
            skipIdentifier: "onboarding.later",
            onSkip: { store.completeOnboarding() }
        ) {
            TastePicker(dislikedNames: $dislikedNames, allergyNames: $allergyNames)
        }
    }

    // MARK: - 공통 뼈대

    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .figmaText(24, .bold, lineHeight: 34)
                .foregroundStyle(Color.oneLogInk)
            Text(subtitle)
                .figmaText(13, lineHeight: 21)
                .foregroundStyle(Color(hex: 0x574F40))
        }
    }

    private func stepScaffold<Content: View>(
        step current: Int,
        primaryTitle: String,
        contentTop: CGFloat = 28,
        onBack: @escaping () -> Void,
        onPrimary: @escaping () -> Void,
        skipIdentifier: String,
        onSkip: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            FigmaStepHeader(step: current, onBack: onBack)

            ScrollView(showsIndicators: false) {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, contentTop)
                    .padding(.bottom, 24)
            }

            VStack(spacing: 19) {
                FigmaPrimaryButton(title: primaryTitle, action: onPrimary)
                Button("나중에 설정할게요", action: onSkip)
                    .font(.figma(12))
                    .foregroundStyle(Color(hex: 0x6C5F48))
                    .accessibilityIdentifier(skipIdentifier)
            }
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
    }
}

/// 거주지 행(445:49)을 탭하면 뜨는 동네 입력 시트. 입력값이 채워지면 `인증 완료` 상태가 된다.
/// ponytail: 실제 GPS 인증 없이 입력만 받는다. CoreLocation 붙일 때 여기만 갈아끼우면 된다.
private struct NeighborhoodSheet: View {
    @Binding var neighborhood: String
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("동네 인증")
                .figmaText(18, .bold)
                .foregroundStyle(Color.oneLogInk)
            FigmaTextInput(placeholder: "동네를 검색해 주세요", text: $draft)
                .accessibilityIdentifier("profile.neighborhoodInput")
            Spacer(minLength: 0)
            FigmaPrimaryButton(title: "인증하기", isEnabled: !draft.trimmingCharacters(in: .whitespaces).isEmpty) {
                neighborhood = draft.trimmingCharacters(in: .whitespaces)
                dismiss()
            }
        }
        .padding(24)
        .background(.white)
        .presentationDetents([.height(260)])
        .onAppear { draft = neighborhood }
    }
}

/// 피그마 `도구 / 선택`(350:2316) 카드. 171x92.
private struct ToolCard: View {
    let tool: CookingTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                Color.white

                Group {
                    if let asset = tool.assetName {
                        Image(asset)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                    } else {
                        Image(systemName: tool.symbolName)
                    }
                }
                .frame(width: 24, height: 24)
                .foregroundStyle(Color.oneLogBody)
                .frame(width: 42, height: 42)
                .background(Color.oneLogPaleGreen, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .offset(x: 14, y: 14)

                Text(tool.rawValue)
                    .figmaText(12, .medium)
                    .foregroundStyle(Color.oneLogBody)
                    .offset(x: 14, y: 62)

                if isSelected {
                    ZStack {
                        Circle().fill(Color.oneLogBrandDeep)
                        Text("✓")
                            .figmaText(12, .bold)
                            .foregroundStyle(Color.oneLogBody)
                    }
                    .frame(width: 22, height: 22)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 14)
                    .offset(y: 14)
                }
            }
            .frame(height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.oneLogBrandDeep : Color(hex: 0xECEBEB), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.rawValue)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// 피그마 `B / Content`(368:11, 370:20). 안 좋아하는 재료 / 알레르기 탭.
struct TastePicker: View {
    @Binding var dislikedNames: Set<String>
    @Binding var allergyNames: Set<String>
    @State private var isAllergyTab = false
    @State private var customInput = ""

    private var accent: FigmaChip.Accent { isAllergyTab ? .red : .yellow }

    private var chips: [String] {
        let base = isAllergyTab ? allergyChoices : dislikedIngredientChoices
        let selected = isAllergyTab ? allergyNames : dislikedNames
        return base + selected.filter { !base.contains($0) }.sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("빼고 싶은 재료가 있나요?")
                    .figmaText(24, .bold, lineHeight: 34)
                    .foregroundStyle(Color.oneLogInk)
                Text(isAllergyTab ? "알레르기·못 먹는 재료는 레시피에서 완전히 제외됩니다." : "고른 재료가 들어간 레시피는 추천에서 빼드릴게요.")
                    .figmaText(13, lineHeight: 21)
                    .foregroundStyle(Color(hex: 0x574F40))
            }

            tabs

            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(chips, id: \.self) { name in
                        FigmaChip(title: name, isSelected: isSelected(name), accent: accent, idleBorder: Color(hex: 0xE8E0D1)) {
                            toggle(name)
                        }
                    }
                }

                customInputRow

                Text(isAllergyTab ? "안 좋아하는 재료는 위 탭에서 따로 골라주세요." : "알레르기·못 먹는 재료는 위 탭에서 따로 골라주세요.")
                    .figmaText(12, lineHeight: 18)
                    .foregroundStyle(Color.oneLogFaint)
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            tabButton(title: "안 좋아하는 재료", isActive: !isAllergyTab, showsDot: false) { isAllergyTab = false }
            tabButton(title: "알레르기·못 먹는 재료", isActive: isAllergyTab, showsDot: true) { isAllergyTab = true }
        }
        .padding(4)
        .background(Color.oneLogChip, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tabButton(title: String, isActive: Bool, showsDot: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if showsDot {
                    Circle()
                        .fill(Color(hex: 0xCC4242))
                        .frame(width: 7, height: 7)
                }
                Text(title)
                    .figmaText(13, isActive ? .bold : .medium)
                    .foregroundStyle(isActive ? Color.oneLogInk : Color.oneLogFaint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var customInputRow: some View {
        HStack(spacing: 8) {
            Text("＋")
                .figmaText(16)
                .foregroundStyle(Color.oneLogFaint)
            TextField("", text: $customInput, prompt: Text("직접 입력하기").foregroundColor(Color.oneLogFaint))
                .font(.figma(14))
                .foregroundStyle(Color.oneLogInk)
                .accessibilityIdentifier("taste.customInput")
            Button {
                let value = customInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { return }
                toggle(value, forceOn: true)
                customInput = ""
            } label: {
                Text("추가")
                    .figmaText(13, .bold)
                    .foregroundStyle(isAllergyTab ? Color(hex: 0x9E2626) : Color.oneLogBody)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(isAllergyTab ? Color(hex: 0xFCE6E1) : Color.oneLogPaleGreen, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .frame(height: 46)
        .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(hex: 0xE8E0D1), lineWidth: 1)
        }
    }

    private func isSelected(_ name: String) -> Bool {
        isAllergyTab ? allergyNames.contains(name) : dislikedNames.contains(name)
    }

    private func toggle(_ name: String, forceOn: Bool = false) {
        if isAllergyTab {
            if allergyNames.contains(name), !forceOn { allergyNames.remove(name) } else { allergyNames.insert(name) }
        } else {
            if dislikedNames.contains(name), !forceOn { dislikedNames.remove(name) } else { dislikedNames.insert(name) }
        }
    }
}

/// 온보딩과 마이페이지가 같은 입력 규칙을 쓰도록 공유한다.
struct ProfileFields: View {
    @Binding var nickname: String
    @Binding var ageText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("닉네임 (선택)", text: $nickname)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("profile.nickname")
            Divider().overlay(Color.oneLogLine)
            TextField("나이 (선택)", text: $ageText)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("profile.age")
            if !ageText.isEmpty, Int(ageText).map({ !(14...120).contains($0) }) ?? true {
                Text("나이는 14~120 사이 숫자만 저장해요.")
                    .font(.caption)
                    .foregroundStyle(Color.oneLogOrange)
            }
        }
        .oneLogCard()
    }
}
