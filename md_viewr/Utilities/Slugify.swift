import Foundation

/// Converts heading text to a kebab-cased anchor ID.
/// Matches MarkdownUI's internal `String.kebabCased()` algorithm exactly,
/// so TOC entry IDs align with the `.id()` MarkdownUI attaches to heading views.
func slugify(_ text: String) -> String {
    text
        .components(separatedBy: .alphanumerics.inverted)
        .map { $0.lowercased() }
        .joined(separator: "-")
}
