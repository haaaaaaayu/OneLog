import SwiftUI

// F26 공동구매·소분, F27 채팅, F25 위치.
// 피그마 `재료공유 1 / 공동구매·소분`(350:1267), `재료공유 2 / 소분 요청`(350:1327),
// `재료공유 4 / 채팅`(350:1440)을 옮긴다.
//
// 시안과 다르게 두는 것:
// - 매너온도: 평판 데이터를 만들지 않기로 확정(2026-08-18). 표시하지 않는다.
// - 도보 시간: GPS 사용 확정(2026-08-18). 약 100m 격자 좌표로 직선 거리를 재고 `약 n분`으로 적는다.
// - 앱 안에서 송금하지 않는다. 금액은 표시만 한다.

struct ShareView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var shareStore: ShareStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var location = LocationProvider()

    @State private var selectedDraftIDs: Set<String> = []
    @State private var draftForSheet: ShareDraft?
    @State private var neighborhoodInput = ""
    @State private var isEditingNeighborhood = false

    private var neighborhood: String { store.state.profile.neighborhood }
    private var drafts: [ShareDraft] { shareDrafts(from: store.currentShoppingItems) }

    private var matches: [ShareMatch] {
        rankSharePosts(
            shareStore.posts,
            shoppingItems: store.currentShoppingItems,
            dislikedIngredientIDs: store.state.preferences.dislikedIngredientIDs,
            myUserID: shareStore.userID ?? ""
        )
    }

    /// 시안 `계란·대파가 겹치는 이웃`. 고른 재료와 같은 재료를 올린 동네 글만 남긴다.
    private var overlappingPosts: [SharePost] {
        let selected = Set(drafts.filter { selectedDraftIDs.contains($0.id) }.map(\.ingredientID))
        guard !selected.isEmpty else { return matches.map(\.post) }
        return matches.map(\.post).filter { selected.contains($0.ingredientID) }
    }

    private var myPosts: [SharePost] {
        guard let userID = shareStore.userID else { return [] }
        return shareStore.posts
            .filter { $0.authorID == userID || $0.participantIDs.contains(userID) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// 시안 `나누면 아끼는 돈`. 포장 가격과 남는 양이 모두 확인된 경우에만
    /// 남는 양의 포장가치를 표시한다. 근거가 없으면 금액을 만들지 않는다.
    private var savingText: String {
        let selected = drafts.filter { selectedDraftIDs.contains($0.id) }
        let known = selected.compactMap { draft -> Int? in
            guard let item = store.currentShoppingItems.first(where: { $0.ingredientID == draft.ingredientID && $0.unit == draft.unit }),
                  let price = store.state.prices[draft.ingredientID],
                  price.unit == draft.unit,
                  price.packageAmount > 0,
                  abs(price.packageAmount - item.packageSize.amount) < 0.000001 else { return nil }
            let ratio = min(max(draft.amount / price.packageAmount, 0), 1)
            return Int((Double(price.price) * ratio).rounded())
        }
        guard !known.isEmpty else { return "가격 확인 전" }
        return won(known.reduce(0, +))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    CareHeader(title: "공동구매·소분") { dismiss() }

                    Text("혼자 다 못 쓸 재료, 이웃과 조금씩 나눠요")
                        .figmaText(20, .bold)
                        .foregroundStyle(SharePalette.ink)
                        .frame(width: 336, alignment: .leading)
                        .padding(.top, 16)

                    Text(subtitleText)
                        .figmaText(11)
                        .foregroundStyle(SharePalette.subtitle)
                        .padding(.top, 8)

                    if !shareStore.isConfigured {
                        noticeCard(ShareStore.notConfiguredMessage)
                    }
                    if let error = shareStore.errorMessage {
                        noticeCard(error)
                    }
                    if let error = location.errorMessage {
                        noticeCard(error)
                    }

                    neighborhoodRow
                        .padding(.top, 14)

                    if !neighborhood.isEmpty {
                        Text("나눌 재료를 골라주세요")
                            .figmaText(14, .bold)
                            .foregroundStyle(SharePalette.sectionLabel)
                            .padding(.top, 18)

                        draftList
                            .padding(.top, 12)

                        Text(overlapTitle)
                            .figmaText(11, .bold)
                            .foregroundStyle(SharePalette.ink)
                            .padding(.top, 20)

                        neighborList
                            .padding(.top, 10)

                        if !myPosts.isEmpty {
                            Text("내가 올리거나 참여한 글")
                                .figmaText(11, .bold)
                                .foregroundStyle(SharePalette.ink)
                                .padding(.top, 20)

                            VStack(spacing: 8) {
                                ForEach(myPosts) { post in
                                    postRow(post, showsOverlapBadge: false)
                                }
                            }
                            .padding(.top, 10)
                        }
                    }

                    safetyNote
                        .padding(.top, 20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            if !neighborhood.isEmpty { stickyFooter }
        }
        .background(SharePalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { neighborhoodInput = neighborhood }
        .task(id: neighborhood) {
            guard !neighborhood.isEmpty else { return }
            await shareStore.start(neighborhood: neighborhood)
            // 도보 시간을 보여주려면 좌표가 필요하다. 거부하면 시간만 빠지고 나머지는 그대로 쓴다.
            if store.state.profile.coordinate == nil,
               let coordinate = await location.requestOnce() {
                store.setNeighborhoodCoordinate(coordinate)
            }
        }
        .sheet(item: $draftForSheet) { draft in
            SharePostComposer(draft: draft, coordinate: myCoordinate)
                .environmentObject(store)
                .environmentObject(shareStore)
        }
    }

    private var myCoordinate: ShareCoordinate? {
        location.coordinate ?? store.state.profile.coordinate
    }

    private var subtitleText: String {
        let count = overlappingPosts.count
        guard count > 0 else { return "같은 동네에 올라온 글이 아직 없어요. 먼저 올려보세요." }
        if let nearest = overlappingPosts.compactMap({ walkingMinutes(from: myCoordinate, to: $0.coordinate) }).min() {
            return "지금 걸어서 약 \(nearest)분 안에 같은 재료가 필요한 이웃 \(count)명이 있어요"
        }
        return "같은 재료가 필요한 이웃 \(count)명이 있어요"
    }

    private var overlapTitle: String {
        let names = drafts.filter { selectedDraftIDs.contains($0.id) }.map(\.ingredientName)
        guard !names.isEmpty else { return "동네에 올라온 글" }
        return "\(names.prefix(2).joined(separator: "·"))가 겹치는 이웃"
    }

    // MARK: - 동네

    private var neighborhoodRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            if neighborhood.isEmpty || isEditingNeighborhood {
                HStack(spacing: 8) {
                    TextField("예: 성수동", text: $neighborhoodInput)
                        .figmaText(13)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(SharePalette.line, lineWidth: 1)
                        }
                        .accessibilityIdentifier("neighborhoodField")
                    Button("저장") {
                        store.setNeighborhood(neighborhoodInput)
                        isEditingNeighborhood = false
                    }
                    .figmaText(13, .bold)
                    .foregroundStyle(SharePalette.ink)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(SharePalette.brand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            } else {
                Button {
                    neighborhoodInput = neighborhood
                    isEditingNeighborhood = true
                } label: {
                    HStack(spacing: 6) {
                        Image("IconPin").resizable().scaledToFit().frame(width: 16, height: 16)
                        Text(neighborhood)
                            .figmaText(12, .bold)
                            .foregroundStyle(SharePalette.ink)
                        Text(myCoordinate == nil ? "· 위치 확인 전" : "· 도보 시간 표시 중")
                            .figmaText(10)
                            .foregroundStyle(SharePalette.muted)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(SharePalette.chip, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("내 동네 \(neighborhood) 수정")
            }
        }
    }

    // MARK: - 나눌 재료 (350:1277)

    private var draftList: some View {
        VStack(spacing: 8) {
            if drafts.isEmpty {
                emptyCard("나눌 재료가 아직 없어요", "식단을 확정하고 장보기 계산이 끝나면 남을 재료를 여기에 모아 드려요.")
            } else {
                ForEach(drafts) { draft in
                    let isSelected = selectedDraftIDs.contains(draft.id)
                    Button {
                        if isSelected { selectedDraftIDs.remove(draft.id) } else { selectedDraftIDs.insert(draft.id) }
                    } label: {
                        HStack(spacing: 0) {
                            ZStack {
                                RoundedRectangle(cornerRadius: isSelected ? 8 : 7, style: .continuous)
                                    .fill(isSelected ? SharePalette.brand : .white)
                                    .frame(width: 26, height: 26)
                                    .overlay {
                                        if !isSelected {
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .strokeBorder(SharePalette.checkboxLine, lineWidth: 1.5)
                                        }
                                    }
                                if isSelected {
                                    Text("✓").figmaText(12, .bold).foregroundStyle(.white)
                                }
                            }
                            .padding(.leading, 12.5)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(draft.ingredientName) \(formatQuantity(draft.amount, unit: draft.unit))")
                                    .figmaText(13, .bold)
                                    .foregroundStyle(SharePalette.ink)
                                    .lineLimit(1)
                                Text(draft.reason)
                                    .figmaText(10)
                                    .foregroundStyle(SharePalette.draftBody)
                                    .lineLimit(1)
                            }
                            .padding(.leading, 18)

                            Spacer(minLength: 8)

                            if let saving = savingText(for: draft) {
                                Text(saving)
                                    .figmaText(12, .bold)
                                    .foregroundStyle(SharePalette.saving)
                                    .padding(.trailing, 14)
                            }
                        }
                        .frame(height: 64)
                        .background(isSelected ? SharePalette.selectedFill : .white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(isSelected ? SharePalette.brand : SharePalette.line, lineWidth: isSelected ? 1.5 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
                }
            }
        }
    }

    // MARK: - 이웃 글 (350:1290)

    private var neighborList: some View {
        VStack(spacing: 8) {
            if shareStore.isLoading && shareStore.posts.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if overlappingPosts.isEmpty {
                emptyCard("겹치는 이웃이 아직 없어요", "먼저 올리면 같은 동네 이웃이 볼 수 있어요.")
            } else {
                ForEach(overlappingPosts) { post in
                    postRow(post, showsOverlapBadge: true)
                }
            }
        }
    }

    private func postRow(_ post: SharePost, showsOverlapBadge: Bool) -> some View {
        NavigationLink {
            SharePostDetailView(postID: post.id, myCoordinate: myCoordinate)
                .environmentObject(store)
                .environmentObject(shareStore)
        } label: {
            HStack(spacing: 12) {
                Text(post.kind == .groupBuy ? "🛒" : "🥕")
                    .figmaText(18)
                    .frame(width: 42, height: 42)
                    .background(SharePalette.chip, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(headline(post))
                        .figmaText(13, .bold)
                        .foregroundStyle(SharePalette.ink)
                        .lineLimit(1)
                    Text(caption(post))
                        .figmaText(10)
                        .foregroundStyle(SharePalette.neighborBody)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if showsOverlapBadge {
                    Text("\(post.joinedCount)/\(post.capacity)명")
                        .figmaText(9, .bold)
                        .foregroundStyle(SharePalette.badgeText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(SharePalette.badgeFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    Text(post.status.label)
                        .figmaText(9, .bold)
                        .foregroundStyle(SharePalette.muted)
                }
            }
            .padding(.horizontal, 13)
            .frame(height: 58)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(SharePalette.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func headline(_ post: SharePost) -> String {
        guard let walking = walkingText(from: myCoordinate, to: post.coordinate) else {
            return post.authorNickname
        }
        return "\(post.authorNickname) · \(walking)"
    }

    private func caption(_ post: SharePost) -> String {
        var parts = ["\(post.ingredientName) \(post.amountText)", post.kind.label]
        if let price = post.pricePerShare { parts.append("1인 \(won(price))") }
        return parts.joined(separator: " · ")
    }

    private func savingText(for draft: ShareDraft) -> String? {
        guard let item = store.currentShoppingItems.first(where: { $0.ingredientID == draft.ingredientID && $0.unit == draft.unit }),
              item.precision == .exact,
              let price = store.state.prices[draft.ingredientID],
              price.unit == draft.unit,
              price.packageAmount > 0,
              abs(price.packageAmount - item.packageSize.amount) < 0.000001 else { return nil }
        let ratio = min(max(draft.amount / price.packageAmount, 0), 1)
        let value = Int((Double(price.price) * ratio).rounded())
        return value > 0 ? "−\(won(value))" : nil
    }

    // MARK: - 하단 고정 (350:1268)

    private var stickyFooter: some View {
        VStack(spacing: 0) {
            Rectangle().fill(SharePalette.footerLine).frame(height: 1)
            HStack {
                Text("나누면 아끼는 돈")
                    .figmaText(12, .bold)
                    .foregroundStyle(SharePalette.footerLabel)
                Spacer()
                Text(savingText)
                    .figmaText(17, .bold)
                    .foregroundStyle(SharePalette.ink)
            }
            .padding(.horizontal, 20)
            .padding(.top, 17)

            Button {
                if let first = drafts.first(where: { selectedDraftIDs.contains($0.id) }) {
                    draftForSheet = first
                }
            } label: {
                Text(ctaTitle)
                    .figmaText(13, .bold)
                    .foregroundStyle(SharePalette.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(SharePalette.cta.opacity(selectedDraftIDs.isEmpty ? 0.4 : 1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(selectedDraftIDs.isEmpty)
            .accessibilityIdentifier("share.createPost")
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
        .background(.white)
    }

    private var ctaTitle: String {
        guard let first = drafts.first(where: { selectedDraftIDs.contains($0.id) }) else { return "나눌 재료를 골라주세요" }
        return "\(first.ingredientName) 소분 글 올리기"
    }

    // MARK: - 보조

    private func noticeCard(_ text: String) -> some View {
        Text(text)
            .figmaText(11)
            .foregroundStyle(Color.oneLogOrange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(SharePalette.chip, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 12)
    }

    private func emptyCard(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).figmaText(13, .bold).foregroundStyle(SharePalette.ink)
            Text(body).figmaText(10).foregroundStyle(SharePalette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(SharePalette.line, lineWidth: 1)
        }
    }

    private var safetyNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("앱 안에서 송금하지 않아요")
                .figmaText(13, .bold)
                .foregroundStyle(SharePalette.ink)
            Text("금액은 표시만 하고 결제·송금 기능은 없어요. 정산은 직접 하시고, 만날 때는 사람이 많은 공개된 장소를 이용해 주세요. 위치는 도보 시간을 계산할 때만 쓰고 약 100m 단위로 반올림해 저장해요.")
                .figmaText(10, lineHeight: 16)
                .foregroundStyle(SharePalette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(SharePalette.chip, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - 시안 값

enum SharePalette {
    static let canvas = Color(hex: 0xFFFEFB)
    static let ink = Color(hex: 0x14120D)
    static let brand = Color(hex: 0xFFC914)
    static let cta = Color(hex: 0xFFD114)
    static let selectedFill = Color(hex: 0xFFF3C9)
    static let line = Color(hex: 0xE5DECC)
    static let checkboxLine = Color(hex: 0xC7BDA8)
    static let subtitle = Color(hex: 0x918A7D)
    static let sectionLabel = Color(hex: 0x857D6E)
    static let draftBody = Color(hex: 0x807563)
    static let neighborBody = Color(hex: 0x8C8578)
    static let muted = Color(hex: 0x948C80)
    static let saving = Color(hex: 0xB86E05)
    static let badgeFill = Color(hex: 0xEDF7E8)
    static let badgeText = Color(hex: 0x528547)
    static let footerLine = Color(hex: 0xEBE3D4)
    static let footerLabel = Color(hex: 0x665E52)
    static let chip = Color(hex: 0xF5F0E0)

    // 채팅 (350:1440)
    static let chatCanvas = Color(hex: 0xF7F1E6)
    static let chatInk = Color(hex: 0x2D2A24)
    static let chatMeta = Color(hex: 0x797163)
    static let chatNotice = Color(hex: 0xECE6DA)
    static let chatNoticeText = Color(hex: 0x787164)
    static let composerFill = Color(hex: 0xF7F2E8)
    static let composerPlaceholder = Color(hex: 0xA69E91)
    static let promiseBorder = Color(hex: 0xF1CC5C)
    static let promiseTitle = Color(hex: 0xB48010)
    static let promiseBody = Color(hex: 0x4B3004)
    static let summaryLine = Color(hex: 0xF2EDE0)
    static let summaryBody = Color(hex: 0x787061)
    static let statusFill = Color(hex: 0xFFF0C2)
    static let statusText = Color(hex: 0x7A5E14)
}

// MARK: - 글 올리기

private struct SharePostComposer: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var shareStore: ShareStore
    @Environment(\.dismiss) private var dismiss
    let draft: ShareDraft
    let coordinate: ShareCoordinate?

    @State private var priceText = ""
    @State private var capacity = 2
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("나눌 재료") {
                    LabeledContent(draft.ingredientName, value: formatQuantity(draft.amount, unit: draft.unit))
                    LabeledContent("방식", value: draft.kind.label)
                    Text(draft.kind.explanation)
                        .font(.caption)
                        .foregroundStyle(SharePalette.muted)
                }
                Section("모집") {
                    Stepper("총 \(capacity)명 (나 포함)", value: $capacity, in: 2...8)
                    LabeledContent("동네", value: store.state.profile.neighborhood)
                    LabeledContent("도보 시간 표시", value: coordinate == nil ? "위치 없음" : "켜짐")
                    Text("7일 뒤 자동으로 마감돼요. 위치를 켜면 이웃에게 도보 시간이 보여요(약 100m 단위).")
                        .font(.caption)
                        .foregroundStyle(SharePalette.muted)
                }
                Section("1인당 금액 (선택)") {
                    TextField("예: 1500", text: $priceText)
                        .keyboardType(.numberPad)
                    Text("표시만 해요. 앱에서 송금하지 않아요.")
                        .font(.caption)
                        .foregroundStyle(SharePalette.muted)
                }
            }
            .navigationTitle("나눔 글 올리기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("올리기") {
                        isSaving = true
                        Task {
                            let ok = await shareStore.createPost(
                                draft: draft,
                                neighborhood: store.state.profile.neighborhood,
                                pricePerShare: Int(priceText.trimmingCharacters(in: .whitespaces)),
                                capacity: capacity,
                                nickname: store.state.profile.nickname,
                                coordinate: coordinate
                            )
                            isSaving = false
                            if ok { dismiss() }
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}

// MARK: - 글 상세 + 채팅 (350:1327, 350:1440)

private struct SharePostDetailView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var shareStore: ShareStore
    @Environment(\.dismiss) private var dismiss
    let postID: String
    let myCoordinate: ShareCoordinate?

    @State private var messageText = ""
    @State private var isMeetupEditorPresented = false

    private var post: SharePost? { shareStore.posts.first { $0.id == postID } }
    private var userID: String { shareStore.userID ?? "" }
    private var membershipKey: String {
        let participantKey = post?.participantIDs.sorted().joined(separator: ",") ?? ""
        return "\(postID)|\(userID)|\(participantKey)"
    }

    var body: some View {
        Group {
            if let post {
                content(post)
            } else {
                VStack(spacing: 8) {
                    Text("글을 찾을 수 없어요").figmaText(16, .bold).foregroundStyle(SharePalette.ink)
                    Text("마감되었거나 작성자가 지웠을 수 있어요.").figmaText(11).foregroundStyle(SharePalette.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SharePalette.chatCanvas)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: membershipKey) { shareStore.startMemberDetails(postID: postID) }
        .onDisappear { shareStore.stopChat() }
        .sheet(isPresented: $isMeetupEditorPresented) {
            MeetupEditor(postID: postID, existing: shareStore.meetup, legacyPlaceNote: post?.meetupNote ?? "")
                .environmentObject(shareStore)
        }
    }

    private func content(_ post: SharePost) -> some View {
        VStack(spacing: 0) {
            chatHeader(post)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        matchNotice(post)
                        summaryCard(post)

                        if post.isMember(userID) {
                            if shareStore.messages.isEmpty {
                                Text("아직 대화가 없어요. 먼저 인사해 보세요.")
                                    .figmaText(10)
                                    .foregroundStyle(SharePalette.chatMeta)
                                    .padding(.top, 8)
                            }
                            ForEach(shareStore.messages) { message in
                                bubble(message)
                                    .id(message.id)
                            }
                            promiseCard(post)
                        } else {
                            lockedCard(post)
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
                .onChange(of: shareStore.messages.count) {
                    guard let last = shareStore.messages.last else { return }
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            if post.isMember(userID) { composerDock(post) }
        }
        .background(SharePalette.chatCanvas)
    }

    // MARK: 헤더 (350:1441)

    private func chatHeader(_ post: SharePost) -> some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Text("‹")
                    .figmaText(24)
                    .foregroundStyle(Color(hex: 0x2D2B27))
                    .frame(width: 28, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로")

            Text(post.kind == .groupBuy ? "🛒" : "🥕")
                .figmaText(18)
                .frame(width: 42, height: 42)
                .background(SharePalette.chip, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(post.authorNickname)
                    .figmaText(17, .bold)
                    .foregroundStyle(Color(hex: 0x191815))
                Text(headerMeta(post))
                    .figmaText(10)
                    .foregroundStyle(SharePalette.chatMeta)
            }

            Spacer(minLength: 8)

            if post.authorID == userID, post.status != .closed {
                Button {
                    Task { await shareStore.close(post) }
                } label: {
                    Text("모집 닫기")
                        .figmaText(10, .bold)
                        .foregroundStyle(SharePalette.chatMeta)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
    }

    private func headerMeta(_ post: SharePost) -> String {
        var parts: [String] = []
        if let walking = walkingText(from: myCoordinate, to: post.coordinate) { parts.append(walking) }
        parts.append("\(post.joinedCount)/\(post.capacity)명")
        return parts.joined(separator: " · ")
    }

    // MARK: 매칭 알림 (350:1484)

    private func matchNotice(_ post: SharePost) -> some View {
        Text("\(post.ingredientName) \(post.kind.label) 글이에요")
            .figmaText(9, .medium)
            .foregroundStyle(SharePalette.chatNoticeText)
            .padding(.horizontal, 19)
            .frame(height: 25)
            .background(SharePalette.chatNotice, in: Capsule())
    }

    // MARK: 요약 (350:1340 / 350:1460)

    private func summaryCard(_ post: SharePost) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(post.ingredientName) \(post.amountText)")
                        .figmaText(14, .bold)
                        .foregroundStyle(Color(hex: 0x181714))
                    Text(post.kind.explanation)
                        .figmaText(10, lineHeight: 18)
                        .foregroundStyle(Color(hex: 0x776F61))
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(post.status.label)
                    .figmaText(10, .bold)
                    .foregroundStyle(SharePalette.badgeText)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(SharePalette.badgeFill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .padding(.horizontal, 17)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Rectangle().fill(SharePalette.summaryLine).frame(height: 1)

            HStack {
                participant(post.authorNickname, share: post.capacity)
                Text("1/\(post.capacity)")
                    .figmaText(13, .medium)
                    .foregroundStyle(Color(hex: 0x946B0D))
                    .frame(width: 42, height: 42)
                    .background(Color(hex: 0xFFF2C9), in: Circle())
                participant(post.joinedCount > 1 ? "참여 \(post.joinedCount - 1)명" : "참여 대기", share: post.capacity)
            }
            .padding(.horizontal, 18)
            .frame(height: 62)

            Rectangle().fill(SharePalette.summaryLine).frame(height: 1)

            HStack {
                Text("각자 낼 돈")
                    .figmaText(11)
                    .foregroundStyle(SharePalette.summaryBody)
                Spacer()
                Text(post.pricePerShare.map { "\(won($0))씩" } ?? "정하지 않았어요")
                    .figmaText(14, .bold)
                    .foregroundStyle(SharePalette.ink)
            }
            .padding(.horizontal, 18)
            .frame(height: 38)

            joinAction(post)
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color(hex: 0xE5DEC9), lineWidth: 1)
        }
    }

    private func participant(_ name: String, share: Int) -> some View {
        VStack(spacing: 4) {
            Text(name)
                .figmaText(13, .bold)
                .foregroundStyle(SharePalette.ink)
                .lineLimit(1)
            Text("\(share)명이 나눠요")
                .figmaText(10)
                .foregroundStyle(SharePalette.summaryBody)
        }
        .frame(width: 118)
    }

    @ViewBuilder
    private func joinAction(_ post: SharePost) -> some View {
        if post.authorID == userID {
            EmptyView()
        } else if post.participantIDs.contains(userID) {
            detailButton("참여 취소", filled: false) { Task { await shareStore.leave(post) } }
        } else if post.canJoin(userID: userID) {
            detailButton("참여하기", filled: true) { Task { await shareStore.join(post) } }
        } else {
            Text(post.isFull ? "인원이 다 찼어요." : "지금은 참여할 수 없는 글이에요.")
                .figmaText(10)
                .foregroundStyle(SharePalette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
        }
    }

    private func detailButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .figmaText(13, .bold)
                .foregroundStyle(filled ? SharePalette.ink : Color(hex: 0x4D473D))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(filled ? SharePalette.cta : .white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    if !filled {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color(hex: 0xD1C7AD), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 17)
        .padding(.bottom, 14)
        .accessibilityIdentifier("share.joinAction")
    }

    private func lockedCard(_ post: SharePost) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("참여하면 대화할 수 있어요")
                .figmaText(13, .bold)
                .foregroundStyle(SharePalette.ink)
            Text("만날 시간과 장소는 참여한 사람끼리만 이야기해요.")
                .figmaText(10)
                .foregroundStyle(SharePalette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: 말풍선 (350:1465, 350:1467)

    private func bubble(_ message: ShareMessage) -> some View {
        let isMine = message.senderID == userID
        return VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
            if !isMine {
                Text(message.senderNickname)
                    .figmaText(9, .medium)
                    .foregroundStyle(SharePalette.chatMeta)
            }
            Text(message.text)
                .figmaText(11, lineHeight: 18)
                .foregroundStyle(SharePalette.chatInk)
                .padding(.horizontal, isMine ? 18 : 14)
                .padding(.vertical, 13)
                .background(
                    isMine ? SharePalette.brand : .white,
                    in: RoundedRectangle(cornerRadius: isMine ? 18 : 16, style: .continuous)
                )
                .shadow(color: isMine ? .clear : Color(red: 86 / 255, green: 71 / 255, blue: 44 / 255).opacity(0.06), radius: 2, y: 2)
            Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                .figmaText(9)
                .foregroundStyle(Color(hex: 0xA59D90))
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }

    // MARK: 약속 카드 (350:1471)

    private func promiseCard(_ post: SharePost) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(shareStore.meetup == nil ? "약속을 정해 보세요." : "약속을 만들었어요.")
                .figmaText(15, .bold)
                .foregroundStyle(SharePalette.promiseTitle)
                .padding(.top, 12)

            if let meetup = shareStore.meetup {
                Text("날짜: \(meetup.scheduledAt.formatted(date: .abbreviated, time: .shortened))")
                    .figmaText(9, lineHeight: 17)
                    .foregroundStyle(SharePalette.promiseBody)
                    .padding(.top, 9)
                Text("장소: \(meetup.placeNote)")
                    .figmaText(10, lineHeight: 17)
                    .foregroundStyle(Color(hex: 0x4A453D))
                    .lineLimit(2)
            } else {
                Text(post.meetupNote.isEmpty ? "만날 날짜·시간과 장소를 정하면 참여한 사람에게만 보여요." : post.meetupNote)
                    .figmaText(10, lineHeight: 17)
                    .foregroundStyle(Color(hex: 0x4A453D))
                    .padding(.top, 9)
            }

            Button {
                isMeetupEditorPresented = true
            } label: {
                Text(shareStore.meetup == nil ? "약속 잡기" : "약속 보기")
                    .figmaText(9)
                    .foregroundStyle(Color(hex: 0x6F6659))
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color(hex: 0xDED0B5), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("meetupEditorButton")
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 15)
        .frame(width: 201, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(SharePalette.promiseBorder, lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: 입력 독 (350:1476)

    private func composerDock(_ post: SharePost) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color(hex: 0xEFE7D9)).frame(height: 1)
            HStack(spacing: 10) {
                TextField("메시지 보내기", text: $messageText, axis: .vertical)
                    .figmaText(11)
                    .lineLimit(1...4)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 48)
                    .background(SharePalette.composerFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .accessibilityIdentifier("chatField")

                Button {
                    let text = messageText
                    messageText = ""
                    Task { await shareStore.send(text: text, postID: post.id, nickname: store.state.profile.nickname) }
                } label: {
                    Text("↑")
                        .figmaText(19, .bold)
                        .foregroundStyle(Color(hex: 0x1F1D18))
                        .frame(width: 48, height: 48)
                        .background(SharePalette.brand, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("보내기")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(.white)
    }
}

// MARK: - 약속 편집 (기존 유지)

private struct MeetupEditor: View {
    @EnvironmentObject private var shareStore: ShareStore
    @Environment(\.dismiss) private var dismiss

    let postID: String
    let existing: ShareMeetup?
    let legacyPlaceNote: String

    @State private var scheduledAt: Date
    @State private var placeNote: String
    @State private var isSaving = false

    init(postID: String, existing: ShareMeetup?, legacyPlaceNote: String) {
        self.postID = postID
        self.existing = existing
        self.legacyPlaceNote = legacyPlaceNote
        _scheduledAt = State(initialValue: existing?.scheduledAt ?? Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(24 * 60 * 60))
        _placeNote = State(initialValue: existing?.placeNote ?? legacyPlaceNote)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("약속 날짜·시간") {
                    DatePicker("만날 날짜·시간", selection: $scheduledAt, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                }
                Section("장소") {
                    TextField("예: 성수역 2번 출구 앞", text: $placeNote, axis: .vertical)
                        .lineLimit(2...4)
                    Text("사람이 많은 공개된 장소를 이용하세요.")
                        .font(.caption)
                        .foregroundStyle(SharePalette.muted)
                }
                if existing != nil {
                    Section {
                        Button("약속 지우기", role: .destructive) {
                            isSaving = true
                            Task {
                                let ok = await shareStore.clearMeetup(postID: postID)
                                isSaving = false
                                if ok { dismiss() }
                            }
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .navigationTitle(existing == nil ? "약속 잡기" : "약속 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        isSaving = true
                        Task {
                            let ok = await shareStore.saveMeetup(postID: postID, scheduledAt: scheduledAt, placeNote: placeNote)
                            isSaving = false
                            if ok { dismiss() }
                        }
                    }
                    .disabled(isSaving || placeNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
