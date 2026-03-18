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
import UniformTypeIdentifiers

struct AppCommands: Commands {
    let windowManager: WindowManager

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open...") {
                openFile()
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        SidebarCommands()
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        let markdownTypes: [UTType] = markdownExtensions.compactMap {
            UTType(filenameExtension: $0)
        }

        panel.allowedContentTypes = markdownTypes

        if panel.runModal() == .OK {
            for url in panel.urls {
                windowManager.openFile(url: url)
            }
        }
    }
}
