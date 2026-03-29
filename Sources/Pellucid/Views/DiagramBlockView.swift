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

/// Displays a PlantUML diagram rendered via the CLI subprocess.
/// Shows a spinner while rendering, a "not installed" prompt if PlantUML is missing,
/// or the error message if rendering fails.
struct DiagramBlockView: View {
    let source: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var state: RenderState = .loading

    private enum RenderState {
        case loading
        case rendered(NSImage)
        case unavailable
        case failed(String)
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            case .rendered(let image):
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .padding(colorScheme == .dark ? 8 : 0)
                    .background(
                        colorScheme == .dark
                            ? AnyShapeStyle(Color.white)
                            : AnyShapeStyle(.clear)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: colorScheme == .dark ? 8 : 0))
            case .unavailable:
                unavailableView
            case .failed(let message):
                errorView(message)
            }
        }
        .padding(.vertical, 8)
        .task(id: source) {
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

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 4) {
            Text("Diagram rendering failed")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func renderDiagram() async {
        let renderer = PlantUMLRenderer.shared
        do {
            let image = try await renderer.render(source: source)
            state = .rendered(image)
        } catch PlantUMLError.notInstalled {
            state = .unavailable
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
