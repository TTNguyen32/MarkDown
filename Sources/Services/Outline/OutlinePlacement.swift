import Foundation

/// Maps a printed page number to the deepest structural node that owns it.
///
/// After TOC import each structural node has a `startPage`. Flattened in reading
/// order, a node owns `[startPage, nextStartPage)`. The deepest node whose range
/// contains the page wins, so a page lands on its section rather than its chapter.
enum OutlinePlacement {

    static func node(for page: Int, in book: Book) -> OutlineNode? {
        let flat = flattenedStructural(book)
        let withPages = flat.filter { $0.startPage != nil }
        guard !withPages.isEmpty else { return flat.first }

        // Sort by startPage, then by original reading order for ties.
        let ordered = withPages.enumerated().sorted { a, b in
            if a.element.startPage! != b.element.startPage! {
                return a.element.startPage! < b.element.startPage!
            }
            return a.offset < b.offset
        }.map(\.element)

        // Candidate = last node whose startPage <= page.
        guard let candidateIndex = ordered.lastIndex(where: { $0.startPage! <= page }) else {
            return ordered.first
        }
        let candidate = ordered[candidateIndex]

        // Walk up from the candidate to the deepest ancestor that still contains
        // the page (a section's range is a subrange of its chapter's).
        return deepestContaining(page, startingAt: candidate) ?? candidate
    }

    /// Fills in `endPage` on every structural node from the next start boundary.
    static func recomputeRanges(in book: Book) {
        let flat = flattenedStructural(book).filter { $0.startPage != nil }
        let ordered = flat.sorted { ($0.startPage ?? 0) < ($1.startPage ?? 0) }
        for (i, node) in ordered.enumerated() {
            let next = ordered[(i + 1)...].first(where: { ($0.startPage ?? 0) > (node.startPage ?? 0) })
            node.endPage = next.map { ($0.startPage ?? 0) - 1 }
        }
    }

    // MARK: -

    private static func deepestContaining(_ page: Int, startingAt node: OutlineNode) -> OutlineNode? {
        // Prefer a child section that contains the page.
        for child in node.structuralChildren where child.startPage != nil {
            let lower = child.startPage!
            let upper = child.endPage ?? Int.max
            if (lower...upper).contains(page) {
                return deepestContaining(page, startingAt: child) ?? child
            }
        }
        return node
    }

    static func flattenedStructural(_ book: Book) -> [OutlineNode] {
        var out: [OutlineNode] = []
        func visit(_ nodes: [OutlineNode]) {
            for n in nodes.sorted(by: { $0.order < $1.order }) where n.kind.isStructural {
                out.append(n)
                visit(n.children ?? [])
            }
        }
        visit(book.rootStructuralNodes)
        return out
    }
}
