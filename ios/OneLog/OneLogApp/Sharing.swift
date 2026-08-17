import Foundation

// F26 공동구매·소분, F27 채팅의 순수 도메인. 여기에는 네트워크 코드를 두지 않는다.
// `같이 사기`와 `나눠 쓰기`는 "한 포장을 여러 명이 나눈다"는 같은 구조라 한 모델로 둔다.
// 다른 것은 시점뿐이다: 사기 전이면 같이 사기, 산 뒤 남으면 나눠 쓰기.

enum ShareKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case groupBuy
    case split

    var id: String { rawValue }

    var label: String {
        switch self {
        case .groupBuy: return "같이 사기"
        case .split: return "나눠 쓰기"
        }
    }

    var symbolName: String {
        switch self {
        case .groupBuy: return "cart.badge.plus"
        case .split: return "rectangle.split.2x1"
        }
    }

    var explanation: String {
        switch self {
        case .groupBuy: return "아직 안 샀어요. 한 포장을 같이 사서 나눌 사람을 찾아요."
        case .split: return "이미 샀는데 남아요. 남는 양을 나눌 사람을 찾아요."
        }
    }
}

enum ShareStatus: String, Codable, Hashable {
    case open
    case matched
    case closed

    var label: String {
        switch self {
        case .open: return "모집 중"
        case .matched: return "인원 마감"
        case .closed: return "종료"
        }
    }
}

struct SharePost: Codable, Identifiable, Hashable {
    var id: String
    var kind: ShareKind
    var ingredientID: String
    var ingredientName: String
    /// 나눌 수 있는 양. 판매 단위가 확인된 재료에서만 계산된 값을 채운다.
    var amount: Double
    var unit: Unit
    /// 사용자가 직접 적은 동네 이름. GPS·위치 인증을 쓰지 않는다(F25 미확정, AGENTS 3절 10항).
    var neighborhood: String
    /// 예전 버전에서 글에 저장하던 만남 메모. 새 약속은 `meetup/details` 하위 문서에 저장한다.
    /// 기존 Firestore 문서와의 하위 호환을 위해 남겨 둔다.
    var meetupNote: String
    /// 1인당 나눠 낼 금액. 표시용이며 앱 안에서 송금하지 않는다.
    var pricePerShare: Int?
    var authorID: String
    var authorNickname: String
    var participantIDs: [String]
    /// 작성자를 포함한 총 인원.
    var capacity: Int
    var status: ShareStatus
    var createdAt: Date
    var expiresAt: Date

    /// 작성자도 한 명으로 센다.
    var joinedCount: Int { participantIDs.count + 1 }
    var isFull: Bool { joinedCount >= capacity }

    func isExpired(now: Date = Date()) -> Bool { expiresAt <= now }

    func isVisible(now: Date = Date()) -> Bool { status != .closed && !isExpired(now: now) }

    func canJoin(userID: String, now: Date = Date()) -> Bool {
        isVisible(now: now) && !isFull && userID != authorID && !participantIDs.contains(userID)
    }

    /// 작성자와 참여자만 채팅에 들어간다.
    func isMember(_ userID: String) -> Bool { userID == authorID || participantIDs.contains(userID) }

    var amountText: String { formatQuantity(amount, unit: unit) }
}

/// 작성자·참여자만 읽고 수정할 수 있는 약속 정보.
/// 글 목록 문서와 분리해 동네의 다른 사용자는 날짜·장소를 볼 수 없다.
struct ShareMeetup: Codable, Hashable {
    var scheduledAt: Date
    var placeNote: String
    var updatedBy: String
    var updatedAt: Date
}

struct ShareMessage: Codable, Identifiable, Hashable {
    var id: String
    var senderID: String
    var senderNickname: String
    var text: String
    var createdAt: Date
}

struct ShareMatch: Identifiable, Hashable {
    let post: SharePost
    let score: Int
    let reasons: [String]

    var id: String { post.id }
    var isRelevant: Bool { score > 0 }
}

/// 글 작성 화면을 미리 채우는 데 쓰는 후보.
struct ShareDraft: Identifiable, Hashable {
    let kind: ShareKind
    let ingredientID: String
    let ingredientName: String
    let amount: Double
    let unit: Unit
    let reason: String

    var id: String { "\(kind.rawValue):\(ingredientID):\(unit.rawValue)" }
}

/// 이번 장보기 계산에서 나눌 만한 재료를 뽑는다.
///
/// 판매 단위가 확인되지 않은 재료(`precision == .manual`)는 남는 양 자체가 추정이 아니라 미상이므로 제외한다.
/// 남는 양이 실제로 살 양보다 많으면 한 포장이 과한 경우라 `같이 사기`, 그보다 적으면 `나눠 쓰기`로 제안한다.
func shareDrafts(from items: [ShoppingPlanItem]) -> [ShareDraft] {
    items.compactMap { item in
        guard item.precision != .manual,
              item.additionalNeeded > 0,
              let remaining = item.expectedRemaining,
              remaining > 0 else { return nil }
        let kind: ShareKind = remaining >= item.additionalNeeded ? .groupBuy : .split
        let reason = kind == .groupBuy
            ? "한 포장이 필요량보다 \(formatQuantity(remaining, unit: item.unit)) 많아요. 같이 사면 나눠 떨어져요."
            : "\(formatQuantity(remaining, unit: item.unit)) 남을 예정이에요."
        return ShareDraft(kind: kind, ingredientID: item.ingredientID, ingredientName: item.ingredientName, amount: remaining, unit: item.unit, reason: reason)
    }
    .sorted { $0.ingredientName < $1.ingredientName }
}

/// 동네 글을 내 장보기 목록 기준으로 정렬한다.
///
/// 점수 근거는 하나뿐이다: **이번 장보기에서 실제로 사야 하는 재료인가**.
/// 그 외의 친밀도·평점 같은 지표는 근거 데이터가 없어 만들지 않는다(AGENTS 3절 8항).
func rankSharePosts(
    _ posts: [SharePost],
    shoppingItems: [ShoppingPlanItem],
    dislikedIngredientIDs: Set<String> = [],
    myUserID: String,
    now: Date = Date()
) -> [ShareMatch] {
    let needIDs = Set(shoppingItems.filter { $0.additionalNeeded > 0 }.map(\.ingredientID))

    return posts
        .filter { $0.isVisible(now: now) && $0.authorID != myUserID && !dislikedIngredientIDs.contains($0.ingredientID) }
        .map { post -> ShareMatch in
            var score = 0
            var reasons: [String] = []
            if needIDs.contains(post.ingredientID) {
                score += 50
                reasons.append(post.kind == .groupBuy
                    ? "이번 장보기에서 살 재료예요. 같이 사면 남는 양이 줄어요."
                    : "이번 장보기에서 살 재료예요. 나눠 받으면 안 사도 될 수 있어요.")
                if post.expiresAt.timeIntervalSince(now) <= 24 * 60 * 60 {
                    score += 10
                    reasons.append("오늘 안에 마감돼요.")
                }
            }
            return ShareMatch(post: post, score: score, reasons: reasons)
        }
        .sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.post.createdAt > $1.post.createdAt
        }
}
