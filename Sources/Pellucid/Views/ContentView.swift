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
import os.log

struct RawMarkdownKey: FocusedValueKey {
    typealias Value = String
}

extension FocusedValues {
    var rawMarkdown: String? {
        get { self[RawMarkdownKey.self] }
        set { self[RawMarkdownKey.self] = newValue }
    }
}

struct ContentView: View {
    @EnvironmentObject var document: MarkdownDocument
    @Environment(WindowManager.self) private var windowManager
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedHeadingID: String?
    @State private var showCopiedToast = false
    @State private var toastDismissTask: Task<Void, Never>?
    @State private var plantUMLTask: Task<Void, Never>?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    /// Guards against onChange(of: columnVisibility) firing during onAppear
    /// restoration, which would overwrite the stored value with the default.
    @State private var didRestoreState = false
    @SceneStorage("columnVisibility") private var storedVisibility: String = "automatic"

    /// The current render result produced by MarkdownRenderer.
    @State private var renderResult: RenderResult?

    private static let logger = Logger(subsystem: "Pellucid", category: "ContentView")
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            detail
                .navigationSplitViewColumnWidth(min: 400, ideal: 600)
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(document.fileName)
        .navigationSubtitle(document.fileURL?.deletingLastPathComponent().path ?? "")
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            switch storedVisibility {
            case "all": columnVisibility = .all
            case "detailOnly": columnVisibility = .detailOnly
            default: columnVisibility = .automatic
            }
            didRestoreState = true
            updateRenderResult()
        }
        .onChange(of: columnVisibility) { _, newValue in
            guard didRestoreState else { return }
            switch newValue {
            case .all: storedVisibility = "all"
            case .detailOnly: storedVisibility = "detailOnly"
            default: storedVisibility = "automatic"
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first,
                  markdownExtensions.contains(url.pathExtension.lowercased())
            else { return false }
            if document.fileURL == nil {
                document.loadFile(url: url)
                windowManager.updateMapping(for: document)
            } else {
                windowManager.openFile(url: url)
            }
            return true
        }
        // Re-render when the document's content, theme, or color scheme changes.
        // Track processedMarkdown (String, Equatable) as a proxy for parsedDocument changes.
        .onChange(of: document.processedMarkdown) { _, _ in
            updateRenderResult()
        }
        .onChange(of: themeManager.selectedTheme) { _, _ in
            updateRenderResult()
        }
        .onChange(of: colorScheme) { _, _ in
            updateRenderResult()
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        if document.tocEntries.isEmpty {
            Text("No headings")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            TOCSidebarView(
                entries: document.tocEntries,
                rawMarkdown: document.rawMarkdown,
                selectedID: $selectedHeadingID
            )
        }
    }

    private var detail: some View {
        ZStack {
            Group {
                if let error = document.errorMessage {
                    errorBanner(error)
                } else if document.rawMarkdown.isEmpty {
                    emptyState
                } else if let result = renderResult {
                    let theme = themeManager.selectedTheme.attributedStringTheme(isDark: isDark)
                    MarkdownTextView(
                        renderResult: result,
                        theme: theme,
                        selectedHeadingID: selectedHeadingID,
                        fileURL: document.fileURL,
                        rawMarkdown: document.rawMarkdown,
                        windowManager: windowManager
                    )
                    .focusedSceneValue(\.rawMarkdown, document.rawMarkdown)
                    .onChange(of: selectedHeadingID) { _, newValue in
                        if newValue != nil {
                            // Clear selection after scroll animation so the same
                            // heading can be re-selected from the sidebar.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                selectedHeadingID = nil
                            }
                        }
                    }
                } else {
                    // Render result not yet computed — show loading state.
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            if showCopiedToast {
                Text("Copied to clipboard")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .background(themeManager.selectedTheme.windowBackgroundColor(isDark: isDark))
        .onReceive(NotificationCenter.default.publisher(for: .didCopyToClipboard)) { _ in
            toastDismissTask?.cancel()
            withAnimation(.easeIn(duration: 0.15)) {
                showCopiedToast = true
            }
            toastDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    showCopiedToast = false
                }
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Open a Markdown file")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("File > Open or drag a .md file here")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Rendering

    /// Renders the current parsed document with the active theme.
    private func updateRenderResult() {
        guard let parsedDoc = document.parsedDocument else {
            renderResult = nil
            return
        }

        let theme = themeManager.selectedTheme.attributedStringTheme(isDark: isDark)
        let baseURL = document.fileURL?.deletingLastPathComponent()

        renderResult = MarkdownRenderer.render(
            document: parsedDoc,
            theme: theme,
            baseURL: baseURL
        )

        renderPlantUMLDiagrams()
    }

    /// Finds DiagramAttachment placeholders in the current render result and
    /// replaces them asynchronously with rendered PlantUML diagrams.
    private func renderPlantUMLDiagrams() {
        guard let result = renderResult else { return }

        let attrString = result.attributedString

        // Collect placeholder attachments with their ranges and source text.
        struct PlantUMLEntry {
            let range: NSRange
            let source: String
            let isDarkMode: Bool
        }

        var entries: [PlantUMLEntry] = []
        attrString.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attrString.length)
        ) { value, range, _ in
            if let diagram = value as? DiagramAttachment {
                entries.append(PlantUMLEntry(
                    range: range,
                    source: diagram.plantUMLSource,
                    isDarkMode: diagram.isDarkMode
                ))
            }
        }

        guard !entries.isEmpty else { return }

        // Cancel any in-flight PlantUML rendering task to avoid stale writes.
        plantUMLTask?.cancel()

        plantUMLTask = Task {
            guard await PlantUMLRenderer.shared.isAvailable() else {
                Self.logger.info("PlantUML is not available; diagram placeholders will remain")
                return
            }
            guard !Task.isCancelled else { return }

            // Work on a mutable copy of the attributed string.
            let mutableCopy = NSMutableAttributedString(attributedString: attrString)

            // Process entries in reverse order so range offsets remain valid.
            for entry in entries.reversed() {
                do {
                    let image = try await PlantUMLRenderer.shared.render(source: entry.source)
                    guard !Task.isCancelled else { return }

                    let renderedAttachment = DiagramAttachment(
                        renderedImage: image,
                        plantUMLSource: entry.source,
                        isDarkMode: entry.isDarkMode
                    )
                    let replacementString = NSMutableAttributedString(attachment: renderedAttachment)

                    // Preserve paragraph style from the placeholder.
                    let existingAttrs = mutableCopy.attributes(at: entry.range.location, effectiveRange: nil)
                    if let paraStyle = existingAttrs[.paragraphStyle] {
                        replacementString.addAttribute(
                            .paragraphStyle,
                            value: paraStyle,
                            range: NSRange(location: 0, length: replacementString.length)
                        )
                    }

                    mutableCopy.replaceCharacters(in: entry.range, with: replacementString)
                } catch {
                    Self.logger.warning("PlantUML render failed: \(error.localizedDescription)")
                }
            }

            // Only update if this task was not superseded by a newer render pass.
            guard !Task.isCancelled else { return }

            // Update the render result with the new attributed string.
            renderResult = RenderResult(
                attributedString: mutableCopy,
                sourceMap: result.sourceMap
            )
        }
    }
}
