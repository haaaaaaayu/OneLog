import XCTest

final class OneLogUITests: XCTestCase {
    private func launchApp(resetState: Bool = false, aiChatFixture: Bool = false, sharingFixture: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        if resetState { app.launchArguments.append("-uiTestResetState") }
        if aiChatFixture { app.launchArguments.append("-uiTestAIChat") }
        if sharingFixture { app.launchArguments.append("-uiTestSharing") }
        // 실제 Google 웹 로그인 창은 테스트에서 띄울 수 없다. 항상 실패 경로로 두고 기기 전용으로 들어간다.
        app.launchArguments.append("-uiTestGoogleSignInFails")
        app.launch()
        // 첫 실행은 번들 레시피를 읽느라 몇 초 걸린다. 짧게 잡으면 온보딩이 뜬 줄 알고 헛다리를 짚는다.
        if !app.buttons["tab.home"].waitForExistence(timeout: 8) {
            completeOnboarding(app)
        }
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 5))
        _ = app.buttons["home.createPlan"].waitForExistence(timeout: 5)
        // 홈 상단 알림 토스트가 헤더(마이페이지 버튼)를 가린다. 스스로 사라질 때까지 기다렸다 넘긴다.
        let toastClose = app.buttons["알림 닫기"]
        for _ in 0..<12 where toastClose.exists {
            if toastClose.isHittable { toastClose.tap() }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return app
    }

    /// 시작 화면 → 계정 → 조리도구 → 불호·알레르기 순서로 온보딩을 통과한다(피그마 350:1899~370:11).
    private func completeOnboarding(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let google = app.buttons["onboarding.google"]
        XCTAssertTrue(google.waitForExistence(timeout: 5))
        let consent = app.buttons["필수 약관 동의"]
        XCTAssertTrue(consent.waitForExistence(timeout: 5))
        consent.tap()
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

    /// 마이페이지(383:24)에서 계정·프로필·불호 설정 경로가 살아 있는지 본다.
    func testMyPageKeepsAccountProfileAndTastePaths() {
        let app = launchApp(resetState: true)

        app.buttons["마이페이지"].tap()
        XCTAssertTrue(app.staticTexts["마이페이지"].waitForExistence(timeout: 5))

        // 내 정보 수정(395:23). 계정 관리도 이 화면 안에 있다.
        app.buttons["mypage.editProfile"].tap()

        let nickname = app.textFields["mypage.nickname"]
        XCTAssertTrue(nickname.waitForExistence(timeout: 5))
        nickname.tap()
        nickname.typeText("한끼")
        app.buttons["mypage.saveProfile"].tap()

        // 불호 음식·알레르기 시트(396:77)
        XCTAssertTrue(app.buttons["mypage.preferences"].waitForExistence(timeout: 5))
        app.buttons["mypage.preferences"].tap()
        XCTAssertTrue(app.buttons["sheet.save"].waitForExistence(timeout: 5))
        app.buttons["sheet.save"].tap()

        // 최종본 설정(792:26)과 알림 설정(799:26)으로 이어진다.
        app.buttons["mypage.editProfile"].tap()
        XCTAssertTrue(app.buttons["mypage.manageAccount"].waitForExistence(timeout: 5))
        app.buttons["mypage.manageAccount"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.screen"].waitForExistence(timeout: 5))
        app.buttons["settings.notifications"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["notificationSettings.screen"].waitForExistence(timeout: 5))
    }

    private func scrollUntilVisible(_ app: XCUIApplication, _ element: XCUIElement, swipes: Int = 12) -> Bool {
        for _ in 0..<swipes {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists
    }

    private func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: element)], timeout: timeout) == .completed
    }

    /// 식단을 만드는 유일한 경로는 `식단 만들기`다. 확정까지 마치고 흐름을 닫는다.
    private func createPlan(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["home.createPlan"].waitForExistence(timeout: 5))
        app.buttons["home.createPlan"].tap()

        let next = app.buttons["plan.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        // 1 기간 → … → 11 장보기 목록 → 완료
        for step in 2...11 {
            if step == 5 { XCTAssertTrue(waitUntilEnabled(next), "식단 계산이 완료되지 않았습니다") }
            next.tap()
            XCTAssertTrue(app.staticTexts["\(step) / 11"].waitForExistence(timeout: 5), "\(step)단계로 넘어가지 못했습니다")
        }
        next.tap()
        XCTAssertTrue(app.buttons["tab.plan"].waitForExistence(timeout: 5))
    }

    private func openPlanReview(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["home.createPlan"].waitForExistence(timeout: 5))
        app.buttons["home.createPlan"].tap()

        let next = app.buttons["plan.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        // 1 기간 → 2 끼니 → 3 예산 → 4 분석 → 5 식단안 → 6 확인·수정
        for expected in ["2 / 11", "3 / 11", "4 / 11", "5 / 11", "6 / 11"] {
            if expected == "5 / 11" { XCTAssertTrue(waitUntilEnabled(next), "식단 계산이 완료되지 않았습니다") }
            next.tap()
            XCTAssertTrue(app.staticTexts[expected].waitForExistence(timeout: 5), "(expected) 단계로 넘어가지 못했습니다")
        }
    }

    func testConfirmedPlanProducesShoppingListWithQuantities() {
        // 앞선 실행이 남긴 식단이 쌓이면 품목이 섞여 들어와 단정이 흔들린다.
        let app = launchApp(resetState: true)
        createPlan(app)

        app.buttons["tab.plan"].tap()
        app.buttons["meals.shopping"].tap()
        XCTAssertTrue(app.staticTexts["이번 식단에 필요한 재료"].waitForExistence(timeout: 5))
        // 확정한 식단의 재료가 판매 단위와 함께 올라와야 한다.
        let itemRow = app.buttons.matching(NSPredicate(format: "label CONTAINS '개' OR label CONTAINS '판매 단위 확인 필요'")).firstMatch
        XCTAssertTrue(itemRow.waitForExistence(timeout: 5), "장보기 목록에 품목이 없습니다")
    }

    /// F26 진입점. Figma 최종본대로 재료소분 탭에서 진입한다.
    func testShareEntryPointIsReachableFromTab() {
        let app = launchApp(resetState: true)
        createPlan(app)

        app.buttons["tab.share"].tap()
        XCTAssertTrue(app.buttons["share.start"].waitForExistence(timeout: 5))
        app.buttons["share.start"].tap()

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
        // 첫 실행은 번들 레시피를 읽느라 시작 화면이 늦게 뜬다. 뜨기 전에 누르면 탭이 그냥 사라진다.
        XCTAssertTrue(app.images.firstMatch.waitForExistence(timeout: 10))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let google = app.buttons["onboarding.google"]
        XCTAssertTrue(google.waitForExistence(timeout: 5))
        let consent = app.buttons["필수 약관 동의"]
        XCTAssertTrue(consent.waitForExistence(timeout: 5))
        consent.tap()
        google.tap()

        // 실패해도 계정 단계에 남아 다시 시도(Google 버튼)와 기기 전용 시작을 함께 보여준다.
        XCTAssertTrue(app.buttons["onboarding.deviceOnly"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["onboarding.google"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Google 로그인'")).firstMatch.exists)
    }

    func testNeighborhoodVerificationFollowsFinalFigmaTwoStepFlow() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetState", "-uiTestGoogleSignInFails"]
        app.launch()
        XCTAssertTrue(app.images.firstMatch.waitForExistence(timeout: 10))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["필수 약관 동의"].waitForExistence(timeout: 5))
        app.buttons["필수 약관 동의"].tap()
        app.buttons["onboarding.google"].tap()
        XCTAssertTrue(app.buttons["onboarding.deviceOnly"].waitForExistence(timeout: 5))
        app.buttons["onboarding.deviceOnly"].tap()

        XCTAssertTrue(app.buttons["profile.neighborhood"].waitForExistence(timeout: 5))
        app.buttons["profile.neighborhood"].tap()
        let search = app.textFields["profile.neighborhoodInput"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("성수동")
        XCTAssertTrue(app.buttons["neighborhood.result.0"].waitForExistence(timeout: 5))
        app.buttons["neighborhood.result.0"].tap()
        XCTAssertTrue(app.buttons["neighborhood.confirm"].waitForExistence(timeout: 5))
        app.buttons["neighborhood.confirm"].tap()
        XCTAssertTrue(app.buttons["profile.neighborhood"].waitForExistence(timeout: 5))
    }

    func testFinalSharingScreens() {
        // 744:35 → 795:26 → 723:263 순서로 최종본의 연결 상태를 확인한다.
        let app = launchApp(resetState: true, sharingFixture: true)
        app.buttons["tab.share"].tap()

        let activePost = app.buttons["share.activePost.ui-share-post"]
        XCTAssertTrue(activePost.waitForExistence(timeout: 5))
        activePost.coordinate(withNormalizedOffset: CGVector(dx: 0.86, dy: 0.5)).tap()
        XCTAssertTrue(app.descendants(matching: .any)["share.receivedRequest"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tab.share"].exists, "상세 화면에는 Figma에 없는 하단 탭이 노출되면 안 됩니다")
        app.buttons["수락하고 채팅하기"].tap()
        XCTAssertTrue(activePost.waitForExistence(timeout: 5))
        activePost.coordinate(withNormalizedOffset: CGVector(dx: 0.86, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["meetupEditorButton"].waitForExistence(timeout: 5))
        app.buttons["meetupEditorButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["share.meetupDetail"].waitForExistence(timeout: 5))
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
            if expected == "5 / 11" { XCTAssertTrue(waitUntilEnabled(next), "식단 계산이 완료되지 않았습니다") }
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

        // 9 보유 재료 확인 → 10 구매 가격 → 11 장보기 목록까지 간 뒤 `완료`로 흐름을 닫는다.
        for expected in ["9 / 11", "10 / 11", "11 / 11"] {
            next.tap()
            XCTAssertTrue(app.staticTexts[expected].waitForExistence(timeout: 5), "\(expected) 단계로 넘어가지 못했습니다")
        }
        next.tap()

        XCTAssertTrue(app.buttons["tab.plan"].waitForExistence(timeout: 5))
        app.buttons["tab.plan"].tap()
        // 확정한 식단이 실제로 담겼는지 본다.
        // 시안 723:558로 바뀌며 헤더가 브랜드 로고로 바뀌었다. 섹션 제목은 `OO님의 오늘 식단`이다.
        let todaySection = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '오늘 식단'")).firstMatch
        XCTAssertTrue(todaySection.waitForExistence(timeout: 5) || app.staticTexts["다음 식단"].exists)
        XCTAssertFalse(app.staticTexts["아직 계획한 식단이 없어요"].exists)
    }

    func testCookingCompletesWithoutUsageInputScreen() {
        let app = launchApp(resetState: true)
        createPlan(app)

        app.buttons["tab.plan"].tap()
        let mealCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "meals.card.")).firstMatch
        XCTAssertTrue(mealCard.waitForExistence(timeout: 5))
        mealCard.tap()

        let complete = app.buttons["recipe.detail.addMeal"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()

        XCTAssertTrue(app.buttons["cooking.useLeftovers"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["사용량"].exists)
        XCTAssertFalse(app.switches["요리 후 남은 양을 직접 기록"].exists)
    }

    func testAIChatCanSuggestAndApplyRecipeToPlan() {
        let app = launchApp(resetState: true, aiChatFixture: true)
        openPlanReview(app)

        let entry = app.buttons["plan.aiChatEntry"]
        XCTAssertTrue(scrollUntilVisible(app, entry), "식단 수정 AI 채팅 진입점이 보이지 않습니다")
        entry.tap()

        let screen = app.descendants(matching: .any)["aiChat.screen"]
        XCTAssertTrue(screen.waitForExistence(timeout: 5))
        let input = app.descendants(matching: .any)["aiChat.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("저녁을 더 가벼운 메뉴로 바꿔줘")
        app.buttons["aiChat.send"].tap()

        let detail = app.buttons["레시피 상세보기"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "AI 레시피 제안 카드가 나타나지 않았습니다")
        detail.tap()
        let apply = app.buttons["recipe.detail.addMeal"]
        XCTAssertTrue(apply.waitForExistence(timeout: 5), "AI 제안 적용 버튼이 나타나지 않았습니다")
        apply.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '메뉴를 식단에 반영했어요'")).firstMatch.waitForExistence(timeout: 5))
    }

    func testP0ExecutionTabsAreReachable() {
        // 장보기·냉장고는 확정한 식단에서 이어지는 화면이라 식단부터 만든다.
        let app = launchApp(resetState: true)
        createPlan(app)

        app.buttons["tab.plan"].tap()
        app.buttons["meals.shopping"].tap()
        XCTAssertTrue(app.staticTexts["장보기 리스트"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tab.plan"].exists, "장보기 상세 화면에는 하단 탭이 노출되면 안 됩니다")

        // Figma에 없는 상시 버튼은 만들지 않고 장보기 완료 버튼의 보조 동작으로 제공한다.
        app.buttons["shopping.complete"].press(forDuration: 1.1)
        XCTAssertTrue(app.buttons["보유 재료 수량 수정"].waitForExistence(timeout: 5))
        app.buttons["보유 재료 수량 수정"].tap()
        XCTAssertTrue(app.navigationBars["냉장고"].waitForExistence(timeout: 5))

        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["뒤로"].tap()

        // 레시피 탭은 피그마 헤더를 쓰므로 내비게이션 바 대신 화면 요소로 확인한다.
        app.buttons["tab.recipe"].tap()
        XCTAssertTrue(app.buttons["recipe.favorites"].waitForExistence(timeout: 5))
    }
}
