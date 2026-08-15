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
    @Published private(set) var userID: String?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let db: Firestore?
    private var postsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    private var listeningNeighborhood: String?
    private var listeningPostID: String?

    var isConfigured: Bool { db != nil }

    init() {
        db = FirebaseApp.app() == nil ? nil : Firestore.firestore()
    }

    deinit {
        postsListener?.remove()
        messagesListener?.remove()
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

    private func ensureSignedIn() async -> Bool {
        if let userID, !userID.isEmpty { return true }
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
    func createPost(draft: ShareDraft, neighborhood: String, meetupNote: String, pricePerShare: Int?, capacity: Int, nickname: String) async -> Bool {
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
            meetupNote: String(meetupNote.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)),
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
        } catch {
            errorMessage = "글을 닫지 못했어요. \(error.localizedDescription)"
        }
    }

    // MARK: - 채팅 (F27)

    func startChat(postID: String) {
        guard let postsCollection else {
            errorMessage = Self.notConfiguredMessage
            return
        }
        guard listeningPostID != postID || messagesListener == nil else { return }
        stopChat()
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

    func stopChat() {
        messagesListener?.remove()
        messagesListener = nil
        listeningPostID = nil
        messages = []
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
            return true
        } catch {
            errorMessage = "메시지를 보내지 못했어요. \(error.localizedDescription)"
            return false
        }
    }
}
