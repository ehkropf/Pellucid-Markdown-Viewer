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

import SwiftUI
import MarkdownUI

struct ContentView: View {
    @EnvironmentObject var document: MarkdownDocument
    @State private var selectedHeadingID: String?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            detail
        }
        .navigationTitle(document.fileName)
        .navigationSubtitle(document.fileURL?.deletingLastPathComponent().path ?? "")
        .frame(minWidth: 600, minHeight: 400)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
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
                selectedID: $selectedHeadingID
            )
        }
    }

    private var detail: some View {
        Group {
            if let error = document.errorMessage {
                errorBanner(error)
            } else if document.rawMarkdown.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        MarkdownUI.Markdown(document.rawMarkdown)
                            .markdownCodeSyntaxHighlighter(.app)
                            .markdownBlockStyle(\.codeBlock) { configuration in
                                codeBlockView(configuration: configuration)
                            }
                            .markdownTheme(.gitHub)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 24)
                            .frame(maxWidth: 860, alignment: .leading)
                            .frame(maxWidth: .infinity)
                            .textSelection(.enabled)
                    }
                    .onChange(of: selectedHeadingID) { _, newValue in
                        if let id = newValue {
                            withAnimation {
                                proxy.scrollTo(id, anchor: .top)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                selectedHeadingID = nil
                            }
                        }
                    }
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
            MathBlockView(latex: configuration.content.trimmingCharacters(in: .whitespacesAndNewlines))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
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
                .background(Color(.textBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .markdownMargin(top: .zero, bottom: .em(0.8))
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  ["md", "markdown", "mdown", "mkd"].contains(url.pathExtension.lowercased())
            else { return }
            DispatchQueue.main.async {
                document.loadFile(url: url)
            }
        }
        return true
    }
}
