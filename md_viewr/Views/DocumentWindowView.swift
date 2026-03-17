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

struct DocumentWindowView: View {
    let initialURL: URL?
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
                if windowManager.openWindowAction == nil {
                    windowManager.openWindowAction = openWindow
                }
                windowManager.register(document)
                if let url = initialURL {
                    document.loadFile(url: url)
                    windowManager.updateMapping(for: document)
                }
                windowManager.processPendingURLs()
            }
    }
}
