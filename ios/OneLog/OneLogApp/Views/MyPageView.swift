import SwiftUI

/// F24 마이페이지. 피그마 `마이페이지 (수정)`(383:24)를 그대로 옮겼다.
/// 계정 관리와 데이터 삭제는 디자인상 `내 정보 수정`(395:23)의 계정 행으로 들어간다.
struct MyPageView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var editingProfile = false
    @State private var sheet: PreferenceSheet?

    enum PreferenceSheet: String, Identifiable {
        case skill
        case cookTime
        case tools
        case taste

        var id: String { rawValue }
    }

    private var preferences: AppPreferences { store.state.preferences }

    private var nickname: String {
        let value = store.state.profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "회원" : value
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                profile
                    .padding(.top, 44)
                savingsGauge
                    .padding(.top, 31)
                Text("나의 요리 설정")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.oneLogInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 49)
                preferenceCard
                    .padding(.top, 19)
                Color.clear.frame(height: 32)
            }
            .padding(.horizontal, 20)
        }
        .background(Color(hex: 0xFFFEFB))
        .fullScreenCover(isPresented: $editingProfile) {
            ProfileEditView().environmentObject(store)
        }
        .sheet(item: $sheet) { item in
            preferenceSheet(for: item)
                .presentationDetents([.height(sheetHeight(for: item))])
                .presentationDragIndicator(.hidden)
        }
    }

    private var header: some View {
        ZStack {
            Text("마이페이지")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: 0x141411))
            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("‹")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color(hex: 0x141411))
                        .frame(width: 38, height: 38)
                        .background(Color(hex: 0xFFF8DC), in: Circle())
                }
                .accessibilityLabel("닫기")
                Spacer()
            }
        }
        .frame(height: 46)
        .padding(.top, 2)
    }

    private var profile: some View {
        VStack(spacing: 12) {
            Image("ProfileAvatar")
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 88)
                .background(Color.oneLogPaleGreen, in: Circle())
                .clipShape(Circle())

            Text("\(nickname)님")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Color.oneLogInk)

            Button {
                editingProfile = true
            } label: {
                Text("내 정보 수정")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.oneLogInk)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(.white, in: Capsule())
                    .overlay { Capsule().stroke(Color(hex: 0xE5DECC), lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mypage.editProfile")
        }
    }

    // MARK: - 이번 달 절약 게이지 (384:33)

    private var savingsGauge: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("이번 달 아낀 금액")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: 0x2F2105))
                HStack(spacing: 7) {
                    Text("밖에서 사먹는 거 보다")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: 0x574F40))
                        .frame(width: 108, alignment: .leading)
                    (Text(decimal(store.monthlyConfirmedSavings)).font(.system(size: 26, weight: .bold))
                        + Text("원").font(.system(size: 18, weight: .bold)))
                        .foregroundStyle(Color.oneLogInk)
                    Text("아꼈어요!")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: 0x574F40))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                GeometryReader { proxy in
                    let ratio = savingsRatio
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(hex: 0xEBE5D9))
                            .frame(height: 10)
                        Capsule()
                            .fill(Color.oneLogBrandDeep)
                            .frame(width: max(proxy.size.width * ratio, 10), height: 10)
                        Circle()
                            .fill(Color.oneLogBrandDeep)
                            .overlay { Circle().stroke(.white, lineWidth: 3) }
                            .frame(width: 20, height: 20)
                            .offset(x: max(proxy.size.width * ratio - 20, 0))
                    }
                    .frame(height: 20)
                }
                .frame(height: 20)
                Text("0원")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.oneLogFaint)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.oneLogBand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .oneLogCardShadow()
    }

    /// ponytail: 월 절약 목표가 기획에 없어 5만원을 눈금 끝으로 둔다. 목표가 정해지면 이 값만 바꾼다.
    private var savingsRatio: Double {
        min(Double(store.monthlyConfirmedSavings) / 50_000, 1)
    }

    // MARK: - 나의 요리 설정 (391:265)

    private var preferenceCard: some View {
        VStack(spacing: 0) {
            preferenceRow(
                icon: "chart.bar.fill",
                iconColor: Color(hex: 0x7D6000),
                iconBackground: Color(hex: 0xFFF7D0),
                title: "요리 숙련도",
                value: preferences.cookingSkill?.rawValue ?? "아직 고르지 않았어요",
                identifier: "mypage.skill"
            ) { sheet = .skill }
            divider
            preferenceRow(
                icon: "timer",
                iconColor: Color(hex: 0x6953B4),
                iconBackground: Color(hex: 0xF2EFFF),
                title: "선호 조리 시간",
                value: preferences.preferredCookTime?.rawValue ?? "아직 고르지 않았어요",
                identifier: "mypage.cookTime"
            ) { sheet = .cookTime }
            divider
            preferenceRow(
                icon: "frying.pan",
                iconColor: Color(hex: 0x4061A8),
                iconBackground: Color(hex: 0xEEF3FF),
                title: "보유 조리도구",
                value: summary(of: CookingTool.selectable.filter { preferences.availableTools.contains($0) }.map(\.rawValue)),
                identifier: "mypage.tools"
            ) { sheet = .tools }
            divider
            preferenceRow(
                icon: "cross.case.fill",
                iconColor: Color(hex: 0xC74D38),
                iconBackground: Color(hex: 0xFFF0EC),
                title: "불호 음식·알레르기",
                value: summary(of: store.dislikedIngredientNames.sorted() + store.allergyIngredientNames.sorted()),
                identifier: "mypage.preferences"
            ) { sheet = .taste }
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hex: 0xEFE7D7), lineWidth: 1)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(hex: 0xF2EBDD))
            .frame(height: 1)
            .padding(.horizontal, 17)
    }

    private func preferenceRow(icon: String, iconColor: Color, iconBackground: Color, title: String, value: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(iconColor)
                    .frame(width: 42, height: 42)
                    .background(iconBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(hex: 0x141411))
                    Text(value)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: 0x7A7468))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text("›")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(Color(hex: 0x9B9488))
            }
            .padding(.horizontal, 17)
            .frame(height: 64)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    /// 피그마 `고수 · 땅콩 · 갑각류 외 2개` 형식.
    private func summary(of values: [String]) -> String {
        guard !values.isEmpty else { return "아직 고르지 않았어요" }
        let head = values.prefix(3).joined(separator: " · ")
        let rest = values.count - 3
        return rest > 0 ? "\(head) 외 \(rest)개" : head
    }

    private func decimal(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func sheetHeight(for item: PreferenceSheet) -> CGFloat {
        switch item {
        case .skill: return 204
        case .cookTime: return 250
        case .tools: return 280
        case .taste: return 409
        }
    }

    @ViewBuilder
    private func preferenceSheet(for item: PreferenceSheet) -> some View {
        switch item {
        case .skill:
            SkillSheet().environmentObject(store)
        case .cookTime:
            CookTimeSheet().environmentObject(store)
        case .tools:
            ToolSheet().environmentObject(store)
        case .taste:
            TasteSheet().environmentObject(store)
        }
    }
}

// MARK: - 내 정보 수정 (395:23)

struct ProfileEditView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = ""
    @State private var birthDate = ""
    @State private var neighborhood = ""
    @State private var showingAccount = false
    @State private var showingUnlinkConfirm = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("내 정보 수정")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.oneLogInk)
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("‹")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.oneLogInk)
                            .frame(width: 38, height: 38)
                            .background(Color(hex: 0xFFF8DC), in: Circle())
                    }
                    .accessibilityLabel("닫기")
                    Spacer()
                }
            }
            .frame(height: 38)
            .padding(.top, 6)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image("ProfileAvatar")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .background(Color.oneLogPaleGreen, in: Circle())
                            .clipShape(Circle())
                        Text("사진 변경")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.oneLogInk)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(.white, in: Capsule())
                            .overlay { Capsule().stroke(Color(hex: 0xE5DECC), lineWidth: 1) }
                    }

                    field(label: "닉네임") {
                        TextField("", text: $nickname, prompt: Text("닉네임을 입력해 주세요").foregroundColor(Color.oneLogFaint))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.oneLogInk)
                            .accessibilityIdentifier("mypage.nickname")
                    }
                    field(label: "생년월일") {
                        TextField("", text: $birthDate, prompt: Text("YYYY . MM . DD").foregroundColor(Color.oneLogFaint))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.oneLogInk)
                            .keyboardType(.numbersAndPunctuation)
                            .accessibilityIdentifier("mypage.birthDate")
                    }
                    field(label: "거주지") {
                        TextField("", text: $neighborhood, prompt: Text("동네를 입력해 주세요").foregroundColor(Color.oneLogFaint))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.oneLogInk)
                            .accessibilityIdentifier("mypage.neighborhood")
                    }
                    field(label: "계정") {
                        HStack(spacing: 8) {
                            Text("G")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: 0x4285F5))
                                .frame(width: 22, height: 22)
                                .background(Color(hex: 0xFAFAFA), in: Circle())
                                .overlay { Circle().stroke(Color(hex: 0xE5DECC), lineWidth: 1) }
                            Text(accountLabel)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.oneLogInk)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Button {
                                showingAccount = true
                            } label: {
                                Text("관리 ›")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.oneLogFaint)
                            }
                            .accessibilityIdentifier("mypage.manageAccount")
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 24)
            }

            Button {
                store.setBasicProfile(
                    nickname: nickname,
                    birthDate: birthDate.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ".", with: "-"),
                    neighborhood: neighborhood,
                    skill: store.state.preferences.cookingSkill,
                    cookTime: store.state.preferences.preferredCookTime
                )
                dismiss()
            } label: {
                Text("저장하기")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: 0xF5F5F5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: 0x2C2C2C), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .accessibilityIdentifier("mypage.saveProfile")
            .padding(.bottom, 26)
        }
        .padding(.horizontal, 20)
        .background(Color(hex: 0xFFFEFB))
        .onAppear {
            nickname = store.state.profile.nickname
            birthDate = store.state.profile.birthDate.replacingOccurrences(of: "-", with: " . ")
            neighborhood = store.state.profile.neighborhood
        }
        .confirmationDialog("계정", isPresented: $showingAccount, titleVisibility: .visible) {
            if store.state.account == nil || store.state.account?.provider == .deviceOnly {
                Button("Google 계정 연결하기") { store.signInWithGoogle() }
            }
            if store.state.account != nil {
                Button("계정 연결 해제", role: .destructive) { showingUnlinkConfirm = true }
            }
            Button("계정 탈퇴하고 데이터 모두 지우기", role: .destructive) { showingDeleteConfirm = true }
            Button("취소", role: .cancel) {}
        }
        .confirmationDialog("계정 연결을 해제할까요?", isPresented: $showingUnlinkConfirm, titleVisibility: .visible) {
            Button("계정 연결 해제", role: .destructive) { store.unlinkAccount() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 기기에 저장한 식단과 재고는 그대로 남아요.")
        }
        .confirmationDialog("정말 모두 지울까요?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("모두 지우기", role: .destructive) {
                store.deleteAllData()
                dismiss()
            }
            .accessibilityIdentifier("mypage.deleteAll")
            Button("취소", role: .cancel) {}
        } message: {
            Text("식단, 재고, 장보기 기록, 프로필이 모두 사라지고 되돌릴 수 없어요.")
        }
    }

    private var accountLabel: String {
        guard let account = store.state.account else { return "연결한 계정이 없어요" }
        return account.provider == .google ? "Google 계정으로 연동됨" : "이 기기에만 저장 중"
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.oneLogInk)
            content()
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: 0xE5DECC), lineWidth: 1)
                }
        }
    }
}

// MARK: - 바텀시트 (396:23, 396:38, 396:55, 396:77)

/// 피그마 시트 공통 뼈대: 핸들 + 제목 + ✕ + 내용 + 저장하기.
private struct SheetScaffold<Content: View>: View {
    let title: String
    let onSave: () -> Void
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(Color(hex: 0xD9D1C2))
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
                .frame(height: 8)

            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.oneLogInk)
                Spacer(minLength: 8)
                Button {
                    dismiss()
                } label: {
                    Text("✕")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.oneLogFaint)
                }
                .accessibilityLabel("닫기")
            }

            content

            Button {
                onSave()
                dismiss()
            } label: {
                Text("저장하기")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: 0xF5F5F5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color(hex: 0x2C2C2C), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .accessibilityIdentifier("sheet.save")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.white)
    }
}

/// 3칸 줄바꿈 칩 묶음(w112, h38).
private struct SheetChips<Value: Hashable>: View {
    let values: [Value]
    let title: (Value) -> String
    let isSelected: (Value) -> Bool
    var accent: FigmaChip.Accent = .yellow
    let onTap: (Value) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(values, id: \.self) { value in
                FigmaChip(title: title(value), isSelected: isSelected(value), accent: accent, idleBorder: Color(hex: 0xE5DECC)) {
                    onTap(value)
                }
                .frame(height: 38)
            }
        }
    }
}

private struct SkillSheet: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection: CookingSkill?

    var body: some View {
        SheetScaffold(title: "요리 숙련도") {
            store.setBasicProfile(
                nickname: store.state.profile.nickname,
                birthDate: store.state.profile.birthDate,
                neighborhood: store.state.profile.neighborhood,
                skill: selection,
                cookTime: store.state.preferences.preferredCookTime,
                notify: false
            )
        } content: {
            SheetChips(values: CookingSkill.allCases, title: \.rawValue, isSelected: { $0 == selection }) { value in
                selection = selection == value ? nil : value
            }
        }
        .onAppear { selection = store.state.preferences.cookingSkill }
    }
}

private struct CookTimeSheet: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection: CookTimePreference?

    var body: some View {
        SheetScaffold(title: "선호 조리 시간") {
            store.setBasicProfile(
                nickname: store.state.profile.nickname,
                birthDate: store.state.profile.birthDate,
                neighborhood: store.state.profile.neighborhood,
                skill: store.state.preferences.cookingSkill,
                cookTime: selection,
                notify: false
            )
        } content: {
            SheetChips(values: CookTimePreference.allCases, title: \.rawValue, isSelected: { $0 == selection }) { value in
                selection = selection == value ? nil : value
            }
        }
        .onAppear { selection = store.state.preferences.preferredCookTime }
    }
}

private struct ToolSheet: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection: Set<CookingTool> = []

    var body: some View {
        SheetScaffold(title: "보유 조리도구") {
            store.setAvailableTools(selection, notify: false)
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                Text("여러 개 선택할 수 있어요")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.oneLogFaint)
                SheetChips(values: CookingTool.selectable, title: \.rawValue, isSelected: { selection.contains($0) }) { tool in
                    if selection.contains(tool) { selection.remove(tool) } else { selection.insert(tool) }
                }
            }
        }
        .onAppear { selection = store.state.preferences.availableTools.intersection(CookingTool.selectable) }
    }
}

private struct TasteSheet: View {
    @EnvironmentObject private var store: AppStore
    @State private var disliked: Set<String> = []
    @State private var allergy: Set<String> = []

    private var dislikedChips: [String] {
        dislikedIngredientChoices + disliked.filter { !dislikedIngredientChoices.contains($0) }.sorted()
    }

    private var allergyChips: [String] {
        allergyChoices + allergy.filter { !allergyChoices.contains($0) }.sorted()
    }

    var body: some View {
        SheetScaffold(title: "불호 음식·알레르기") {
            store.setDislikedIngredientNames(disliked, notify: false)
            store.setAllergyIngredientNames(allergy, notify: false)
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                Text("안 좋아하는 재료")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.oneLogInk)
                SheetChips(values: dislikedChips, title: { $0 }, isSelected: { disliked.contains($0) }) { name in
                    if disliked.contains(name) { disliked.remove(name) } else { disliked.insert(name) }
                }
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: 0xCC4242))
                    Text("알레르기")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.oneLogInk)
                }
                SheetChips(values: allergyChips, title: { $0 }, isSelected: { allergy.contains($0) }, accent: .red) { name in
                    if allergy.contains(name) { allergy.remove(name) } else { allergy.insert(name) }
                }
            }
        }
        .onAppear {
            disliked = store.dislikedIngredientNames
            allergy = store.allergyIngredientNames
        }
    }
}
