import Foundation
import SwiftData

@Model
final class Book {
    var id: UUID = UUID()
    var title: String = ""
    var author: String = ""
    var isbn: String?
    var coverURLString: String?
    var pageCount: Int = 0

    /// Printed page 1 corresponds to this scan-sheet index. Lets the page-number
    /// detector and manual stepper agree on "which printed page is this".
    var bodyPageOffset: Int = 0

    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \OutlineNode.book)
    var nodes: [OutlineNode]? = []

    @Relationship(deleteRule: .cascade, inverse: \Scan.book)
    var scans: [Scan]? = []

    init(title: String = "", author: String = "") {
        self.title = title
        self.author = author
    }

    /// Structural (non-note) nodes with no parent, in reading order.
    var rootStructuralNodes: [OutlineNode] {
        (nodes ?? [])
            .filter { $0.parent == nil && $0.kind != .note }
            .sorted { $0.order < $1.order }
    }
}
