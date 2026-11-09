import XCTest

final class InstructionInputUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testJapaneseInputCanBeReviewedAndEdited() throws {
        let app = makeApp()
        app.launch()

        let review = app.buttons["reviewInstruction"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        XCTAssertFalse(review.isEnabled)

        let editor = app.textViews["instructionEditor"]
        let original = "間違いがあったら報告してください\nファイルを削除しないでください"
        editor.tap()
        editor.typeText(original)
        app.buttons["入力を終える"].tap()
        review.tap()

        let displayedOriginal = app.staticTexts["originalInstruction"]
        XCTAssertTrue(displayedOriginal.waitForExistence(timeout: 5))
        XCTAssertEqual(displayedOriginal.label, original)

        app.buttons["returnToInput"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, original)
        editor.tap()
        editor.typeText("。")
        let edited = try XCTUnwrap(editor.value as? String)
        // タップ位置でカーソルが動くため、末尾への挿入は前提にしない。
        XCTAssertEqual(edited.count, original.count + 1)
        XCTAssertEqual(edited.replacingOccurrences(of: "。", with: ""), original)
    }

    @MainActor
    func testClearRequiresConfirmationAndCanBeUndone() throws {
        let app = makeApp()
        app.launch()

        let editor = app.textViews["instructionEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        let original = "明日の午前10時までに3枚の書類を提出してください"
        editor.tap()
        editor.typeText(original)
        app.buttons["入力を終える"].tap()

        app.buttons["clearInstruction"].tap()
        app.alerts.buttons["キャンセル"].tap()
        XCTAssertEqual(editor.value as? String, original)

        app.buttons["clearInstruction"].tap()
        app.alerts.buttons["文章を消す"].tap()
        XCTAssertFalse(app.buttons["reviewInstruction"].isEnabled)
        app.buttons["undoClear"].tap()
        XCTAssertEqual(editor.value as? String, original)
    }

    @MainActor
    func testChecklistSourceAndEditsSurviveRelaunch() throws {
        let app = makeApp()
        app.launch()

        let marker = UUID().uuidString.prefix(6)
        let original = "適当に整理しておいてください \(marker)"
        let editor = app.textViews["instructionEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(original)
        app.buttons["入力を終える"].tap()
        app.buttons["createChecklist"].tap()

        let reason = app.staticTexts["checklistReviewReason"]
        XCTAssertTrue(reason.waitForExistence(timeout: 5))
        XCTAssertTrue(reason.label.contains("要確認"))
        app.buttons["reviewChecklistOriginal"].tap()
        XCTAssertEqual(app.staticTexts["originalInstruction"].label, original)
        app.buttons["returnToInput"].tap()

        app.buttons["editChecklistItem"].tap()
        XCTAssertEqual(app.staticTexts["checklistItemSource"].label, original)
        let itemText = app.descendants(matching: .any)["checklistItemText"].firstMatch
        itemText.tap()
        itemText.typeText("追記")
        app.buttons["applyChecklistItem"].tap()

        let completion = app.buttons["checklistItemCompletion"]
        XCTAssertTrue(completion.label.contains("追記"))
        completion.tap()
        XCTAssertEqual(completion.value as? String, "完了")
        let progress = app.staticTexts["checklistProgress"]
        XCTAssertTrue(progress.label.contains("1/1"), progress.label)
        app.buttons["saveChecklist"].tap()
        XCTAssertEqual(app.staticTexts["checklistSaveState"].label, "保存済み")

        app.terminate()
        app.launch()
        app.buttons["openChecklistHistory"].tap()
        let saved = app.buttons.matching(identifier: "savedChecklist")
            .matching(NSPredicate(format: "label CONTAINS %@", String(marker))).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
        XCTAssertTrue(progress.label.contains("1/1"), progress.label)
        XCTAssertTrue(completion.label.contains("追記"))
        app.buttons["editChecklistItem"].tap()
        XCTAssertEqual(app.staticTexts["checklistItemSource"].label, original)
        app.buttons["キャンセル"].tap()
        app.buttons["closeChecklist"].tap()

        saved.swipeLeft()
        app.buttons["削除"].tap()
        app.alerts.buttons["削除"].tap()
        XCTAssertTrue(saved.waitForNonExistence(timeout: 5))
    }

    @MainActor
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KIKITORI_UI_TEST_STORE_ID"] = UUID().uuidString
        return app
    }
}
