import SwiftUI

/// F23 온보딩. 시작 화면 → 계정 연결 → 프로필 → 불호·조리도구 순서로 진행한다.
/// 각 단계는 건너뛸 수 있고, 저장한 값은 마이페이지에서 언제든 수정·삭제할 수 있다.
struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var step = 0
    @State private var nickname = ""
    @State private var ageText = ""
    @State private var dislikedIngredients: Set<String> = []
    @State private var dislikedRecipes: Set<String> = []
    @State private var availableTools: Set<CookingTool> = Set(CookingTool.allCases)

    var body: some View {
        switch step {
        case 0: welcome
        case 1: accountStep
        case 2: profileStep
        default: preferenceStep
        }
    }

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

    private var accountStep: some View {
        OnboardingStep(title: "계정을 연결할까요?", subtitle: "식단과 재고를 기기 밖에 백업하려면 Google 계정이 필요해요. 지금은 건너뛰고 이 기기에만 저장할 수도 있어요.") {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    store.signInWithGoogle()
                } label: {
                    Label("Google 계정으로 계속하기", systemImage: "person.crop.circle.badge.checkmark")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("onboarding.google")

                if let error = store.accountError {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color.oneLogOrange)
                        Button("다시 시도") { store.signInWithGoogle() }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    .oneLogCard(fill: Color.oneLogOrange.opacity(0.08))
                }

                Button("이 기기에만 저장하고 시작하기") {
                    store.useDeviceOnlyAccount()
                    step = 2
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("onboarding.deviceOnly")

                Text("이 기기에만 저장하면 앱을 지울 때 기록도 함께 사라져요. 나중에 마이페이지에서 계정을 연결할 수 있어요.")
                    .font(.caption)
                    .foregroundStyle(Color.oneLogMuted)
            }
        }
        .onChange(of: store.state.account) { _, account in
            if account != nil { step = 2 }
        }
    }

    private var profileStep: some View {
        OnboardingStep(title: "어떻게 부를까요?", subtitle: "닉네임과 나이는 선택이에요. 비워 두면 저장하지 않아요.") {
            VStack(alignment: .leading, spacing: 14) {
                ProfileFields(nickname: $nickname, ageText: $ageText)
                Button("다음") {
                    store.setProfile(nickname: nickname, age: Int(ageText))
                    step = 3
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("건너뛰기") { step = 3 }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("onboarding.skipProfile")
            }
        }
    }

    private var preferenceStep: some View {
        NavigationStack {
            Form {
                Section {
                    Text("여기서 고른 조건은 자동 추천에서만 사용해요. 직접 고른 메뉴는 지우지 않고 주의 문구로 알려드려요.")
                        .font(.footnote)
                        .foregroundStyle(Color.oneLogMuted)
                }
                PreferenceSections(dislikedIngredients: $dislikedIngredients, dislikedRecipes: $dislikedRecipes, availableTools: $availableTools)
            }
            .navigationTitle("불호와 조리도구")
            .navigationBarTitleDisplayMode(.inline)
            // 목록이 길어 화면 밖으로 나가므로 완료·건너뛰기는 툴바에 고정한다.
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("나중에") { store.completeOnboarding() }
                        .foregroundStyle(Color.oneLogMuted)
                        .accessibilityIdentifier("onboarding.later")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("시작하기") {
                        store.setPreferences(dislikedIngredientIDs: dislikedIngredients, dislikedRecipeIDs: dislikedRecipes, availableTools: availableTools)
                        store.completeOnboarding()
                    }
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.oneLogGreen)
                    .accessibilityIdentifier("onboarding.finish")
                }
            }
        }
    }
}

private struct OnboardingStep<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Eyebrow(text: "한끼로그 시작하기")
                Text(title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color.oneLogInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.oneLogMuted)
                    .lineSpacing(3)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(Color.oneLogCream)
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
