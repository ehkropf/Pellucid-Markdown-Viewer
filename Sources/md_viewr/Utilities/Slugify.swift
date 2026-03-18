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

import Foundation

/// Recognized markdown file extensions for Open panel and drag-drop validation.
let markdownExtensions = ["md", "markdown", "mdown", "mkd"]

/// Converts heading text to a kebab-cased anchor ID.
/// Matches MarkdownUI's internal `String.kebabCased()` algorithm exactly,
/// so TOC entry IDs align with the `.id()` MarkdownUI attaches to heading views.
func slugify(_ text: String) -> String {
    text
        .components(separatedBy: .alphanumerics.inverted)
        .map { $0.lowercased() }
        .joined(separator: "-")
}
