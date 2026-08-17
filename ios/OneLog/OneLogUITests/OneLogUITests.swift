import XCTest

final class OneLogUITests: XCTestCase {
    private func launchApp(resetState: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        if resetState { app.launchArguments.append("-uiTestResetState") }
        // 실제 Google 웹 로그인 창은 테스트에서 띄울 수 없다. 항상 실패 경로로 두고 기기 전용으로 들어간다.
        app.launchArguments.append("-uiTestGoogleSignInFails")
        app.launch()
        // 첫 실행은 번들 레시피를 읽느라 몇 초 걸린다. 짧게 잡으면 온보딩이 뜬 줄 알고 헛다리를 짚는다.
        if !app.buttons["tab.home"].waitForExistence(timeout: 8) {
            completeOnboarding(app)
        }
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 5))
        // 홈 상단 알림 토스트가 헤더를 가린다. 4초 뒤 사라진다.
        _ = app.buttons["home.createPlan"].waitForExistence(timeout: 5)
        return app
    }

    /// 시작 화면 → 계정 → 조리도구 → 불호·알레르기 순서로 온보딩을 통과한다(피그마 350:1899~370:11).
    private func completeOnboarding(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let google = app.buttons["onboarding.google"]
        XCTAssertTrue(google.waitForExistence(timeout: 5))
        google.tap()

        let deviceOnly = app.buttons["onboarding.deviceOnly"]
        XCTAssertTrue(deviceOnly.waitForExistence(timeout: 5))
        deviceOnly.tap()

        // 기본정보 → 조리도구 → 불호·알레르기
        for _ in 0..<2 {
            let next = app.buttons["다음"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            next.tap()
        }

        let start = app.buttons["한끼로그 시작하기"]
        if start.waitForExistence(timeout: 5) {
            start.tap()
        } else {
            app.buttons["onboarding.later"].tap()
        }
    }

    func testOnboardingCollectsAccountAndPreferencesThenOpensMyPage() {
        let app = launchApp(resetState: true)

        app.buttons["마이페이지"].tap()
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
        // 앞선 실행이 남긴 식단이 쌓이면 "확인 필요" 품목이 섞여 들어와 단정이 깨진다.
        let app = launchApp(resetState: true)

        app.buttons["tab.recipe"].tap()
        app.buttons["home.calculableFilter"].tap()
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '에 담기'")).firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        app.buttons["tab.plan"].tap()
        app.buttons["meals.shopping"].tap()
        XCTAssertTrue(app.navigationBars["장보기"].waitForExistence(timeout: 5))
        // 계산이 되는 레시피만 담았으므로 "확인 필요" 문구가 뜨면 안 된다.
        XCTAssertFalse(app.staticTexts["판매 단위 확인 필요"].exists)
    }

    /// F26 진입점. 탭을 6개로 늘리면 iOS가 마지막 탭을 More로 접으므로 장보기에서 들어간다.
    func testShareEntryPointIsReachableFromShopping() {
        let app = launchApp()

        app.buttons["tab.recipe"].tap()
        app.buttons["home.calculableFilter"].tap()
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '에 담기'")).firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        app.buttons["tab.plan"].tap()
        app.buttons["meals.shopping"].tap()
        let shareLink = app.buttons["동네에서 같이 사기 · 나눠 쓰기"]
        XCTAssertTrue(shareLink.waitForExistence(timeout: 5))
        shareLink.tap()

        XCTAssertTrue(app.textFields["neighborhoodField"].waitForExistence(timeout: 5))
        // 서버 설정 파일이 없는 빌드에서도 화면은 열리고 이유를 알려줘야 한다.
        XCTAssertTrue(app.staticTexts["앱 안에서 송금하지 않아요"].exists)
    }

    func testGoogleSignInFailureKeepsUserOnAccountStepWithRetry() {
        let app = XCUIApplication()
        app.launchArguments.append("-uiTestResetState")
        // 실제 Google 웹 로그인 창은 테스트에서 띄울 수 없다. 실패 경로만 확인한다.
        app.launchArguments.append("-uiTestGoogleSignInFails")
        app.launch()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let google = app.buttons["onboarding.google"]
        XCTAssertTrue(google.waitForExistence(timeout: 5))
        google.tap()

        XCTAssertTrue(app.buttons["다시 시도"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["onboarding.deviceOnly"].exists)
    }

    /// 피그마 `식단 만들기 1~8`을 순서대로 지나 식단이 실제로 담기는지 본다.
    func testPlanFlowFollowsFigmaSteps() {
        // 앞선 실행이 남긴 식단이 있으면 홈 버튼이 `요리하러 가기`로 바뀐다.
        let app = launchApp(resetState: true)

        XCTAssertTrue(app.buttons["home.createPlan"].waitForExistence(timeout: 5))
        app.buttons["home.createPlan"].tap()

        let next = app.buttons["plan.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 / 11"].exists)

        // 1 기간 → 2 끼니 → 3 예산 → 4 분석 → 5 식단안
        for expected in ["2 / 11", "3 / 11", "4 / 11", "5 / 11"] {
            next.tap()
            XCTAssertTrue(app.staticTexts[expected].waitForExistence(timeout: 5), "\(expected) 단계로 넘어가지 못했습니다")
        }

        // 첫 식단안이 기본 선택이라 그대로 6 확인·수정 → 7 최종 확인
        XCTAssertTrue(app.otherElements["plan.option.0"].exists || app.buttons["plan.option.0"].exists)
        next.tap()
        XCTAssertTrue(app.staticTexts["6 / 11"].waitForExistence(timeout: 5))
        next.tap()
        XCTAssertTrue(app.staticTexts["7 / 11"].waitForExistence(timeout: 5))

        // 확정하면 8 전체 재료 목록으로 넘어가고 식단이 담긴다.
        next.tap()
        XCTAssertTrue(app.staticTexts["8 / 11"].waitForExistence(timeout: 5))

        // 9 가격 확인까지 간 뒤 `완료`로 흐름을 닫는다.
        next.tap()
        XCTAssertTrue(app.staticTexts["9 / 11"].waitForExistence(timeout: 5))
        next.tap()

        XCTAssertTrue(app.buttons["tab.plan"].waitForExistence(timeout: 5))
        app.buttons["tab.plan"].tap()
        XCTAssertTrue(app.navigationBars["내 식사"].waitForExistence(timeout: 5))
        // 확정한 식단이 실제로 담겼는지 본다.
        XCTAssertFalse(app.staticTexts["아직 계획한 식사가 없어요"].exists)
    }

    func testP0ExecutionTabsAreReachable() {
        let app = launchApp()

        app.buttons["tab.plan"].tap()
        app.buttons["meals.shopping"].tap()
        XCTAssertTrue(app.navigationBars["장보기"].waitForExistence(timeout: 5))
        app.navigationBars["장보기"].buttons.firstMatch.tap()

        XCTAssertTrue(app.buttons["meals.fridge"].waitForExistence(timeout: 5))
        app.buttons["meals.fridge"].tap()
        XCTAssertTrue(app.navigationBars["냉장고"].waitForExistence(timeout: 5))

        // 레시피 탭은 피그마 헤더를 쓰므로 내비게이션 바 대신 화면 요소로 확인한다.
        app.buttons["tab.recipe"].tap()
        XCTAssertTrue(app.buttons["recipe.favorites"].waitForExistence(timeout: 5))
    }
}
