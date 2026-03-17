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
import AppKit

@MainActor @Observable
final class WindowManager {
    static let shared = WindowManager()

    private(set) var documents: [MarkdownDocument] = []
    private var openDocuments: [FileIdentity: MarkdownDocument] = [:]
    private var windowMap: [ObjectIdentifier: NSWindow] = [:]
    var openWindowAction: OpenWindowAction?
    private var pendingURLs: [URL] = []

    private init() {}

    func register(_ document: MarkdownDocument) {
        guard !documents.contains(where: { $0 === document }) else { return }
        documents.append(document)
    }

    func unregister(_ document: MarkdownDocument) {
        if let url = document.fileURL, let identity = FileIdentity(url: url) {
            openDocuments.removeValue(forKey: identity)
        }
        windowMap.removeValue(forKey: ObjectIdentifier(document))
        documents.removeAll { $0 === document }
    }

    func updateMapping(for document: MarkdownDocument) {
        // Remove old mapping for this document
        for (key, doc) in openDocuments where doc === document {
            openDocuments.removeValue(forKey: key)
        }
        // Add new mapping
        if let url = document.fileURL, let identity = FileIdentity(url: url) {
            openDocuments[identity] = document
        }
    }

    func registerWindow(_ window: NSWindow, for document: MarkdownDocument) {
        windowMap[ObjectIdentifier(document)] = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak document] _ in
            Task { @MainActor in
                guard let self, let document else { return }
                self.unregister(document)
            }
        }
    }

    func openFile(url: URL) {
        let resolved = url.standardized

        // Dedup: if file already open, activate its window
        if let identity = FileIdentity(url: resolved),
           let existing = openDocuments[identity] {
            activateWindow(for: existing)
            return
        }

        // Reuse empty window
        if let empty = emptyDocument() {
            empty.loadFile(url: resolved)
            updateMapping(for: empty)
            activateWindow(for: empty)
            return
        }

        // Open new window
        if let action = openWindowAction {
            action(id: "viewer", value: resolved)
        } else {
            pendingURLs.append(resolved)
        }
    }

    func processPendingURLs() {
        guard openWindowAction != nil else { return }
        let urls = pendingURLs
        pendingURLs.removeAll()
        for url in urls {
            openFile(url: url)
        }
    }

    private func emptyDocument() -> MarkdownDocument? {
        documents.first { $0.fileURL == nil }
    }

    private func activateWindow(for document: MarkdownDocument) {
        if let window = windowMap[ObjectIdentifier(document)] {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
        }
    }
}
