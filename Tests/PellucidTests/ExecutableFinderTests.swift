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

import XCTest
@testable import Pellucid

final class ExecutableFinderTests: XCTestCase {

    func testFindsExecutableOnPath() {
        let result = findExecutable(named: "ls")
        XCTAssertNotNil(result)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: result!))
    }

    func testFallsBackToKnownPath() {
        let result = findExecutable(named: "nonexistent_tool_xyz", fallbackPaths: ["/bin/ls"])
        XCTAssertEqual(result, "/bin/ls")
    }

    func testReturnsNilWhenNotFound() {
        let result = findExecutable(named: "nonexistent_tool_xyz", fallbackPaths: ["/nonexistent/path"])
        XCTAssertNil(result)
    }

    func testPathResolutionTakesPrecedenceOverFallback() {
        let result = findExecutable(named: "ls", fallbackPaths: ["/some/other/ls"])
        XCTAssertNotNil(result)
        XCTAssertNotEqual(result, "/some/other/ls")
    }
}
