import AppKit
import CryptoKit

/// Renders PlantUML diagrams by invoking the `plantuml` CLI as a subprocess.
/// Caches results by content hash to avoid redundant renders on file reload.
actor PlantUMLRenderer {
    static let shared = PlantUMLRenderer()

    private var cache: [String: NSImage] = [:]
    private var plantumlPath: String?
    private var checked = false

    /// Check if PlantUML is available on this system.
    func isAvailable() -> Bool {
        if !checked {
            plantumlPath = findPlantUML()
            checked = true
        }
        return plantumlPath != nil
    }

    /// Render PlantUML source to an NSImage.
    /// Returns nil if PlantUML is not installed or rendering fails.
    func render(source: String) async throws -> NSImage? {
        guard isAvailable(), let path = plantumlPath else {
            return nil
        }

        // Check cache
        let key = hashSource(source)
        if let cached = cache[key] {
            return cached
        }

        let image = try await runPlantUML(source: source, executablePath: path)
        if let image {
            cache[key] = image
        }
        return image
    }

    /// Clear the render cache.
    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Private

    private func findPlantUML() -> String? {
        let candidates = [
            "/opt/local/bin/plantuml",      // MacPorts
            "/usr/local/bin/plantuml",       // manual install / older Homebrew
            "/opt/homebrew/bin/plantuml",    // Homebrew on Apple Silicon
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try `which` as fallback
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["plantuml"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let result, !result.isEmpty, FileManager.default.isExecutableFile(atPath: result) {
                return result
            }
        } catch {}

        return nil
    }

    private func runPlantUML(source: String, executablePath: String) async throws -> NSImage? {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    let inputPipe = Pipe()
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()

                    process.executableURL = URL(fileURLWithPath: executablePath)
                    // -pipe: read from stdin, write to stdout
                    // -tsvg: output SVG for crisp rendering at any scale
                    process.arguments = ["-pipe", "-tsvg"]
                    process.standardInput = inputPipe
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe

                    try process.run()

                    // Write source to stdin and close
                    let inputData = source.data(using: .utf8) ?? Data()
                    inputPipe.fileHandleForWriting.write(inputData)
                    inputPipe.fileHandleForWriting.closeFile()

                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

                    if process.terminationStatus == 0, !outputData.isEmpty {
                        if let image = NSImage(data: outputData) {
                            continuation.resume(returning: image)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func hashSource(_ source: String) -> String {
        let digest = SHA256.hash(data: Data(source.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
