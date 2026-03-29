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

enum AppTheme: String, CaseIterable, Sendable {
    case `default` = "default"
    case solarized = "solarized"

    var displayName: String {
        switch self {
        case .default: "Default"
        case .solarized: "Solarized"
        }
    }

    func syntaxColors(isDark: Bool) -> SyntaxColorPalette {
        switch self {
        case .default: .default
        case .solarized: isDark ? .solarizedDark : .solarizedLight
        }
    }
}
