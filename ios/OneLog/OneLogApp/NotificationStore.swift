import CryptoKit
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

enum OneLogNotificationCategory: String, Codable {
    case shareRequest, chat, meal, shopping, savings, system

    var symbol: String {
        switch self {
        case .shareRequest: "🐻"
        case .chat: "💬"
        case .meal: "🍚"
        case .shopping: "🛒"
        case .savings: "💰"
        case .system: "✅"
        }
    }
}

struct OneLogNotification: Codable, Hashable, Identifiable {
    let id: String
    let category: OneLogNotificationCategory
    let title: String
    let body: String
    let createdAt: Date
    var isRead: Bool
    let postID: String?
}

@MainActor
final class NotificationStore: NSObject, ObservableObject {
    static let shared = NotificationStore()
    private static let storageKey = "onelog.notifications.v1"
    private static let tokenKey = "onelog.fcm.token"

    @Published private(set) var notifications: [OneLogNotification] = []
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var errorMessage: String?
    private var authListener: AuthStateDidChangeListenerHandle?

    var unreadCount: Int { notifications.lazy.filter { !$0.isRead }.count }
    var isAuthorized: Bool { authorizationStatus == .authorized || authorizationStatus == .provisional }

    override init() {
        super.init()
        load()
    }

    func start() {
        UNUserNotificationCenter.current().delegate = self
        guard FirebaseApp.app() != nil else { return }
        Messaging.messaging().delegate = self
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            Task { @MainActor in await self?.uploadStoredToken() }
        }
    }

    func refreshAuthorization() async {
        authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorization()
            if granted { UIApplication.shared.registerForRemoteNotifications() }
            errorMessage = granted ? nil : "알림 권한이 꺼져 있어요. 기기 설정에서 허용할 수 있어요."
            return granted
        } catch {
            errorMessage = "알림 권한을 요청하지 못했어요. 잠시 후 다시 시도해 주세요."
            return false
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func registerAPNSToken(_ token: Data) { Messaging.messaging().apnsToken = token }
    func reportRegistrationFailure(_ error: Error) { errorMessage = "푸시 알림 기기 등록에 실패했어요." }

    func ingest(userInfo: [AnyHashable: Any]) {
        let category = OneLogNotificationCategory(rawValue: userInfo["category"] as? String ?? "") ?? .system
        let alert = (userInfo["aps"] as? [String: Any])?["alert"] as? [String: Any]
        let title = userInfo["title"] as? String ?? alert?["title"] as? String ?? "한끼로그 알림"
        let body = userInfo["body"] as? String ?? alert?["body"] as? String ?? "새 소식이 있어요."
        insert(.init(
            id: userInfo["notificationID"] as? String ?? UUID().uuidString,
            category: category,
            title: String(title.prefix(80)),
            body: String(body.prefix(240)),
            createdAt: Date(),
            isRead: false,
            postID: userInfo["postID"] as? String
        ))
    }

    func markRead(_ id: String) {
        guard let index = notifications.firstIndex(where: { $0.id == id }), !notifications[index].isRead else { return }
        notifications[index].isRead = true
        persist()
    }

    func markAllRead() {
        guard unreadCount > 0 else { return }
        for index in notifications.indices { notifications[index].isRead = true }
        persist()
    }

    func clear() {
        notifications = []
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func reschedule(
        plannedMeals: [PlannedMeal],
        shoppingItems: [ShoppingPlanItem],
        purchaseChecks: [String: Bool],
        monthlySavings: Int
    ) async {
        await refreshAuthorization()
        guard isAuthorized else { return }
        let center = UNUserNotificationCenter.current()
        let managed = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("onelog.") }
        center.removePendingNotificationRequests(withIdentifiers: managed)

        if UserDefaults.standard.object(forKey: "notification.meals") as? Bool ?? true {
            for meal in plannedMeals where meal.status == .planned {
                guard let date = Self.reminderDate(day: meal.date, slot: meal.mealSlot), date > Date(),
                      let mealRecipe = recipe(for: meal.recipeID) else { continue }
                let content = UNMutableNotificationContent()
                content.title = "오늘 \(meal.mealSlot.rawValue) 식단"
                content.body = "\(mealRecipe.title), 이제 준비해 볼까요?"
                content.sound = .default
                content.userInfo = ["category": OneLogNotificationCategory.meal.rawValue]
                try? await center.add(.init(
                    identifier: "onelog.meal.\(meal.id)", content: content,
                    trigger: UNCalendarNotificationTrigger(
                        dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
                        repeats: false
                    )
                ))
            }
        }

        if UserDefaults.standard.object(forKey: "notification.shopping") as? Bool ?? false,
           shoppingItems.contains(where: { purchaseChecks[$0.id] != true }) {
            let content = UNMutableNotificationContent()
            content.title = "장보기 목록을 확인해 주세요"
            content.body = "아직 사지 않은 품목이 있어요. 필요한 수량을 확인해 보세요."
            content.sound = .default
            content.userInfo = ["category": OneLogNotificationCategory.shopping.rawValue]
            guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                  let date = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) else { return }
            try? await center.add(.init(
                identifier: "onelog.shopping.next", content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
                    repeats: false
                )
            ))
        }

        if UserDefaults.standard.object(forKey: "notification.savings") as? Bool ?? true, monthlySavings > 0 {
            let content = UNMutableNotificationContent()
            content.title = "확인된 재료 절감 요약"
            content.body = "이번 달 완료한 식사에서 확인된 절감액은 \(monthlySavings.formatted())원이에요."
            content.sound = .default
            content.userInfo = ["category": OneLogNotificationCategory.savings.rawValue]
            try? await center.add(.init(
                identifier: "onelog.savings.weekly", content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 19, weekday: 1), repeats: true)
            ))
        }
    }

    private func insert(_ value: OneLogNotification) {
        guard !notifications.contains(where: { $0.id == value.id }) else { return }
        notifications.insert(value, at: 0)
        notifications = Array(notifications.sorted { $0.createdAt > $1.createdAt }.prefix(100))
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let values = try? JSONDecoder().decode([OneLogNotification].self, from: data) else { return }
        notifications = values.sorted { $0.createdAt > $1.createdAt }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(notifications) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func uploadStoredToken() async {
        guard let token = UserDefaults.standard.string(forKey: Self.tokenKey) else { return }
        await upload(token: token)
    }

    func unregisterCurrentUserToken() async {
        guard FirebaseApp.app() != nil,
              let uid = Auth.auth().currentUser?.uid,
              let token = UserDefaults.standard.string(forKey: Self.tokenKey) else { return }
        let digest = SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
        try? await Firestore.firestore().collection("users").document(uid)
            .collection("devices").document(digest).delete()
    }

    private func upload(token: String) async {
        guard FirebaseApp.app() != nil, let uid = Auth.auth().currentUser?.uid else { return }
        let digest = SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
        do {
            try await Firestore.firestore().collection("users").document(uid)
                .collection("devices").document(digest)
                .setData(["token": token, "platform": "ios", "updatedAt": FieldValue.serverTimestamp()], merge: true)
            errorMessage = nil
        } catch {
            errorMessage = "푸시 알림 기기를 서버에 등록하지 못했어요."
        }
    }

    private static func reminderDate(day: String, slot: MealSlot) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let base = formatter.date(from: day) else { return nil }
        let hour: Int = switch slot { case .breakfast: 7; case .lunch: 11; case .dinner: 17 }
        return Calendar.current.date(bySettingHour: hour, minute: slot == .breakfast ? 30 : 0, second: 0, of: base)
    }
}

extension NotificationStore: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        await MainActor.run { ingest(userInfo: notification.request.content.userInfo) }
        return [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run { ingest(userInfo: response.notification.request.content.userInfo) }
    }
}

extension NotificationStore: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }
        Task { @MainActor in
            UserDefaults.standard.set(fcmToken, forKey: Self.tokenKey)
            await upload(token: fcmToken)
        }
    }
}
