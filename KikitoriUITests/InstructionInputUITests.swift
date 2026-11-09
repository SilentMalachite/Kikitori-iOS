import XCTest

final class InstructionInputUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testJapaneseInputCanBeReviewedAndEdited() throws {
        let app = XCUIApplication()
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
        let app = XCUIApplication()
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
}
