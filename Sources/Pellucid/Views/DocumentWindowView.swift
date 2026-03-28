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

/// Per-window wrapper that bridges WindowManager with ContentView.
/// On appear: captures openWindowAction, registers the document, claims
/// any queued URL, updates the file mapping, and drains pending URLs.
struct DocumentWindowView: View {
    @StateObject private var document = MarkdownDocument()
    @Environment(WindowManager.self) private var windowManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ContentView()
            .environmentObject(document)
            .background {
                WindowAccessor { window in
                    windowManager.registerWindow(window, for: document)
                }
            }
            .onAppear {
                windowManager.captureOpenWindowAction(openWindow)
                windowManager.register(document)
                if let url = windowManager.claimQueuedURL() {
                    document.loadFile(url: url)
                    windowManager.updateMapping(for: document)
                }
                windowManager.processPendingURLs()
            }
    }
}
