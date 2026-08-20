import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFunctions
import FirebaseFirestore
import Foundation
import GoogleSignIn
import UIKit

private struct PersistedEnvelope: Codable {
    let version: Int
    let state: AppState
}

@MainActor
final class AppStore: ObservableObject {
    private static let storageKey = "onelog.native.state.v1"

    @Published private(set) var state: AppState
    @Published var notice: String?
    /// 계정 연동 실패 사유. 온보딩과 마이페이지에서 재시도 안내로 보여준다.
    @Published var accountError: String?
    private var isRestoringCloudState = false
    private var cloudUploadTask: Task<Void, Never>?

    init() {
        // UI 테스트가 온보딩부터 다시 확인할 수 있도록 저장 상태를 비운다.
        if ProcessInfo.processInfo.arguments.contains("-uiTestResetState") {
            // 시뮬레이터는 앱 컨테이너 밖(기기 단위 Preferences)에 값을 남겨 두기도 한다.
            // 키 하나만 지우면 예전 실행의 상태가 살아남아 테스트가 온보딩부터 시작하지 못한다.
            if let identifier = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: identifier)
            }
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
            UserDefaults.standard.synchronize()
        }
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let envelope = try? JSONDecoder().decode(PersistedEnvelope.self, from: data),
           envelope.version == 1 {
            state = Self.sanitize(envelope.state)
        } else {
            state = AppState()
        }
    }

    var plannedMeals: [PlannedMeal] {
        state.plannedMeals.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.mealSlot != $1.mealSlot { return MealSlot.allCases.firstIndex(of: $0.mealSlot)! < MealSlot.allCases.firstIndex(of: $1.mealSlot)! }
            return $0.createdAt < $1.createdAt
        }
    }

    var currentShoppingItems: [ShoppingPlanItem] {
        calculateShoppingPlan(requirements: aggregateRequirements(for: state.plannedMeals), inventory: state.inventory, packageOverrides: state.packageOverrides)
    }

    /// 사용자 입력이 아닌 앱 가격 카탈로그. 식단·장보기·절약 계산은 모두 같은 스냅샷을 쓴다.
    var ingredientPrices: [String: IngredientPrice] { bundledIngredientPrices }

    /// 이번 달에 실제 완료한 식사에서, 보유 재료 덕분에 덜 산 확인 가격 기준 포장 금액.
    var monthlyConfirmedSavings: Int {
        let prefix = String(isoDateString().prefix(7))
        return state.completions
            .filter { $0.completedAt.hasPrefix(prefix) }
            .compactMap(\.confirmedInventorySavings)
            .reduce(0, +)
    }

    var cookedMealsThisMonth: Int {
        let prefix = String(isoDateString().prefix(7))
        return state.completions.filter { $0.completedAt.hasPrefix(prefix) }.count
    }

    func estimate(for drafts: [PlannedMealDraft], targetBudget: Int) -> BudgetEstimate {
        budgetEstimate(drafts: drafts, targetBudget: targetBudget, inventory: state.inventory, prices: ingredientPrices, packageOverrides: state.packageOverrides)
    }

    func save() {
        let envelope = PersistedEnvelope(version: 1, state: state)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
        scheduleCloudUpload()
    }

    func clearNotice() {
        notice = nil
    }

    func completeOnboarding() {
        guard !state.hasCompletedOnboarding else { return }
        update { $0.hasCompletedOnboarding = true }
    }

    // MARK: - 계정 (F23)

    /// Google Sign-In SDK가 사용하는 URL 스킴. `GoogleService-Info.plist`의 CLIENT_ID를 역순으로 만든 값이다.
    private var googleCallbackScheme: String? {
        guard let options = FirebaseApp.app()?.options else { return nil }
        if let clientID = options.clientID {
            let reversed = clientID.components(separatedBy: ".").reversed().joined(separator: ".")
            if Self.registeredURLSchemes.contains(reversed) { return reversed }
        }
        return "app-" + options.googleAppID.replacingOccurrences(of: ":", with: "-")
    }

    private static var registeredURLSchemes: [String] {
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        return types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
    }

    /// URL scheme 또는 Google client ID가 빠진 경우 Google SDK를 열지 않는다.
    var isGoogleSignInConfigured: Bool {
        guard let options = FirebaseApp.app()?.options,
              let clientID = options.clientID,
              !clientID.isEmpty,
              let scheme = googleCallbackScheme else { return false }
        return Self.registeredURLSchemes.contains(scheme)
    }

    func signInWithGoogle() async {
        // UI 테스트는 실제 웹 로그인 창을 띄울 수 없다. 실패 화면만 결정론적으로 확인한다.
        guard !ProcessInfo.processInfo.arguments.contains("-uiTestGoogleSignInFails") else {
            accountError = "Google 로그인 연결을 확인하지 못했어요. 잠시 후 다시 시도해 주세요."
            return
        }
        guard isGoogleSignInConfigured else {
            accountError = "아직 Google 로그인을 연결할 수 없어요. 지금은 이 기기에만 저장하고 시작한 뒤, 나중에 마이페이지에서 계정을 연결할 수 있어요."
            return
        }
        do {
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw NSError(domain: "OneLog.GoogleSignIn", code: 1, userInfo: [NSLocalizedDescriptionKey: "Google client ID가 없습니다."])
            }
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            guard let presentingViewController = Self.presentingViewController() else {
                throw NSError(domain: "OneLog.GoogleSignIn", code: 2, userInfo: [NSLocalizedDescriptionKey: "로그인 화면을 표시할 앱 화면을 찾지 못했습니다."])
            }
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw NSError(domain: "OneLog.GoogleSignIn", code: 3, userInfo: [NSLocalizedDescriptionKey: "Google ID token을 받지 못했습니다."])
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let user = try await authenticate(with: credential).user
            await connectGoogleAccount(UserAccount(
                provider: .google,
                userID: user.uid,
                email: user.email,
                displayName: user.displayName,
                linkedAt: ISO8601DateFormatter().string(from: Date())
            ))
        } catch let error as NSError where error.code == -5 || error.code == AuthErrorCode.webContextCancelled.rawValue {
            // GoogleSignIn의 공개 헤더에서 취소는 kGIDSignInErrorCodeCanceled(-5)다.
            accountError = nil
        } catch let error as NSError {
            // Google Sign-In can fail before Firebase receives a credential. Keep the public
            // message friendly, but expose a small DEBUG-only diagnostic for device QA.
            print("[GoogleSignIn] domain=\(error.domain) code=\(error.code) message=\(error.localizedDescription)")
#if DEBUG
            accountError = "Google 로그인 오류 (\(error.code))\n\(error.localizedDescription)"
#else
            accountError = "Google 로그인을 마치지 못했어요. 잠시 후 다시 시도해 주세요."
#endif
        } catch {
            print("[GoogleSignIn] error=\(error.localizedDescription)")
            accountError = "Google 로그인을 마치지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }

    private static func presentingViewController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
        let root = windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? windows.first?.rootViewController
        return topViewController(from: root)
    }

    private static func topViewController(from viewController: UIViewController?) -> UIViewController? {
        if let presented = viewController?.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigation = viewController as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }
        if let tab = viewController as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        return viewController
    }

    /// 이미 익명으로 쓰고 있었다면 그 계정 위에 연결한다. 동네 나눔 글의 작성자·참여자 ID가 그대로 유지된다.
    /// 그 Google 계정이 이미 다른 사용자에 붙어 있으면 그쪽으로 로그인한다(기기에 저장한 식단은 그대로 남는다).
    private func authenticate(with credential: AuthCredential) async throws -> AuthDataResult {
        if let current = Auth.auth().currentUser, current.isAnonymous {
            do {
                return try await current.link(with: credential)
            } catch let error as NSError where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                return try await Auth.auth().signIn(with: credential)
            }
        }
        return try await Auth.auth().signIn(with: credential)
    }

    func linkAccount(_ account: UserAccount) {
        update { state in
            state.account = account
            // Google 이름을 받아 두고도 쓰지 않으면 로그인한 사용자도 계속 `회원님`으로 불린다.
            // 아직 닉네임을 정하지 않았을 때만 채우고, 직접 적은 이름은 덮어쓰지 않는다.
            if state.profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let displayName = account.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !displayName.isEmpty {
                state.profile.nickname = displayName
            }
        }
        accountError = nil
        notice = account.provider == .google ? "Google 계정을 연결했어요." : "이 기기에만 저장하도록 시작했어요."
    }

    /// Google 계정의 최신 백업이 있으면 내려받고, 없으면 현재 기기 상태를 첫 백업으로 올린다.
    private func connectGoogleAccount(_ account: UserAccount) async {
        guard FirebaseApp.app() != nil else { linkAccount(account); return }
        isRestoringCloudState = true
        defer { isRestoringCloudState = false }
        do {
            let ref = Firestore.firestore().collection("users").document(account.userID)
                .collection("private").document("appState")
            let snapshot = try await ref.getDocument()
            if let json = snapshot.data()?["stateJSON"] as? String,
               let data = json.data(using: .utf8),
               var restored = try? JSONDecoder().decode(AppState.self, from: data) {
                restored.account = account
                state = Self.sanitize(restored)
                let envelope = PersistedEnvelope(version: 1, state: state)
                if let local = try? JSONEncoder().encode(envelope) {
                    UserDefaults.standard.set(local, forKey: Self.storageKey)
                }
                notice = "Google 계정의 식단·재고 백업을 불러왔어요."
            } else {
                linkAccount(account)
                isRestoringCloudState = false
                scheduleCloudUpload()
            }
            accountError = nil
        } catch {
            // 네트워크가 끊겨도 로그인 자체와 로컬 데이터는 잃지 않는다. 다음 저장 때 업로드를 재시도한다.
            linkAccount(account)
            accountError = "Google 계정은 연결했지만 백업 동기화는 잠시 후 다시 시도할게요."
        }
    }

    private func scheduleCloudUpload() {
        guard !isRestoringCloudState,
              state.account?.provider == .google,
              let uid = Auth.auth().currentUser?.uid,
              let data = try? JSONEncoder().encode(state),
              data.count < 900_000,
              let json = String(data: data, encoding: .utf8) else { return }
        cloudUploadTask?.cancel()
        cloudUploadTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            do {
                try await Firestore.firestore().collection("users").document(uid)
                    .collection("private").document("appState").setData([
                        "schemaVersion": 1,
                        "stateJSON": json,
                        "updatedAt": FieldValue.serverTimestamp()
                    ])
            } catch {
                print("[CloudSync] upload failed: \(error.localizedDescription)")
            }
        }
    }

    /// 저장한 계정과 Firebase 세션이 어긋난 상태를 정리한다.
    ///
    /// UserDefaults는 iCloud 백업에서 복원되지만 Keychain의 Firebase 세션은 따라오지 않는 기기가 있다.
    /// 그대로 두면 마이페이지는 `Google 계정으로 연동됨`이라고 하는데 동네 나눔은 익명 uid로 글을 올려서,
    /// 내가 쓴 글이 남의 글처럼 보이고 참여 취소도 되지 않는다.
    func reconcileAccountSession() {
        guard FirebaseApp.app() != nil,
              let account = state.account,
              account.provider == .google,
              Auth.auth().currentUser == nil else { return }
        update { $0.account = nil }
        accountError = "Google 세션이 만료됐어요. 마이페이지에서 계정을 다시 연결해 주세요."
    }

    func useDeviceOnlyAccount() {
        linkAccount(UserAccount(provider: .deviceOnly, userID: UUID().uuidString, email: nil, displayName: nil, linkedAt: ISO8601DateFormatter().string(from: Date())))
    }

    /// 연결만 해제한다. 기기에 저장한 식단·재고 데이터는 그대로 둔다.
    func unlinkAccount() {
        guard state.account != nil else { return }
        Task {
            await NotificationStore.shared.unregisterCurrentUserToken()
            signOutOfFirebase()
            update { $0.account = nil }
            accountError = nil
            notice = "계정 연결을 해제했어요. 이 기기에 저장한 식단과 재고는 그대로예요."
        }
    }

    /// 탈퇴. 서버 계정까지 지우고, 이 기기에 저장한 모든 데이터를 지운 뒤 온보딩부터 다시 시작한다.
    ///
    /// 서버 삭제가 실패해도(재인증 요구·네트워크 오류) 이 기기 데이터는 반드시 지운다.
    /// 사용자가 `모두 지우기`를 눌렀는데 기기에 기록이 남는 쪽이 더 나쁘다.
    func deleteAllData() async {
        let remoteDeleted = await deleteRemoteAccount()
        guard remoteDeleted else {
            notice = "서버 데이터를 지우지 못했어요. 네트워크를 확인한 뒤 다시 시도해 주세요. 기기 데이터는 안전하게 남겨 뒀어요."
            return
        }
        signOutOfFirebase()
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        NotificationStore.shared.clear()
        state = AppState()
        accountError = nil
        notice = "계정, 동네 글·대화와 이 기기에 저장한 데이터를 모두 지웠어요."
    }

    /// Admin callable이 글 하위 대화·약속·요청·푸시 토큰을 재귀 삭제한 뒤 Auth 계정을 지운다.
    private func deleteRemoteAccount() async -> Bool {
        guard FirebaseApp.app() != nil, Auth.auth().currentUser != nil else { return true }
        do {
            _ = try await Functions.functions(region: "us-central1").httpsCallable("deleteAccount").call()
            return true
        } catch {
            print("[Account] delete failed: \(error.localizedDescription)")
            return false
        }
    }

    /// 계정을 끊으면 서버 세션도 끊는다. 다음에 동네 나눔을 열면 익명으로 새로 로그인한다.
    ///
    /// Firebase만 로그아웃하면 GoogleSignIn SDK에 이전 계정이 남아, 다시 `Google 계정으로 시작하기`를
    /// 눌렀을 때 계정 선택 창 없이 끊었던 계정으로 되돌아간다. 두 세션을 함께 끊어야 계정을 바꿀 수 있다.
    private func signOutOfFirebase() {
        GIDSignIn.sharedInstance.signOut()
        guard FirebaseApp.app() != nil else { return }
        try? Auth.auth().signOut()
    }

    func setProfile(nickname: String, age: Int?) {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeAge = age.flatMap { (14...120).contains($0) ? $0 : nil }
        update { state in
            state.profile.nickname = String(trimmed.prefix(20))
            state.profile.age = safeAge
        }
        notice = "프로필을 저장했어요."
    }

    /// 피그마 `첫가입 / 1. 기본정보`(350:2256)와 `내 정보 수정`(395:23)이 함께 쓰는 저장 경로.
    /// 생년월일은 `YYYY-MM-DD` 형식일 때만 저장하고, 동네는 사용자가 적은 문자열만 남긴다(좌표·위치 권한 없음).
    @discardableResult
    func setBasicProfile(nickname: String, birthDate: String, neighborhood: String, skill: CookingSkill?, cookTime: CookTimePreference?, notify: Bool = true) -> Bool {
        let trimmedNickname = String(nickname.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        let trimmedNeighborhood = String(neighborhood.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
        let safeBirthDate = Self.normalizedBirthDate(birthDate)
        if !birthDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, safeBirthDate == nil {
            notice = "생년월일을 YYYY.MM.DD 형식의 실제 날짜로 입력해 주세요."
            return false
        }
        let neighborhoodChanged = state.profile.neighborhood != trimmedNeighborhood
        update { state in
            state.profile.nickname = trimmedNickname
            state.profile.birthDate = safeBirthDate ?? ""
            state.profile.neighborhood = trimmedNeighborhood
            if neighborhoodChanged { state.profile.coordinate = nil }
            state.preferences.cookingSkill = skill
            state.preferences.preferredCookTime = cookTime
        }
        if notify { notice = "기본 정보를 저장했어요." }
        return true
    }

    /// 불호 재료 칩 선택. 재료 사전에 있으면 ID로, 없으면 이름 그대로 남긴다.
    func setDislikedIngredientNames(_ names: Set<String>, notify: Bool = true) {
        let split = Self.splitByCatalog(names)
        update { state in
            state.preferences.dislikedIngredientIDs = split.ids
            state.preferences.customDislikedNames = split.names
        }
        if notify { notice = "안 좋아하는 재료를 저장했어요. 이미 담은 식사는 지우지 않았어요." }
    }

    /// 알레르기·못 먹는 재료. 자동 추천에서 완전히 제외한다.
    func setAllergyIngredientNames(_ names: Set<String>, notify: Bool = true) {
        let split = Self.splitByCatalog(names)
        let groupedNames = names.filter(isGroupedAvoidanceName)
        update { state in
            state.preferences.allergyIngredientIDs = split.ids
            // `견과류`처럼 재료 사전에 같은 이름이 있어도 분류 전체 규칙을 함께 유지한다.
            state.preferences.customAllergyNames = split.names.union(groupedNames)
        }
        if notify { notice = "알레르기 재료를 저장했어요. 추천에서 완전히 빼드릴게요." }
    }

    func setAvailableTools(_ tools: Set<CookingTool>, notify: Bool = true) {
        // 화면에 없는 도구(칼·볼)는 항상 보유로 두어 기존 레시피 추천이 끊기지 않게 한다.
        let hidden = Set(CookingTool.allCases).subtracting(CookingTool.selectable)
        update { $0.preferences.availableTools = tools.intersection(CookingTool.selectable).union(hidden) }
        if notify { notice = "보유 조리도구를 저장했어요." }
    }

    /// 화면에 보여줄 불호 재료 칩. 디자인 기본 목록 + 사용자가 이미 고른 재료.
    var dislikedIngredientNames: Set<String> {
        Set(state.preferences.dislikedIngredientIDs.compactMap { ingredient(for: $0)?.name })
            .union(state.preferences.customDislikedNames)
    }

    var allergyIngredientNames: Set<String> {
        Set(state.preferences.allergyIngredientIDs.compactMap { ingredient(for: $0)?.name })
            .union(state.preferences.customAllergyNames)
    }

    private static func splitByCatalog(_ names: Set<String>) -> (ids: Set<String>, names: Set<String>) {
        var ids: Set<String> = []
        var custom: Set<String> = []
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if let match = resolveIngredient(trimmed) {
                ids.insert(match.id)
            } else {
                custom.insert(String(trimmed.prefix(20)))
            }
        }
        return (ids, custom)
    }

    private static func normalizedBirthDate(_ value: String) -> String? {
        let digits = value.filter(\.isNumber)
        guard digits.count == 8 else { return nil }
        let normalized = "\(digits.prefix(4))-\(digits.dropFirst(4).prefix(2))-\(digits.suffix(2))"
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: normalized), date <= Date(),
              let oldest = Calendar(identifier: .gregorian).date(byAdding: .year, value: -120, to: Date()),
              date >= oldest else { return nil }
        return formatter.string(from: date)
    }

    /// 동네 나눔(F26)에서만 쓰는 자기입력 값이다. 위치 권한을 요청하지 않고 좌표도 저장하지 않는다.
    func setNeighborhood(_ value: String) {
        let trimmed = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
        guard trimmed != state.profile.neighborhood else { return }
        update {
            $0.profile.neighborhood = trimmed
            // 좌표는 입력한 동네와 묶여 있으므로 동네를 바꾸면 다시 1회 확인한다.
            $0.profile.coordinate = nil
        }
        notice = trimmed.isEmpty ? "동네를 지웠어요. 동네 나눔 글은 보이지 않아요." : "동네를 \(trimmed)(으)로 저장했어요."
    }

    /// F25 도보 시간 표시용 대략 좌표. 값은 이미 약 100m 격자로 반올림된 상태로 들어온다.
    func setNeighborhoodCoordinate(_ coordinate: ShareCoordinate?) {
        let rounded = coordinate.flatMap { ShareCoordinate.rounded(latitude: $0.latitude, longitude: $0.longitude) }
        guard state.profile.coordinate != rounded else { return }
        update { $0.profile.coordinate = rounded }
    }

    /// GPS로 한 번 확인한 동네 이름과 약 100m 격자 좌표를 같은 저장 작업으로 반영한다.
    /// 이름을 먼저 바꾸는 기존 경로가 좌표를 지우던 문제를 막는다.
    func setVerifiedNeighborhood(_ value: String, coordinate: ShareCoordinate) {
        let trimmed = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
        guard !trimmed.isEmpty,
              let rounded = ShareCoordinate.rounded(latitude: coordinate.latitude, longitude: coordinate.longitude) else { return }
        update {
            $0.profile.neighborhood = trimmed
            $0.profile.coordinate = rounded
        }
        notice = "동네 위치를 확인했어요. 좌표는 약 100m 단위로만 저장해요."
    }

    /// 프로필 사진 저장. 원본을 그대로 두면 UserDefaults가 수 MB로 불어나므로
    /// 256px 정사각으로 줄이고 JPEG로 압축한 것만 담는다. `nil`이면 기본 이미지로 되돌린다.
    func setAvatar(_ image: UIImage?) {
        guard let image else {
            update { $0.profile.avatarData = nil }
            notice = "프로필 사진을 기본 이미지로 되돌렸어요."
            return
        }
        guard let data = Self.avatarJPEG(from: image) else {
            notice = "사진을 저장하지 못했어요. 다른 사진으로 시도해 주세요."
            return
        }
        update { $0.profile.avatarData = data }
        notice = "프로필 사진을 바꿨어요."
    }

    /// 짧은 변을 기준으로 정사각으로 자른 뒤 256px로 줄인다.
    static func avatarJPEG(from image: UIImage, side: CGFloat = 256) -> Data? {
        let shortest = min(image.size.width, image.size.height)
        guard shortest > 0 else { return nil }
        let origin = CGPoint(x: (image.size.width - shortest) / 2, y: (image.size.height - shortest) / 2)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let square = renderer.image { _ in
            let scale = side / shortest
            image.draw(in: CGRect(
                x: -origin.x * scale,
                y: -origin.y * scale,
                width: image.size.width * scale,
                height: image.size.height * scale
            ))
        }
        return square.jpegData(compressionQuality: 0.8)
    }

    func toggleFavorite(_ recipeID: String) {
        guard recipe(for: recipeID) != nil else { return }
        update { state in
            if let index = state.favorites.firstIndex(of: recipeID) {
                state.favorites.remove(at: index)
                self.notice = "찜을 해제했어요."
            } else {
                state.favorites.append(recipeID)
                self.notice = "찜한 메뉴에 저장했어요."
            }
        }
    }

    @discardableResult
    func addPlannedMeal(recipeID: String, date: String, slot: MealSlot) -> Bool {
        guard let recipe = recipe(for: recipeID), Self.isValidISODate(date), recipe.mealSlots.contains(slot) else { return false }
        let duplicate = state.plannedMeals.contains { $0.date == date && $0.mealSlot == slot && $0.status != .cooked }
        guard !duplicate else {
            notice = "같은 날짜와 끼니에 이미 다른 메뉴가 담겨 있어요. 식단 관리에서 바꿔 주세요."
            return false
        }
        update { state in
            state.plannedMeals.append(PlannedMeal(id: UUID().uuidString, recipeID: recipeID, date: date, mealSlot: slot, status: .planned, createdAt: ISO8601DateFormatter().string(from: Date())))
            Self.resetShoppingExecution(in: &state)
        }
        let title = recipe.title
        notice = ["\(title)를 내 식사에 담았어요.", preferenceWarning(forRecipeID: recipeID)].compactMap { $0 }.joined(separator: " ")
        return true
    }

    /// 직접 고른 메뉴는 삭제하지 않고 불호·조리도구 조건만 알려준다(AGENTS 8절).
    func preferenceWarning(forRecipeID recipeID: String) -> String? {
        guard let recipe = recipe(for: recipeID) else { return nil }
        var reasons: [String] = []
        if state.preferences.dislikedRecipeIDs.contains(recipeID) {
            reasons.append("불호 메뉴로 설정한 메뉴")
        }
        let disliked = Set(recipe.ingredients.map(\.ingredientID)).intersection(state.preferences.dislikedIngredientIDs)
        if !disliked.isEmpty {
            reasons.append("불호 재료 \(disliked.compactMap { ingredient(for: $0)?.name }.sorted().joined(separator: ", ")) 포함")
        }
        let allergy = Set(recipe.ingredients.map(\.ingredientID)).intersection(state.preferences.allergyIngredientIDs)
        if !allergy.isEmpty {
            reasons.append("알레르기 재료 \(allergy.compactMap { ingredient(for: $0)?.name }.sorted().joined(separator: ", ")) 포함")
        }
        let customDisliked = customAvoidanceMatches(in: recipe, names: state.preferences.customDislikedNames)
        if !customDisliked.isEmpty {
            reasons.append("불호 재료 \(customDisliked.sorted().joined(separator: ", ")) 포함")
        }
        let customAllergy = customAvoidanceMatches(in: recipe, names: state.preferences.customAllergyNames)
        if !customAllergy.isEmpty {
            reasons.append("알레르기 분류 \(customAllergy.sorted().joined(separator: ", ")) 포함")
        }
        let missingTools = recipe.requiredTools.subtracting(state.preferences.availableTools)
        if !missingTools.isEmpty {
            reasons.append("조리도구 \(missingTools.map(\.rawValue).sorted().joined(separator: ", ")) 필요")
        }
        guard !reasons.isEmpty else { return nil }
        return "\(reasons.joined(separator: " · "))예요. 자동 추천에서는 빼지만 직접 고른 메뉴는 그대로 둘게요."
    }

    @discardableResult
    func applyPlan(_ option: MealPlanOption, targetBudget: Int = 0) -> Int {
        var added = 0
        update { state in
            // 식단관리 화면이 남은 예산을 보여주려면 확정 시점의 목표 예산이 필요하다.
            if targetBudget > 0 { state.targetBudget = targetBudget }
            for draft in option.drafts {
                // 새 식단을 다시 확정하면 같은 날짜·끼니의 예정 메뉴를
                // 복제하지 않고 교체한다. 완료 기록은 보존하고, 건너뛴 끼니는
                // 새 계획으로 되살린다.
                if let index = state.plannedMeals.firstIndex(where: { $0.date == draft.date && $0.mealSlot == draft.mealSlot }) {
                    guard state.plannedMeals[index].status != .cooked else { continue }
                    let changed = state.plannedMeals[index].recipeID != draft.recipeID || state.plannedMeals[index].status != .planned
                    state.plannedMeals[index].recipeID = draft.recipeID
                    state.plannedMeals[index].status = .planned
                    if changed { added += 1 }
                } else {
                    state.plannedMeals.append(PlannedMeal(id: UUID().uuidString, recipeID: draft.recipeID, date: draft.date, mealSlot: draft.mealSlot, status: .planned, createdAt: ISO8601DateFormatter().string(from: Date())))
                    added += 1
                }
            }
            if added > 0 { Self.resetShoppingExecution(in: &state) }
        }
        notice = added == 0 ? "이미 같은 계획이 있어 새로 추가된 식사가 없어요." : "\(added)개 식사를 내 식사에 담았어요."
        return added
    }

    func replaceMeal(_ mealID: String, recipeID: String) {
        guard let recipe = recipe(for: recipeID),
              let existing = state.plannedMeals.first(where: { $0.id == mealID }),
              existing.status != .cooked,
              recipe.mealSlots.contains(existing.mealSlot),
              !state.plannedMeals.contains(where: { $0.id != mealID && $0.date == existing.date && $0.mealSlot == existing.mealSlot && $0.status != .cooked }) else {
            notice = "이 메뉴를 바꿀 수 없는 상태예요."
            return
        }
        update { state in
            guard let index = state.plannedMeals.firstIndex(where: { $0.id == mealID }) else { return }
            state.plannedMeals[index].recipeID = recipeID
            Self.resetShoppingExecution(in: &state)
        }
        notice = ["메뉴를 \(recipe.title)(으)로 바꿨어요. 필요한 재료와 예산도 다시 계산돼요.", preferenceWarning(forRecipeID: recipeID)].compactMap { $0 }.joined(separator: " ")
    }

    func moveMeal(_ mealID: String, date: String, slot: MealSlot) {
        guard let existing = state.plannedMeals.first(where: { $0.id == mealID }),
              (existing.status == .planned || existing.status == .skipped),
              Self.isValidISODate(date),
              recipe(for: existing.recipeID)?.mealSlots.contains(slot) == true else {
            notice = "이 식사를 옮길 수 없는 일정이에요."
            return
        }
        let conflict = state.plannedMeals.contains { $0.id != mealID && $0.date == date && $0.mealSlot == slot && $0.status != .cooked }
        guard !conflict else {
            notice = "그 날짜와 끼니에 이미 다른 계획이 있어요."
            return
        }
        update { state in
            guard let index = state.plannedMeals.firstIndex(where: { $0.id == mealID }) else { return }
            state.plannedMeals[index].date = date
            state.plannedMeals[index].mealSlot = slot
            Self.resetShoppingExecution(in: &state)
        }
        notice = "식사 일정을 옮겼어요. 필요한 재료와 보관 주의를 다시 확인해 주세요."
    }

    func removeMeal(_ mealID: String) {
        guard let meal = state.plannedMeals.first(where: { $0.id == mealID }) else { return }
        guard meal.status != .cooked else {
            notice = "완료한 식사는 재고 차감 기록을 보호하기 위해 삭제할 수 없어요."
            return
        }
        update { state in
            state.plannedMeals.removeAll { $0.id == mealID }
            state.completions.removeAll { $0.plannedMealID == mealID }
            Self.resetShoppingExecution(in: &state)
        }
        notice = "식사 계획을 삭제했어요."
    }

    func setInventory(ingredientID: String, quantity: Double?, unit: Unit, status: QuantityStatus) {
        guard ingredient(for: ingredientID) != nil else { return }
        let safe = status == .unknown ? nil : max(quantity ?? 0, 0)
        update { state in
            let index = state.inventory.firstIndex(where: { $0.ingredientID == ingredientID && $0.unit == unit })
            let existing = index.map { state.inventory[$0] }
            let item = InventoryItem(
                ingredientID: ingredientID, quantity: safe, unit: unit, quantityStatus: status,
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                purchasedAt: existing?.purchasedAt, openedAt: existing?.openedAt, bestBefore: existing?.bestBefore
            )
            if let index {
                state.inventory[index] = item
            } else {
                state.inventory.append(item)
            }
        }
    }

    func setInventoryDates(_ itemID: String, purchasedAt: String?, openedAt: String?, bestBefore: String?) {
        update { state in
            guard let index = state.inventory.firstIndex(where: { $0.id == itemID }) else { return }
            state.inventory[index].purchasedAt = purchasedAt
            state.inventory[index].openedAt = openedAt
            state.inventory[index].bestBefore = bestBefore
            state.inventory[index].updatedAt = ISO8601DateFormatter().string(from: Date())
        }
        notice = "보관 날짜를 저장했어요. 제품 포장 표시가 있으면 그 날짜를 우선해 주세요."
    }

    func removeInventory(_ item: InventoryItem) {
        update { state in
            state.inventory.removeAll { $0.id == item.id }
        }
        notice = "\(ingredient(for: item.ingredientID)?.name ?? "재료")를 냉장고에서 지웠어요."
    }

    func setPackageOverride(ingredientID: String, package: PackageSize) {
        guard package.amount.isFinite, package.amount > 0, ingredient(for: ingredientID) != nil else { return }
        update { $0.packageOverrides[ingredientID] = package }
    }

    func setPrice(ingredientID: String, price: Int, packageAmount: Double, unit: Unit) {
        guard price >= 0, packageAmount.isFinite, packageAmount > 0, ingredient(for: ingredientID) != nil else { return }
        update { state in
            state.prices[ingredientID] = IngredientPrice(price: price, packageAmount: packageAmount, unit: unit, confirmedAt: ISO8601DateFormatter().string(from: Date()), source: "user")
        }
    }

    func setPreferences(dislikedIngredientIDs: Set<String>, dislikedRecipeIDs: Set<String> = [], availableTools: Set<CookingTool>) {
        update { state in
            state.preferences.dislikedIngredientIDs = dislikedIngredientIDs
            state.preferences.dislikedRecipeIDs = dislikedRecipeIDs
            state.preferences.availableTools = availableTools
        }
        notice = "추천 설정을 저장했어요. 이미 담은 식사는 지우지 않았어요."
    }

    func setPurchaseChecked(itemID: String, checked: Bool) {
        update { state in
            if checked {
                state.purchaseChecks[itemID] = true
            } else {
                state.purchaseChecks.removeValue(forKey: itemID)
            }
            appendShoppingEvent(.itemChecked, itemIDs: [itemID], to: &state)
        }
    }

    func setPurchaseQuantity(itemID: String, value: Double?) {
        guard let value, value.isFinite, value >= 0 else {
            update { state in
                state.purchaseQuantityOverrides.removeValue(forKey: itemID)
                appendShoppingEvent(.quantityAdjusted, itemIDs: [itemID], to: &state)
            }
            return
        }
        update { state in
            state.purchaseQuantityOverrides[itemID] = floor(value)
            appendShoppingEvent(.quantityAdjusted, itemIDs: [itemID], to: &state)
        }
    }

    func recordShoppingEvent(_ action: ShoppingEventAction, itemIDs: [String]) {
        guard !itemIDs.isEmpty else { return }
        update { state in
            appendShoppingEvent(action, itemIDs: itemIDs, to: &state)
        }
    }

    @discardableResult
    func confirmPurchase(items: [ShoppingPlanItem]) -> Bool {
        let confirmedItems = items.filter {
            $0.precision == .exact && resolvedPurchasePackageCount(for: $0) > 0
        }
        guard !confirmedItems.isEmpty else {
            notice = "추가로 살 품목이 없어요."
            return false
        }
        let signature = shoppingSignature(confirmedItems, quantityOverrides: state.purchaseQuantityOverrides, sessionID: state.shoppingSessionID)
        guard !state.appliedPurchaseSignatures.contains(signature) else {
            notice = "이 장보기 목록은 이미 재고에 반영했어요."
            return false
        }
        update { state in
            state.inventory = applyPurchases(inventory: state.inventory, shoppingItems: confirmedItems, quantityOverrides: state.purchaseQuantityOverrides)
            state.appliedPurchaseSignatures.append(signature)
            confirmedItems.forEach { state.purchaseChecks[$0.id] = true }
            appendShoppingEvent(.purchaseConfirmed, itemIDs: confirmedItems.map(\.id), to: &state)
        }
        notice = "구매한 양을 냉장고 재고에 반영했어요. 같은 목록을 다시 눌러도 중복되지 않아요."
        return true
    }

    /// F22 `오늘만 비활성화`. 재료는 그대로 두고 상태만 바꾼다. 되돌릴 수 있다.
    func setMealSkipped(_ mealID: String, skipped: Bool) {
        guard let index = state.plannedMeals.firstIndex(where: { $0.id == mealID }),
              state.plannedMeals[index].status == .planned || state.plannedMeals[index].status == .skipped else { return }
        update { state in
            state.plannedMeals[index].status = skipped ? .skipped : .planned
            Self.resetShoppingExecution(in: &state)
        }
        notice = skipped ? "이 끼니를 건너뛰었어요. 재료는 그대로 남아 있어요." : "다시 예정으로 되돌렸어요."
    }

    func completeMeal(_ mealID: String, consumptions: [CookingConsumption]) -> Bool {
        guard let meal = state.plannedMeals.first(where: { $0.id == mealID }), meal.status == .planned else {
            notice = "이미 완료한 식사예요. 재고를 다시 차감하지 않았어요."
            return false
        }
        guard !state.completions.contains(where: { $0.plannedMealID == mealID }) else {
            notice = "이미 완료한 식사예요. 재고를 다시 차감하지 않았어요."
            return false
        }
        let draft = PlannedMealDraft(
            recipeID: meal.recipeID, date: meal.date, mealSlot: meal.mealSlot,
            reason: "", reusedIngredientIDs: [], newPurchaseCount: 0
        )
        let confirmedSavings = estimate(for: [draft], targetBudget: 0).confirmedInventorySavings
        let completion = CookingCompletion(
            plannedMealID: mealID, recipeID: meal.recipeID,
            completedAt: ISO8601DateFormatter().string(from: Date()),
            consumptions: consumptions, confirmedInventorySavings: confirmedSavings
        )
        update { state in
            state.inventory = applyConsumption(inventory: state.inventory, consumptions: consumptions)
            state.completions.append(completion)
            if let index = state.plannedMeals.firstIndex(where: { $0.id == mealID }) {
                state.plannedMeals[index].status = .cooked
            }
            Self.resetShoppingExecution(in: &state)
        }
        notice = "요리 완료를 기록하고 계획된 사용량을 냉장고에 반영했어요."
        return true
    }

    private func update(_ transform: (inout AppState) -> Void) {
        var next = state
        transform(&next)
        state = next
        save()
    }

    private func appendShoppingEvent(_ action: ShoppingEventAction, itemIDs: [String], to state: inout AppState) {
        state.shoppingEvents.append(ShoppingEvent(id: UUID().uuidString, action: action, itemIDs: itemIDs, createdAt: ISO8601DateFormatter().string(from: Date())))
        if state.shoppingEvents.count > 500 {
            state.shoppingEvents.removeFirst(state.shoppingEvents.count - 500)
        }
    }

    private static func resetShoppingExecution(in state: inout AppState) {
        state.shoppingSessionID = UUID().uuidString
        state.purchaseChecks = [:]
        state.purchaseQuantityOverrides = [:]
        state.appliedPurchaseSignatures = []
    }

    private static func sanitize(_ input: AppState) -> AppState {
        var state = input
        let recipeIDs = Set(recipes.map(\.id))
        let ingredientIDs = Set(ingredients.map(\.id))
        state.favorites = state.favorites.filter { recipeIDs.contains($0) }
        state.plannedMeals = state.plannedMeals.filter { recipeIDs.contains($0.recipeID) && $0.date.count == 10 }
        state.inventory = state.inventory.filter { ingredientIDs.contains($0.ingredientID) && ($0.quantity == nil || ($0.quantity ?? 0) >= 0) }
        state.prices = state.prices.filter { ingredientIDs.contains($0.key) && $0.value.price >= 0 && $0.value.packageAmount > 0 }
        state.purchaseQuantityOverrides = state.purchaseQuantityOverrides.filter { $0.value.isFinite && $0.value >= 0 }
        if state.shoppingSessionID.isEmpty { state.shoppingSessionID = UUID().uuidString }
        state.shoppingEvents = Array(state.shoppingEvents.suffix(500))
        state.preferences.dislikedIngredientIDs = state.preferences.dislikedIngredientIDs.intersection(ingredientIDs)
        state.preferences.dislikedRecipeIDs = state.preferences.dislikedRecipeIDs.intersection(recipeIDs)
        if state.preferences.availableTools.isEmpty { state.preferences.availableTools = Set(CookingTool.allCases) }
        state.profile.nickname = String(state.profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        state.profile.age = state.profile.age.flatMap { (14...120).contains($0) ? $0 : nil }
        state.profile.neighborhood = String(state.profile.neighborhood.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
        state.profile.coordinate = state.profile.coordinate.flatMap { ShareCoordinate.rounded(latitude: $0.latitude, longitude: $0.longitude) }
        return state
    }

    private func resolvedPurchasePackageCount(for item: ShoppingPlanItem) -> Int {
        purchasePackageCount(state.purchaseQuantityOverrides[item.id], fallback: item.purchaseQuantity)
    }

    private static func isValidISODate(_ value: String) -> Bool {
        guard value.count == 10 else { return false }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value) != nil
    }
}
