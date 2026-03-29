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

import AppKit
import Foundation
import os.log

extension Notification.Name {
    static let didCopyToClipboard = Notification.Name("didCopyToClipboard")
}

/// Copies text to the system pasteboard and posts a notification for toast display.
/// Does nothing if the text is empty or if the pasteboard write fails.
func copyToClipboard(_ text: String) {
    guard !text.isEmpty else { return }
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    guard pasteboard.setString(text, forType: .string) else {
        Logger(subsystem: "Pellucid", category: "Clipboard").warning("Failed to write to pasteboard")
        return
    }
    NotificationCenter.default.post(name: .didCopyToClipboard, object: nil)
}
