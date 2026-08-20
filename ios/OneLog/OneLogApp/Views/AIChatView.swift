import SwiftUI

/// 피그마 `식단 만들기 / AI 채팅`(713:2454). 식단 수정 요청을 대화로 받고,
/// 실제 번들 레시피 후보를 식단안에 교체·추가한다.
struct AIPlanChatView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AIChatViewModel
    @State private var input = ""
    @State private var detailTarget: AIChatDetailTarget?
    @FocusState private var isInputFocused: Bool

    let summary: AIChatPlanSummary
    let contextProvider: (String) -> AIChatPlanContext
    let onApply: (AIRecipeSuggestion) -> Bool

    init(
        summary: AIChatPlanSummary,
        contextProvider: @escaping (String) -> AIChatPlanContext,
        onApply: @escaping (AIRecipeSuggestion) -> Bool,
        service: AIChatServing? = nil
    ) {
        self.summary = summary
        self.contextProvider = contextProvider
        self.onApply = onApply
        _viewModel = StateObject(wrappedValue: AIChatViewModel(service: service ?? OpenAIChatService()))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        noticePill
                        summaryCard

                        ForEach(viewModel.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }

                        if viewModel.isSending {
                            loadingBubble
                                .id("ai.loading")
                        }

                        ForEach(viewModel.suggestions) { suggestion in
                            suggestionCard(suggestion)
                                .id(suggestion.id)
                        }

                        if let errorMessage = viewModel.errorMessage {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(errorMessage)
                                    .figmaText(11, .medium, lineHeight: 17)
                                    .foregroundStyle(AIChatPalette.warning)
                                Button("다시 시도") {
                                    viewModel.retry()
                                }
                                .figmaText(11, .bold)
                                .foregroundStyle(AIChatPalette.ink)
                                .frame(height: 36)
                                .frame(maxWidth: .infinity)
                                .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AIChatPalette.lineStrong, lineWidth: 1)
                                }
                                .accessibilityIdentifier("aiChat.retry")
                            }
                            .padding(14)
                            .background(AIChatPalette.userBubble.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.horizontal, 26)
                            .padding(.top, 16)
                        }

                        Color.clear.frame(height: 20)
                    }
                    .padding(.bottom, 12)
                }
                .background(AIChatPalette.canvas)
                .onChange(of: viewModel.messages.count) { _, _ in scrollToLatest(proxy) }
                .onChange(of: viewModel.suggestions.count) { _, _ in scrollToLatest(proxy) }
                .onChange(of: viewModel.isSending) { _, _ in scrollToLatest(proxy) }
            }
        }
        .background(AIChatPalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $detailTarget) { target in
            RecipeDetailView(
                recipeID: target.id,
                actionTitle: target.suggestion.actionTitle,
                onAddToPlan: {
                    apply(target.suggestion)
                    detailTarget = nil
                }
            )
            .environmentObject(store)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aiChat.screen")
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button {
                dismiss()
            } label: {
                Text("‹")
                    .figmaText(25, .medium)
                    .foregroundStyle(AIChatPalette.ink)
                    .frame(width: 28, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("AI 채팅 닫기")

            AIAvatar(size: 43)
                .padding(.leading, 5)

            Text("한끼로그 AI")
                .figmaText(17, .bold)
                .foregroundStyle(AIChatPalette.ink)
                .padding(.leading, 12)

            Spacer()

            Text("⋯")
                .figmaText(19)
                .foregroundStyle(AIChatPalette.muted)
                .padding(.trailing, 18)
        }
        .padding(.top, 8)
        .padding(.horizontal, 18)
        // iPhone 393×852의 상단 안전영역(59pt)을 포함해 Figma의 106pt 헤더가 된다.
        .frame(height: 47, alignment: .bottom)
        .background(.white)
    }

    private var noticePill: some View {
        Text("AI가 식단 수정을 도와드려요")
            .figmaText(9, .medium)
            .foregroundStyle(AIChatPalette.muted)
            .padding(.horizontal, 17)
            .frame(height: 25)
            .background(AIChatPalette.notice, in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 13)
    }

    private var summaryCard: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Text(summary.title)
                    .figmaText(14, .bold)
                    .foregroundStyle(AIChatPalette.ink)
                    .lineLimit(1)
                Text(summary.subtitle)
                    .figmaText(10, lineHeight: 18)
                    .foregroundStyle(AIChatPalette.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text("진행 중")
                .figmaText(10, .bold)
                .foregroundStyle(AIChatPalette.success)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(AIChatPalette.successFill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .padding(.horizontal, 19)
        .frame(height: 86, alignment: .center)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AIChatPalette.line, lineWidth: 1)
        }
        .padding(.horizontal, 26)
    }

    private func messageBubble(_ message: AIChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 82) }

            Text(message.text)
                .figmaText(11, lineHeight: 19)
                .foregroundStyle(AIChatPalette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(message.role == .user ? AIChatPalette.userBubble : .white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .shadow(color: message.role == .user ? .clear : .black.opacity(0.06), radius: 4, y: 2)

            if message.role == .assistant { Spacer(minLength: 82) }
        }
        .padding(.horizontal, 26)
        .padding(.top, 19)
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var loadingBubble: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(AIChatPalette.muted)
            Text("식단을 살펴보고 있어요…")
                .figmaText(11, .medium)
                .foregroundStyle(AIChatPalette.muted)
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .padding(.horizontal, 26)
        .padding(.top, 19)
    }

    private func suggestionCard(_ suggestion: AIRecipeSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(suggestion.title)
                .figmaText(15, .bold)
                .foregroundStyle(AIChatPalette.accentText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(suggestion.metaText)
                .figmaText(9, lineHeight: 17)
                .foregroundStyle(AIChatPalette.darkBrown)
                .padding(.top, 6)

            Button {
                detailTarget = AIChatDetailTarget(id: suggestion.recipeID, suggestion: suggestion)
            } label: {
                Text("레시피 상세보기")
                    .figmaText(9, .medium)
                    .foregroundStyle(AIChatPalette.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AIChatPalette.lineStrong, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
        }
        .padding(15)
        .frame(width: 260, alignment: .topLeading)
        .frame(minHeight: 145, alignment: .topLeading)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AIChatPalette.yellowLine, lineWidth: 1)
        }
        .padding(.horizontal, 26)
        .padding(.top, 16)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("식단 수정을 입력해보세요", text: $input)
                .figmaText(11)
                .foregroundStyle(AIChatPalette.ink)
                .lineLimit(1)
                .submitLabel(.send)
                .onSubmit(send)
                .padding(.horizontal, 18)
                .frame(minHeight: 48)
                .background(AIChatPalette.inputFill, in: Capsule())
                .accessibilityIdentifier("aiChat.input")
                .focused($isInputFocused)

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.figma(19, .bold))
                    .foregroundStyle(AIChatPalette.ink)
                    .frame(width: 48, height: 48)
                    .background(AIChatPalette.userBubble, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            .opacity(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending ? 0.45 : 1)
            .accessibilityLabel("AI 메시지 보내기")
            .accessibilityIdentifier("aiChat.send")
        }
        .padding(.horizontal, 21)
        .padding(.top, 20)
        .padding(.bottom, 20)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle().fill(AIChatPalette.footerLine).frame(height: 1)
        }
        .offset(y: 34)
    }

    private func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        input = ""
        isInputFocused = false
        viewModel.send(message: trimmed, context: contextProvider(trimmed))
    }

    private func apply(_ suggestion: AIRecipeSuggestion) {
        if onApply(suggestion) {
            viewModel.markApplied(suggestion)
        } else {
            viewModel.errorMessage = "제안한 메뉴를 현재 날짜·끼니에 적용하지 못했어요. 다른 후보를 선택해 주세요."
        }
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if let suggestion = viewModel.suggestions.last {
                proxy.scrollTo(suggestion.id, anchor: .bottom)
            } else if let message = viewModel.messages.last {
                proxy.scrollTo(message.id, anchor: .bottom)
            }
        }
    }
}

private struct AIChatDetailTarget: Identifiable {
    let id: String
    let suggestion: AIRecipeSuggestion
}

private struct AIAvatar: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Image("PlanAiHalo")
                .resizable()
                .scaledToFit()
            Image("PlanMascotAnalyzing")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.82, height: size * 0.82)
                .clipShape(Circle())
        }
        .frame(width: size, height: size)
    }
}

private enum AIChatPalette {
    static let canvas = Color(hex: 0xF7F1E6)
    static let ink = Color(hex: 0x2D2B27)
    static let muted = Color(hex: 0x776F61)
    static let notice = Color(hex: 0xECE6DA)
    static let line = Color(hex: 0xEFE6D6)
    static let lineStrong = Color(hex: 0xDED0B5)
    static let yellowLine = Color(hex: 0xF1CC5C)
    static let yellow = Color(hex: 0xFFCA12)
    static let userBubble = Color(hex: 0xFFCA12)
    static let inputFill = Color(hex: 0xF7F2E8)
    static let footerLine = Color(hex: 0xEFE7D9)
    static let success = Color(hex: 0x4C8245)
    static let successFill = Color(hex: 0xEDF7EA)
    static let warning = Color(hex: 0xB85F27)
    static let accentText = Color(hex: 0xB48010)
    static let darkBrown = Color(hex: 0x4B3004)
}
