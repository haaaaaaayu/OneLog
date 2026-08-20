import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions
import Foundation

/// F26·F27의 서버 연결. Firestore 문서 하나가 글 하나이고, 채팅은 그 글의 `messages` 하위 컬렉션이다.
///
/// `GoogleService-Info.plist`가 없으면 `FirebaseApp.configure()`가 실행되지 않으므로
/// 여기의 모든 동작은 조용히 실패하지 않고 `errorMessage`로 이유를 남긴다.
@MainActor
final class ShareStore: ObservableObject {
    static let notConfiguredMessage = "아직 동네 나눔 서버가 연결되지 않았어요. Firebase 설정 파일(GoogleService-Info.plist)을 앱에 넣어야 동작해요."

    @Published private(set) var posts: [SharePost] = []
    @Published private(set) var messages: [ShareMessage] = []
    @Published private(set) var meetup: ShareMeetup?
    @Published private(set) var requests: [ShareRequest] = []
    @Published private(set) var blockedUserIDs: Set<String> = []
    @Published private(set) var userID: String?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let db: Firestore?
    private var postsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    private var meetupListener: ListenerRegistration?
    private var authoredRequestsListener: ListenerRegistration?
    private var requestedRequestsListener: ListenerRegistration?
    private var blocksListener: ListenerRegistration?
    private var authoredRequests: [ShareRequest] = []
    private var requestedRequests: [ShareRequest] = []
    private var listeningNeighborhood: String?
    private var listeningPostID: String?
    private var listeningMeetupPostID: String?
    private var authListener: AuthStateDidChangeListenerHandle?
    private let isUITestFixture: Bool

    var isConfigured: Bool { db != nil }

    init() {
        isUITestFixture = ProcessInfo.processInfo.arguments.contains("-uiTestSharing")
        db = FirebaseApp.app() == nil ? nil : Firestore.firestore()
        if isUITestFixture {
            let now = Date()
            userID = "ui-author"
            posts = [SharePost(
                id: "ui-share-post",
                kind: .groupBuy,
                ingredientID: "egg",
                ingredientName: "달걀",
                amount: 10,
                unit: .count,
                neighborhood: "서울 성동구 성수동",
                coordinate: ShareCoordinate(latitude: 37.544, longitude: 127.056),
                meetupNote: "",
                pricePerShare: 3_500,
                authorID: "ui-author",
                authorNickname: "한끼",
                participantIDs: [],
                capacity: 2,
                status: .open,
                createdAt: now,
                expiresAt: now.addingTimeInterval(7 * 24 * 60 * 60)
            )]
            requests = [ShareRequest(
                id: "ui-share-request",
                postID: "ui-share-post",
                authorID: "ui-author",
                requesterID: "ui-neighbor",
                requesterNickname: "보리네",
                message: "달걀을 함께 나누고 싶어요.",
                status: .pending,
                createdAt: now,
                updatedAt: now
            )]
            messages = [ShareMessage(
                id: "ui-message",
                senderID: "ui-neighbor",
                senderNickname: "보리네",
                text: "오늘 저녁 7시 성수점 앞에서 만나요!",
                createdAt: now
            )]
            meetup = ShareMeetup(
                scheduledAt: now.addingTimeInterval(24 * 60 * 60),
                placeNote: "성수역 3번 출구 앞",
                updatedBy: "ui-neighbor",
                updatedAt: now
            )
            return
        }
        // 마이페이지에서 계정을 끊거나 다른 Google 계정으로 다시 로그인하면 uid가 바뀐다.
        // 세션 변화를 구독하지 않으면 `내 글` 판정이 이전 uid에 묶여, 남의 글에 참여 취소 버튼이 뜬다.
        guard FirebaseApp.app() != nil else { return }
        userID = Auth.auth().currentUser?.uid
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.applySession(uid: user?.uid) }
        }
    }

    deinit {
        postsListener?.remove()
        messagesListener?.remove()
        meetupListener?.remove()
        authoredRequestsListener?.remove()
        requestedRequestsListener?.remove()
        blocksListener?.remove()
        if let authListener { Auth.auth().removeStateDidChangeListener(authListener) }
    }

    /// uid가 바뀌면 이전 계정으로 열어 둔 채팅·약속 구독을 끊는다. 글 목록은 동네 단위라 그대로 둔다.
    private func applySession(uid: String?) {
        guard userID != uid else { return }
        userID = uid
        stopChat()
        stopPrivateListeners()
        if uid != nil { startPrivateListeners() }
    }

    private var postsCollection: CollectionReference? { db?.collection("sharePosts") }
    private var requestsCollection: CollectionReference? { db?.collection("shareRequests") }

    // MARK: - 연결

    /// 동네 글 구독을 시작한다. 동네가 바뀌면 구독을 갈아끼운다.
    func start(neighborhood: String) async {
        if isUITestFixture { return }
        let trimmed = neighborhood.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let postsCollection else {
            errorMessage = Self.notConfiguredMessage
            return
        }
        guard !trimmed.isEmpty else {
            stopPosts()
            errorMessage = "동네를 먼저 입력해 주세요. 같은 동네 글만 보여줘요."
            return
        }
        guard await ensureSignedIn() else { return }
        guard let db, let userID else { return }
        do {
            try await db.collection("users").document(userID).setData([
                "neighborhood": String(trimmed.prefix(30)),
                "nickname": String((Auth.auth().currentUser?.displayName ?? "").prefix(20)),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            errorMessage = "동네 접근 정보를 저장하지 못했어요. \(error.localizedDescription)"
            return
        }
        startPrivateListeners()
        guard listeningNeighborhood != trimmed || postsListener == nil else { return }

        stopPosts()
        errorMessage = nil
        listeningNeighborhood = trimmed
        isLoading = true
        // ponytail: 동등 조건 하나만 걸어 복합 인덱스 없이 돌린다. 정렬과 만료 제외는 클라이언트에서 한다.
        // 한 동네 글이 100건을 넘기기 시작하면 createdAt 정렬 + 복합 인덱스로 올린다.
        postsListener = postsCollection
            .whereField("neighborhood", isEqualTo: trimmed)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.errorMessage = "동네 글을 불러오지 못했어요. \(error.localizedDescription)"
                        return
                    }
                    self.posts = (snapshot?.documents ?? [])
                        .compactMap { try? $0.data(as: SharePost.self) }
                        .filter { !self.blockedUserIDs.contains($0.authorID) }
                }
            }
    }

    private func startPrivateListeners() {
        guard let db, let userID else { return }
        if authoredRequestsListener == nil {
            authoredRequestsListener = db.collection("shareRequests")
                .whereField("authorID", isEqualTo: userID)
                .limit(to: 100)
                .addSnapshotListener { [weak self] snapshot, _ in
                    Task { @MainActor [weak self] in
                        self?.authoredRequests = (snapshot?.documents ?? []).compactMap { try? $0.data(as: ShareRequest.self) }
                        self?.mergeRequests()
                    }
                }
        }
        if requestedRequestsListener == nil {
            requestedRequestsListener = db.collection("shareRequests")
                .whereField("requesterID", isEqualTo: userID)
                .limit(to: 100)
                .addSnapshotListener { [weak self] snapshot, _ in
                    Task { @MainActor [weak self] in
                        self?.requestedRequests = (snapshot?.documents ?? []).compactMap { try? $0.data(as: ShareRequest.self) }
                        self?.mergeRequests()
                    }
                }
        }
        if blocksListener == nil {
            blocksListener = db.collection("users").document(userID).collection("blocks")
                .addSnapshotListener { [weak self] snapshot, _ in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.blockedUserIDs = Set((snapshot?.documents ?? []).map(\.documentID))
                        self.posts.removeAll { self.blockedUserIDs.contains($0.authorID) }
                        self.messages.removeAll { self.blockedUserIDs.contains($0.senderID) }
                    }
                }
        }
    }

    private func mergeRequests() {
        requests = Dictionary(uniqueKeysWithValues: (authoredRequests + requestedRequests).map { ($0.id, $0) })
            .values.sorted { $0.createdAt > $1.createdAt }
    }

    private func stopPrivateListeners() {
        authoredRequestsListener?.remove(); authoredRequestsListener = nil
        requestedRequestsListener?.remove(); requestedRequestsListener = nil
        blocksListener?.remove(); blocksListener = nil
        authoredRequests = []; requestedRequests = []; requests = []; blockedUserIDs = []
    }

    /// 캐시한 `userID`를 믿지 않는다. 마이페이지에서 Google 계정을 연결하거나 끊으면 uid가 바뀐다.
    private func ensureSignedIn() async -> Bool {
        if let uid = Auth.auth().currentUser?.uid {
            userID = uid
            return true
        }
        do {
            userID = try await Auth.auth().signInAnonymously().user.uid
            return true
        } catch {
            errorMessage = "동네 나눔에 연결하지 못했어요. 잠시 후 다시 시도해 주세요."
            return false
        }
    }

    private func stopPosts() {
        postsListener?.remove()
        postsListener = nil
        listeningNeighborhood = nil
        posts = []
    }

    // MARK: - 글

    /// 저장 전에 길이·인원·금액을 여기서 자른다. Firestore 보안 규칙(`ios/firestore.rules`)이 같은 조건을 서버에서 한 번 더 막는다.
    @discardableResult
    func createPost(draft: ShareDraft, neighborhood: String, pricePerShare: Int?, capacity: Int, nickname: String, coordinate: ShareCoordinate? = nil) async -> Bool {
        guard let postsCollection else {
            errorMessage = Self.notConfiguredMessage
            return false
        }
        let place = neighborhood.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !place.isEmpty else {
            errorMessage = "동네를 입력해 주세요."
            return false
        }
        guard !name.isEmpty else {
            errorMessage = "마이페이지에서 닉네임을 먼저 정해 주세요. 모르는 사람과 만나는 글이라 이름 없이 올리지 않아요."
            return false
        }
        guard draft.amount.isFinite, draft.amount > 0 else {
            errorMessage = "나눌 양을 확인해 주세요."
            return false
        }
        guard await ensureSignedIn(), let userID else { return false }

        let now = Date()
        let post = SharePost(
            id: UUID().uuidString,
            kind: draft.kind,
            ingredientID: draft.ingredientID,
            ingredientName: draft.ingredientName,
            amount: draft.amount,
            unit: draft.unit,
            neighborhood: String(place.prefix(30)),
            // 도보 시간 표시용 대략 좌표(약 100m 격자). 권한을 거부하면 nil로 올라간다.
            coordinate: coordinate.flatMap { ShareCoordinate.rounded(latitude: $0.latitude, longitude: $0.longitude) },
            // 약속 정보는 공개 동네 글과 분리된 `meetup/details`에 저장한다.
            meetupNote: "",
            pricePerShare: pricePerShare.flatMap { (0...200_000).contains($0) ? $0 : nil },
            authorID: userID,
            authorNickname: String(name.prefix(20)),
            participantIDs: [],
            capacity: min(max(capacity, 2), 8),
            status: .open,
            createdAt: now,
            // ponytail: 모집 기간은 7일 고정. 사용자가 기간을 고르고 싶다는 요청이 나오면 그때 입력으로 뺀다.
            expiresAt: now.addingTimeInterval(7 * 24 * 60 * 60)
        )
        do {
            try postsCollection.document(post.id).setData(from: post)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "글을 올리지 못했어요. \(error.localizedDescription)"
            return false
        }
    }

    /// 참여 버튼은 즉시 멤버로 만들지 않고 작성자에게 승인 요청을 보낸다.
    @discardableResult
    func requestJoin(_ post: SharePost, message: String? = nil, nickname: String) async -> Bool {
        guard let requestsCollection else {
            errorMessage = Self.notConfiguredMessage
            return false
        }
        guard await ensureSignedIn(), let userID else { return false }
        guard post.canJoin(userID: userID) else {
            errorMessage = "이미 마감되었거나 참여할 수 없는 글이에요."
            return false
        }
        guard !requests.contains(where: { $0.postID == post.id && $0.requesterID == userID && $0.status == .pending }) else {
            errorMessage = "이미 응답을 기다리는 요청이 있어요."
            return false
        }
        let name = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultMessage = "(post.ingredientName)을 함께 나누고 싶어요."
        guard let safeMessage = CommunityContentPolicy.validate(message ?? defaultMessage, maximumLength: 300) else {
            errorMessage = "요청 메시지에 보낼 수 없는 표현이 있거나 너무 길어요."
            return false
        }
        let now = Date()
        let requestID = UUID().uuidString
        let request = ShareRequest(
            id: requestID, postID: post.id, authorID: post.authorID, requesterID: userID,
            requesterNickname: String((name.isEmpty ? "이웃" : name).prefix(20)),
            message: safeMessage, status: .pending, createdAt: now, updatedAt: now
        )
        do {
            try requestsCollection.document(requestID).setData(from: request)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "요청을 보내지 못했어요. \(error.localizedDescription)"
            return false
        }
    }

    func request(for postID: String, requesterID: String? = nil) -> ShareRequest? {
        requests.first {
            $0.postID == postID && (requesterID == nil || $0.requesterID == requesterID) && $0.status == .pending
        }
    }

    /// 작성자의 수락 시점에만 정원 확인과 멤버 추가를 원자적으로 수행한다.
    @discardableResult
    func accept(_ request: ShareRequest) async -> Bool {
        if isUITestFixture, userID == request.authorID, request.status == .pending {
            if let requestIndex = requests.firstIndex(where: { $0.id == request.id }) {
                requests[requestIndex].status = .accepted
                requests[requestIndex].updatedAt = Date()
            }
            if let postIndex = posts.firstIndex(where: { $0.id == request.postID }) {
                if !posts[postIndex].participantIDs.contains(request.requesterID) {
                    posts[postIndex].participantIDs.append(request.requesterID)
                }
                if posts[postIndex].participantIDs.count + 1 >= posts[postIndex].capacity {
                    posts[postIndex].status = .matched
                }
            }
            errorMessage = nil
            return true
        }
        guard FirebaseApp.app() != nil, userID == request.authorID else { return false }
        do {
            _ = try await Functions.functions(region: "us-central1").httpsCallable("respondShareRequest")
                .call(["requestID": request.id, "decision": "accepted"])
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func leave(_ post: SharePost) async {
        guard let postsCollection else {
            errorMessage = Self.notConfiguredMessage
            return
        }
        guard let userID, post.participantIDs.contains(userID) else { return }
        do {
            try await postsCollection.document(post.id).updateData([
                "participantIDs": FieldValue.arrayRemove([userID]),
                "status": ShareStatus.open.rawValue
            ])
            errorMessage = nil
        } catch {
            errorMessage = "참여를 취소하지 못했어요. \(error.localizedDescription)"
        }
    }

    func cancel(_ request: ShareRequest) async {
        guard let requestsCollection, userID == request.requesterID, request.status == .pending else { return }
        do {
            try await requestsCollection.document(request.id).updateData([
                "status": ShareRequestStatus.cancelled.rawValue, "updatedAt": Date()
            ])
            errorMessage = nil
        } catch { errorMessage = "요청을 취소하지 못했어요. \(error.localizedDescription)" }
    }

    /// 작성자만 닫는다. 서버 규칙에서도 작성자만 통과한다.
    func close(_ post: SharePost) async {
        guard let postsCollection else {
            errorMessage = Self.notConfiguredMessage
            return
        }
        guard userID == post.authorID else { return }
        do {
            try await postsCollection.document(post.id).updateData(["status": ShareStatus.closed.rawValue])
            errorMessage = nil
        } catch {
            errorMessage = "글을 닫지 못했어요. \(error.localizedDescription)"
        }
    }

    func reject(_ request: ShareRequest) async {
        guard FirebaseApp.app() != nil, userID == request.authorID, request.status == .pending else { return }
        do {
            _ = try await Functions.functions(region: "us-central1").httpsCallable("respondShareRequest")
                .call(["requestID": request.id, "decision": "rejected"])
            errorMessage = nil
        } catch {
            errorMessage = "요청을 거절하지 못했어요. \(error.localizedDescription)"
        }
    }

    @discardableResult
    func deletePost(_ post: SharePost) async -> Bool {
        guard userID == post.authorID, FirebaseApp.app() != nil else { return false }
        do {
            _ = try await Functions.functions(region: "us-central1").httpsCallable("deleteSharePost")
                .call(["postID": post.id])
            errorMessage = nil
            return true
        } catch {
            errorMessage = "글과 대화를 지우지 못했어요. \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func report(targetType: String, targetID: String, targetUserID: String, reason: ShareReportReason) async -> Bool {
        guard await ensureSignedIn() else { return false }
        do {
            _ = try await Functions.functions(region: "us-central1").httpsCallable("submitReport").call([
                "targetType": targetType,
                "targetID": targetID,
                "targetUserID": targetUserID,
                "reason": reason.rawValue
            ])
            errorMessage = "신고를 접수했어요. 운영정책에 따라 확인할게요."
            return true
        } catch {
            errorMessage = "신고를 접수하지 못했어요. \(error.localizedDescription)"
            return false
        }
    }

    func block(userID targetUserID: String) async {
        guard let db, await ensureSignedIn(), let userID, targetUserID != userID else { return }
        do {
            try await db.collection("users").document(userID).collection("blocks").document(targetUserID).setData([
                "blockedUserID": targetUserID,
                "createdAt": FieldValue.serverTimestamp()
            ])
            blockedUserIDs.insert(targetUserID)
            posts.removeAll { $0.authorID == targetUserID }
            messages.removeAll { $0.senderID == targetUserID }
            errorMessage = "이 사용자를 차단했어요. 글과 메시지가 더 이상 보이지 않아요."
        } catch { errorMessage = "차단하지 못했어요. \(error.localizedDescription)" }
    }

    // MARK: - 채팅·약속 (F27)

    /// 작성자·참여자일 때만 채팅과 약속 문서를 구독한다.
    /// 동네 글 본문은 목록을 위해 공개로 읽지만, 약속 정보는 별도 문서라 멤버만 접근할 수 있다.
    func startMemberDetails(postID: String) {
        if isUITestFixture { return }
        guard let postsCollection else {
            errorMessage = Self.notConfiguredMessage
            return
        }
        guard let userID,
              let post = posts.first(where: { $0.id == postID }),
              post.isMember(userID) else {
            stopChat()
            return
        }

        if listeningPostID != postID || messagesListener == nil {
            messagesListener?.remove()
            messagesListener = nil
            messages = []
            listeningPostID = postID
            messagesListener = postsCollection.document(postID).collection("messages")
                .order(by: "createdAt")
                .limit(toLast: 200)
                .addSnapshotListener { [weak self] snapshot, error in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if let error {
                            self.errorMessage = "대화를 불러오지 못했어요. \(error.localizedDescription)"
                            return
                        }
                        self.messages = (snapshot?.documents ?? [])
                            .compactMap { try? $0.data(as: ShareMessage.self) }
                            .filter { !self.blockedUserIDs.contains($0.senderID) }
                    }
                }
        }

        if meetupListener == nil || listeningMeetupPostID != postID {
            startMeetup(postID: postID, postsCollection: postsCollection)
        }
    }

    private func startMeetup(postID: String, postsCollection: CollectionReference) {
        meetupListener?.remove()
        meetupListener = nil
        meetup = nil
        listeningMeetupPostID = postID
        meetupListener = postsCollection.document(postID).collection("meetup").document("details")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = "약속 정보를 불러오지 못했어요. \(error.localizedDescription)"
                        self.meetup = nil
                        return
                    }
                    guard let snapshot, snapshot.exists else {
                        self.meetup = nil
                        return
                    }
                    self.meetup = try? snapshot.data(as: ShareMeetup.self)
                }
            }
    }

    func stopChat() {
        messagesListener?.remove()
        messagesListener = nil
        meetupListener?.remove()
        meetupListener = nil
        listeningPostID = nil
        listeningMeetupPostID = nil
        messages = []
        meetup = nil
    }

    @discardableResult
    func saveMeetup(postID: String, scheduledAt: Date, placeNote: String) async -> Bool {
        guard let postsCollection else {
            errorMessage = Self.notConfiguredMessage
            return false
        }
        guard await ensureSignedIn(), let userID,
              let post = posts.first(where: { $0.id == postID }),
              post.isMember(userID) else {
            errorMessage = "약속을 정할 수 있는 참여자만 저장할 수 있어요."
            return false
        }
        guard let place = CommunityContentPolicy.validate(placeNote, maximumLength: 200) else {
            errorMessage = "장소 메모를 확인해 주세요. 보낼 수 없는 표현이 있거나 너무 길어요."
            return false
        }
        guard scheduledAt > Date() else {
            errorMessage = "현재 시각 이후의 약속을 정해 주세요."
            return false
        }
        let meetup = ShareMeetup(
            scheduledAt: scheduledAt,
            placeNote: String(place.prefix(200)),
            updatedBy: userID,
            updatedAt: Date()
        )
        do {
            try postsCollection.document(postID).collection("meetup").document("details").setData(from: meetup)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "약속을 저장하지 못했어요. \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func clearMeetup(postID: String) async -> Bool {
        guard let postsCollection else {
            errorMessage = Self.notConfiguredMessage
            return false
        }
        guard await ensureSignedIn(), let userID,
              let post = posts.first(where: { $0.id == postID }),
              post.isMember(userID) else {
            errorMessage = "약속을 지울 수 있는 참여자만 변경할 수 있어요."
            return false
        }
        do {
            try await postsCollection.document(postID).collection("meetup").document("details").delete()
            errorMessage = nil
            return true
        } catch {
            errorMessage = "약속을 지우지 못했어요. \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func send(text: String, postID: String, nickname: String) async -> Bool {
        guard let postsCollection else {
            errorMessage = Self.notConfiguredMessage
            return false
        }
        guard let trimmed = CommunityContentPolicy.validate(text, maximumLength: 500) else {
            errorMessage = "메시지에 보낼 수 없는 표현이 있거나 너무 길어요."
            return false
        }
        guard await ensureSignedIn(), let userID else { return false }
        guard let post = posts.first(where: { $0.id == postID }), post.isMember(userID) else {
            errorMessage = "이 글에 참여한 이웃만 대화할 수 있어요."
            return false
        }
        let name = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = ShareMessage(
            id: UUID().uuidString,
            senderID: userID,
            senderNickname: String((name.isEmpty ? "이웃" : name).prefix(20)),
            text: String(trimmed.prefix(500)),
            createdAt: Date()
        )
        do {
            try postsCollection.document(postID).collection("messages").document(message.id).setData(from: message)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "메시지를 보내지 못했어요. \(error.localizedDescription)"
            return false
        }
    }
}
