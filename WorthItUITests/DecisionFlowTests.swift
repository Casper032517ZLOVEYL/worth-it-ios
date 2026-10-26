import XCTest

final class DecisionFlowTests: XCTestCase {
    @MainActor func testCompleteDecisionAndResumeDraft() throws {
        continueAfterFailure = false
        let app = launchRegistered()
        app.buttons["tab.问一问"].tap()
        let input = app.descendants(matching: .any).matching(identifier: "decisionInput").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        capture(app, name: "01-Home")
        let start = app.buttons["startDecision"]
        XCTAssertFalse(start.isEnabled, "Blank decisions must not start")
        input.tap()
        input.typeText("周末开始一个独立小项目")
        app.swipeUp()
        XCTAssertTrue(start.isEnabled)
        start.tap()

        let next = app.buttons["nextQuestion"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled, "An answer is required")
        app.buttons["answer3"].tap()
        capture(app, name: "02-Question")
        next.tap()
        XCTAssertTrue(app.staticTexts["02 / 20"].waitForExistence(timeout: 5))
        app.buttons["保存并退出"].tap()
        app.buttons["保存进度，稍后继续"].tap()
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: "继续上次的思考").firstMatch.waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        app.buttons["tab.问一问"].tap()
        let resume = app.buttons.containing(.staticText, identifier: "继续上次的思考").firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        XCTAssertTrue(app.staticTexts["02 / 20"].waitForExistence(timeout: 5))
        app.buttons["上一题"].tap()
        XCTAssertTrue(app.buttons["answer3"].isSelected, "Previous answers must survive relaunch")
        next.tap()

        for number in 2...20 {
            XCTAssertTrue(app.staticTexts[String(format: "%02d / 20", number)].waitForExistence(timeout: 5))
            app.buttons["answer3"].tap()
            next.tap()
        }
        XCTAssertTrue(app.staticTexts["胸有成竹型"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["100"].exists)
        capture(app, name: "03-Report")

        for _ in 0..<3 { app.swipeUp() }
        let note = app.textViews.firstMatch
        if note.exists && note.isHittable {
            note.tap()
            note.typeText("先用一个周末完成最小版本")
            app.swipeUp()
        }
        let close = app.buttons.containing(.staticText, identifier: "带着答案，回到生活里").firstMatch
        for _ in 0..<3 where !close.isHittable { app.swipeUp() }
        close.tap()
        app.buttons["tab.我的"].tap()
        app.buttons["profile.history"].tap()
        XCTAssertTrue(app.staticTexts["周末开始一个独立小项目"].exists)
        capture(app, name: "04-Journal")
        app.terminate()
        app.launch()
        app.buttons["tab.我的"].tap()
        app.buttons["profile.history"].tap()
        XCTAssertTrue(app.staticTexts["周末开始一个独立小项目"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["openSettings"].tap()
        app.buttons["settings.clearHistory"].tap()
        app.buttons["清除问答历史和草稿"].tap()
        app.alerts.buttons["完成"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["profile.history"].tap()
        XCTAssertTrue(app.staticTexts["第一份决定签，等你来写。"].waitForExistence(timeout: 5))
    }

    @MainActor func testRegistrationStarsAndAppearance() throws {
        continueAfterFailure = false
        let app = launchRegistered()
        XCTAssertTrue(app.staticTexts["todayStarScore"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["readingPeriod.周"].exists)
        capture(app, name: "V3-01-Daily-Home")
        app.buttons["openStarDetails"].tap()
        XCTAssertTrue(app.staticTexts["overallStarScore"].waitForExistence(timeout: 5))
        for period in ["周", "月", "年", "日"] {
            let button = app.buttons["readingPeriod.\(period)"]
            button.tap()
            XCTAssertTrue(button.isSelected)
            XCTAssertTrue(app.staticTexts["overallStarScore"].exists)
            if period != "日" {
                XCTAssertFalse(app.staticTexts["小小幸运"].exists)
                XCTAssertFalse(app.staticTexts["让心慢下来的三件小事"].exists)
            }
        }
        app.buttons["readingPeriod.周"].tap()
        let before = app.buttons["readingDateLabel"].label
        app.buttons["nextReadingDate"].tap()
        XCTAssertNotEqual(app.buttons["readingDateLabel"].label, before)
        scrollUntilVisible(app.staticTexts["本期幸运"], app: app)
        capture(app, name: "V3-02-Weekly-Lucky")
        scrollUntilVisible(app.staticTexts["本周的五个生活角度"], app: app)
        capture(app, name: "V3-03-Weekly-Reading")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["openStarDetails"].tap()
        scrollUntilVisible(app.staticTexts["小小幸运"], app: app)
        capture(app, name: "V3-04-Daily-Lucky")
        scrollUntilVisible(app.staticTexts["让心慢下来的三件小事"], app: app)
        scrollSmall(app)
        capture(app, name: "V3-05-Daily-Tasks")
        let firstInterpretation = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "interpretation.")).firstMatch
        scrollUntilVisible(firstInterpretation, app: app)
        firstInterpretation.tap()
        XCTAssertTrue(app.buttons["完成"].waitForExistence(timeout: 5))
        capture(app, name: "V3-06-Psychological-Reading")
        app.buttons["完成"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["tab.我的"].tap()
        XCTAssertFalse(app.buttons["appearance.深色"].exists)
        capture(app, name: "V3-07-Profile")
        app.buttons["openSettings"].tap()
        XCTAssertTrue(app.buttons["settings.accountSecurity"].waitForExistence(timeout: 5))
        capture(app, name: "V3-08-Settings")
        app.buttons["settings.accountSecurity"].tap()
        XCTAssertTrue(app.staticTexts["设置密码"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["实名认证"].exists)
        XCTAssertFalse(app.staticTexts["紧急联系人"].exists)
        capture(app, name: "V3-09-Account-Security")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["settings.display"].tap()
        app.buttons["appearance.深色"].tap()
        XCTAssertTrue(app.buttons["appearance.深色"].isSelected)
        capture(app, name: "V3-10-Display-Dark")
        app.terminate(); app.launch()
        app.buttons["openSettings"].tap()
        app.buttons["settings.display"].tap()
        XCTAssertTrue(app.buttons["appearance.深色"].isSelected)
        app.buttons["appearance.浅色"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["settings.share"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5) || app.buttons["关闭"].exists || app.otherElements["ActivityListView"].exists)
        capture(app, name: "V3-11-Share")
    }

    @MainActor func testEmotionLotteryAndPersistence() throws {
        continueAfterFailure = false
        let app = launchRegistered()
        app.buttons["tab.问心签"].tap()
        let arm = app.buttons["armLottery"]
        scrollUntilVisible(arm, app: app)
        XCTAssertFalse(arm.isEnabled)
        app.swipeDown()
        app.buttons["emotion.伤心"].tap()
        scrollUntilVisible(arm, app: app)
        capture(app, name: "V3-12-Lottery")
        arm.tap()
        app.buttons["drawLot"].tap()
        let text = app.staticTexts["lotInterpretation"]
        XCTAssertTrue(text.waitForExistence(timeout: 8))
        XCTAssertTrue(text.label.contains("难过不需要"))
        capture(app, name: "V3-13-Supportive-Lot")
        app.buttons["完成"].tap()
        app.terminate(); app.launch()
        app.buttons["tab.问心签"].tap()
        app.buttons["我的签笺"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "伤心 ·")).firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor func testSMSRequiresVerificationAndReportsMissingConfiguration() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["WORTHIT_UI_TESTING"] = "1"
        app.launchEnvironment["WORTHIT_UI_RESET"] = "1"
        app.launch()
        app.buttons["registerMethod.手机号"].tap()
        let identity = app.textFields["registrationIdentifier"]
        XCTAssertTrue(identity.waitForExistence(timeout: 5))
        identity.tap(); identity.typeText("13800138000")
        app.swipeUp()
        app.buttons["registrationConsent"].tap()
        XCTAssertFalse(app.buttons["registrationContinue"].isEnabled)
        app.buttons["sendSMSCode"].tap()
        XCTAssertTrue(app.alerts["登录提示"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.staticTexts["登录服务尚未开放，请稍后再试。"].exists || app.alerts.staticTexts["界面测试不发送验证码，请在正常运行的 App 中联调。"].exists)
        capture(app, name: "V3-14-SMS-Unconfigured")
        app.alerts.buttons["知道了"].tap()
        XCTAssertFalse(app.buttons["registrationContinue"].isEnabled)
        XCTAssertFalse(app.buttons["tab.星笺"].exists)
    }

    @MainActor func testContactFreeLocalProfileAndRemovedCopy() throws {
        continueAfterFailure = false
        let app = launchLocal()
        XCTAssertTrue(app.buttons["openStarDetails"].exists)
        app.buttons["tab.我的"].tap()
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "本机未验证档案")).firstMatch.exists)
        capture(app, name: "V4-01-Local-Profile")
        app.buttons["tab.问一问"].tap()
        XCTAssertFalse(app.staticTexts["一点赛博玄学，一次认真自问。"].exists)
        XCTAssertFalse(app.staticTexts["专属本机档案 · 真实自问 · 自己选择"].exists)
        XCTAssertTrue(app.staticTexts["20 个问题"].exists)
    }

    @MainActor func testGlassNavigationDrag() throws {
        continueAfterFailure = false
        let app = launchLocal()
        let stars = app.buttons["tab.星笺"]
        let question = app.buttons["tab.问一问"]
        let lots = app.buttons["tab.问心签"]
        let profile = app.buttons["tab.我的"]
        stars.press(forDuration: 0.05, thenDragTo: question)
        XCTAssertTrue(app.textFields["decisionInput"].waitForExistence(timeout: 5))
        XCTAssertTrue(question.isSelected)
        capture(app, name: "V5-01-Animated-Orb-Glass")
        question.press(forDuration: 0.05, thenDragTo: profile)
        XCTAssertTrue(profile.isSelected)
        profile.press(forDuration: 0.05, thenDragTo: lots)
        XCTAssertTrue(app.buttons["emotion.高兴"].waitForExistence(timeout: 5))
        XCTAssertTrue(lots.isSelected)
        lots.press(forDuration: 0.05, thenDragTo: stars)
        XCTAssertTrue(app.buttons["openStarDetails"].waitForExistence(timeout: 5))
        XCTAssertTrue(stars.isSelected)
        capture(app, name: "V5-02-Daily-Glass")
    }

    @MainActor func testLanguageSwitchPersistenceAndRTL() throws {
        continueAfterFailure = false
        let app = launchLocal()
        app.buttons["openSettings"].tap()
        app.buttons.containing(.staticText, identifier: "语言设置").firstMatch.tap()
        app.buttons["language.en"].tap()
        XCTAssertTrue(app.navigationBars["Language"].waitForExistence(timeout: 5))
        capture(app, name: "V4-02-Languages-English")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["tab.问一问"].exists)
        app.buttons["tab.问一问"].tap()
        let input = app.descendants(matching: .any).matching(identifier: "decisionInput").firstMatch
        input.tap(); input.typeText("Try a new direction")
        app.swipeUp(); app.buttons["startDecision"].tap()
        XCTAssertTrue(app.staticTexts["This idea still matters to me after calm reflection over time."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["answer3"].label.contains("Fully true"))
        capture(app, name: "V4-03-Question-English")
        app.buttons["Save and exit"].tap()
        app.buttons["Save and continue later"].tap()
        app.terminate(); app.launch()
        app.buttons["openSettings"].tap()
        app.buttons.containing(.staticText, identifier: "Language").firstMatch.tap()
        XCTAssertTrue(app.buttons["language.en"].isSelected)
        let arabic = app.buttons["language.ar"]
        scrollUntilVisible(arabic, app: app); arabic.tap()
        XCTAssertTrue(app.navigationBars["اللغة"].waitForExistence(timeout: 5))
        capture(app, name: "V4-04-Languages-Arabic")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["الإعدادات"].exists)
        capture(app, name: "V4-05-Settings-RTL")
    }

    @MainActor func testGuanyinHundredLotsAndFourthEntry() throws {
        continueAfterFailure = false
        let app = launchLocal()
        app.buttons["tab.问心签"].tap()
        app.buttons["drawMode.guanyin"].tap()
        capture(app, name: "V4-06-Two-Hundred-Lots")
        app.buttons["openGuanyinLibrary"].tap()
        XCTAssertTrue(app.navigationBars["观音百签"].waitForExistence(timeout: 5))
        app.staticTexts["玉莲会十朋"].tap()
        XCTAssertTrue(app.staticTexts["千年古镜复重圆\n女再求夫男再婚\n自此门庭重改换\n更添福禄在儿孙"].waitForExistence(timeout: 5))
        capture(app, name: "V4-07-Guanyin-Fourth")
        scrollUntilVisible(app.staticTexts["传统原文"], app: app)
        capture(app, name: "V4-08-Guanyin-Traditional-Text")
    }

    @MainActor func testTreeHoleDraftAndUnavailableService() throws {
        continueAfterFailure = false
        let app = launchLocal()
        let tree = app.buttons["tab.树洞"]
        XCTAssertLessThan(app.buttons["tab.问一问"].frame.midX, tree.frame.midX)
        XCTAssertLessThan(tree.frame.midX, app.buttons["tab.问心签"].frame.midX)
        tree.tap()
        XCTAssertTrue(app.staticTexts["tree.status"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tree.send"].isEnabled)
        capture(app, name: "V6-01-Tree-Hole")
        app.buttons["先听我说，不用给建议"].tap()
        XCTAssertFalse(app.buttons["tree.send"].isEnabled)
        app.buttons["tab.我的"].tap()
        app.terminate(); app.launch()
        app.buttons["tab.树洞"].tap()
        let input = app.descendants(matching: .any).matching(identifier: "tree.input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertTrue((input.value as? String ?? "").contains("先听我说"))
        XCTAssertFalse(app.staticTexts["树洞 · AI"].exists)
    }

    @MainActor func testZodiacProfileAndBirthPlace() throws {
        continueAfterFailure = false
        let app = launchRegistered()
        app.buttons["tab.我的"].tap()
        app.buttons["profile.zodiacDetails"].tap()
        XCTAssertTrue(app.navigationBars["我的星座档案"].waitForExistence(timeout: 5))
        capture(app, name: "V6-02-Zodiac-Password")
        scrollUntilVisible(app.buttons["zodiac.editPlace"], app: app)
        app.buttons["zodiac.editPlace"].tap()
        let search = app.textFields["birthPlace.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("北京\n")
        app.buttons["birthPlace.city.北京"].tap()
        scrollUntilVisible(app.buttons["birthPlace.save"], app: app)
        app.buttons["birthPlace.save"].tap()
        XCTAssertTrue(app.navigationBars["我的星座档案"].waitForExistence(timeout: 5))
        let sun = app.descendants(matching: .any).matching(identifier: "zodiac.placement.0").firstMatch
        scrollUntilVisible(sun, app: app)
        capture(app, name: "V6-03-Native-Natal-Chart")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "zodiac.placement.1").firstMatch.exists)
        app.segmentedControls["zodiac.segment"].buttons["宫位"].tap()
        XCTAssertTrue(app.staticTexts["第 1 宫"].waitForExistence(timeout: 5))
        capture(app, name: "V6-04-Whole-Sign-Houses")
    }

    @MainActor private func launchLocal() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["WORTHIT_UI_TESTING"] = "1"
        app.launchEnvironment["WORTHIT_UI_RESET"] = "1"
        app.launch()
        app.launchEnvironment.removeValue(forKey: "WORTHIT_UI_RESET")
        XCTAssertTrue(app.buttons["registerMethod.本机档案"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["registrationIdentifier"].exists)
        let consent = app.buttons["registrationConsent"]
        for _ in 0..<3 where !consent.isHittable { app.swipeUp() }
        consent.tap()
        app.buttons["registrationContinue"].tap()
        let nickname = app.textFields["profileNickname"]
        XCTAssertTrue(nickname.waitForExistence(timeout: 5))
        nickname.tap(); nickname.typeText("Casper\n")
        app.swipeUp()
        app.buttons["finishRegistration"].tap()
        XCTAssertTrue(app.buttons["tab.星笺"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor private func launchRegistered() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["WORTHIT_UI_TESTING"] = "1"
        app.launchEnvironment["WORTHIT_UI_RESET"] = "1"
        app.launch()
        app.launchEnvironment.removeValue(forKey: "WORTHIT_UI_RESET")
        XCTAssertTrue(app.buttons["registrationContinue"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["registrationContinue"].isEnabled)
        capture(app, name: "V2-01-Registration")
        app.buttons["registerMethod.邮箱"].tap()
        let identity = app.descendants(matching: .any).matching(identifier: "registrationIdentifier").firstMatch
        identity.tap()
        identity.typeText("qa@example.com\n")
        let consent = app.buttons["registrationConsent"]
        for _ in 0..<2 where !consent.isHittable { app.swipeUp() }
        consent.tap()
        app.buttons["registrationContinue"].tap()
        let nickname = app.textFields["profileNickname"]
        XCTAssertTrue(nickname.waitForExistence(timeout: 5))
        nickname.tap()
        nickname.typeText("小满\n")
        app.swipeUp()
        app.switches["birthTimeKnown"].tap()
        XCTAssertTrue(app.datePickers["profileBirthTime"].exists)
        capture(app, name: "V2-02-Birth-Profile")
        app.buttons["finishRegistration"].tap()
        XCTAssertTrue(app.buttons["tab.星笺"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor private func scrollSmall(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        start.press(forDuration: 0.15, thenDragTo: end)
    }

    @MainActor private func scrollUntilVisible(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<15 {
            if element.isHittable && element.frame.maxY < app.frame.height - 130 && element.frame.midY > 100 { break }
            scrollSmall(app)
        }
        XCTAssertTrue(element.isHittable && element.frame.maxY < app.frame.height - 130)
    }

    @MainActor private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
