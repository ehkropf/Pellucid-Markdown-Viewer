import SwiftUI

@main
struct md_viewrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var document = MarkdownDocument()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(document)
                .onOpenURL { url in
                    document.loadFile(url: url)
                }
        }
        .commands {
            AppCommands(document: document)
        }
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
