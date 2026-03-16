import SwiftUI

struct TOCSidebarView: View {
    let entries: [TOCEntry]
    @Binding var selectedID: String?

    var body: some View {
        List(selection: $selectedID) {
            ForEach(entries) { entry in
                TOCEntryRow(entry: entry, selectedID: $selectedID)
            }
        }
        .listStyle(.sidebar)
    }
}

private struct TOCEntryRow: View {
    let entry: TOCEntry
    @Binding var selectedID: String?

    var body: some View {
        if entry.children.isEmpty {
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
        } else {
            DisclosureGroup {
                ForEach(entry.children) { child in
                    TOCEntryRow(entry: child, selectedID: $selectedID)
                }
            } label: {
                Button(action: { selectedID = entry.id }) {
                    Text(entry.title)
                        .font(fontForLevel(entry.level))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
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
}
