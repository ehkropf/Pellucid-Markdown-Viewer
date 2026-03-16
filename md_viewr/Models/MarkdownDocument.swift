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

@preconcurrency import Foundation
import SwiftUI
import Markdown

@MainActor
class MarkdownDocument: ObservableObject {
    @Published var fileURL: URL?
    @Published var rawMarkdown: String = ""
    @Published var fileName: String = "No File"
    @Published var tocEntries: [TOCEntry] = []

    private let fileWatcher = FileWatcher()
    private var systemFileNotificationObserver: (any NSObjectProtocol)?

    init() {
        systemFileNotificationObserver = NotificationCenter.default.addObserver(
            forName: .openFileFromSystem,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let url = notification.userInfo?["url"] as? URL
            Task { @MainActor in
                guard let self, let url else { return }
                self.loadFile(url: url)
            }
        }
    }

    nonisolated deinit {
        let observer = systemFileNotificationObserver
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func loadFile(url: URL) {
        fileURL = url
        fileName = url.lastPathComponent
        reloadFile()

        fileWatcher.onChange = { [weak self] in
            Task { @MainActor in
                self?.reloadFile()
            }
        }
        fileWatcher.watch(url: url)
    }

    func reloadFile() {
        guard let url = fileURL else { return }
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            rawMarkdown = content

            let document = Document(parsing: content)
            tocEntries = TOCExtractor.extractTOC(from: document)
        } catch {
            rawMarkdown = "**Error reading file:** \(error.localizedDescription)"
            tocEntries = []
        }
    }
}
