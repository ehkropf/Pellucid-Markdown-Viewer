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
            tocButton(entry: entry)
        } else {
            Section(isExpanded: $isExpanded) {
                ForEach(entry.children) { child in
                    TOCChildEntry(entry: child, selectedID: $selectedID)
                }
            } header: {
                tocButton(entry: entry)
            }
        }
    }

    @ViewBuilder
    private func tocButton(entry: TOCEntry) -> some View {
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

/// Nested entries use DisclosureGroup for deeper hierarchy.
private struct TOCChildEntry: View {
    let entry: TOCEntry
    @Binding var selectedID: String?

    var body: some View {
        if entry.children.isEmpty {
            tocButton(entry: entry)
        } else {
            DisclosureGroup {
                ForEach(entry.children) { child in
                    TOCChildEntry(entry: child, selectedID: $selectedID)
                }
            } label: {
                tocButton(entry: entry)
            }
        }
    }

    @ViewBuilder
    private func tocButton(entry: TOCEntry) -> some View {
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
    case 3: .system(size: 11, weight: .regular)
    default: .system(size: 11, weight: .regular)
    }
}
