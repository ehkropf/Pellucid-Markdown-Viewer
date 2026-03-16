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
    @StateObject private var document = MarkdownDocument()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(document)
                .onOpenURL { url in
                    document.loadFile(url: url)
                }
        }
        .commands {
            AppCommands(document: document)
        }
        .defaultSize(width: 900, height: 700)
        .windowToolbarStyle(.unified)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        NotificationCenter.default.post(
            name: .openFileFromSystem,
            object: nil,
            userInfo: ["url": url]
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check for CLI argument: md_viewr /path/to/file.md
        let args = CommandLine.arguments
        if args.count > 1 {
            let path = args[1]
            let url: URL
            if path.hasPrefix("/") {
                url = URL(fileURLWithPath: path)
            } else {
                // Resolve relative paths against the current working directory
                let cwd = FileManager.default.currentDirectoryPath
                url = URL(fileURLWithPath: cwd).appendingPathComponent(path)
            }
            let resolved = url.standardized
            if FileManager.default.fileExists(atPath: resolved.path) {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .openFileFromSystem,
                        object: nil,
                        userInfo: ["url": resolved]
                    )
                }
            }
        }
    }
}

extension Notification.Name {
    static let openFileFromSystem = Notification.Name("openFileFromSystem")
}
