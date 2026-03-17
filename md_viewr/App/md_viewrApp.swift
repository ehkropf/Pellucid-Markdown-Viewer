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
        WindowGroup(id: "viewer") {
            DocumentWindowView()
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
        // Guard against duplicate instances when binary is run directly
        if let bundleID = Bundle.main.bundleIdentifier {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if running.count > 1 {
                // Forward CLI args to existing instance via Finder open, then quit
                for arg in CommandLine.arguments.dropFirst() {
                    let url = Self.resolveFileArg(arg)
                    if FileManager.default.fileExists(atPath: url.path) {
                        NSWorkspace.shared.open(url)
                    }
                }
                DispatchQueue.main.async {
                    NSApp.terminate(nil)
                }
                return
            }
        }

        // Handle CLI file arguments
        for arg in CommandLine.arguments.dropFirst() {
            let resolved = Self.resolveFileArg(arg)
            if FileManager.default.fileExists(atPath: resolved.path) {
                DispatchQueue.main.async {
                    WindowManager.shared.openFile(url: resolved)
                }
            }
        }
    }

    private static func resolveFileArg(_ arg: String) -> URL {
        let url: URL
        if arg.hasPrefix("/") {
            url = URL(fileURLWithPath: arg)
        } else {
            let cwd = FileManager.default.currentDirectoryPath
            url = URL(fileURLWithPath: cwd).appendingPathComponent(arg)
        }
        return url.standardized
    }
}
