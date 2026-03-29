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

import Foundation
import os.log

/// Watches a file for changes using DispatchSource.
/// Handles write, rename, and delete events with debouncing.
@MainActor
final class FileWatcher {
    private static let logger = Logger(subsystem: "Pellucid", category: "FileWatcher")
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var coalesceTimer: DispatchWorkItem?
    private var lastModTime: Date?
    private var watchedURL: URL?

    /// Called on the main queue when the file changes.
    var onChange: (() -> Void)?

    /// Called when the watcher fails to attach or loses contact with the file.
    var onWatchFailed: ((_ reason: String) -> Void)?

    /// How long to wait after the last event before processing (trailing-edge debounce).
    /// Resets on each new event so the file is read only after writes settle.
    let debounceInterval: TimeInterval = 0.25

    /// Delay for the verification pass that catches missed events.
    let verifyInterval: TimeInterval = 0.3

    func watch(url: URL) {
        stop()
        watchedURL = url
        startWatching(url: url)
    }

    func stop() {
        coalesceTimer?.cancel()
        coalesceTimer = nil
        source?.cancel()
        source = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
        lastModTime = nil
        watchedURL = nil
    }

    private func startWatching(url: URL) {
        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            let err = String(cString: strerror(errno))
            onWatchFailed?("Cannot watch file: \(err)")
            return
        }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        // Source dispatches on .main, matching @MainActor isolation.
        // MainActor.assumeIsolated proves this to the compiler.
        source?.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                let event = self.source?.data ?? []

                if event.contains(.delete) || event.contains(.rename) {
                    // File was deleted or renamed (common with atomic-write editors).
                    // Stop watching the old descriptor and try to re-watch after a brief delay,
                    // since the editor may recreate the file.
                    self.restartAfterDelete()
                } else {
                    self.debounceNotify()
                }
            }
        }

        source?.setCancelHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.fileDescriptor >= 0 {
                    close(self.fileDescriptor)
                    self.fileDescriptor = -1
                }
            }
        }

        source?.resume()
    }

    /// Trailing-edge debounce: every event resets the timer so we only
    /// read the file after writes have settled. A verification pass
    /// afterwards catches any events DispatchSource failed to deliver.
    private func debounceNotify() {
        coalesceTimer?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, let url = self.watchedURL else { return }
                self.coalesceTimer = nil
                let currentModTime = self.modificationDate(of: url)
                if currentModTime != self.lastModTime {
                    self.lastModTime = currentModTime
                    self.onChange?()
                }
                // Schedule a verification pass to catch any missed events
                self.scheduleVerification()
            }
        }
        coalesceTimer = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    /// Follow-up check using file modification time — catches events that
    /// DispatchSource coalesced away or failed to deliver.
    private func scheduleVerification() {
        DispatchQueue.main.asyncAfter(deadline: .now() + verifyInterval) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, let url = self.watchedURL else { return }
                let currentModTime = self.modificationDate(of: url)
                if currentModTime != self.lastModTime {
                    self.lastModTime = currentModTime
                    self.onChange?()
                }
            }
        }
    }

    private func modificationDate(of url: URL) -> Date? {
        do {
            return try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        } catch {
            Self.logger.debug("Failed to read modification date for \(url.path): \(error.localizedDescription)")
            return nil
        }
    }

    /// After a delete/rename, close the old descriptor and attempt to re-open.
    /// Tries a few times with short delays to handle atomic-write patterns.
    private func restartAfterDelete() {
        source?.cancel()
        source = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }

        guard let url = watchedURL else { return }
        tryReopen(url: url, attempt: 0)
    }

    private func tryReopen(url: URL, attempt: Int) {
        let maxAttempts = 5
        guard watchedURL != nil else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            startWatching(url: url)
            debounceNotify()
        } else if attempt < maxAttempts {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.tryReopen(url: url, attempt: attempt + 1)
            }
        } else {
            onWatchFailed?("File is no longer available: \(url.lastPathComponent)")
        }
    }

    // Copy to locals because deinit cannot access @MainActor-isolated properties.
    deinit {
        let source = source
        let fd = fileDescriptor
        source?.cancel()
        if fd >= 0 {
            close(fd)
        }
    }
}
