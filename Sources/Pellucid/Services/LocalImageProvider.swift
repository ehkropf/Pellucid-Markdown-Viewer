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

import AppKit
import MarkdownUI
import SwiftUI

/// Image provider that loads local file:// URLs via NSImage.
/// Falls back to the default (network) provider for remote URLs,
/// nil URLs, or when NSImage fails to load the file.
struct LocalImageProvider: ImageProvider, Sendable {
    func makeImage(url: URL?) -> some View {
        if let url, url.isFileURL {
            if let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: nsImage.size.width, maxHeight: nsImage.size.height)
            } else {
                Label(url.lastPathComponent, systemImage: "photo.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            }
        } else {
            DefaultImageProvider.default.makeImage(url: url)
        }
    }
}

extension ImageProvider where Self == LocalImageProvider {
    static var local: Self { .init() }
}
