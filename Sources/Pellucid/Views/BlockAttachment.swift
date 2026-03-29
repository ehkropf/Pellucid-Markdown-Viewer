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

import AppKit
import os
@preconcurrency import SwiftMath

// MARK: - MarkdownAttachment Protocol

/// Protocol for NSTextAttachment subclasses that carry markdown-specific metadata.
/// Used by the renderer to insert block-level content (images, math, diagrams, tables)
/// into the attributed string, and by copy-as-markdown to reconstruct source.
protocol MarkdownAttachment {
    /// The original markdown source for copy-as-markdown reconstruction.
    var sourceMarkdown: String? { get }

    /// The rendered image (if any) for display in the text view.
    var attachmentImage: NSImage? { get }
}

// MARK: - Default Max Width

/// Default maximum content width for block attachments (~860pt matches current
/// ContentView layout width). Callers should pass the actual text container width
/// when available.
let blockAttachmentDefaultMaxWidth: CGFloat = 860.0

// MARK: - ImageAttachment

/// NSTextAttachment that wraps a locally-loaded NSImage from a file URL.
/// Scales down to fit maxWidth (never upscales).
final class ImageAttachment: NSTextAttachment, MarkdownAttachment {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pellucid",
        category: "ImageAttachment"
    )

    /// The source file URL, retained for context menu "Copy Image" / copy-as-markdown.
    let sourceURL: URL?

    /// Original markdown source (e.g., `![alt](path)`).
    let sourceMarkdown: String?

    /// The rendered image scaled to fit within maxWidth.
    var attachmentImage: NSImage? { image }

    /// Creates an ImageAttachment from a local file URL.
    ///
    /// - Parameters:
    ///   - url: The file URL of the image.
    ///   - maxWidth: Maximum display width; the image is scaled down if wider but never upscaled.
    ///   - sourceMarkdown: The original markdown source text.
    init(url: URL, maxWidth: CGFloat = blockAttachmentDefaultMaxWidth, sourceMarkdown: String? = nil) {
        self.sourceURL = url
        self.sourceMarkdown = sourceMarkdown

        super.init(data: nil, ofType: nil)

        if let nsImage = NSImage(contentsOf: url) {
            let scaled = Self.scaledSize(for: nsImage.size, maxWidth: maxWidth)
            nsImage.size = scaled
            self.image = nsImage
            self.bounds = CGRect(origin: .zero, size: scaled)
        } else {
            Self.logger.warning("Failed to load image from \(url.path, privacy: .public)")
        }
    }

    /// Creates an ImageAttachment from an already-loaded NSImage.
    ///
    /// - Parameters:
    ///   - nsImage: The image to display.
    ///   - maxWidth: Maximum display width.
    ///   - sourceURL: Optional source URL for context menus.
    ///   - sourceMarkdown: The original markdown source text.
    init(
        nsImage: NSImage,
        maxWidth: CGFloat = blockAttachmentDefaultMaxWidth,
        sourceURL: URL? = nil,
        sourceMarkdown: String? = nil
    ) {
        self.sourceURL = sourceURL
        self.sourceMarkdown = sourceMarkdown

        super.init(data: nil, ofType: nil)

        let scaled = Self.scaledSize(for: nsImage.size, maxWidth: maxWidth)
        nsImage.size = scaled
        self.image = nsImage
        self.bounds = CGRect(origin: .zero, size: scaled)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Scaling

    /// Scales an image size to fit within maxWidth while preserving aspect ratio.
    /// Never upscales — if the image is already narrower than maxWidth, returns original size.
    static func scaledSize(for originalSize: CGSize, maxWidth: CGFloat) -> CGSize {
        guard originalSize.width > maxWidth, originalSize.width > 0 else {
            return originalSize
        }
        let scale = maxWidth / originalSize.width
        return CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
    }
}

// MARK: - DiagramAttachment

/// NSTextAttachment for PlantUML diagrams rendered as SVG -> NSImage.
/// Adds a white background behind the diagram in dark mode for visibility,
/// matching DiagramBlockView behavior.
final class DiagramAttachment: NSTextAttachment, MarkdownAttachment {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pellucid",
        category: "DiagramAttachment"
    )

    /// The PlantUML source code for re-rendering or copy-as-markdown.
    let plantUMLSource: String

    /// Original markdown source (fenced code block).
    var sourceMarkdown: String? {
        "```plantuml\n\(plantUMLSource)\n```"
    }

    /// The rendered image.
    var attachmentImage: NSImage? { image }

    /// Whether the diagram should be rendered with a white background (dark mode).
    let isDarkMode: Bool

    /// Creates a DiagramAttachment from a pre-rendered NSImage.
    ///
    /// - Parameters:
    ///   - renderedImage: The NSImage produced by PlantUMLRenderer.
    ///   - plantUMLSource: The original PlantUML source code.
    ///   - isDarkMode: Whether to add a white background for dark mode visibility.
    ///   - maxWidth: Maximum display width.
    init(
        renderedImage: NSImage,
        plantUMLSource: String,
        isDarkMode: Bool = false,
        maxWidth: CGFloat = blockAttachmentDefaultMaxWidth
    ) {
        self.plantUMLSource = plantUMLSource
        self.isDarkMode = isDarkMode

        super.init(data: nil, ofType: nil)

        let scaledSize = ImageAttachment.scaledSize(for: renderedImage.size, maxWidth: maxWidth)

        if isDarkMode {
            // Composite the diagram onto a white background with rounded corners.
            let finalImage = Self.addWhiteBackground(
                to: renderedImage,
                size: scaledSize,
                padding: 8.0,
                cornerRadius: 8.0
            )
            self.image = finalImage
            let totalSize = CGSize(
                width: scaledSize.width + 16.0,
                height: scaledSize.height + 16.0
            )
            self.bounds = CGRect(origin: .zero, size: totalSize)
        } else {
            renderedImage.size = scaledSize
            self.image = renderedImage
            self.bounds = CGRect(origin: .zero, size: scaledSize)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Dark Mode Background

    /// Composites the diagram onto a white rounded-rect background, matching
    /// DiagramBlockView's dark mode treatment.
    private static func addWhiteBackground(
        to image: NSImage,
        size: CGSize,
        padding: CGFloat,
        cornerRadius: CGFloat
    ) -> NSImage {
        let totalSize = CGSize(
            width: size.width + padding * 2,
            height: size.height + padding * 2
        )

        let result = NSImage(size: totalSize, flipped: false) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()

            // Draw white rounded-rect background.
            let bgPath = CGPath(
                roundedRect: bounds,
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
            )
            context.setFillColor(NSColor.white.cgColor)
            context.addPath(bgPath)
            context.fillPath()

            // Draw the diagram image centered within the padding.
            let imageRect = CGRect(
                x: padding,
                y: padding,
                width: size.width,
                height: size.height
            )
            image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1.0)

            context.restoreGState()
            return true
        }

        return result
    }
}

// MARK: - MathAttachment

/// NSTextAttachment for LaTeX math expressions rendered via SwiftMath.
/// Uses MTMathImage's rendering approach: parse LaTeX -> typeset -> draw to CGContext -> NSImage.
final class MathAttachment: NSTextAttachment, MarkdownAttachment {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pellucid",
        category: "MathAttachment"
    )

    /// The LaTeX source for copy-as-markdown.
    let latexSource: String

    /// Original markdown source (fenced code block).
    var sourceMarkdown: String? {
        "```math\n\(latexSource)\n```"
    }

    /// The rendered math image.
    var attachmentImage: NSImage? { image }

    /// Creates a MathAttachment by rendering LaTeX to an NSImage.
    ///
    /// - Parameters:
    ///   - latex: The LaTeX math expression.
    ///   - fontSize: Font size for rendering (default 18pt, matching MathBlockView).
    ///   - textColor: The text color for the math expression.
    ///   - maxWidth: Maximum display width (math is centered, not scaled).
    init(
        latex: String,
        fontSize: CGFloat = 18,
        textColor: NSColor = .textColor,
        maxWidth: CGFloat = blockAttachmentDefaultMaxWidth
    ) {
        self.latexSource = latex

        super.init(data: nil, ofType: nil)

        if let renderedImage = Self.renderMath(
            latex: latex,
            fontSize: fontSize,
            textColor: textColor
        ) {
            self.image = renderedImage
            self.bounds = CGRect(origin: .zero, size: renderedImage.size)
        } else {
            Self.logger.warning("Failed to render LaTeX: \(latex.prefix(80), privacy: .public)")
            // Create a placeholder for failed math.
            let placeholder = Self.renderErrorPlaceholder(latex: latex, fontSize: fontSize)
            self.image = placeholder
            self.bounds = CGRect(origin: .zero, size: placeholder.size)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Math Rendering

    /// Renders a LaTeX expression to an NSImage using SwiftMath's public MTMathImage API.
    private static func renderMath(
        latex: String,
        fontSize: CGFloat,
        textColor: NSColor
    ) -> NSImage? {
        let mathImage = MTMathImage(
            latex: latex,
            fontSize: fontSize,
            textColor: textColor,
            labelMode: .display,
            textAlignment: .center
        )
        let (error, image) = mathImage.asImage()
        if let error {
            logger.debug("LaTeX render error: \(error.localizedDescription)")
            return nil
        }
        return image
    }

    /// Renders an error placeholder when LaTeX parsing fails.
    private static func renderErrorPlaceholder(
        latex: String,
        fontSize: CGFloat
    ) -> NSImage {
        let displayText = "⚠ \(latex.prefix(60))"
        let font = NSFont.monospacedSystemFont(ofSize: fontSize * 0.75, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        let attrString = NSAttributedString(string: displayText, attributes: attrs)
        let textSize = attrString.size()
        let imageSize = CGSize(
            width: max(textSize.width + 16, 100),
            height: max(textSize.height + 8, 24)
        )

        let image = NSImage(size: imageSize, flipped: false) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()

            // Light red background.
            context.setFillColor(NSColor.systemRed.withAlphaComponent(0.1).cgColor)
            context.fill(bounds)

            // Draw the error text.
            let textOrigin = CGPoint(
                x: 8,
                y: (bounds.height - textSize.height) / 2
            )
            attrString.draw(at: textOrigin)

            context.restoreGState()
            return true
        }

        return image
    }
}

// MARK: - TableAttachment

/// Column alignment for table cells, mirroring swift-markdown's Table.ColumnAlignment.
enum TableColumnAlignment: Sendable {
    case left
    case center
    case right
}

/// NSTextAttachment for GFM tables rendered as an NSImage.
/// Takes a 2D array of attributed strings (cells), column alignments, and header flag,
/// then renders the table to an image using Core Graphics drawing.
final class TableAttachment: NSTextAttachment, MarkdownAttachment {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pellucid",
        category: "TableAttachment"
    )

    /// Original markdown source for copy-as-markdown.
    let sourceMarkdown: String?

    /// The rendered table image.
    var attachmentImage: NSImage? { image }

    /// Table layout configuration.
    struct TableLayout {
        let headerRow: [NSAttributedString]
        let bodyRows: [[NSAttributedString]]
        let columnAlignments: [TableColumnAlignment]
        let borderColor: NSColor
        let headerBackgroundColor: NSColor
        let evenRowBackground: NSColor
        let oddRowBackground: NSColor
        let cellHorizontalPadding: CGFloat
        let cellVerticalPadding: CGFloat
    }

    /// Creates a TableAttachment by rendering a table to an NSImage.
    ///
    /// - Parameters:
    ///   - headerRow: Attributed strings for the header cells.
    ///   - bodyRows: 2D array of attributed strings for body cells.
    ///   - columnAlignments: Alignment for each column.
    ///   - theme: The AttributedStringTheme providing colors and spacing.
    ///   - maxWidth: Maximum table width.
    ///   - sourceMarkdown: The original markdown source.
    init(
        headerRow: [NSAttributedString],
        bodyRows: [[NSAttributedString]],
        columnAlignments: [TableColumnAlignment],
        theme: AttributedStringTheme,
        maxWidth: CGFloat = blockAttachmentDefaultMaxWidth,
        sourceMarkdown: String? = nil
    ) {
        self.sourceMarkdown = sourceMarkdown

        super.init(data: nil, ofType: nil)

        let layout = TableLayout(
            headerRow: headerRow,
            bodyRows: bodyRows,
            columnAlignments: columnAlignments,
            borderColor: theme.tableBorderColor,
            headerBackgroundColor: theme.tableRowBackgrounds.first ?? .textBackgroundColor,
            evenRowBackground: theme.tableRowBackgrounds.first ?? .textBackgroundColor,
            oddRowBackground: theme.tableRowBackgrounds.count > 1
                ? theme.tableRowBackgrounds[1]
                : .textBackgroundColor.withAlphaComponent(0.5),
            cellHorizontalPadding: theme.tableCellHorizontalPadding,
            cellVerticalPadding: theme.tableCellVerticalPadding
        )

        let renderedImage = Self.renderTable(layout: layout, maxWidth: maxWidth)
        self.image = renderedImage
        self.bounds = CGRect(origin: .zero, size: renderedImage.size)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Table Rendering

    /// Renders the table to an NSImage using AppKit drawing.
    private static func renderTable(layout: TableLayout, maxWidth: CGFloat) -> NSImage {
        let columnCount = layout.headerRow.count
        guard columnCount > 0 else {
            return NSImage(size: CGSize(width: 1, height: 1))
        }

        let hPad = layout.cellHorizontalPadding
        let vPad = layout.cellVerticalPadding
        let borderWidth: CGFloat = 1.0

        // Measure column widths: each column is sized to its widest cell,
        // then proportionally scaled to fit maxWidth if the total exceeds it.
        var columnWidths = [CGFloat](repeating: 0, count: columnCount)
        let allRows = [layout.headerRow] + layout.bodyRows

        for row in allRows {
            for (colIndex, cell) in row.enumerated() where colIndex < columnCount {
                let cellSize = cell.size()
                let neededWidth = cellSize.width + hPad * 2
                columnWidths[colIndex] = max(columnWidths[colIndex], neededWidth)
            }
        }

        // Scale columns if total exceeds maxWidth.
        let totalNatural = columnWidths.reduce(0, +)
        let availableWidth = maxWidth - borderWidth * CGFloat(columnCount + 1)
        if totalNatural > availableWidth, totalNatural > 0 {
            let scale = availableWidth / totalNatural
            columnWidths = columnWidths.map { $0 * scale }
        }

        let tableWidth = columnWidths.reduce(0, +) + borderWidth * CGFloat(columnCount + 1)

        // Measure row heights.
        var rowHeights = [CGFloat]()
        for row in allRows {
            var maxHeight: CGFloat = 0
            for (colIndex, cell) in row.enumerated() where colIndex < columnCount {
                let drawWidth = columnWidths[colIndex] - hPad * 2
                let constrainedSize = CGSize(width: max(drawWidth, 1), height: .greatestFiniteMagnitude)
                let boundingRect = cell.boundingRect(
                    with: constrainedSize,
                    options: [.usesLineFragmentOrigin, .usesFontLeading]
                )
                maxHeight = max(maxHeight, boundingRect.height + vPad * 2)
            }
            rowHeights.append(max(maxHeight, vPad * 2 + 16))  // Minimum row height
        }

        let tableHeight = rowHeights.reduce(0, +) + borderWidth * CGFloat(rowHeights.count + 1)

        // Render the table.
        let tableSize = CGSize(width: tableWidth, height: tableHeight)
        let image = NSImage(size: tableSize, flipped: true) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()

            var yOffset: CGFloat = 0

            for (rowIndex, row) in allRows.enumerated() {
                let rowHeight = rowHeights[rowIndex]

                // Draw row background.
                let bgColor: NSColor
                if rowIndex == 0 {
                    bgColor = layout.headerBackgroundColor
                } else if rowIndex % 2 == 0 {
                    bgColor = layout.oddRowBackground
                } else {
                    bgColor = layout.evenRowBackground
                }

                var xOffset = borderWidth
                for colIndex in 0..<columnCount {
                    let cellWidth = columnWidths[colIndex]
                    let cellRect = CGRect(
                        x: xOffset,
                        y: yOffset + borderWidth,
                        width: cellWidth,
                        height: rowHeight
                    )

                    // Background.
                    context.setFillColor(bgColor.cgColor)
                    context.fill(cellRect)

                    // Draw cell text.
                    if colIndex < row.count {
                        let cell = row[colIndex]
                        let drawWidth = cellWidth - hPad * 2
                        let constrainedSize = CGSize(width: max(drawWidth, 1), height: .greatestFiniteMagnitude)
                        let textRect = cell.boundingRect(
                            with: constrainedSize,
                            options: [.usesLineFragmentOrigin, .usesFontLeading]
                        )

                        let alignment = colIndex < layout.columnAlignments.count
                            ? layout.columnAlignments[colIndex]
                            : .left
                        let textX: CGFloat
                        switch alignment {
                        case .left:
                            textX = xOffset + hPad
                        case .center:
                            textX = xOffset + (cellWidth - textRect.width) / 2
                        case .right:
                            textX = xOffset + cellWidth - hPad - textRect.width
                        }
                        let textY = yOffset + borderWidth + vPad

                        let drawRect = CGRect(
                            x: textX,
                            y: textY,
                            width: max(drawWidth, 1),
                            height: textRect.height
                        )

                        // NSAttributedString.draw(with:options:) works in the
                        // current NSGraphicsContext, which is flipped for this image.
                        cell.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
                    }

                    xOffset += cellWidth + borderWidth
                }

                yOffset += rowHeight + borderWidth
            }

            // Draw grid lines.
            context.setStrokeColor(layout.borderColor.cgColor)
            context.setLineWidth(borderWidth)

            // Horizontal lines.
            var y: CGFloat = 0
            for rowIndex in 0...allRows.count {
                let lineY = y + borderWidth / 2
                context.move(to: CGPoint(x: 0, y: lineY))
                context.addLine(to: CGPoint(x: tableWidth, y: lineY))
                if rowIndex < rowHeights.count {
                    y += rowHeights[rowIndex] + borderWidth
                }
            }

            // Vertical lines.
            var x: CGFloat = 0
            for colIndex in 0...columnCount {
                let lineX = x + borderWidth / 2
                context.move(to: CGPoint(x: lineX, y: 0))
                context.addLine(to: CGPoint(x: lineX, y: tableHeight))
                if colIndex < columnCount {
                    x += borderWidth + columnWidths[colIndex]
                }
            }

            context.strokePath()

            context.restoreGState()
            return true
        }

        return image
    }
}
