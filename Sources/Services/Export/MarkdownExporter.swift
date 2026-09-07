import Foundation

/// Serialises a book's outline to Markdown.
///
/// `.obsidian` — structural nodes as headings (`##`/`###`/`####`), notes as
/// nested bullets with a `(p. N)` ref; verbatim notes as block quotes.
/// `.markmap` — pure heading + bullet tree that the markmap plugin renders
/// directly (also what the in-app preview loads).
enum MarkdownExporter {

    enum Style { case obsidian, markmap }

    static func export(_ book: Book, style: Style = .obsidian) -> String {
        var out = ""
        let title = book.title.isEmpty ? "Untitled" : book.title
        out += "# \(title)\n"
        if !book.author.isEmpty { out += "*by \(book.author)*\n" }
        out += "\n"

        for node in book.rootStructuralNodes {
            appendStructural(node, depth: 0, style: style, into: &out)
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private static func appendStructural(_ node: OutlineNode, depth: Int,
                                         style: Style, into out: inout String) {
        let level = min(6, node.kind.headingLevel + depthAdjustment(depth))
        out += String(repeating: "#", count: level) + " " + node.title
        if style == .obsidian, let p = node.startPage {
            out += "  ^p\(p)"
        }
        out += "\n\n"

        for note in node.noteChildren {
            appendNote(note, style: style, into: &out)
        }
        if !node.noteChildren.isEmpty { out += "\n" }

        for child in node.structuralChildren {
            appendStructural(child, depth: depth + 1, style: style, into: &out)
        }
    }

    private static func appendNote(_ note: OutlineNode, style: Style, into out: inout String) {
        let text = (note.noteText ?? note.title).trimmingCharacters(in: .whitespacesAndNewlines)
        let ref = note.sourcePage.map { " (p. \($0))" } ?? ""

        if note.isVerbatim {
            out += "> \(text)\(ref)\n"
        } else {
            out += "- \(text)\(ref)\n"
        }
        for sub in note.noteChildren {
            out += "\t"
            appendNote(sub, style: style, into: &out)
        }
    }

    /// Structural depth beyond the node's intrinsic level nudges the heading down
    /// one, so deeply nested sections don't all collapse to `####`.
    private static func depthAdjustment(_ depth: Int) -> Int {
        max(0, depth - 1)
    }

    static func fileName(for book: Book) -> String {
        let base = book.title.isEmpty ? "book" : book.title
        let safe = base.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined(separator: "-")
        return "\(safe).md"
    }
}
