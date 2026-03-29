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
import MarkdownUI

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
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    /// Guards against onChange(of: columnVisibility) firing during onAppear
    /// restoration, which would overwrite the stored value with the default.
    @State private var didRestoreState = false
    @SceneStorage("columnVisibility") private var storedVisibility: String = "automatic"

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
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            MarkdownUI.Markdown(document.processedMarkdown, imageBaseURL: document.fileURL?.deletingLastPathComponent())
                                .markdownCodeSyntaxHighlighter(AppCodeSyntaxHighlighter(palette: themeManager.selectedTheme.syntaxColors(isDark: isDark)))
                                .markdownBlockStyle(\.codeBlock) { configuration in
                                    codeBlockView(configuration: configuration)
                                }
                                .markdownImageProvider(.local)
                                .markdownTheme(themeManager.selectedTheme.markdownTheme(isDark: isDark))
                                .padding(.horizontal, 32)
                                .padding(.vertical, 24)
                                .frame(maxWidth: 860, alignment: .leading)
                                .frame(maxWidth: .infinity)
                                .textSelection(.enabled)
                        }
                        .background(themeManager.selectedTheme.windowBackground(isDark: isDark) ?? Color(.windowBackgroundColor))
                        .focusedSceneValue(\.rawMarkdown, document.rawMarkdown)
                        .onChange(of: selectedHeadingID) { _, newValue in
                            if let id = newValue {
                                withAnimation {
                                    proxy.scrollTo(id, anchor: .top)
                                }
                                // Clear selection after scroll animation so the same heading can be re-selected
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    selectedHeadingID = nil
                                }
                            }
                        }
                    }
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

    @ViewBuilder
    private func codeBlockView(configuration: CodeBlockConfiguration) -> some View {
        let lang = configuration.language?.lowercased()
        if lang == "math" || lang == "latex" {
            MathBlockView(latex: configuration.content.trimmingCharacters(in: .whitespacesAndNewlines), textColor: themeManager.selectedTheme.mathTextColor(isDark: isDark))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .markdownMargin(top: .em(0.8), bottom: .em(0.8))
        } else if lang == "plantuml" {
            DiagramBlockView(source: configuration.content)
        } else {
            configuration.label
                .relativeLineSpacing(.em(0.225))
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(.em(0.85))
                }
                .padding(16)
                .background(themeManager.selectedTheme.codeBlockBackground(isDark: isDark))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .markdownMargin(top: .zero, bottom: .em(0.8))
        }
    }
}
