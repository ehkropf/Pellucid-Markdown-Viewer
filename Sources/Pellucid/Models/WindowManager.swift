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
import AppKit
import os.log

/// Manages multi-window lifecycle: tracks open documents, deduplicates by
/// `FileIdentity`, reuses empty windows, and brings existing windows to front.
///
/// All file-open paths (File > Open, drag-drop, CLI args, Finder) converge
/// through `openFile(url:)`.
@MainActor @Observable
final class WindowManager {
    static let shared = WindowManager()

    private(set) var documents: [MarkdownDocument] = []
    private var openDocuments: [FileIdentity: MarkdownDocument] = [:]
    private var windowMap: [ObjectIdentifier: NSWindow] = [:]
    private var observerTokens: [ObjectIdentifier: any NSObjectProtocol] = [:]
    private(set) var openWindowAction: OpenWindowAction?
    private var urlQueue: [URL] = []
    private var nextCascadePoint: NSPoint = .zero

    private static let logger = Logger(subsystem: "Pellucid", category: "WindowManager")

    private init() {}

    /// Captures the SwiftUI `OpenWindowAction` from the first window's environment.
    /// Set only once; subsequent calls are no-ops.
    func captureOpenWindowAction(_ action: OpenWindowAction) {
        guard openWindowAction == nil else { return }
        openWindowAction = action
    }

    func register(_ document: MarkdownDocument) {
        guard !documents.contains(where: { $0 === document }) else { return }
        documents.append(document)
    }

    func unregister(_ document: MarkdownDocument) {
        let id = ObjectIdentifier(document)
        if let url = document.fileURL, let identity = FileIdentity(url: url) {
            openDocuments.removeValue(forKey: identity)
        }
        if let token = observerTokens.removeValue(forKey: id) {
            NotificationCenter.default.removeObserver(token)
        }
        windowMap.removeValue(forKey: id)
        documents.removeAll { $0 === document }
    }

    func updateMapping(for document: MarkdownDocument) {
        for (key, doc) in openDocuments where doc === document {
            openDocuments.removeValue(forKey: key)
        }
        if let url = document.fileURL, let identity = FileIdentity(url: url) {
            openDocuments[identity] = document
        }
    }

    /// Associates an `NSWindow` with a document for activation and cascade positioning.
    /// Observes `willCloseNotification` to auto-unregister on window close.
    func registerWindow(_ window: NSWindow, for document: MarkdownDocument) {
        let id = ObjectIdentifier(document)
        windowMap[id] = window
        nextCascadePoint = window.cascadeTopLeft(from: nextCascadePoint)

        let token = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak document] _ in
            Task { @MainActor in
                guard let self, let document else { return }
                self.unregister(document)
            }
        }
        observerTokens[id] = token
    }

    /// Opens a file, deduplicating against already-open documents.
    ///
    /// Three-step fallback:
    /// 1. If the file is already open, activate its window.
    /// 2. If an empty (no-file) window exists, load into it.
    /// 3. Queue the URL and request a new window via `openWindowAction`.
    func openFile(url: URL) {
        let resolved = url.standardized

        if let identity = FileIdentity(url: resolved),
           let existing = openDocuments[identity] {
            activateWindow(for: existing)
            return
        }

        if let empty = emptyDocument() {
            empty.loadFile(url: resolved)
            updateMapping(for: empty)
            activateWindow(for: empty)
            return
        }

        urlQueue.append(resolved)
        if let action = openWindowAction {
            action(id: "viewer")
        } else {
            Self.logger.warning("openWindowAction is nil — URL queued but no window will open until the action is captured")
        }
    }

    /// Displays an error message in an empty window (e.g., for CLI args pointing
    /// to nonexistent files).
    func reportError(_ message: String) {
        if let empty = emptyDocument() {
            empty.errorMessage = message
        }
    }

    func claimQueuedURL() -> URL? {
        guard !urlQueue.isEmpty else { return nil }
        return urlQueue.removeFirst()
    }

    /// Drains any remaining queued URLs by calling `openFile` for each.
    /// Called from `DocumentWindowView.onAppear` after the first window captures
    /// `openWindowAction` — this handles CLI args that were queued before
    /// the SwiftUI window system was ready.
    func processPendingURLs() {
        guard openWindowAction != nil else { return }
        let urls = urlQueue
        urlQueue.removeAll()
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
