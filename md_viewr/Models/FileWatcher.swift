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

import Foundation

/// Watches a file for changes using DispatchSource.
/// Handles write, rename, and delete events with debouncing.
final class FileWatcher: @unchecked Sendable {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var debounceWorkItem: DispatchWorkItem?
    private var watchedURL: URL?

    /// Called on the main queue when the file changes.
    var onChange: (() -> Void)?

    /// Debounce interval in seconds. Editors often write in multiple steps
    /// (e.g., vim does delete + create for atomic writes).
    var debounceInterval: TimeInterval = 0.2

    func watch(url: URL) {
        stop()
        watchedURL = url
        startWatching(url: url)
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        source?.cancel()
        source = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
        watchedURL = nil
    }

    private func startWatching(url: URL) {
        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source?.setEventHandler { [weak self] in
            guard let self else { return }
            let event = self.source?.data ?? []

            if event.contains(.delete) || event.contains(.rename) {
                // File was deleted or renamed (common with atomic-write editors).
                // Stop watching the old descriptor and try to re-watch after a brief delay,
                // since the editor may recreate the file.
                self.restartAfterDelete()
            } else {
                self.debouncedNotify()
            }
        }

        source?.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        source?.resume()
    }

    private func debouncedNotify() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.onChange?()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
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
        if FileManager.default.fileExists(atPath: url.path) {
            startWatching(url: url)
            debouncedNotify()
        } else if attempt < maxAttempts {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.tryReopen(url: url, attempt: attempt + 1)
            }
        }
    }

    deinit {
        source?.cancel()
        if fileDescriptor >= 0 {
            close(fileDescriptor)
        }
    }
}
