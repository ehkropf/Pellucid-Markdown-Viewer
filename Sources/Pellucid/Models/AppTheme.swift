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

import SwiftUI
@preconcurrency import MarkdownUI

enum AppTheme: String, CaseIterable, Sendable {
    case `default` = "default"
    case solarized = "solarized"

    var displayName: String {
        switch self {
        case .default: "Default"
        case .solarized: "Solarized"
        }
    }

    @MainActor func markdownTheme(isDark: Bool) -> Theme {
        switch self {
        case .default:
            Theme.gitHub.link {
                ForegroundColor(Color(nsColor: .linkColor))
                UnderlineStyle(.single)
            }
        case .solarized: makeSolarizedTheme(isDark: isDark)
        }
    }

    func syntaxColors(isDark: Bool) -> SyntaxColorPalette {
        switch self {
        case .default: .default
        case .solarized: isDark ? .solarizedDark : .solarizedLight
        }
    }

    func codeBlockBackground(isDark: Bool) -> Color {
        switch self {
        case .default: Color(.textBackgroundColor).opacity(0.5)
        case .solarized: isDark ? Solarized.base02 : Solarized.base2
        }
    }

    func windowBackground(isDark: Bool) -> Color? {
        switch self {
        case .default: nil
        case .solarized: isDark ? Solarized.base03 : Solarized.base3
        }
    }

    func mathTextColor(isDark: Bool) -> NSColor {
        switch self {
        case .default: .textColor
        case .solarized: isDark ? NSColor(Solarized.base0) : NSColor(Solarized.base00)
        }
    }
}
