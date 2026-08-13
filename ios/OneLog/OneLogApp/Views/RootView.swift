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

            if let notice = store.notice {
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

private struct MainTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        TabView(selection: $selectedTab) {
            RecipeHomeView()
                .tabItem { Label("탐색", systemImage: "fork.knife") }
                .tag(0)
            PlanView()
                .tabItem { Label("식단", systemImage: "calendar.badge.plus") }
                .tag(1)
            MealsView()
                .tabItem { Label("내 식사", systemImage: "calendar") }
                .tag(2)
            ShoppingView()
                .tabItem { Label("장보기", systemImage: "cart") }
                .tag(3)
            FridgeView()
                .tabItem { Label("냉장고", systemImage: "refrigerator") }
                .tag(4)
        }
        .tint(.oneLogGreen)
    }
}
