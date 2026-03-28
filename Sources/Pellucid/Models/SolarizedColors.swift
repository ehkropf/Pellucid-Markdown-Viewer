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

// MARK: - Solarized color palette

enum Solarized {
    // Base tones
    static let base03  = Color(red: 0x00 / 255.0, green: 0x2b / 255.0, blue: 0x36 / 255.0) // #002b36
    static let base02  = Color(red: 0x07 / 255.0, green: 0x36 / 255.0, blue: 0x42 / 255.0) // #073642
    static let base01  = Color(red: 0x58 / 255.0, green: 0x6e / 255.0, blue: 0x75 / 255.0) // #586e75
    static let base00  = Color(red: 0x65 / 255.0, green: 0x7b / 255.0, blue: 0x83 / 255.0) // #657b83
    static let base0   = Color(red: 0x83 / 255.0, green: 0x94 / 255.0, blue: 0x96 / 255.0) // #839496
    static let base1   = Color(red: 0x93 / 255.0, green: 0xa1 / 255.0, blue: 0xa1 / 255.0) // #93a1a1
    static let base2   = Color(red: 0xee / 255.0, green: 0xe8 / 255.0, blue: 0xd5 / 255.0) // #eee8d5
    static let base3   = Color(red: 0xfd / 255.0, green: 0xf6 / 255.0, blue: 0xe3 / 255.0) // #fdf6e3

    // Accent colors
    static let yellow  = Color(red: 0xb5 / 255.0, green: 0x89 / 255.0, blue: 0x00 / 255.0) // #b58900
    static let orange  = Color(red: 0xcb / 255.0, green: 0x4b / 255.0, blue: 0x16 / 255.0) // #cb4b16
    static let red     = Color(red: 0xdc / 255.0, green: 0x32 / 255.0, blue: 0x2f / 255.0) // #dc322f
    static let magenta = Color(red: 0xd3 / 255.0, green: 0x36 / 255.0, blue: 0x82 / 255.0) // #d33682
    static let violet  = Color(red: 0x6c / 255.0, green: 0x71 / 255.0, blue: 0xc4 / 255.0) // #6c71c4
    static let blue    = Color(red: 0x26 / 255.0, green: 0x8b / 255.0, blue: 0xd2 / 255.0) // #268bd2
    static let cyan    = Color(red: 0x2a / 255.0, green: 0xa1 / 255.0, blue: 0x98 / 255.0) // #2aa198
    static let green   = Color(red: 0x85 / 255.0, green: 0x99 / 255.0, blue: 0x00 / 255.0) // #859900
}

// MARK: - Syntax highlighting color palette

struct SyntaxColorPalette: Sendable {
    let keyword: Color
    let string: Color
    let comment: Color
    let number: Color
    let type: Color
    let function: Color
    let operator_: Color
    let attribute: Color
    let constant: Color

    static let `default` = SyntaxColorPalette(
        keyword: .purple,
        string: .red,
        comment: .gray,
        number: .blue,
        type: .teal,
        function: .blue,
        operator_: .secondary,
        attribute: .orange,
        constant: .purple
    )

    static let solarizedLight = SyntaxColorPalette(
        keyword: Solarized.green,
        string: Solarized.cyan,
        comment: Solarized.base1,
        number: Solarized.magenta,
        type: Solarized.yellow,
        function: Solarized.blue,
        operator_: Solarized.base00,
        attribute: Solarized.orange,
        constant: Solarized.violet
    )

    static let solarizedDark = SyntaxColorPalette(
        keyword: Solarized.green,
        string: Solarized.cyan,
        comment: Solarized.base01,
        number: Solarized.magenta,
        type: Solarized.yellow,
        function: Solarized.blue,
        operator_: Solarized.base0,
        attribute: Solarized.orange,
        constant: Solarized.violet
    )
}
