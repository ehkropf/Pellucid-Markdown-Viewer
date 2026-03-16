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

/// Displays a PlantUML diagram rendered via the CLI subprocess.
/// Shows a loading indicator while rendering, fallback on error.
struct DiagramBlockView: View {
    let source: String

    @State private var image: NSImage?
    @State private var isLoading = true
    @State private var isAvailable = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if !isAvailable {
                unavailableView
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
            } else {
                errorView
            }
        }
        .padding(.vertical, 8)
        .task {
            await renderDiagram()
        }
    }

    private var unavailableView: some View {
        VStack(spacing: 4) {
            Text("PlantUML not installed")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Text("Install with: sudo port install plantuml")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var errorView: some View {
        VStack(spacing: 4) {
            Text("Diagram rendering failed")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func renderDiagram() async {
        let renderer = PlantUMLRenderer.shared
        do {
            image = try await renderer.render(source: source)
        } catch PlantUMLError.notInstalled {
            isAvailable = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
