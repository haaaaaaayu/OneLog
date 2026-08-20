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
        // Figma AI 채팅 화면은 네트워크 대신 결정론적 후보 응답으로 끝까지 검증한다.
        app.launchArguments.append("-uiTestAIChat")
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

    private func shotImmediately(_ name: String) {
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

    /// 레시피 카드의 번들 사진과 스크롤 중 상태바 안전영역을 빠르게 회귀 확인한다.
    func testCaptureRecipeGridFixes() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        tap(app.buttons["필수 약관 동의"])
        tap(app.buttons["onboarding.google"])
        tap(app.buttons["onboarding.deviceOnly"])
        tap(app.buttons["다음"].firstMatch)
        tap(app.buttons["다음"].firstMatch)
        tap(app.buttons["한끼로그 시작하기"]) || tap(app.buttons["onboarding.later"])
        guard app.buttons["tab.recipe"].waitForExistence(timeout: 5) else {
            return XCTFail("레시피 탭이 나타나지 않았습니다")
        }
        Thread.sleep(forTimeInterval: 5)
        tap(app.buttons["tab.recipe"])
        shot("recipe-grid-photos")
        app.swipeUp()
        shot("recipe-grid-safe-area")
    }

    /// 이번 수정 범위만 캡처한다. 전체 화면 회귀 대신 Figma 4·7·10·11단계와 조리 완료만 본다.
    func testCaptureFigmaFixesOnly() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        tap(app.buttons["필수 약관 동의"])
        tap(app.buttons["onboarding.google"])
        tap(app.buttons["onboarding.deviceOnly"])
        tap(app.buttons["다음"].firstMatch)
        tap(app.buttons["다음"].firstMatch)
        tap(app.buttons["한끼로그 시작하기"]) || tap(app.buttons["onboarding.later"])
        _ = app.buttons["tab.home"].waitForExistence(timeout: 5)

        let toastClose = app.buttons["알림 닫기"]
        if toastClose.waitForExistence(timeout: 2), toastClose.isHittable { toastClose.tap() }
        guard tap(app.buttons["home.createPlan"]) else {
            return XCTFail("식단 만들기 진입점을 찾지 못했습니다")
        }

        let next = app.buttons["plan.next"]
        tap(next) // 2
        tap(next) // 3
        tap(next) // 4 + 계산 시작
        shotImmediately("fix-04-loading")

        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: next)
        guard XCTWaiter.wait(for: [ready], timeout: 8) == .completed else {
            return XCTFail("식단 계산이 완료되지 않았습니다")
        }
        shot("fix-04-ready")
        tap(next) // 5
        tap(next) // 6
        tap(next) // 7
        shot("fix-07-final")
        tap(next) // 8
        tap(next) // 9
        tap(next) // 10
        shot("fix-10-purchase-summary")
        tap(next) // 11
        shot("fix-11-shopping-list")
        tap(next) // 완료

        tap(app.buttons["tab.plan"])
        let mealCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "meals.card.")).firstMatch
        guard tap(mealCard, timeout: 5) else {
            return XCTFail("요리할 식사 카드를 찾지 못했습니다")
        }
        guard tap(app.buttons["recipe.detail.addMeal"], timeout: 5) else {
            return XCTFail("레시피 상세의 요리 완료 버튼을 찾지 못했습니다")
        }
        guard app.buttons["cooking.useLeftovers"].waitForExistence(timeout: 5) else {
            return XCTFail("요리 완료 화면으로 이동하지 못했습니다")
        }
        shot("fix-cooking-done")
    }

    /// 최종 대조에서 남은 동네 인증 화면만 짧게 다시 캡처한다.
    func testCaptureNeighborhoodAuditFix() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        tap(app.buttons["필수 약관 동의"])
        tap(app.buttons["onboarding.google"])
        tap(app.buttons["onboarding.deviceOnly"])

        guard tap(app.buttons["profile.neighborhood"]) else {
            return XCTFail("동네 인증 화면을 열지 못했습니다")
        }
        let input = app.textFields["profile.neighborhoodInput"]
        guard input.waitForExistence(timeout: 4) else {
            return XCTFail("동네 검색 입력창이 없습니다")
        }
        input.tap()
        input.typeText("성수동")
        shot("audit-neighborhood-search")
        guard tap(app.buttons["neighborhood.result.0"]) else {
            return XCTFail("동네 검색 결과가 없습니다")
        }
        shot("audit-neighborhood-confirmation")
        tap(app.buttons["neighborhood.confirm"])
        shot("audit-neighborhood-verified")
    }

    /// 장보기 상세의 하단 탭 제거만 확인하는 집중 캡처다.
    func testCaptureShoppingNavigationAuditFix() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        tap(app.buttons["필수 약관 동의"])
        tap(app.buttons["onboarding.google"])
        tap(app.buttons["onboarding.deviceOnly"])
        tap(app.buttons["다음"].firstMatch)
        tap(app.buttons["다음"].firstMatch)
        tap(app.buttons["한끼로그 시작하기"]) || tap(app.buttons["onboarding.later"])
        _ = app.buttons["tab.home"].waitForExistence(timeout: 5)
        if app.buttons["알림 닫기"].waitForExistence(timeout: 2) { app.buttons["알림 닫기"].tap() }

        guard tap(app.buttons["home.createPlan"]) else {
            return XCTFail("식단 만들기를 열지 못했습니다")
        }
        let next = app.buttons["plan.next"]
        for target in 2...11 {
            if target == 5 {
                let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: next)
                guard XCTWaiter.wait(for: [ready], timeout: 8) == .completed else {
                    return XCTFail("식단 계산이 완료되지 않았습니다")
                }
            }
            tap(next)
        }
        tap(next)
        tap(app.buttons["tab.plan"])
        guard tap(app.buttons["meals.shopping"]) else {
            return XCTFail("장보기 상세를 열지 못했습니다")
        }
        XCTAssertFalse(app.buttons["tab.plan"].exists, "장보기 상세에 하단 탭이 남아 있습니다")
        shot("audit-shopping-no-tab")
    }

    func testCaptureAllFigmaScreens() {
        // 온보딩 350:1899
        shot("onboarding-welcome")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // 350:1905
        _ = app.buttons["onboarding.google"].waitForExistence(timeout: 4)
        shot("onboarding-login")

        // 구글 로그인은 시뮬레이터에서 실패한다. 실패 뒤 뜨는 기기 전용 시작으로 넘어간다.
        tap(app.buttons["필수 약관 동의"])
        tap(app.buttons["onboarding.google"])
        shot("onboarding-login-error")
        tap(app.buttons["onboarding.deviceOnly"])

        // 445:26 기본정보 (동네 인증 전)
        _ = app.buttons["profile.neighborhood"].waitForExistence(timeout: 4)
        shot("onboarding-basic-unverified")

        // 최종본 789:26 검색 → 790:26 인증 확인
        if tap(app.buttons["profile.neighborhood"]) {
            let input = app.textFields["profile.neighborhoodInput"]
            if input.waitForExistence(timeout: 3) {
                input.tap()
                input.typeText("성수동")
                shot("onboarding-neighborhood-search")
                tap(app.buttons["neighborhood.result.0"])
                shot("onboarding-neighborhood-confirmation")
                tap(app.buttons["neighborhood.confirm"])
            } else {
                shot("onboarding-neighborhood-search")
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

        // 최종본 804:125 검색 결과 / 805:17 빈 결과
        let search = app.textFields["recipe.search"]
        if search.waitForExistence(timeout: 3) {
            search.tap()
            search.typeText("두부")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
            shot("recipe-search-results")
            search.tap()
            search.typeKey("a", modifierFlags: .command)
            search.typeText("검색결과없음")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
            _ = app.descendants(matching: .any)["recipe.emptySearch"].waitForExistence(timeout: 4)
            shot("recipe-search-empty")
            search.tap()
            search.typeKey("a", modifierFlags: .command)
            search.typeText("두부")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }

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

        // 713:1322 시트/선호 조리 시간
        if tap(app.buttons["mypage.cookTime"]) {
            shot("sheet-cook-time")
            tap(app.buttons["sheet.save"])
        }

        // 713:1339 시트/보유 조리도구
        if tap(app.buttons["mypage.tools"]) {
            shot("sheet-tools")
            tap(app.buttons["sheet.save"])
        }

        // 396:77 시트/불호 음식·알레르기
        if tap(app.buttons["mypage.preferences"]) {
            shot("sheet-taste")
            tap(app.buttons["sheet.save"])
        }

        // 395:23 내 정보 수정
        if tap(app.buttons["mypage.editProfile"]) {
            shot("profile-edit")
            if tap(app.buttons["mypage.manageAccount"]) {
                _ = app.descendants(matching: .any)["settings.screen"].waitForExistence(timeout: 3)
                shot("settings")
                if tap(app.buttons["settings.notifications"]) {
                    _ = app.descendants(matching: .any)["notificationSettings.screen"].waitForExistence(timeout: 3)
                    shot("notification-settings")
                }
            }
        }
    }

    /// 식단 만들기 1~8 (350:1551, 350:1586, 350:1645, 350:1690, 350:1729, 350:1779, 350:1832, 438:23).
    func testCapturePlanFlow() {
        // 온보딩을 기기 전용으로 지나 홈까지 간다.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        tap(app.buttons["필수 약관 동의"])
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

        // 1 기간 … 11 예산 업그레이드까지 한 장씩 찍는다.
        for name in ["plan-01-duration", "plan-02-meals", "plan-03-budget", "plan-04-analyzing",
                     "plan-05-options", "plan-06-review", "plan-07-final", "plan-08-ingredients",
                     "plan-09-inventory", "plan-10-purchase-summary", "plan-11-shopping-list"] {
            shot(name)

            // 713:2072 식단 기간 선택 상태
            if name == "plan-01-duration", tap(app.buttons["plan.duration"]) {
                shot("plan-duration-picker")
                guard tap(app.buttons["plan.duration.option.5"]) else {
                    return XCTFail("기간 선택 시트에서 5일 항목을 찾지 못했습니다")
                }
            }

            // 713:2454 식단 수정 AI 채팅. 실제 입력→fixture 응답까지 화면으로 확인한다.
            if name == "plan-06-review" {
                let chatEntry = app.buttons["plan.aiChatEntry"]
                for _ in 0..<6 where !chatEntry.isHittable {
                    app.swipeUp()
                }
                shot("plan-ai-entry")
                guard tap(chatEntry) else {
                    return XCTFail("식단 검토 화면에서 AI 채팅 진입점을 찾지 못했습니다")
                }
                _ = app.descendants(matching: .any)["aiChat.screen"].waitForExistence(timeout: 5)
                let input = app.textFields["aiChat.input"]
                if input.waitForExistence(timeout: 4) {
                    input.tap()
                    input.typeText("2일차 저녁을 더 가벼운 메뉴로 바꿔줘")
                    tap(app.buttons["aiChat.send"])
                    _ = app.buttons["레시피 상세보기"].waitForExistence(timeout: 6)
                }
                shot("plan-ai-chat")
                guard tap(app.buttons["AI 채팅 닫기"]) else {
                    return XCTFail("AI 채팅 화면을 닫지 못했습니다")
                }
            }

            if name == "plan-04-analyzing" {
                let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: app.buttons["plan.next"])
                guard XCTWaiter.wait(for: [ready], timeout: 8) == .completed else {
                    return XCTFail("식단 계산이 완료되지 않았습니다")
                }
            }
            tap(app.buttons["plan.next"])
        }

        // 식단 관리 1 (723:558)
        tap(app.buttons["tab.plan"])
        shot("care-1-main")

        // 식단 관리 2 / 장보기 리스트 (723:777)
        if tap(app.buttons["meals.shopping"]) {
            shot("care-2-shopping")
            tap(app.buttons["뒤로"])
        }

        // 723:964 식단 변경. 카드의 실제 컨텍스트 메뉴에서 진입한다.
        let mealCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "meals.card.")).firstMatch
        if mealCard.waitForExistence(timeout: 5) {
            mealCard.press(forDuration: 1.1)
            if tap(app.buttons["일정 변경"]) {
                shot("care-4-meal-change")
                tap(app.buttons["변경 완료"])
            }
        }

        // 772:90 레시피를 보며 요리 → 707:1667 완료 → 723:1134 남은 재료 활용.
        if mealCard.waitForExistence(timeout: 5) {
            mealCard.tap()
            guard app.buttons["recipe.detail.addMeal"].waitForExistence(timeout: 5) else {
                return XCTFail("요리 레시피 상세의 완료 버튼을 찾지 못했습니다")
            }
            shot("care-3-recipe-detail")

            guard tap(app.buttons["recipe.detail.addMeal"]) else {
                return XCTFail("요리 완료 화면으로 이동하지 못했습니다")
            }
            guard app.buttons["cooking.useLeftovers"].waitForExistence(timeout: 5) else {
                return XCTFail("요리 완료 화면으로 이동하지 못했습니다")
            }
            shot("care-5-cooking-done")
            guard tap(app.buttons["cooking.useLeftovers"]) else {
                return XCTFail("남은 재료 활용 화면으로 이동하지 못했습니다")
            }
            shot("care-6-leftovers")
            tap(app.buttons["뒤로"])
        }

        // 홈 (713:884) — 식단이 담긴 뒤라야 날짜 띠와 식사 카드가 나온다.
        tap(app.buttons["tab.home"])
        shot("home-with-plan")

        // 레시피 탭 4 (707:881)
        tap(app.buttons["tab.recipe"])
        shot("recipe-explore-final")
        app.swipeUp()
        shot("recipe-explore-scrolled")

        // 재료 소분 1 (744:35) 대시보드 → 재료 소분 2 (723:160)
        tap(app.buttons["tab.share"])
        shot("share-1-landing")
        if tap(app.buttons["share.start"]) {
            let field = app.textFields["neighborhoodField"]
            if field.waitForExistence(timeout: 4) {
                field.tap()
                field.typeText("성수동")
                tap(app.buttons["저장"])
            }
            shot("share-2-picker")
        }
    }

    /// 최종본 재료소분 홈(744:35) → 받은 요청(795:26) → 채팅 → 약속 흐름.
    func testCaptureFinalSharingScreens() {
        app.terminate()
        step = 0
        app = XCUIApplication()
        app.launchArguments += ["-uiTestResetState", "-uiTestGoogleSignInFails", "-uiTestSharing"]
        app.launch()

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        tap(app.buttons["필수 약관 동의"])
        tap(app.buttons["onboarding.google"])
        tap(app.buttons["onboarding.deviceOnly"])
        tap(app.buttons["다음"].firstMatch)
        tap(app.buttons["다음"].firstMatch)
        tap(app.buttons["한끼로그 시작하기"]) || tap(app.buttons["onboarding.later"])
        _ = app.buttons["tab.home"].waitForExistence(timeout: 5)
        if app.buttons["알림 닫기"].waitForExistence(timeout: 2) {
            app.buttons["알림 닫기"].tap()
        }

        tap(app.buttons["tab.share"])
        _ = app.buttons["share.activePost.ui-share-post"].waitForExistence(timeout: 5)
        shot("share-active")

        let activePost = app.buttons["share.activePost.ui-share-post"]
        if activePost.waitForExistence(timeout: 5) {
            activePost.coordinate(withNormalizedOffset: CGVector(dx: 0.86, dy: 0.5)).tap()
        }
        _ = app.descendants(matching: .any)["share.receivedRequest"].waitForExistence(timeout: 5)
        XCTAssertFalse(app.buttons["tab.share"].exists, "받은 요청 상세에 하단 탭이 남아 있습니다")
        shot("share-received-request")

        tap(app.buttons["수락하고 채팅하기"])
        if activePost.waitForExistence(timeout: 5) {
            activePost.coordinate(withNormalizedOffset: CGVector(dx: 0.86, dy: 0.5)).tap()
        }
        _ = app.buttons["meetupEditorButton"].waitForExistence(timeout: 5)
        XCTAssertFalse(app.buttons["tab.share"].exists, "채팅 상세에 하단 탭이 남아 있습니다")
        shot("share-chat")
        tap(app.buttons["meetupEditorButton"])
        _ = app.descendants(matching: .any)["share.meetupDetail"].waitForExistence(timeout: 5)
        shot("share-meetup")
    }
}
