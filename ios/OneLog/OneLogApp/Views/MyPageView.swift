import PhotosUI
import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFunctions

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
                    .figmaText(15, .bold, lineHeight: 18) // 391:26
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
                .figmaText(18, .bold)
                .foregroundStyle(Color(hex: 0x141411))
            HStack {
                // 772:193. 36×36 흰 원, 테두리 #E3D9BF, 안에 18×18 뒤로 아이콘.
                Button {
                    dismiss()
                } label: {
                    Image("IconBack")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color(hex: 0x141411))
                        .frame(width: 36, height: 36)
                        .background(.white, in: Circle())
                        .overlay { Circle().strokeBorder(Color(hex: 0xE3D9BF), lineWidth: 1) }
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
            ProfileAvatarView(data: store.state.profile.avatarData, size: 88)

            Text("\(nickname)님")
                .figmaText(21, .bold, lineHeight: 25) // 386:76
                .foregroundStyle(Color.oneLogInk)

            Button {
                editingProfile = true
            } label: {
                Text("내 정보 수정")
                    .figmaText(13, .bold, lineHeight: 16) // 386:79 h34 = 9+16+9
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
                    .figmaText(13, .medium, lineHeight: 16) // 384:35
                    .foregroundStyle(Color(hex: 0x2F2105))
                HStack(spacing: 7) {
                    Text("보유 재료로 구매를 덜 해")
                        .figmaText(12, .medium)
                        .foregroundStyle(Color(hex: 0x574F40))
                        .frame(width: 126, alignment: .leading)
                    (Text(decimal(store.monthlyConfirmedSavings)).font(.figma(26, .bold))
                        + Text("원").font(.figma(18, .bold)))
                        .figmaLineHeight(31, size: 26, weight: .bold) // 384:37
                        .foregroundStyle(Color.oneLogInk)
                    Text("아꼈어요!")
                        .figmaText(12, .medium)
                        .foregroundStyle(Color(hex: 0x574F40))
                        .frame(width: 49, alignment: .leading) // 391:23
                }
            }

            Text("완료한 식사의 사용자 확인 가격만 합산했어요.")
                .figmaText(11, .medium, lineHeight: 16)
                .foregroundStyle(Color.oneLogFaint)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.oneLogBand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .oneLogCardShadow()
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
        // 713:1266~1270. 64 높이 행 안에서 배지(17,10) · 제목(73,8) · 설명(73,32) · 화살표(320,17).
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                Color.clear

                Image(systemName: icon)
                    .font(.figma(20))
                    .foregroundStyle(iconColor)
                    .frame(width: 42, height: 42)
                    .background(iconBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .offset(x: 17, y: 10)

                Text(title)
                    .figmaText(15, .bold, lineHeight: 18)
                    .foregroundStyle(Color(hex: 0x141411))
                    .fixedSize()
                    .offset(x: 73, y: 8)

                Text(value)
                    .figmaText(11, lineHeight: 13)
                    .foregroundStyle(Color(hex: 0x7A7468))
                    .lineLimit(1)
                    .frame(width: 240, alignment: .leading)
                    .offset(x: 73, y: 32)

                Text("›")
                    .figmaText(23, .medium)
                    .foregroundStyle(Color(hex: 0x9B9488))
                    .offset(x: 320, y: 17)
            }
            .frame(height: 64)
            .contentShape(Rectangle())
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
    @State private var showingSettings = false
    @State private var showingUnlinkConfirm = false
    @State private var showingDeleteConfirm = false
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var isEditingNeighborhood = false

    var body: some View {
        VStack(spacing: 0) {
            // 772:197 뒤로가기 y47(36×36) · 713:1279 타이틀 y52. 상태바 아래 13에서 시작한다.
            ZStack {
                Text("내 정보 수정")
                    .figmaText(18, .bold)
                    .foregroundStyle(Color.oneLogInk)
                    .offset(y: -2)
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image("IconBack")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(Color(hex: 0x141411))
                            .frame(width: 36, height: 36)
                            .background(.white, in: Circle())
                            .overlay { Circle().strokeBorder(Color(hex: 0xE3D9BF), lineWidth: 1) }
                    }
                    .accessibilityLabel("닫기")
                    Spacer()
                }
            }
            .frame(height: 36)
            .padding(.top, 13)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        ProfileAvatarView(data: store.state.profile.avatarData, size: 96)
                        PhotosPicker(selection: $pickedPhoto, matching: .images, photoLibrary: .shared()) {
                            Text("사진 변경")
                                .figmaText(12, .bold)
                                .foregroundStyle(Color.oneLogInk)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(.white, in: Capsule())
                                .overlay { Capsule().stroke(Color(hex: 0xE5DECC), lineWidth: 1) }
                        }
                        .accessibilityIdentifier("mypage.changePhoto")
                        if store.state.profile.avatarData != nil {
                            Button("기본 이미지로") { store.setAvatar(nil) }
                                .figmaText(11, .medium)
                                .foregroundStyle(Color.oneLogFaint)
                                .accessibilityIdentifier("mypage.resetPhoto")
                        }
                    }

                    field(label: "닉네임") {
                        TextField("", text: $nickname, prompt: Text("닉네임을 입력해 주세요").foregroundColor(Color.oneLogFaint))
                            .font(.figma(15, .medium))
                            .foregroundStyle(Color.oneLogInk)
                            .accessibilityIdentifier("mypage.nickname")
                    }
                    field(label: "생년월일") {
                        TextField("", text: $birthDate, prompt: Text("YYYY . MM . DD").foregroundColor(Color.oneLogFaint))
                            .font(.figma(15, .medium))
                            .foregroundStyle(Color.oneLogInk)
                            .keyboardType(.numbersAndPunctuation)
                            .accessibilityIdentifier("mypage.birthDate")
                    }
                    field(label: "거주지") {
                        // 395:42 — 값 + 오른쪽 `변경 ›`. `변경`은 온보딩과 같은 동네 인증 시트를 연다.
                        HStack(spacing: 8) {
                            TextField("", text: $neighborhood, prompt: Text("동네를 입력해 주세요").foregroundColor(Color.oneLogFaint))
                                .font(.figma(15, .medium))
                                .foregroundStyle(Color.oneLogInk)
                                .accessibilityIdentifier("mypage.neighborhood")
                            Button {
                                isEditingNeighborhood = true
                            } label: {
                                Text("변경 ›")
                                    .figmaText(13, .medium)
                                    .foregroundStyle(Color.oneLogFaint)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("mypage.changeNeighborhood")
                        }
                    }
                    field(label: "계정") {
                        HStack(spacing: 8) {
                            // Google로 연동했을 때만 G 배지를 쓴다. 기기 전용 계정에 구글 로고를 달면
                            // 연동한 적 없는 계정을 연동한 것처럼 보여 준다.
                            // 769:17. 시안은 20×20 구글 로고를 배경 없이 그대로 둔다.
                            Group {
                                if store.state.account?.provider == .google {
                                    Image("IconGoogle")
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    Image(systemName: "iphone")
                                        .font(.figma(13, .bold))
                                        .foregroundStyle(Color.oneLogFaint)
                                }
                            }
                            .frame(width: 20, height: 20)
                            Text(accountLabel)
                                .figmaText(15, .medium)
                                .foregroundStyle(Color.oneLogInk)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Button {
                                showingSettings = true
                            } label: {
                                Text("관리 ›")
                                    .figmaText(13, .medium)
                                    .foregroundStyle(Color.oneLogFaint)
                            }
                            .accessibilityIdentifier("mypage.manageAccount")
                        }
                    }
                    if let error = store.accountError {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(Color.oneLogOrange)
                            Button("Google 계정 다시 연결") {
                                Task { await store.signInWithGoogle() }
                            }
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Color.oneLogGreen)
                        }
                    }
                }
                .padding(.top, 20) // 713:1280 콘텐츠 y137 (뒤로가기 아래 20)
                .padding(.bottom, 24)
            }

            Button {
                let saved = store.setBasicProfile(
                    nickname: nickname,
                    birthDate: birthDate.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ".", with: "-"),
                    neighborhood: neighborhood,
                    skill: store.state.preferences.cookingSkill,
                    cookTime: store.state.preferences.preferredCookTime
                )
                if saved { dismiss() }
            } label: {
                Text("저장하기")
                    .figmaText(15, .bold)
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
        .fullScreenCover(isPresented: $isEditingNeighborhood) {
            NeighborhoodSheet(neighborhood: $neighborhood)
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showingSettings) {
            AppSettingsView().environmentObject(store)
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    store.notice = "사진을 불러오지 못했어요."
                    return
                }
                store.setAvatar(image)
                pickedPhoto = nil
            }
        }
        .confirmationDialog("계정", isPresented: $showingAccount, titleVisibility: .visible) {
            if store.state.account == nil || store.state.account?.provider == .deviceOnly {
                Button("Google 계정 연결하기") { Task { await store.signInWithGoogle() } }
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
                Task {
                    await store.deleteAllData()
                    dismiss()
                }
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
                .figmaText(13, .bold)
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

// MARK: - 설정·알림 (792:26, 798:26, 799:26)

struct AppSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingNotifications = false
    @State private var showingNotificationCenter = false
    @State private var showingDeleteConfirm = false
    @State private var legalDocument: LegalDocumentKind?
    @State private var showingSupport = false

    var body: some View {
        VStack(spacing: 0) {
            FinalTopHeader(title: "설정", backFill: .white, action: { dismiss() })

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    settingsSection("계정") {
                        settingsRow(icon: accountIcon, title: "Google 계정", value: accountValue) {
                            if store.state.account?.provider == .google {
                                store.unlinkAccount()
                            } else {
                                Task { await store.signInWithGoogle() }
                            }
                        }
                        settingsDivider
                        settingsRow(title: "알림 설정") { showingNotifications = true }
                            .accessibilityIdentifier("settings.notifications")
                            .contextMenu {
                                Button("알림함 보기") { showingNotificationCenter = true }
                            }
                            .accessibilityAction(named: "알림함 보기") { showingNotificationCenter = true }
                    }

                    settingsSection("약관 · 정책") {
                        settingsRow(title: "문의·신고 접수") { showingSupport = true }
                        settingsDivider
                        settingsRow(title: "서비스 이용약관") { legalDocument = .terms }
                        settingsDivider
                        settingsRow(title: "개인정보 처리방침") { legalDocument = .privacy }
                        settingsDivider
                        settingsRow(title: "커뮤니티 운영정책") { legalDocument = .community }
                        settingsDivider
                        settingsRow(title: "오픈소스 라이선스") { legalDocument = .openSource }
                        settingsDivider
                        HStack {
                            Text("버전 정보").figmaText(15, .medium).foregroundStyle(Color.oneLogInk)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                                .figmaText(13, .medium).foregroundStyle(Color.oneLogFaint)
                        }
                        .frame(height: 46)
                        .padding(.horizontal, 16)
                    }

                    VStack(spacing: 0) {
                        settingsRow(title: "로그아웃") { store.unlinkAccount() }
                        settingsDivider
                        settingsRow(title: "회원 탈퇴", tint: Color(hex: 0xCC4242)) { showingDeleteConfirm = true }
                    }
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: 0xE5DECC), lineWidth: 1) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 26)
                .padding(.bottom, 30)
            }
        }
        .background(Color(hex: 0xFFFEFB))
        .accessibilityIdentifier("settings.screen")
        .fullScreenCover(isPresented: $showingNotifications) { NotificationSettingsView() }
        .fullScreenCover(isPresented: $showingNotificationCenter) { OneLogNotificationCenterView() }
        .fullScreenCover(item: $legalDocument) { kind in LegalDocumentsView(kind: kind) }
        .fullScreenCover(isPresented: $showingSupport) { SupportContactView() }
        .confirmationDialog("정말 모두 지울까요?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("모두 지우기", role: .destructive) {
                Task { await store.deleteAllData(); dismiss() }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("식단, 재고, 장보기 기록, 프로필이 모두 사라지고 되돌릴 수 없어요.")
        }
    }

    @ViewBuilder
    private var accountIcon: some View {
        if store.state.account?.provider == .google {
            Image("IconGoogle").resizable().scaledToFit()
        } else {
            Image(systemName: "iphone").font(.figma(16, .medium)).foregroundStyle(Color.oneLogFaint)
        }
    }

    private var accountValue: String { store.state.account?.provider == .google ? "연동됨" : "연동하기" }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).figmaText(12, .bold).foregroundStyle(Color.oneLogFaint)
            VStack(spacing: 0) { content() }
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: 0xE5DECC), lineWidth: 1) }
        }
    }

    private func settingsRow<Icon: View>(icon: Icon, title: String, value: String? = nil, tint: Color = .oneLogInk, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon.frame(width: 20, height: 20)
                Text(title).figmaText(15, .medium).foregroundStyle(tint)
                Spacer(minLength: 8)
                if let value { Text(value).figmaText(13, .medium).foregroundStyle(Color.oneLogFaint) }
                Text("›").figmaText(18, .medium).foregroundStyle(Color.oneLogFaint)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingsRow(title: String, value: String? = nil, tint: Color = .oneLogInk, action: @escaping () -> Void) -> some View {
        settingsRow(icon: Color.clear.frame(width: 0, height: 0), title: title, value: value, tint: tint, action: action)
    }

    private var settingsDivider: some View {
        Rectangle().fill(Color.oneLogDivider).frame(height: 1).padding(.horizontal, 16)
    }
}

struct NotificationSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var notificationStore: NotificationStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notification.shareRequests") private var shareRequests = true
    @AppStorage("notification.chat") private var chat = true
    @AppStorage("notification.meals") private var meals = true
    @AppStorage("notification.shopping") private var shopping = false
    @AppStorage("notification.savings") private var savings = true

    var body: some View {
        VStack(spacing: 0) {
            FinalTopHeader(title: "알림 설정", backFill: Color(hex: 0xFFC914), action: { dismiss() })
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    permissionCard
                    toggleSection("재료 소분") {
                        notificationToggle("소분 요청 알림", subtitle: "이웃의 소분·공동구매 요청", value: $shareRequests)
                        notificationDivider
                        notificationToggle("채팅 메시지 알림", value: $chat)
                    }
                    toggleSection("식단") {
                        notificationToggle("오늘 식단 리마인더", subtitle: "요리할 시간을 알려드려요", value: $meals)
                        notificationDivider
                        notificationToggle("장보기 리마인더", value: $shopping)
                        notificationDivider
                        notificationToggle("주간 절약 리포트", value: $savings)
                    }
                    Text("식단·장보기 알림은 기기에서 예약하고, 소분 요청·채팅은 Firebase 푸시로 받아요.")
                        .figmaText(11, .medium, lineHeight: 17)
                        .foregroundStyle(Color.oneLogFaint)
                }
                .padding(.horizontal, 20)
                .padding(.top, 26)
            }
        }
        .background(Color(hex: 0xFFFEFB))
        .accessibilityIdentifier("notificationSettings.screen")
        .task { await notificationStore.refreshAuthorization() }
    }

    private var permissionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: notificationStore.isAuthorized ? "bell.badge.fill" : "bell.slash.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(notificationStore.isAuthorized ? Color.oneLogSuccess : Color.oneLogOrange)
                .frame(width: 38, height: 38)
                .background(Color.oneLogPaleGreen, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(notificationStore.isAuthorized ? "기기 알림 허용됨" : "기기 알림 권한이 필요해요")
                    .figmaText(14, .bold).foregroundStyle(Color.oneLogInk)
                if let error = notificationStore.errorMessage {
                    Text(error).figmaText(10, .medium, lineHeight: 15).foregroundStyle(Color.oneLogOrange)
                }
            }
            Spacer()
            Button(notificationStore.authorizationStatus == .denied ? "설정 열기" : "허용하기") {
                if notificationStore.authorizationStatus == .denied {
                    notificationStore.openSystemSettings()
                } else {
                    Task {
                        if await notificationStore.requestAuthorization() { await syncSchedules() }
                    }
                }
            }
            .figmaText(12, .bold)
            .foregroundStyle(Color.oneLogInk)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color.oneLogBrandDeep, in: Capsule())
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: 0xE5DECC), lineWidth: 1) }
    }

    private func toggleSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).figmaText(12, .bold).foregroundStyle(Color.oneLogFaint)
            VStack(spacing: 0) { content() }
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: 0xE5DECC), lineWidth: 1) }
        }
    }

    private func notificationToggle(_ title: String, subtitle: String? = nil, value: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).figmaText(15, .medium).foregroundStyle(Color.oneLogInk)
                if let subtitle { Text(subtitle).figmaText(11, .medium).foregroundStyle(Color.oneLogFaint) }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { value.wrappedValue },
                set: { newValue in
                    value.wrappedValue = newValue
                    Task {
                        if newValue, !notificationStore.isAuthorized {
                            _ = await notificationStore.requestAuthorization()
                        }
                        await syncSchedules()
                    }
                }
            ))
            .labelsHidden().tint(Color(hex: 0xFFC914)).scaleEffect(0.88)
        }
        .padding(.horizontal, 16)
        .frame(height: subtitle == nil ? 54 : 64)
    }

    private var notificationDivider: some View {
        Rectangle().fill(Color.oneLogDivider).frame(height: 1).padding(.horizontal, 16)
    }

    private func syncSchedules() async {
        await notificationStore.reschedule(
            plannedMeals: store.plannedMeals,
            shoppingItems: store.currentShoppingItems,
            purchaseChecks: store.state.purchaseChecks,
            monthlySavings: store.monthlyConfirmedSavings
        )
    }
}

struct OneLogNotificationCenterView: View {
    @EnvironmentObject private var notificationStore: NotificationStore
    @Environment(\.dismiss) private var dismiss

    private var today: [OneLogNotification] {
        notificationStore.notifications.filter { Calendar.current.isDateInToday($0.createdAt) }
    }
    private var previous: [OneLogNotification] {
        notificationStore.notifications.filter { !Calendar.current.isDateInToday($0.createdAt) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("알림").figmaText(20, .bold).foregroundStyle(Color.oneLogInk)
                HStack {
                    FinalBackButton(fill: Color(hex: 0xFFC914), action: { dismiss() })
                    Spacer()
                    Button("모두 읽음") { notificationStore.markAllRead() }
                        .figmaText(13, .medium)
                        .foregroundStyle(Color.oneLogFaint)
                        .disabled(notificationStore.unreadCount == 0)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 20)
            .padding(.top, 8)

            if notificationStore.notifications.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(Color.oneLogFaint)
                    Text("아직 받은 알림이 없어요")
                        .figmaText(16, .bold).foregroundStyle(Color.oneLogInk)
                    Text("식단 리마인더와 실제 소분 요청·채팅 알림이 여기에 쌓여요.")
                        .figmaText(12, .medium, lineHeight: 18).foregroundStyle(Color.oneLogFaint)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 40)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        if !today.isEmpty { notificationGroup("오늘", rows: today) }
                        if !previous.isEmpty { notificationGroup("이전", rows: previous) }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 25)
                }
            }
        }
        .background(Color(hex: 0xFFFEFB))
        .accessibilityIdentifier("notifications.screen")
    }

    private func notificationGroup(_ title: String, rows: [OneLogNotification]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).figmaText(13, .bold).foregroundStyle(Color.oneLogFaint)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    Button { notificationStore.markRead(row.id) } label: {
                    HStack(spacing: 12) {
                        Text(row.category.symbol).font(.system(size: 20)).frame(width: 40, height: 40)
                            .background(Color(hex: 0xFFEDB8), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.title).figmaText(14, .bold).foregroundStyle(Color.oneLogInk)
                            Text(row.body).figmaText(11, .medium).foregroundStyle(Color(hex: 0x574F40)).lineLimit(2)
                        }
                        Spacer(minLength: 5)
                        VStack(alignment: .trailing, spacing: 7) {
                            Text(Self.relativeFormatter.localizedString(for: row.createdAt, relativeTo: Date()))
                                .figmaText(10, .medium).foregroundStyle(Color.oneLogFaint)
                            if !row.isRead { Circle().fill(Color(hex: 0xCC4242)).frame(width: 7, height: 7) }
                        }
                    }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 67)
                    if index < rows.count - 1 { Rectangle().fill(Color.oneLogDivider).frame(height: 1).padding(.leading, 66) }
                }
            }
            .background(indexedNotificationBackground(title), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: 0xE5DECC), lineWidth: 1) }
        }
    }

    private func indexedNotificationBackground(_ title: String) -> Color { title == "오늘" ? Color(hex: 0xFFFBED) : .white }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}

private struct FinalTopHeader: View {
    let title: String
    let backFill: Color
    let action: () -> Void
    var body: some View {
        ZStack {
            Text(title).figmaText(20, .bold).foregroundStyle(Color.oneLogInk)
            HStack { FinalBackButton(fill: backFill, action: action); Spacer() }
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

private struct FinalBackButton: View {
    let fill: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image("IconBack").resizable().renderingMode(.template).scaledToFit()
                .frame(width: 18, height: 18).foregroundStyle(Color.oneLogInk)
                .frame(width: 38, height: 38).background(fill, in: Circle())
                .overlay { Circle().stroke(Color(hex: 0xE3D9BF), lineWidth: 1) }
        }
        .accessibilityLabel("뒤로")
    }
}

// MARK: - 바텀시트 (396:23, 396:38, 396:55, 396:77)

/// 피그마 시트 공통 뼈대: 핸들 + 제목 + ✕ + 내용 + 저장하기.
private struct SheetScaffold<Content: View>: View {
    let title: String
    /// 시트 루트 간격. 396:23·38·55는 16, 396:77(불호·알레르기)만 14.
    var spacing: CGFloat = 16
    let onSave: () -> Void
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Capsule()
                .fill(Color(hex: 0xD9D1C2))
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
                .frame(height: 8)

            HStack {
                Text(title)
                    .figmaText(18, .bold)
                    .foregroundStyle(Color.oneLogInk)
                Spacer(minLength: 8)
                Button {
                    dismiss()
                } label: {
                    Text("✕")
                        .figmaText(16)
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
                    .figmaText(15, .bold)
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
                FigmaChip(title: title(value), isSelected: isSelected(value), accent: accent, idleBorder: Color(hex: 0xE5DECC), height: 38) {
                    onTap(value)
                }
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
                    .figmaText(12, .medium)
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
        SheetScaffold(title: "불호 음식·알레르기", spacing: 14) {
            store.setDislikedIngredientNames(disliked, notify: false)
            store.setAllergyIngredientNames(allergy, notify: false)
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                Text("안 좋아하는 재료")
                    .figmaText(14, .bold)
                    .foregroundStyle(Color.oneLogInk)
                SheetChips(values: dislikedChips, title: { $0 }, isSelected: { disliked.contains($0) }) { name in
                    if disliked.contains(name) { disliked.remove(name) } else { disliked.insert(name) }
                }
                // 408:42 — 18pt 빨간 원 안에 흰 `!`, 라벨과 8pt 간격, 위 4pt 여백.
                HStack(spacing: 8) {
                    Text("!")
                        .figmaText(12, .bold)
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color(hex: 0xCC4242), in: Circle())
                    Text("알레르기")
                        .figmaText(14, .bold)
                        .foregroundStyle(Color.oneLogInk)
                }
                .padding(.top, 4)
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

private struct SupportContactView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var category = "이용 문의"
    @State private var message = ""
    @State private var isSending = false
    @State private var resultMessage: String?

    private let categories = ["이용 문의", "계정·개인정보", "결제 없는 거래 신고", "안전 신고", "기타"]

    var body: some View {
        VStack(spacing: 0) {
            FinalTopHeader(title: "문의·신고", backFill: .white, action: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("접수한 내용은 운영 확인용으로만 사용해요. 긴급한 위험 상황은 경찰·소방 등 관계 기관에 먼저 연락해 주세요.")
                        .figmaText(12, .medium, lineHeight: 19)
                        .foregroundStyle(Color.oneLogBody)
                        .padding(16)
                        .background(Color.oneLogPaleGreen, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text("문의 유형").figmaText(13, .bold).foregroundStyle(Color.oneLogInk)
                    Picker("문의 유형", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).frame(height: 50)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text("내용").figmaText(13, .bold).foregroundStyle(Color.oneLogInk)
                    TextEditor(text: $message)
                        .figmaText(14)
                        .frame(minHeight: 180)
                        .padding(10)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.oneLogDivider) }

                    if let resultMessage {
                        Text(resultMessage).figmaText(12, .medium).foregroundStyle(Color.oneLogBody)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        Text(isSending ? "접수 중…" : "접수하기")
                            .figmaText(15, .bold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(Color.oneLogInk, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isSending || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(20)
            }
        }
        .background(Color(hex: 0xFFFEFB))
    }

    @MainActor
    private func submit() async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 1000 else {
            resultMessage = "내용은 1,000자 이내로 적어 주세요."
            return
        }
        guard FirebaseApp.app() != nil else {
            resultMessage = "서버 연결 설정을 확인해 주세요."
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            if Auth.auth().currentUser == nil { _ = try await Auth.auth().signInAnonymously() }
            _ = try await Functions.functions(region: "us-central1").httpsCallable("submitSupportTicket").call([
                "category": category, "message": trimmed
            ])
            message = ""
            resultMessage = "접수했어요. 필요한 경우 연결된 계정 정보로 안내할게요."
        } catch {
            resultMessage = "접수하지 못했어요. 네트워크를 확인한 뒤 다시 시도해 주세요."
        }
    }
}
