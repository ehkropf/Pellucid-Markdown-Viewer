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

struct TOCSidebarView: View {
    let entries: [TOCEntry]
    @Binding var selectedID: String?

    var body: some View {
        List(selection: $selectedID) {
            ForEach(entries) { entry in
                TOCRootEntry(entry: entry, selectedID: $selectedID)
            }
        }
        .listStyle(.sidebar)
    }
}

/// Root-level entries use Section(isExpanded:) — the idiomatic way
/// to get expandable groups in a sidebar List on macOS.
private struct TOCRootEntry: View {
    let entry: TOCEntry
    @Binding var selectedID: String?
    @State private var isExpanded = true

    var body: some View {
        if entry.children.isEmpty {
            TOCButton(entry: entry, selectedID: $selectedID)
        } else {
            Section(isExpanded: $isExpanded) {
                ForEach(entry.children) { child in
                    TOCChildEntry(entry: child, selectedID: $selectedID)
                }
            } header: {
                TOCButton(entry: entry, selectedID: $selectedID)
            }
        }
    }
}

/// Nested entries use DisclosureGroup for deeper hierarchy.
private struct TOCChildEntry: View {
    let entry: TOCEntry
    @Binding var selectedID: String?

    var body: some View {
        if entry.children.isEmpty {
            TOCButton(entry: entry, selectedID: $selectedID)
        } else {
            DisclosureGroup {
                ForEach(entry.children) { child in
                    TOCChildEntry(entry: child, selectedID: $selectedID)
                }
            } label: {
                TOCButton(entry: entry, selectedID: $selectedID)
            }
        }
    }
}

private struct TOCButton: View {
    let entry: TOCEntry
    @Binding var selectedID: String?

    var body: some View {
        Button(action: { selectedID = entry.id }) {
            Text(entry.title)
                .font(fontForLevel(entry.level))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tag(entry.id)
    }
}

private func fontForLevel(_ level: Int) -> Font {
    switch level {
    case 1: .system(size: 13, weight: .semibold)
    case 2: .system(size: 12, weight: .medium)
    default: .system(size: 11, weight: .regular)
    }
}
