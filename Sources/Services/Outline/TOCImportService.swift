import Foundation
import SwiftData
import UIKit

/// Turns photographed contents pages into the outline skeleton.
@MainActor
struct TOCImportService {
    let provider: LLMProvider
    let context: ModelContext

    func importTOC(images: [UIImage], into book: Book) async throws {
        var content: [LLMContent] = images.compactMap { img in
            img.jpegData(compressionQuality: 0.7).map(LLMContent.imageJPEG)
        }
        content.append(.text("Extract the outline from these contents page(s)."))

        let raw = try await provider.complete(request: LLMRequest(
            system: Prompts.tocSystem,
            content: content,
            maxTokens: 4096,
            effort: .medium
        ))
        let entries = try JSONExtractor.decode([Prompts.TOCEntry].self, from: raw)
        try buildTree(from: entries, into: book)
    }

    /// Rebuilds structural nodes from a flat, ordered entry list using `level`
    /// to nest. Existing note leaves are re-parented to the nearest surviving
    /// structural node by page, so re-importing a better TOC scan is safe.
    private func buildTree(from entries: [Prompts.TOCEntry], into book: Book) throws {
        let salvagedNotes = (book.nodes ?? []).filter { $0.kind == .note }

        for node in (book.nodes ?? []) where node.kind.isStructural {
            context.delete(node)
        }

        var lastByKind: [NodeKind: OutlineNode] = [:]
        var order = 0

        for entry in entries {
            let node = OutlineNode(title: entry.title, kind: entry.kind)
            node.book = book
            node.startPage = entry.startPage
            node.order = order; order += 1

            switch entry.kind {
            case .part:
                node.parent = nil
                lastByKind = [.part: node]
            case .chapter:
                node.parent = lastByKind[.part]
                lastByKind[.chapter] = node
                lastByKind[.section] = nil
            case .section:
                node.parent = lastByKind[.chapter] ?? lastByKind[.part]
                lastByKind[.section] = node
            case .note:
                break
            }
            context.insert(node)
        }

        OutlinePlacement.recomputeRanges(in: book)

        // Re-home salvaged notes.
        for note in salvagedNotes {
            if let page = note.sourcePage,
               let target = OutlinePlacement.node(for: page, in: book) {
                note.parent = target
            } else {
                note.parent = book.rootStructuralNodes.first
            }
        }

        try context.save()
    }
}
