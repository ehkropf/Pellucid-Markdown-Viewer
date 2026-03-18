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
import os.log

/// Converts block-level `$$...$$` math delimiters to fenced ```math code blocks
/// so the existing MathBlockView pipeline can render them.
func preprocessBlockMath(_ markdown: String) -> String {
    enum State {
        case normal
        case insideFencedCodeBlock(fence: String)
        case insideBlockMath
    }

    var state = State.normal
    var result: [String] = []
    let lines = markdown.components(separatedBy: "\n")

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        switch state {
        case .normal:
            if let fence = fencedCodeBlockOpener(trimmed) {
                state = .insideFencedCodeBlock(fence: fence)
                result.append(line)
            } else if trimmed == "$$" {
                state = .insideBlockMath
                result.append("```math")
            } else {
                result.append(line)
            }

        case .insideFencedCodeBlock(let fence):
            if isFenceClose(trimmed, opener: fence) {
                state = .normal
            }
            result.append(line)

        case .insideBlockMath:
            if trimmed == "$$" {
                state = .normal
                result.append("```")
            } else {
                result.append(line)
            }
        }
    }

    // Auto-close unclosed math block
    if case .insideBlockMath = state {
        Logger(subsystem: "md_viewr", category: "MathPreprocessor")
            .warning("Unclosed $$ block at end of document, auto-closing")
        result.append("```")
    }

    return result.joined(separator: "\n")
}

/// Detects a fenced code block opening line. Returns the fence string (e.g., "```" or "~~~")
/// if the line opens a fenced block, nil otherwise.
private func fencedCodeBlockOpener(_ trimmed: String) -> String? {
    for fenceChar: Character in ["`", "~"] {
        if trimmed.hasPrefix(String(repeating: fenceChar, count: 3)) {
            let fenceLength = trimmed.prefix(while: { $0 == fenceChar }).count
            return String(repeating: fenceChar, count: fenceLength)
        }
    }
    return nil
}

/// Checks if a line closes a fenced code block opened with the given fence string.
private func isFenceClose(_ trimmed: String, opener: String) -> Bool {
    let fenceChar = opener.first!
    guard trimmed.allSatisfy({ $0 == fenceChar || $0 == " " }) else { return false }
    let fenceLength = trimmed.prefix(while: { $0 == fenceChar }).count
    return fenceLength >= opener.count
}
