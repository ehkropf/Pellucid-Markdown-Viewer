// Pellucid — Native macOS markdown viewer
// Copyright (C) 2026 Everett Kropf
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import XCTest
@testable import Pellucid

final class AppThemeTests: XCTestCase {
    func testRawValueRoundtrip() {
        for theme in AppTheme.allCases {
            XCTAssertEqual(
                AppTheme(rawValue: theme.rawValue),
                theme,
                "Roundtrip failed for \(theme)"
            )
        }
    }

    func testDisplayNamesAreNonEmpty() {
        for theme in AppTheme.allCases {
            XCTAssertFalse(theme.displayName.isEmpty, "Empty display name for \(theme)")
        }
    }

    func testSyntaxColorsDarkVsLight() {
        let light = AppTheme.solarized.syntaxColors(isDark: false)
        let dark = AppTheme.solarized.syntaxColors(isDark: true)
        // Light and dark palettes should differ in at least the comment color
        // (base1 vs base01 in Solarized)
        XCTAssertNotEqual(light.comment, dark.comment)
    }

    func testDefaultThemeSyntaxColorsAreSameForBothModes() {
        let light = AppTheme.default.syntaxColors(isDark: false)
        let dark = AppTheme.default.syntaxColors(isDark: true)
        // Default theme uses the same palette regardless of mode
        XCTAssertEqual(light.keyword, dark.keyword)
    }
}
