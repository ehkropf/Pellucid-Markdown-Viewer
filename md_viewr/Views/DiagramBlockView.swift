import SwiftUI

/// Displays a PlantUML diagram rendered via the CLI subprocess.
/// Shows a loading indicator while rendering, fallback on error.
struct DiagramBlockView: View {
    let source: String

    @State private var image: NSImage?
    @State private var isLoading = true
    @State private var isAvailable = true

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
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func renderDiagram() async {
        let renderer = PlantUMLRenderer.shared
        guard await renderer.isAvailable() else {
            isAvailable = false
            isLoading = false
            return
        }

        do {
            image = try await renderer.render(source: source)
        } catch {
            image = nil
        }
        isLoading = false
    }
}
