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
@preconcurrency import MarkdownUI

/// Builds a Solarized MarkdownUI theme for light or dark mode.
/// The two modes share identical layout; only four base tone colors differ.
@MainActor
func makeSolarizedTheme(isDark: Bool) -> Theme {
    // These four tones are the only values that differ between light and dark.
    let textColor = isDark ? Solarized.base0 : Solarized.base00
    let backgroundColor = isDark ? Solarized.base03 : Solarized.base3
    let codeBackground = isDark ? Solarized.base02 : Solarized.base2
    let subtleColor = isDark ? Solarized.base01 : Solarized.base1

    return Theme()
        .text {
            ForegroundColor(textColor)
            BackgroundColor(backgroundColor)
            FontSize(16)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
            BackgroundColor(codeBackground)
        }
        .strong {
            FontWeight(.semibold)
        }
        .link {
            ForegroundColor(Solarized.blue)
            UnderlineStyle(.single)
        }
        .heading1 { configuration in
            VStack(alignment: .leading, spacing: 0) {
                configuration.label
                    .relativePadding(.bottom, length: .em(0.3))
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 24, bottom: 16)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(2))
                    }
                Divider().overlay(subtleColor)
            }
        }
        .heading2 { configuration in
            VStack(alignment: .leading, spacing: 0) {
                configuration.label
                    .relativePadding(.bottom, length: .em(0.3))
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 24, bottom: 16)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.5))
                    }
                Divider().overlay(subtleColor)
            }
        }
        .heading3 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.125))
                .markdownMargin(top: 24, bottom: 16)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.25))
                }
        }
        .heading4 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.125))
                .markdownMargin(top: 24, bottom: 16)
                .markdownTextStyle {
                    FontWeight(.semibold)
                }
        }
        .heading5 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.125))
                .markdownMargin(top: 24, bottom: 16)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(0.875))
                }
        }
        .heading6 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.125))
                .markdownMargin(top: 24, bottom: 16)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(0.85))
                    ForegroundColor(subtleColor)
                }
        }
        .paragraph { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.25))
                .markdownMargin(top: 0, bottom: 16)
        }
        .blockquote { configuration in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Solarized.cyan)
                    .relativeFrame(width: .em(0.2))
                configuration.label
                    .markdownTextStyle { ForegroundColor(subtleColor) }
                    .relativePadding(.horizontal, length: .em(1))
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .codeBlock { configuration in
            ScrollView(.horizontal) {
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(0.225))
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.85))
                    }
                    .padding(16)
            }
            .background(codeBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .markdownMargin(top: 0, bottom: 16)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: .em(0.25))
        }
        .taskListMarker { configuration in
            Image(systemName: configuration.isCompleted ? "checkmark.square.fill" : "square")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(subtleColor, codeBackground)
                .imageScale(.small)
                .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
        }
        .table { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .markdownTableBorderStyle(.init(color: subtleColor))
                .markdownTableBackgroundStyle(
                    .alternatingRows(backgroundColor, codeBackground)
                )
                .markdownMargin(top: 0, bottom: 16)
        }
        .tableCell { configuration in
            configuration.label
                .markdownTextStyle {
                    if configuration.row == 0 {
                        FontWeight(.semibold)
                    }
                    BackgroundColor(nil)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)
                .padding(.horizontal, 13)
                .relativeLineSpacing(.em(0.25))
        }
        .thematicBreak {
            Divider()
                .relativeFrame(height: .em(0.25))
                .overlay(subtleColor)
                .markdownMargin(top: 24, bottom: 24)
        }
}
