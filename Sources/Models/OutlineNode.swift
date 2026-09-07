import Foundation
import SwiftData

enum NodeKind: String, Codable, CaseIterable {
    case part, chapter, section, note

    var isStructural: Bool { self != .note }

    /// Markdown heading level used by the exporter for structural nodes.
    var headingLevel: Int {
        switch self {
        case .part: return 2
        case .chapter: return 3
        case .section: return 4
        case .note: return 0
        }
    }
}

@Model
final class OutlineNode {
    var id: UUID = UUID()
    var title: String = ""
    var rawKind: String = NodeKind.section.rawValue

    /// Structural nodes only.
    var startPage: Int?
    var endPage: Int?

    /// Sibling ordering within a parent.
    var order: Int = 0

    /// Note leaves only.
    var noteText: String?
    var isVerbatim: Bool = false
    var sourcePage: Int?
    var sourceScanID: UUID?

    var createdAt: Date = Date()

    var book: Book?
    var parent: OutlineNode?

    @Relationship(deleteRule: .cascade, inverse: \OutlineNode.parent)
    var children: [OutlineNode]? = []

    init(title: String = "", kind: NodeKind = .section) {
        self.title = title
        self.rawKind = kind.rawValue
    }

    var kind: NodeKind {
        get { NodeKind(rawValue: rawKind) ?? .section }
        set { rawKind = newValue.rawValue }
    }

    var sortedChildren: [OutlineNode] {
        (children ?? []).sorted { $0.order < $1.order }
    }

    var structuralChildren: [OutlineNode] {
        sortedChildren.filter { $0.kind.isStructural }
    }

    var noteChildren: [OutlineNode] {
        sortedChildren.filter { $0.kind == .note }
    }

    /// "Chapter 3 › Section 3.2" — context handed to the LLM on page ingest.
    var breadcrumb: String {
        var parts: [String] = []
        var cursor: OutlineNode? = self
        while let n = cursor, n.kind.isStructural {
            parts.append(n.title)
            cursor = n.parent
        }
        return parts.reversed().joined(separator: " › ")
    }
}
