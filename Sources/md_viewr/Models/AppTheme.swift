// md_viewr — Native macOS markdown viewer
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
    case solarizedLight = "solarizedLight"
    case solarizedDark = "solarizedDark"

    var displayName: String {
        switch self {
        case .default: "Default"
        case .solarizedLight: "Solarized Light"
        case .solarizedDark: "Solarized Dark"
        }
    }

    @MainActor var markdownTheme: Theme {
        switch self {
        case .default: .gitHub
        case .solarizedLight: makeSolarizedLightTheme()
        case .solarizedDark: makeSolarizedDarkTheme()
        }
    }

    var syntaxColors: SyntaxColorPalette {
        switch self {
        case .default: .default
        case .solarizedLight: .solarizedLight
        case .solarizedDark: .solarizedDark
        }
    }

    var codeBlockBackground: Color {
        switch self {
        case .default: Color(.textBackgroundColor).opacity(0.5)
        case .solarizedLight: Solarized.base2
        case .solarizedDark: Solarized.base02
        }
    }

    var windowBackground: Color? {
        switch self {
        case .default: nil
        case .solarizedLight: Solarized.base3
        case .solarizedDark: Solarized.base03
        }
    }

    var mathTextColor: NSColor {
        switch self {
        case .default: .textColor
        case .solarizedLight: NSColor(Solarized.base00)
        case .solarizedDark: NSColor(Solarized.base0)
        }
    }
}
