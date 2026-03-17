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

@main
struct md_viewrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup(id: "viewer", for: URL.self) { $url in
            DocumentWindowView(initialURL: url)
                .environment(WindowManager.shared)
        }
        .commands {
            AppCommands(windowManager: WindowManager.shared)
        }
        .defaultSize(width: 900, height: 700)
        .windowToolbarStyle(.unified)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            WindowManager.shared.openFile(url: url)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        for arg in args.dropFirst() {
            let url: URL
            if arg.hasPrefix("/") {
                url = URL(fileURLWithPath: arg)
            } else {
                let cwd = FileManager.default.currentDirectoryPath
                url = URL(fileURLWithPath: cwd).appendingPathComponent(arg)
            }
            let resolved = url.standardized
            if FileManager.default.fileExists(atPath: resolved.path) {
                DispatchQueue.main.async {
                    WindowManager.shared.openFile(url: resolved)
                }
            }
        }
    }
}
