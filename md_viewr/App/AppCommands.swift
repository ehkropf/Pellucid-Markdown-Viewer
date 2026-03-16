import SwiftUI
import UniformTypeIdentifiers

struct AppCommands: Commands {
    @ObservedObject var document: MarkdownDocument

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
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        let markdownTypes: [UTType] = [
            UTType(filenameExtension: "md"),
            UTType(filenameExtension: "markdown"),
            UTType(filenameExtension: "mdown"),
            UTType(filenameExtension: "mkd"),
        ].compactMap { $0 }

        panel.allowedContentTypes = markdownTypes

        if panel.runModal() == .OK, let url = panel.url {
            document.loadFile(url: url)
        }
    }
}
