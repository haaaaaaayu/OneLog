import XCTest

/// 피그마 시안과 눈으로 대조하려고 각 화면을 캡처한다. 단정은 하지 않고, 눌리는 데까지 눌러보고 찍는다.
/// 실행:
///   xcodebuild test -scheme OneLog -only-testing:OneLogUITests/ScreenshotTests \
///     -destination 'platform=iOS Simulator,name=iPhone 17' -resultBundlePath <경로> \
///     -parallel-testing-enabled NO
/// `-parallel-testing-enabled NO`를 빼면 실행할 때마다 시뮬레이터 클론이 새 창으로 뜬다.
///   xcrun xcresulttool export attachments --path <경로>.xcresult --output-path <폴더>
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var step = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments.append("-uiTestResetState")
        // 이 인자가 없으면 Google 버튼이 실제 웹 로그인 창을 띄워 캡처가 그대로 멈춘다.
        app.launchArguments.append("-uiTestGoogleSignInFails")
        app.launch()
    }

    private func shot(_ name: String) {
        // 버튼 라벨이 크로스페이드 중에 찍히면 두 글자가 겹쳐 보인다.
        Thread.sleep(forTimeInterval: 0.6)
        step += 1
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "%02d-%@", step, name)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 있으면 누르고 true, 없으면 조용히 false. 한 단계가 막혀도 나머지는 계속 찍는다.
    @discardableResult
    private func tap(_ element: XCUIElement, timeout: TimeInterval = 4) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        element.tap()
        return true
    }

    func testCaptureAllFigmaScreens() {
        // 온보딩 350:1899
        shot("onboarding-welcome")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // 350:1905
        _ = app.buttons["onboarding.google"].waitForExistence(timeout: 4)
        shot("onboarding-login")

        // 구글 로그인은 시뮬레이터에서 실패한다. 실패 뒤 뜨는 기기 전용 시작으로 넘어간다.
        tap(app.buttons["onboarding.google"])
        shot("onboarding-login-error")
        tap(app.buttons["onboarding.deviceOnly"])

        // 445:26 기본정보 (동네 인증 전)
        _ = app.buttons["profile.neighborhood"].waitForExistence(timeout: 4)
        shot("onboarding-basic-unverified")

        // 동네 인증 시트 → 442:23 인증 완료
        if tap(app.buttons["profile.neighborhood"]) {
            let input = app.textFields["profile.neighborhoodInput"]
            if input.waitForExistence(timeout: 3) {
                input.tap()
                input.typeText("서울 성동구 성수동")
                shot("onboarding-neighborhood-sheet")
                tap(app.buttons["인증하기"])
            } else {
                shot("onboarding-neighborhood-sheet")
            }
        }
        _ = app.buttons["profile.neighborhood"].waitForExistence(timeout: 3)
        shot("onboarding-basic-verified")

        // 350:2304 조리도구
        tap(app.buttons["다음"].firstMatch)
        shot("onboarding-tools")

        // 366:86 / 370:11 불호·알레르기
        tap(app.buttons["다음"].firstMatch)
        shot("onboarding-dislikes")
        tap(app.buttons["알레르기·못 먹는 재료"])
        shot("onboarding-allergies")

        // 383:86 홈 (식단 없음)
        tap(app.buttons["한끼로그 시작하기"]) || tap(app.buttons["onboarding.later"])
        _ = app.buttons["tab.home"].waitForExistence(timeout: 5)
        // RootView 알림 토스트가 헤더를 가린다. 4초 뒤 사라지므로 기다렸다 찍는다.
        Thread.sleep(forTimeInterval: 5)
        shot("home-no-plan")

        // 391:58 레시피 탭 1
        tap(app.buttons["tab.recipe"])
        shot("recipe-explore")

        // 391:598 레시피 탭 3 (찜한 레시피)
        if tap(app.buttons["recipe.favorites"]) {
            shot("recipe-favorites")
            tap(app.buttons["뒤로"])
        }

        // 350:1119 레시피 탭 2 (상세)
        _ = app.buttons["tab.recipe"].waitForExistence(timeout: 3)
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS '상세 보기'")).firstMatch
        if card.waitForExistence(timeout: 3) {
            card.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.27, dy: 0.62)).tap()
        }
        shot("recipe-detail")

        // 383:24 마이페이지
        tap(app.buttons["tab.home"])
        tap(app.buttons["마이페이지"])
        shot("mypage")

        // 396:23 시트/요리 숙련도
        if tap(app.buttons["mypage.skill"]) {
            shot("sheet-skill")
            tap(app.buttons["sheet.save"])
        }

        // 396:77 시트/불호 음식·알레르기
        if tap(app.buttons["mypage.taste"]) {
            shot("sheet-taste")
            tap(app.buttons["sheet.save"])
        }

        // 395:23 내 정보 수정
        if tap(app.buttons["mypage.editProfile"]) {
            shot("profile-edit")
        }
    }

    /// 식단 만들기 1~8 (350:1551, 350:1586, 350:1645, 350:1690, 350:1729, 350:1779, 350:1832, 438:23).
    func testCapturePlanFlow() {
        // 온보딩을 기기 전용으로 지나 홈까지 간다.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        tap(app.buttons["onboarding.google"])
        tap(app.buttons["onboarding.deviceOnly"])
        tap(app.buttons["다음"].firstMatch)
        tap(app.buttons["다음"].firstMatch)
        tap(app.buttons["한끼로그 시작하기"]) || tap(app.buttons["onboarding.later"])
        _ = app.buttons["tab.home"].waitForExistence(timeout: 5)
        Thread.sleep(forTimeInterval: 5)

        // 홈 상단 알림 토스트가 버튼을 가린다. 사라질 때까지 기다린다.
        let toastClose = app.buttons["알림 닫기"]
        for _ in 0..<12 where toastClose.exists {
            if toastClose.isHittable { toastClose.tap() }
            Thread.sleep(forTimeInterval: 0.5)
        }

        // 홈 카드 → 식단 만들기
        guard tap(app.buttons["home.createPlan"]) else {
            return XCTFail("식단 만들기 진입점을 찾지 못했습니다")
        }
        _ = app.buttons["plan.next"].waitForExistence(timeout: 5)

        for name in ["plan-1-duration", "plan-2-meals", "plan-3-budget", "plan-4-analyzing",
                     "plan-5-options", "plan-6-review", "plan-7-final", "plan-8-ingredients", "plan-9-price"] {
            shot(name)
            tap(app.buttons["plan.next"])
        }
    }
}
