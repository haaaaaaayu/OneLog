import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
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
    @Published private(set) var userID: String?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let db: Firestore?
    private var postsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    private var meetupListener: ListenerRegistration?
    private var listeningNeighborhood: String?
    private var listeningPostID: String?
    private var listeningMeetupPostID: String?

    var isConfigured: Bool { db != nil }

    init() {
        db = FirebaseApp.app() == nil ? nil : Firestore.firestore()
    }

    deinit {
        postsListener?.remove()
        messagesListener?.remove()
        meetupListener?.remove()
    }

    private var postsCollection: CollectionReference? { db?.collection("sharePosts") }

    // MARK: - 연결

    /// 동네 글 구독을 시작한다. 동네가 바뀌면 구독을 갈아끼운다.
    func start(neighborhood: String) async {
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
                    self.posts = (snapshot?.documents ?? []).compactMap { try? $0.data(as: SharePost.self) }
                }
            }
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

    /// 정원 초과를 막아야 해서 읽고 쓰는 사이를 트랜잭션으로 묶는다.
    func join(_ post: SharePost) async {
        guard let db, let postsCollection else {
            errorMessage = Self.notConfiguredMessage
            return
        }
        guard await ensureSignedIn(), let userID else { return }
        let ref = postsCollection.document(post.id)
        do {
            _ = try await db.runTransaction { transaction, errorPointer -> Any? in
                do {
                    let snapshot = try transaction.getDocument(ref)
                    var current = try snapshot.data(as: SharePost.self)
                    guard current.canJoin(userID: userID) else {
                        errorPointer?.pointee = NSError(domain: "OneLog.Share", code: 1, userInfo: [NSLocalizedDescriptionKey: "이미 마감되었거나 참여할 수 없는 글이에요."])
                        return nil
                    }
                    current.participantIDs.append(userID)
                    if current.isFull { current.status = .matched }
                    try transaction.setData(from: current, forDocument: ref)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                }
                return nil
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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

    // MARK: - 채팅·약속 (F27)

    /// 작성자·참여자일 때만 채팅과 약속 문서를 구독한다.
    /// 동네 글 본문은 목록을 위해 공개로 읽지만, 약속 정보는 별도 문서라 멤버만 접근할 수 있다.
    func startMemberDetails(postID: String) {
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
                        self.messages = (snapshot?.documents ?? []).compactMap { try? $0.data(as: ShareMessage.self) }
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
        let place = placeNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !place.isEmpty else {
            errorMessage = "만날 장소를 적어 주세요."
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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
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
