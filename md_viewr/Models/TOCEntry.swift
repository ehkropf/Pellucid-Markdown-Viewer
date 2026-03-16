import Foundation

struct TOCEntry: Identifiable, Equatable {
    let id: String
    let level: Int
    let title: String
    var children: [TOCEntry]
}
