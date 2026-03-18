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

import Testing
import Foundation
@testable import md_viewr

struct FileIdentityTests {
    @Test func tempFileHasIdentity() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
        try "# Test".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let identity = FileIdentity(url: tmp)
        #expect(identity != nil)
    }

    @Test func symlinkMatchesOriginal() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
        let link = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-link.md")
        try "# Test".write(to: tmp, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: tmp)
        defer {
            try? FileManager.default.removeItem(at: tmp)
            try? FileManager.default.removeItem(at: link)
        }

        let id1 = FileIdentity(url: tmp)
        let id2 = FileIdentity(url: link)
        #expect(id1 == id2)
    }

    @Test func differentFilesDiffer() throws {
        let tmp1 = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
        let tmp2 = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
        try "# One".write(to: tmp1, atomically: true, encoding: .utf8)
        try "# Two".write(to: tmp2, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: tmp1)
            try? FileManager.default.removeItem(at: tmp2)
        }

        let id1 = FileIdentity(url: tmp1)
        let id2 = FileIdentity(url: tmp2)
        #expect(id1 != id2)
    }

    @Test func nonexistentReturnsNil() {
        let fake = URL(fileURLWithPath: "/tmp/\(UUID().uuidString)-does-not-exist.md")
        #expect(FileIdentity(url: fake) == nil)
    }
}
