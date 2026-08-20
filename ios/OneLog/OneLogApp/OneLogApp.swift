import FirebaseCore
import FirebaseAuth
import FirebaseAppCheck
import FirebaseMessaging
import GoogleSignIn
import SwiftUI
import UIKit

private final class OneLogAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
#if DEBUG || targetEnvironment(simulator)
        return AppCheckDebugProvider(app: app)
#else
        return AppAttestProvider(app: app)
#endif
    }
}

#if DEBUG
/// Personal Team 기기 빌드가 App Check debug provider를 쓸 때만 사용한다.
/// 토큰은 최초 `devicectl` 실행 인자로 받아 기기 로컬에 저장하며 소스·로그에는 남기지 않는다.
private func configureLocalAppCheckDebugToken() {
    let storageKey = "onelog.debug.appcheck.token"
    // AppCheckCore가 로컬 debug token을 읽는 실제 NSUserDefaults 키다.
    // 런타임 `setenv`는 ProcessInfo 환경 캐시 뒤에 적용될 수 있어 실기기에서
    // raw placeholder가 callable로 전달되는 문제가 있었다.
    let sdkStorageKey = "GACAppCheckDebugToken"
    let argument = "-onelogAppCheckDebugToken"
    let arguments = ProcessInfo.processInfo.arguments
    var token = UserDefaults.standard.string(forKey: storageKey)
    if let index = arguments.firstIndex(of: argument), arguments.indices.contains(index + 1) {
        let candidate = arguments[index + 1]
        if UUID(uuidString: candidate) != nil {
            UserDefaults.standard.set(candidate, forKey: storageKey)
            token = candidate
        }
    }
    if let token {
        UserDefaults.standard.set(token, forKey: sdkStorageKey)
    }
}

#endif

private func configureFirebaseIfAvailable() {
    guard FirebaseApp.app() == nil,
          Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else { return }
#if DEBUG
    configureLocalAppCheckDebugToken()
#endif
    AppCheck.setAppCheckProviderFactory(OneLogAppCheckProviderFactory())
    FirebaseApp.configure()
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureFirebaseIfAvailable()
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        NotificationStore.shared.start()
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        guard FirebaseApp.app() != nil else { return false }
        return Auth.auth().canHandle(url)
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationStore.shared.registerAPNSToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationStore.shared.reportRegistrationFailure(error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        NotificationStore.shared.ingest(userInfo: userInfo)
        completionHandler(.newData)
    }
}

@main
struct OneLogApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()
    @StateObject private var shareStore: ShareStore
    @StateObject private var notificationStore: NotificationStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FigmaFont.register()
        // 설정 파일이 없으면 `configure()`가 앱을 죽인다. 동네 나눔만 비활성으로 두고 나머지 흐름은 그대로 쓴다.
        configureFirebaseIfAvailable()
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        _shareStore = StateObject(wrappedValue: ShareStore())
        _notificationStore = StateObject(wrappedValue: NotificationStore.shared)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(shareStore)
                .environmentObject(notificationStore)
                // SwiftUI 앱 생명주기에서는 Firebase Auth의 자동 URL 전달이
                // 기기·OS 조합에 따라 누락될 수 있다. OAuth 콜백을 명시적으로 넘긴다.
                .onOpenURL { url in
                    if GIDSignIn.sharedInstance.handle(url) {
                        return
                    }
                    guard FirebaseApp.app() != nil else { return }
                    _ = Auth.auth().canHandle(url)
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await notificationStore.refreshAuthorization() }
                }
        }
    }
}
