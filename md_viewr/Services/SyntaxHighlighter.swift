import SwiftUI
import MarkdownUI

/// Regex-based syntax highlighter that covers common token types.
/// Produces styled SwiftUI Text for use with MarkdownUI's CodeSyntaxHighlighter protocol.
struct AppCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    @Environment(\.colorScheme) private var colorScheme

    func highlightCode(_ code: String, language: String?) -> Text {
        guard let language = language?.lowercased(),
              let grammar = grammars[language]
        else {
            return Text(code)
        }

        let tokens = tokenize(code: code, grammar: grammar)
        return buildText(code: code, tokens: tokens)
    }

    private func buildText(code: String, tokens: [Token]) -> Text {
        guard !tokens.isEmpty else { return Text(code) }

        let sorted = tokens.sorted { $0.range.lowerBound < $1.range.lowerBound }
        var result = Text("")
        var currentIndex = code.startIndex

        for token in sorted {
            guard let tokenStart = Range(token.range, in: code) else { continue }
            let range = tokenStart

            // Add unstyled text before this token
            if currentIndex < range.lowerBound {
                result = result + Text(code[currentIndex..<range.lowerBound])
            }

            // Add styled token
            let tokenText = String(code[range])
            result = result + Text(tokenText).foregroundColor(color(for: token.kind))

            currentIndex = range.upperBound
        }

        // Add remaining unstyled text
        if currentIndex < code.endIndex {
            result = result + Text(code[currentIndex...])
        }

        return result
    }

    private func color(for kind: TokenKind) -> Color {
        switch kind {
        case .keyword: .purple
        case .string: .red
        case .comment: .gray
        case .number: .blue
        case .type: .teal
        case .function: .blue
        case .operator_: .secondary
        case .attribute: .orange
        case .constant: .purple
        }
    }
}

// MARK: - Token types

private enum TokenKind {
    case keyword, string, comment, number, type, function, operator_, attribute, constant
}

private struct Token {
    let range: NSRange
    let kind: TokenKind
}

// MARK: - Tokenizer

private func tokenize(code: String, grammar: Grammar) -> [Token] {
    var tokens: [Token] = []
    var occupied = IndexSet()

    // Process patterns in priority order (comments/strings first to avoid conflicts)
    for (pattern, kind) in grammar.patterns {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: grammar.options) else {
            continue
        }
        let nsRange = NSRange(code.startIndex..., in: code)
        let matches = regex.matches(in: code, range: nsRange)

        for match in matches {
            let range = match.range
            // Skip if this range overlaps with an already-claimed range
            if !occupied.intersects(integersIn: range.location..<(range.location + range.length)) {
                tokens.append(Token(range: range, kind: kind))
                occupied.insert(integersIn: range.location..<(range.location + range.length))
            }
        }
    }

    return tokens
}

// MARK: - Language grammars

private struct Grammar {
    let patterns: [(String, TokenKind)]
    var options: NSRegularExpression.Options = []
}

private let grammars: [String: Grammar] = [
    "swift": Grammar(patterns: [
        (#"//[^\n]*"#, .comment),
        (#"/\*[\s\S]*?\*/"#, .comment),
        (#"\"\"\"[\s\S]*?\"\"\""#, .string),
        (#""[^"\\]*(?:\\.[^"\\]*)*""#, .string),
        (#"\b(func|var|let|if|else|guard|return|import|struct|class|enum|protocol|extension|case|switch|default|for|in|while|repeat|break|continue|throw|throws|try|catch|do|as|is|self|Self|nil|true|false|init|deinit|static|private|public|internal|fileprivate|open|override|mutating|nonmutating|final|lazy|weak|unowned|async|await|actor|some|any|where|typealias|associatedtype|inout|defer|willSet|didSet|get|set|subscript|convenience|required|optional|indirect|nonisolated|isolated|consuming|borrowing|sending|preconcurrency|MainActor|Sendable)\b"#, .keyword),
        (#"@\w+"#, .attribute),
        (#"\b[A-Z]\w*\b"#, .type),
        (#"\b\d[\d_.]*\b"#, .number),
        (#"\b0x[0-9a-fA-F_]+\b"#, .number),
    ]),
    "python": Grammar(patterns: [
        (#"#[^\n]*"#, .comment),
        (#"\"\"\"[\s\S]*?\"\"\""#, .string),
        (#"'''[\s\S]*?'''"#, .string),
        (#""[^"\\]*(?:\\.[^"\\]*)*""#, .string),
        (#"'[^'\\]*(?:\\.[^'\\]*)*'"#, .string),
        (#"\b(def|class|if|elif|else|for|while|return|import|from|as|try|except|finally|raise|with|yield|lambda|pass|break|continue|and|or|not|in|is|None|True|False|self|global|nonlocal|assert|del|async|await|match|case)\b"#, .keyword),
        (#"@\w+"#, .attribute),
        (#"\b[A-Z]\w*\b"#, .type),
        (#"\b\d[\d_.]*\b"#, .number),
        (#"\b0x[0-9a-fA-F_]+\b"#, .number),
    ]),
    "javascript": jsGrammar,
    "js": jsGrammar,
    "typescript": tsGrammar,
    "ts": tsGrammar,
    "json": Grammar(patterns: [
        (#""[^"\\]*(?:\\.[^"\\]*)*"\s*:"#, .keyword),
        (#""[^"\\]*(?:\\.[^"\\]*)*""#, .string),
        (#"\b(true|false|null)\b"#, .constant),
        (#"-?\b\d[\d.eE+-]*\b"#, .number),
    ]),
    "bash": Grammar(patterns: [
        (#"#[^\n]*"#, .comment),
        (#""[^"\\]*(?:\\.[^"\\]*)*""#, .string),
        (#"'[^']*'"#, .string),
        (#"\b(if|then|else|elif|fi|for|while|do|done|case|esac|in|function|return|local|export|source|alias|unalias|readonly|declare|typeset|set|unset|shift|exit|exec|eval|trap|wait|break|continue|select|until|coproc)\b"#, .keyword),
        (#"\$\{?[A-Za-z_]\w*\}?"#, .attribute),
        (#"\b\d+\b"#, .number),
    ]),
    "sh": Grammar(patterns: [
        (#"#[^\n]*"#, .comment),
        (#""[^"\\]*(?:\\.[^"\\]*)*""#, .string),
        (#"'[^']*'"#, .string),
        (#"\b(if|then|else|elif|fi|for|while|do|done|case|esac|in|function|return|local|export)\b"#, .keyword),
        (#"\$\{?[A-Za-z_]\w*\}?"#, .attribute),
        (#"\b\d+\b"#, .number),
    ]),
    "c": cGrammar,
    "cpp": cppGrammar,
    "c++": cppGrammar,
    "rust": Grammar(patterns: [
        (#"//[^\n]*"#, .comment),
        (#"/\*[\s\S]*?\*/"#, .comment),
        (#""[^"\\]*(?:\\.[^"\\]*)*""#, .string),
        (#"\b(fn|let|mut|const|if|else|match|for|while|loop|return|use|mod|pub|crate|super|self|Self|struct|enum|impl|trait|type|where|as|in|ref|move|async|await|unsafe|extern|dyn|static|true|false|break|continue|yield)\b"#, .keyword),
        (#"#\[[\w:()]*\]"#, .attribute),
        (#"\b[A-Z]\w*\b"#, .type),
        (#"\b\d[\d_.]*\b"#, .number),
        (#"\b0x[0-9a-fA-F_]+\b"#, .number),
    ]),
    "go": Grammar(patterns: [
        (#"//[^\n]*"#, .comment),
        (#"/\*[\s\S]*?\*/"#, .comment),
        (#""[^"\\]*(?:\\.[^"\\]*)*""#, .string),
        (#"`[^`]*`"#, .string),
        (#"\b(func|var|const|if|else|for|range|return|import|package|type|struct|interface|map|chan|go|defer|select|case|default|switch|break|continue|fallthrough|goto|nil|true|false)\b"#, .keyword),
        (#"\b[A-Z]\w*\b"#, .type),
        (#"\b\d[\d_.]*\b"#, .number),
        (#"\b0x[0-9a-fA-F_]+\b"#, .number),
    ]),
    "ruby": Grammar(patterns: [
        (#"#[^\n]*"#, .comment),
        (#""[^"\\]*(?:\\.[^"\\]*)*""#, .string),
        (#"'[^'\\]*(?:\\.[^'\\]*)*'"#, .string),
        (#"\b(def|class|module|if|elsif|else|end|unless|while|until|for|do|begin|rescue|ensure|raise|return|yield|require|include|extend|attr_accessor|attr_reader|attr_writer|self|nil|true|false|and|or|not|in|then|when|case|super|lambda|proc)\b"#, .keyword),
        (#":[A-Za-z_]\w*"#, .constant),
        (#"@{1,2}\w+"#, .attribute),
        (#"\b[A-Z]\w*\b"#, .type),
        (#"\b\d[\d_.]*\b"#, .number),
    ]),
    "java": Grammar(patterns: [
        (#"//[^\n]*"#, .comment),
        (#"/\*[\s\S]*?\*/"#, .comment),
        (#""[^"\\]*(?:\\.[^"\\]*)*""#, .string),
        (#"\b(class|interface|enum|extends|implements|import|package|public|private|protected|static|final|abstract|synchronized|volatile|transient|native|strictfp|if|else|for|while|do|switch|case|default|break|continue|return|throw|throws|try|catch|finally|new|this|super|void|null|true|false|instanceof|assert|var|record|sealed|permits|yield)\b"#, .keyword),
        (#"@\w+"#, .attribute),
        (#"\b[A-Z]\w*\b"#, .type),
        (#"\b\d[\d_.]*[LlFfDd]?\b"#, .number),
        (#"\b0x[0-9a-fA-F_]+\b"#, .number),
    ]),
    "yaml": Grammar(patterns: [
        (#"#[^\n]*"#, .comment),
        (#"^[\w.-]+\s*:"#, .keyword),
        (#""[^"\\]*(?:\\.[^"\\]*)*""#, .string),
        (#"'[^']*'"#, .string),
        (#"\b(true|false|null|yes|no|on|off)\b"#, .constant),
        (#"\b\d[\d.]*\b"#, .number),
    ], options: .anchorsMatchLines),
    "yml": Grammar(patterns: [
        (#"#[^\n]*"#, .comment),
        (#"^[\w.-]+\s*:"#, .keyword),
        (#""[^"\\]*(?:\\.[^"\\]*)*""#, .string),
        (#"'[^']*'"#, .string),
        (#"\b(true|false|null|yes|no|on|off)\b"#, .constant),
        (#"\b\d[\d.]*\b"#, .number),
    ], options: .anchorsMatchLines),
    "toml": Grammar(patterns: [
        (#"#[^\n]*"#, .comment),
        (#"\[[\w.]+\]"#, .keyword),
        (#""[^"\\]*(?:\\.[^"\\]*)*""#, .string),
        (#"'[^']*'"#, .string),
        (#"\b(true|false)\b"#, .constant),
        (#"\b\d[\d._T:Z+-]*\b"#, .number),
    ]),
    "html": Grammar(patterns: [
        (#"<!--[\s\S]*?-->"#, .comment),
        (#""[^"]*""#, .string),
        (#"'[^']*'"#, .string),
        (#"</?[a-zA-Z][\w-]*"#, .keyword),
        (#"/?\s*>"#, .keyword),
        (#"\b[a-zA-Z-]+(?=\s*=)"#, .attribute),
    ]),
    "css": Grammar(patterns: [
        (#"/\*[\s\S]*?\*/"#, .comment),
        (#""[^"]*""#, .string),
        (#"'[^']*'"#, .string),
        (#"[.#][\w-]+"#, .keyword),
        (#"@[\w-]+"#, .attribute),
        (#"[\w-]+(?=\s*:)"#, .attribute),
        (#"#[0-9a-fA-F]{3,8}\b"#, .number),
        (#"\b\d[\d.]*(%|px|em|rem|vh|vw|pt|cm|mm|in)?\b"#, .number),
    ]),
    "sql": Grammar(patterns: [
        (#"--[^\n]*"#, .comment),
        (#"/\*[\s\S]*?\*/"#, .comment),
        (#"'[^']*'"#, .string),
        (#"(?i)\b(SELECT|FROM|WHERE|INSERT|UPDATE|DELETE|CREATE|DROP|ALTER|TABLE|INDEX|VIEW|INTO|VALUES|SET|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AND|OR|NOT|IN|IS|NULL|AS|ORDER|BY|GROUP|HAVING|LIMIT|OFFSET|UNION|ALL|DISTINCT|EXISTS|BETWEEN|LIKE|CASE|WHEN|THEN|ELSE|END|BEGIN|COMMIT|ROLLBACK|PRIMARY|KEY|FOREIGN|REFERENCES|CONSTRAINT|DEFAULT|CHECK|UNIQUE|CASCADE|GRANT|REVOKE)\b"#, .keyword),
        (#"\b\d[\d.]*\b"#, .number),
    ]),
    "markdown": Grammar(patterns: [
        (#"^#{1,6}\s+.*$"#, .keyword),
        (#"\*\*[^*]+\*\*"#, .keyword),
        (#"\*[^*]+\*"#, .string),
        (#"`[^`]+`"#, .attribute),
        (#"\[([^\]]+)\]\([^\)]+\)"#, .string),
    ], options: .anchorsMatchLines),
    "md": Grammar(patterns: [
        (#"^#{1,6}\s+.*$"#, .keyword),
        (#"\*\*[^*]+\*\*"#, .keyword),
        (#"\*[^*]+\*"#, .string),
        (#"`[^`]+`"#, .attribute),
        (#"\[([^\]]+)\]\([^\)]+\)"#, .string),
    ], options: .anchorsMatchLines),
]

private let jsGrammar = Grammar(patterns: [
    (#"//[^\n]*"#, .comment),
    (#"/\*[\s\S]*?\*/"#, .comment),
    (#"`[^`]*`"#, .string),
    (#""[^"\\]*(?:\\.[^"\\]*)*""#, .string),
    (#"'[^'\\]*(?:\\.[^'\\]*)*'"#, .string),
    (#"\b(function|const|let|var|if|else|for|while|return|import|export|from|class|extends|new|this|super|switch|case|default|break|continue|throw|try|catch|finally|typeof|instanceof|in|of|void|delete|async|await|yield|null|undefined|true|false|NaN|Infinity|do)\b"#, .keyword),
    (#"\b[A-Z]\w*\b"#, .type),
    (#"\b\d[\d_.eE]*\b"#, .number),
    (#"\b0x[0-9a-fA-F]+\b"#, .number),
])

private let tsGrammar = Grammar(patterns: [
    (#"//[^\n]*"#, .comment),
    (#"/\*[\s\S]*?\*/"#, .comment),
    (#"`[^`]*`"#, .string),
    (#""[^"\\]*(?:\\.[^"\\]*)*""#, .string),
    (#"'[^'\\]*(?:\\.[^'\\]*)*'"#, .string),
    (#"\b(function|const|let|var|if|else|for|while|return|import|export|from|class|extends|new|this|super|switch|case|default|break|continue|throw|try|catch|finally|typeof|instanceof|in|of|void|delete|async|await|yield|null|undefined|true|false|NaN|Infinity|do|type|interface|enum|namespace|abstract|implements|declare|readonly|as|is|keyof|infer|never|unknown|any|string|number|boolean|symbol|bigint|object)\b"#, .keyword),
    (#"\b[A-Z]\w*\b"#, .type),
    (#"\b\d[\d_.eE]*\b"#, .number),
    (#"\b0x[0-9a-fA-F]+\b"#, .number),
])

private let cGrammar = Grammar(patterns: [
    (#"//[^\n]*"#, .comment),
    (#"/\*[\s\S]*?\*/"#, .comment),
    (#""[^"\\]*(?:\\.[^"\\]*)*""#, .string),
    (#"'[^'\\]*(?:\\.[^'\\]*)*'"#, .string),
    (#"#\s*(include|define|ifdef|ifndef|endif|if|elif|else|undef|pragma|error|warning)\b"#, .attribute),
    (#"\b(auto|break|case|char|const|continue|default|do|double|else|enum|extern|float|for|goto|if|inline|int|long|register|restrict|return|short|signed|sizeof|static|struct|switch|typedef|union|unsigned|void|volatile|while|_Bool|_Complex|_Imaginary|NULL|true|false)\b"#, .keyword),
    (#"\b[A-Z]\w*\b"#, .type),
    (#"\b\d[\d.eEuUlLxX]*\b"#, .number),
    (#"\b0x[0-9a-fA-F]+\b"#, .number),
])

private let cppGrammar = Grammar(patterns: [
    (#"//[^\n]*"#, .comment),
    (#"/\*[\s\S]*?\*/"#, .comment),
    (#""[^"\\]*(?:\\.[^"\\]*)*""#, .string),
    (#"'[^'\\]*(?:\\.[^'\\]*)*'"#, .string),
    (#"#\s*(include|define|ifdef|ifndef|endif|if|elif|else|undef|pragma|error|warning)\b"#, .attribute),
    (#"\b(auto|break|case|char|class|const|constexpr|continue|default|delete|do|double|dynamic_cast|else|enum|explicit|extern|false|float|for|friend|goto|if|inline|int|long|mutable|namespace|new|noexcept|nullptr|operator|private|protected|public|register|reinterpret_cast|return|short|signed|sizeof|static|static_assert|static_cast|struct|switch|template|this|throw|true|try|typedef|typeid|typename|union|unsigned|using|virtual|void|volatile|while|override|final|concept|requires|co_await|co_yield|co_return|module|import|export)\b"#, .keyword),
    (#"\b(std|string|vector|map|set|unique_ptr|shared_ptr|optional|variant|any|tuple|pair|array|span)\b"#, .type),
    (#"\b[A-Z]\w*\b"#, .type),
    (#"\b\d[\d.eEuUlLxX']*\b"#, .number),
    (#"\b0x[0-9a-fA-F']+\b"#, .number),
])

// MARK: - MarkdownUI integration

extension CodeSyntaxHighlighter where Self == AppCodeSyntaxHighlighter {
    static var app: Self { AppCodeSyntaxHighlighter() }
}
