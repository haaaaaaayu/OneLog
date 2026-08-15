import FirebaseCore
import SwiftUI

@main
struct OneLogApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var shareStore: ShareStore

    init() {
        // 설정 파일이 없으면 `configure()`가 앱을 죽인다. 동네 나눔만 비활성으로 두고 나머지 흐름은 그대로 쓴다.
        if FirebaseApp.app() == nil, Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
        }
        _shareStore = StateObject(wrappedValue: ShareStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(shareStore)
        }
    }
}
