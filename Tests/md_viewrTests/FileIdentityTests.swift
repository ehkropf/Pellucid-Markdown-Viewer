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

import XCTest
@testable import md_viewr

final class FileIdentityTests: XCTestCase {
    func testTempFileHasIdentity() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
        try "# Test".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        XCTAssertNotNil(FileIdentity(url: tmp))
    }

    func testSymlinkMatchesOriginal() throws {
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
        XCTAssertEqual(id1, id2)
    }

    func testDifferentFilesDiffer() throws {
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
        XCTAssertNotEqual(id1, id2)
    }

    func testNonexistentReturnsNil() {
        let fake = URL(fileURLWithPath: "/tmp/\(UUID().uuidString)-does-not-exist.md")
        XCTAssertNil(FileIdentity(url: fake))
    }

    func testWorksAsDictionaryKey() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
        try "# Test".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let id1 = FileIdentity(url: tmp)!
        let id2 = FileIdentity(url: tmp)!

        var dict: [FileIdentity: String] = [:]
        dict[id1] = "first"
        dict[id2] = "second"

        XCTAssertEqual(dict.count, 1, "Same file identity should overwrite in dictionary")
        XCTAssertEqual(dict[id1], "second")
    }
}
