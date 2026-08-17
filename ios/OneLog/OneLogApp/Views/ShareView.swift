import SwiftUI

// F26 공동구매·소분 매칭과 F27 채팅 화면.
// 앱 안에서 돈을 주고받지 않는다. 금액은 표시만 하고 정산은 사용자끼리 직접 한다.

struct ShareView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var shareStore: ShareStore
    @State private var draftForSheet: ShareDraft?
    @State private var neighborhoodInput = ""

    private var neighborhood: String { store.state.profile.neighborhood }

    private var matches: [ShareMatch] {
        rankSharePosts(
            shareStore.posts,
            shoppingItems: store.currentShoppingItems,
            dislikedIngredientIDs: store.state.preferences.dislikedIngredientIDs,
            myUserID: shareStore.userID ?? ""
        )
    }

    private var myPosts: [SharePost] {
        guard let userID = shareStore.userID else { return [] }
        return shareStore.posts
            .filter { $0.authorID == userID || $0.participantIDs.contains(userID) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var drafts: [ShareDraft] { shareDrafts(from: store.currentShoppingItems) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if !shareStore.isConfigured {
                        notice(ShareStore.notConfiguredMessage, symbol: "exclamationmark.triangle.fill", tint: .oneLogOrange)
                    }
                    if let error = shareStore.errorMessage {
                        notice(error, symbol: "exclamationmark.circle.fill", tint: .oneLogOrange)
                    }
                    neighborhoodCard
                    if !neighborhood.isEmpty {
                        draftsCard
                        matchesCard
                        myPostsCard
                    }
                    safetyCard
                }
                .padding(16)
            }
            .background(Color.oneLogCream)
            .navigationTitle("동네 나눔")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { neighborhoodInput = neighborhood }
        .task(id: neighborhood) {
            guard !neighborhood.isEmpty else { return }
            await shareStore.start(neighborhood: neighborhood)
        }
        .sheet(item: $draftForSheet) { draft in
            SharePostComposer(draft: draft)
                .environmentObject(store)
                .environmentObject(shareStore)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "같이 사기 · 나눠 쓰기")
            Text("한 봉지가 너무 많으면\n같은 동네에서 나눠요.")
                .font(.system(size: 31, weight: .black, design: .rounded))
                .foregroundStyle(Color.oneLogInk)
            Text("장보기 계산에서 남을 예정인 재료만 글로 올릴 수 있어요. 위치는 받지 않고, 직접 적은 동네 이름으로만 묶어요.")
                .font(.subheadline)
                .foregroundStyle(Color.oneLogMuted)
                .lineSpacing(3)
        }
        .oneLogCard(fill: Color.oneLogPaleGreen)
    }

    private var neighborhoodCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading("내 동네", subtitle: "GPS를 쓰지 않아요. 적은 이름이 똑같은 사람끼리만 글이 보여요.")
            HStack(spacing: 10) {
                TextField("예: 성수동", text: $neighborhoodInput)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .accessibilityIdentifier("neighborhoodField")
                Button("저장") {
                    store.setNeighborhood(neighborhoodInput)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(neighborhoodInput.trimmingCharacters(in: .whitespacesAndNewlines) == neighborhood)
            }
        }
        .oneLogCard()
    }

    private var draftsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading("내가 나눌 수 있는 재료", subtitle: "이번 장보기에서 남을 예정인 양이에요.")
            if drafts.isEmpty {
                EmptyState(symbol: "rectangle.split.2x1", title: "나눌 재료가 아직 없어요", message: "식단을 담고 장보기 계산이 끝나면 남을 재료를 여기에 모아 드려요. 판매 단위가 확인된 재료만 나올 수 있어요.")
            } else {
                ForEach(drafts) { draft in
                    Button {
                        draftForSheet = draft
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: draft.kind.symbolName)
                                .foregroundStyle(Color.oneLogGreen)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(draft.ingredientName) \(formatQuantity(draft.amount, unit: draft.unit))")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.oneLogInk)
                                Text(draft.reason)
                                    .font(.caption)
                                    .foregroundStyle(Color.oneLogMuted)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 8)
                            StatusPill(text: draft.kind.label, tint: .oneLogGreen)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(Color.oneLogLine)
                }
            }
        }
        .oneLogCard()
    }

    private var matchesCard: some View {
        let relevant = matches.filter(\.isRelevant)
        let others = matches.filter { !$0.isRelevant }
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeading("동네 글", subtitle: "이번 장보기에 필요한 재료 글을 위로 올려요.")
            if shareStore.isLoading && shareStore.posts.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if matches.isEmpty {
                EmptyState(symbol: "person.2", title: "아직 동네 글이 없어요", message: "먼저 올리면 같은 동네 이웃이 볼 수 있어요.")
            } else {
                if !relevant.isEmpty {
                    Text("나와 맞는 글")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.oneLogGreen)
                    ForEach(relevant) { match in
                        SharePostRow(match: match)
                    }
                }
                if !others.isEmpty {
                    Text("그 밖의 동네 글")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.oneLogMuted)
                        .padding(.top, relevant.isEmpty ? 0 : 8)
                    ForEach(others) { match in
                        SharePostRow(match: match)
                    }
                }
            }
        }
        .oneLogCard()
    }

    @ViewBuilder
    private var myPostsCard: some View {
        if !myPosts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading("내가 올리거나 참여한 글", subtitle: "여기서 대화하고 만날 시간을 정해요.")
                ForEach(myPosts) { post in
                    SharePostRow(match: ShareMatch(post: post, score: 0, reasons: []))
                }
            }
            .oneLogCard()
        }
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("앱 안에서 송금하지 않아요", systemImage: "hand.raised.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.oneLogInk)
            Text("금액은 표시만 하고 결제·송금 기능은 없어요. 정산은 직접 하시고, 만날 때는 사람이 많은 공개된 장소를 이용해 주세요.")
                .font(.caption)
                .foregroundStyle(Color.oneLogMuted)
                .lineSpacing(2)
        }
        .oneLogCard(fill: Color.oneLogPaleGreen)
    }

    private func notice(_ text: String, symbol: String, tint: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .oneLogCard()
    }
}

private struct SharePostRow: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var shareStore: ShareStore
    let match: ShareMatch

    var body: some View {
        NavigationLink {
            SharePostDetailView(postID: match.post.id)
                .environmentObject(store)
                .environmentObject(shareStore)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: match.post.kind.symbolName)
                        .foregroundStyle(Color.oneLogGreen)
                    Text("\(match.post.ingredientName) \(match.post.amountText)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.oneLogInk)
                    Spacer(minLength: 8)
                    StatusPill(text: match.post.status.label, tint: match.post.status == .open ? .oneLogGreen : .oneLogMuted)
                }
                HStack(spacing: 8) {
                    Text(match.post.kind.label)
                    Text("·")
                    Text("\(match.post.joinedCount)/\(match.post.capacity)명")
                    if let price = match.post.pricePerShare {
                        Text("·")
                        Text("1인 \(won(price))")
                    }
                    Text("·")
                    Text(match.post.authorNickname)
                }
                .font(.caption)
                .foregroundStyle(Color.oneLogMuted)
                ForEach(match.reasons, id: \.self) { reason in
                    Text(reason)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.oneLogGreen)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 글 올리기

private struct SharePostComposer: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var shareStore: ShareStore
    @Environment(\.dismiss) private var dismiss
    let draft: ShareDraft

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
                        .foregroundStyle(Color.oneLogMuted)
                }
                Section("모집") {
                    Stepper("총 \(capacity)명 (나 포함)", value: $capacity, in: 2...8)
                    LabeledContent("동네", value: store.state.profile.neighborhood)
                    Text("7일 뒤 자동으로 마감돼요.")
                        .font(.caption)
                        .foregroundStyle(Color.oneLogMuted)
                }
                Section("약속") {
                    Label("참여자끼리 약속 잡기", systemImage: "calendar.badge.clock")
                        .font(.subheadline.weight(.bold))
                    Text("글을 올린 뒤 참여한 사람만 볼 수 있는 약속 카드에서 날짜·시간과 장소를 정해요.")
                        .font(.caption)
                        .foregroundStyle(Color.oneLogMuted)
                }
                Section("1인당 금액 (선택)") {
                    TextField("예: 1500", text: $priceText)
                        .keyboardType(.numberPad)
                    Text("표시만 해요. 앱에서 송금하지 않아요.")
                        .font(.caption)
                        .foregroundStyle(Color.oneLogMuted)
                }
            }
            .navigationTitle("나눔 글 올리기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("올리기") {
                        isSaving = true
                        Task {
                            let ok = await shareStore.createPost(
                                draft: draft,
                                neighborhood: store.state.profile.neighborhood,
                                pricePerShare: Int(priceText.trimmingCharacters(in: .whitespaces)),
                                capacity: capacity,
                                nickname: store.state.profile.nickname
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

// MARK: - 글 상세 + 채팅 (F27)

private struct SharePostDetailView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var shareStore: ShareStore
    let postID: String

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
                EmptyState(symbol: "questionmark.circle", title: "글을 찾을 수 없어요", message: "마감되었거나 작성자가 지웠을 수 있어요.")
            }
        }
        .background(Color.oneLogCream)
        .navigationTitle("나눔 글")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: membershipKey) { shareStore.startMemberDetails(postID: postID) }
        .onDisappear { shareStore.stopChat() }
        .sheet(isPresented: $isMeetupEditorPresented) {
            MeetupEditor(
                postID: postID,
                existing: shareStore.meetup,
                legacyPlaceNote: post?.meetupNote ?? ""
            )
            .environmentObject(shareStore)
        }
    }

    private func content(_ post: SharePost) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        summary(post)
                        if post.isMember(userID) {
                            chat(post)
                        } else {
                            EmptyState(symbol: "lock", title: "참여하면 대화할 수 있어요", message: "만날 시간과 장소는 참여한 사람끼리만 이야기해요.")
                                .oneLogCard()
                        }
                    }
                    .padding(16)
                }
                .onChange(of: shareStore.messages.count) {
                    guard let last = shareStore.messages.last else { return }
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            if post.isMember(userID) {
                composer(post)
            }
        }
    }

    private func summary(_ post: SharePost) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: post.kind.symbolName)
                    .foregroundStyle(Color.oneLogGreen)
                Text("\(post.ingredientName) \(post.amountText)")
                    .font(.title3.weight(.black))
                    .foregroundStyle(Color.oneLogInk)
                Spacer(minLength: 8)
                StatusPill(text: post.status.label, tint: post.status == .open ? .oneLogGreen : .oneLogMuted)
            }
            Text(post.kind.explanation)
                .font(.caption)
                .foregroundStyle(Color.oneLogMuted)
            Divider().overlay(Color.oneLogLine)
            IngredientLine(name: "동네", value: post.neighborhood, note: nil)
            IngredientLine(name: "인원", value: "\(post.joinedCount)/\(post.capacity)명", note: nil)
            IngredientLine(name: "올린 사람", value: post.authorNickname, note: nil)
            if let price = post.pricePerShare {
                IngredientLine(name: "1인당", value: won(price), note: "송금은 직접")
            }
            meetupCard(post)
            actions(post)
        }
        .oneLogCard()
    }

    @ViewBuilder
    private func meetupCard(_ post: SharePost) -> some View {
        Divider().overlay(Color.oneLogLine)
        if post.isMember(userID) {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeading("약속", subtitle: "작성자와 참여자만 볼 수 있어요.")
                if let meetup = shareStore.meetup {
                    Label {
                        Text(meetup.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline.weight(.bold))
                    } icon: {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(Color.oneLogGreen)
                    }
                    Label(meetup.placeNote, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(Color.oneLogInk)
                } else if !post.meetupNote.isEmpty {
                    Label("기존 만남 메모", systemImage: "note.text")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.oneLogMuted)
                    Text(post.meetupNote)
                        .font(.subheadline)
                        .foregroundStyle(Color.oneLogInk)
                } else {
                    Text("아직 약속을 정하지 않았어요.")
                        .font(.caption)
                        .foregroundStyle(Color.oneLogMuted)
                }
                Button {
                    isMeetupEditorPresented = true
                } label: {
                    Label(shareStore.meetup == nil ? "약속 잡기" : "약속 수정", systemImage: "calendar")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("meetupEditorButton")
            }
            .padding(.top, 2)
        } else {
            Label("참여하면 약속 날짜·시간과 장소를 볼 수 있어요.", systemImage: "lock")
                .font(.caption)
                .foregroundStyle(Color.oneLogMuted)
                .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func actions(_ post: SharePost) -> some View {
        if post.authorID == userID {
            if post.status != .closed {
                Button {
                    Task { await shareStore.close(post) }
                } label: {
                    Label("모집 닫기", systemImage: "xmark.circle")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        } else if post.participantIDs.contains(userID) {
            Button {
                Task { await shareStore.leave(post) }
            } label: {
                Label("참여 취소", systemImage: "arrow.uturn.left")
            }
            .buttonStyle(SecondaryButtonStyle())
        } else if post.canJoin(userID: userID) {
            Button {
                Task { await shareStore.join(post) }
            } label: {
                Label("참여하기", systemImage: "hand.raised.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
        } else {
            Text(post.isFull ? "인원이 다 찼어요." : "지금은 참여할 수 없는 글이에요.")
                .font(.caption)
                .foregroundStyle(Color.oneLogMuted)
        }
    }

    private func chat(_ post: SharePost) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading("대화", subtitle: "만날 시간과 장소를 여기서 정해요.")
            if shareStore.messages.isEmpty {
                Text("아직 대화가 없어요. 먼저 인사해 보세요.")
                    .font(.caption)
                    .foregroundStyle(Color.oneLogMuted)
            } else {
                ForEach(shareStore.messages) { message in
                    ChatBubble(message: message, isMine: message.senderID == userID)
                        .id(message.id)
                }
            }
        }
        .oneLogCard()
    }

    private func composer(_ post: SharePost) -> some View {
        HStack(spacing: 10) {
            TextField("메시지 보내기", text: $messageText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .accessibilityIdentifier("chatField")
            Button {
                let text = messageText
                messageText = ""
                Task { await shareStore.send(text: text, postID: post.id, nickname: store.state.profile.nickname) }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(11)
                    .background(Color.oneLogGreen, in: Circle())
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("보내기")
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }
}

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
                    DatePicker(
                        "만날 날짜·시간",
                        selection: $scheduledAt,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                Section("장소") {
                    TextField("예: 성수역 2번 출구 앞", text: $placeNote, axis: .vertical)
                        .lineLimit(2...4)
                    Text("사람이 많은 공개된 장소를 이용하세요.")
                        .font(.caption)
                        .foregroundStyle(Color.oneLogMuted)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
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

private struct ChatBubble: View {
    let message: ShareMessage
    let isMine: Bool

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
            Text(isMine ? "나" : message.senderNickname)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.oneLogMuted)
            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(isMine ? .white : Color.oneLogInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isMine ? Color.oneLogGreen : Color.oneLogPaleGreen, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(Color.oneLogMuted)
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }
}
