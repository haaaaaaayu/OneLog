import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .top) {
            if store.state.hasCompletedOnboarding {
                MainTabView(selectedTab: $selectedTab)
            } else {
                OnboardingView()
            }

            if let notice = store.notice, store.state.hasCompletedOnboarding {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.oneLogGreen)
                    Text(notice)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.oneLogInk)
                    Spacer(minLength: 4)
                    Button {
                        store.clearNotice()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.oneLogMuted)
                    }
                    .accessibilityLabel("알림 닫기")
                }
                .padding(13)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.oneLogLine, lineWidth: 1)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        if store.notice == notice { store.clearNotice() }
                    }
                }
            }
        }
        .background(Color.oneLogCream)
    }
}

/// 피그마 `Bottom Navigation / Unified`(383:260)의 4개 탭.
/// 장보기·냉장고는 레시피 탭과 홈 카드에서 계속 들어갈 수 있다.
private struct MainTabView: View {
    @Binding var selectedTab: Int
    /// 이미 열린 탭을 다시 누르면 그 탭의 화면 스택을 처음으로 되돌린다(iOS 기본 동작).
    @State private var rootResetCount = [0, 0, 0, 0]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch selectedTab {
                case 1: RecipeHomeView()
                case 2: MealsView()
                case 3: ShareView()
                default: HomeView(selectedTab: $selectedTab)
                }
            }
            .id("\(selectedTab)-\(rootResetCount[min(max(selectedTab, 0), 3)])")
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomNavigation(selectedTab: selectedTab) { tag in
                if tag == selectedTab {
                    rootResetCount[tag] += 1
                } else {
                    selectedTab = tag
                }
            }
        }
    }
}

private struct BottomNavigation: View {
    let selectedTab: Int
    let onSelect: (Int) -> Void

    private static let tabs: [(tag: Int, title: String, asset: String, identifier: String)] = [
        (0, "홈", "NavHome", "tab.home"),
        (1, "레시피", "NavRecipe", "tab.recipe"),
        (2, "식단관리", "NavPlan", "tab.plan"),
        (3, "재료소분", "NavShare", "tab.share")
    ]

    var body: some View {
        HStack {
            ForEach(Self.tabs, id: \.tag) { tab in
                let isActive = selectedTab == tab.tag
                Button {
                    onSelect(tab.tag)
                } label: {
                    VStack(spacing: 2) {
                        Image(tab.asset)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(isActive ? Color.oneLogInk : Color.oneLogMuted)
                            .frame(width: 30, height: 30)
                            .background(isActive ? Color.oneLogBrandDeep : .clear, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        Text(tab.title)
                            .figmaText(14, .medium)
                            .foregroundStyle(isActive ? Color.oneLogInk : Color.oneLogMuted)
                    }
                    .frame(width: 56)
                }
                .accessibilityLabel(tab.title)
                .accessibilityIdentifier(tab.identifier)
                .accessibilityAddTraits(isActive ? [.isSelected] : [])
                if tab.tag != Self.tabs.last?.tag { Spacer(minLength: 0) }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(height: 78)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            Color.white
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.oneLogLine).frame(height: 1)
                }
        }
    }
}
