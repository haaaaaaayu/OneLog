import XCTest

final class OneLogUITests: XCTestCase {
    private func launchApp(resetState: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        if resetState { app.launchArguments.append("-uiTestResetState") }
        app.launch()
        if !app.tabBars.buttons["탐색"].waitForExistence(timeout: 2) {
            completeOnboarding(app)
        }
        XCTAssertTrue(app.tabBars.buttons["식단"].waitForExistence(timeout: 5))
        return app
    }

    /// 시작 화면 → 계정 → 프로필 → 불호·조리도구 순서로 온보딩을 통과한다.
    private func completeOnboarding(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let deviceOnly = app.buttons["onboarding.deviceOnly"]
        XCTAssertTrue(deviceOnly.waitForExistence(timeout: 5))
        deviceOnly.tap()

        let skipProfile = app.buttons["onboarding.skipProfile"]
        XCTAssertTrue(skipProfile.waitForExistence(timeout: 5))
        skipProfile.tap()

        let later = app.buttons["onboarding.later"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()
    }

    func testOnboardingCollectsAccountAndPreferencesThenOpensMyPage() {
        let app = launchApp(resetState: true)

        app.buttons["home.myPage"].tap()
        XCTAssertTrue(app.navigationBars["마이페이지"].waitForExistence(timeout: 5))
        // 계정 연결 해제 버튼은 계정이 연결된 상태에서만 보인다.
        XCTAssertTrue(app.buttons["계정 연결 해제"].waitForExistence(timeout: 5))

        let nickname = app.textFields["mypage.nickname"]
        XCTAssertTrue(nickname.waitForExistence(timeout: 5))
        nickname.tap()
        nickname.typeText("한끼")
        app.buttons["mypage.saveProfile"].tap()

        app.buttons["mypage.preferences"].tap()
        XCTAssertTrue(app.navigationBars["추천 설정"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["자동 추천에서 제외할 재료"].waitForExistence(timeout: 5))
        // 불호 메뉴 섹션은 재료 목록 아래에 있어 스크롤해야 화면에 올라온다.
        XCTAssertTrue(scrollUntilVisible(app, app.staticTexts["자동 추천에서 제외할 메뉴"]))
    }

    private func scrollUntilVisible(_ app: XCUIApplication, _ element: XCUIElement, swipes: Int = 12) -> Bool {
        for _ in 0..<swipes {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists
    }

    func testCalculableFilterLeadsToShoppingListWithRealQuantities() {
        let app = launchApp()

        app.buttons["home.calculableFilter"].tap()
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '에 담기'")).firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        app.tabBars.buttons["장보기"].tap()
        XCTAssertTrue(app.navigationBars["장보기"].waitForExistence(timeout: 5))
        // 계산이 되는 레시피만 담았으므로 "확인 필요" 문구가 뜨면 안 된다.
        XCTAssertFalse(app.staticTexts["판매 단위 확인 필요"].exists)
    }

    func testGoogleSignInFailureKeepsUserOnAccountStepWithRetry() {
        let app = XCUIApplication()
        app.launchArguments.append("-uiTestResetState")
        app.launch()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let google = app.buttons["onboarding.google"]
        XCTAssertTrue(google.waitForExistence(timeout: 5))
        google.tap()

        XCTAssertTrue(app.buttons["다시 시도"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["onboarding.deviceOnly"].exists)
    }

    func testP0TabsAndPlanningFlow() {
        let app = launchApp()

        app.tabBars.buttons["식단"].tap()
        XCTAssertTrue(app.navigationBars["식단 만들기"].waitForExistence(timeout: 5))

        let suggestButton = app.buttons["여러 식단안 제안받기"]
        XCTAssertTrue(suggestButton.waitForExistence(timeout: 5))
        suggestButton.tap()

        XCTAssertTrue(app.navigationBars["식단안 비교"].waitForExistence(timeout: 5))
        let selectButton = app.buttons["이 식단안을 선택하고 재료·예산 확인"].firstMatch
        XCTAssertTrue(selectButton.waitForExistence(timeout: 5))
        selectButton.tap()

        XCTAssertTrue(app.navigationBars["예산 확인"].waitForExistence(timeout: 5))
        let confirmButton = app.buttons["이 식단을 확정하고 내 식사에 담기"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        app.tabBars.buttons["내 식사"].tap()
        XCTAssertTrue(app.navigationBars["내 식사"].waitForExistence(timeout: 5))
    }

    func testP0ExecutionTabsAreReachable() {
        let app = launchApp()

        app.tabBars.buttons["장보기"].tap()
        XCTAssertTrue(app.navigationBars["장보기"].waitForExistence(timeout: 5))

        app.tabBars.buttons["냉장고"].tap()
        XCTAssertTrue(app.navigationBars["냉장고"].waitForExistence(timeout: 5))

        app.tabBars.buttons["탐색"].tap()
        XCTAssertTrue(app.navigationBars["한끼로그"].waitForExistence(timeout: 5))
    }
}
