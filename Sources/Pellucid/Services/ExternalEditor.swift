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

import Foundation
import os

private let logger = Logger(subsystem: "com.pellucid.app", category: "ExternalEditor")

protocol ExternalEditor: Sendable {
    var displayName: String { get }
    func isAvailable() -> Bool
    func openFile(_ url: URL, atLine line: Int) throws
}

enum ExternalEditorError: LocalizedError {
    case notInstalled(String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled(let name):
            "\(name) is not installed"
        case .launchFailed(let message):
            "Failed to launch editor: \(message)"
        }
    }
}

/// Opens files in MacVim using `mvim --remote-silent +{line}`.
struct MacVimEditor: ExternalEditor {
    let displayName = "MacVim"

    private static let fallbackPaths = [
        "/opt/local/bin/mvim",                          // MacPorts
        "/usr/local/bin/mvim",                          // Homebrew (legacy / Intel)
        "/opt/homebrew/bin/mvim",                       // Homebrew (Apple Silicon)
        "/Applications/MacVim.app/Contents/bin/mvim",   // Direct app install
    ]

    func isAvailable() -> Bool {
        findMvim() != nil
    }

    func openFile(_ url: URL, atLine line: Int) throws {
        guard let mvimPath = findMvim() else {
            throw ExternalEditorError.notInstalled(displayName)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: mvimPath)
        process.arguments = ["--remote-silent", "+\(line)", url.path]

        do {
            try process.run()
        } catch {
            logger.error("Failed to launch MacVim: \(error.localizedDescription)")
            throw ExternalEditorError.launchFailed(error.localizedDescription)
        }
    }

    private func findMvim() -> String? {
        findExecutable(named: "mvim", fallbackPaths: Self.fallbackPaths)
    }
}
