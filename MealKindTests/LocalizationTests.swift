import XCTest
@testable import MealKind

final class LocalizationTests: XCTestCase {
    func testTabLabelsCanSwitchToSimplifiedChinese() {
        let l10n = L10n(language: .simplifiedChinese)

        XCTAssertEqual(l10n.t(.today), "今日")
        XCTAssertEqual(l10n.t(.analysis), "分析")
        XCTAssertEqual(l10n.t(.snap), "拍一拍")
        XCTAssertEqual(l10n.t(.record), "记录")
        XCTAssertEqual(l10n.t(.me), "我的")
    }

    func testDecisionTitlesLocalize() {
        XCTAssertEqual(MealDecision.fits.localizedTitle(language: .simplifiedChinese), "这餐可以纳入计划。")
        XCTAssertEqual(MealDecision.adjust.localizedTitle(language: .english), "This meal needs a small adjustment.")
    }
}
