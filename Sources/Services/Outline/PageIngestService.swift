import Foundation
import SwiftData
import UIKit

/// OCR a page → decide its page number → place it → extract bullets → attach.
@MainActor
final class PageIngestService {
    let provider: LLMProvider
    let context: ModelContext

    init(provider: LLMProvider, context: ModelContext) {
        self.provider = provider
        self.context = context
    }

    struct Outcome {
        let scan: Scan
        let targetNode: OutlineNode?
        let addedNotes: [OutlineNode]
        let sectionHint: String?
    }

    /// Step 1 — capture + OCR + page-number guess. Persists a `queued` scan so a
    /// batch survives app kill / offline. The UI can confirm the page before
    /// calling `process`.
    func stage(image: UIImage, in book: Book, autoIncrementFrom previous: Scan?) async throws -> Scan {
        let scan = Scan(kind: .page)
        scan.book = book
        scan.imageData = image.jpegData(compressionQuality: 0.7)

        let ocr = try await OCRService.recognize(image)
        scan.ocrText = ocr.fullText
        scan.ocrConfidence = ocr.averageConfidence
        scan.detectedPage = PageNumberDetector.detect(in: ocr)
            ?? previous?.effectivePage.map { $0 + 1 }

        context.insert(scan)
        try context.save()
        return scan
    }

    /// Step 2 — place + extract + attach. Safe to retry (clears prior notes from
    /// this scan first).
    @discardableResult
    func process(_ scan: Scan) async throws -> Outcome {
        guard let book = scan.book else { throw IngestError.noBook }
        scan.status = .processing
        scan.errorMessage = nil
        try context.save()

        do {
            let page = scan.effectivePage
            let target = page.flatMap { OutlinePlacement.node(for: $0, in: book) }
                ?? book.rootStructuralNodes.first

            let lowConfidence = scan.ocrConfidence < 0.35 || scan.ocrText.count < 40
            var content: [LLMContent] = [.text(scan.ocrText)]
            if lowConfidence, let data = scan.imageData {
                content.append(.imageJPEG(data))
                content.append(.text("OCR was unreliable; use the image as the source of truth."))
            }

            let raw = try await provider.complete(request: LLMRequest(
                system: Prompts.pageExtractSystem(
                    bookTitle: book.title,
                    breadcrumb: target?.breadcrumb ?? "",
                    page: page
                ),
                content: content,
                maxTokens: 2048,
                effort: .low
            ))
            let extraction = try JSONExtractor.decode(Prompts.PageExtraction.self, from: raw)

            // Replace any notes previously attached from this scan.
            for old in (book.nodes ?? []) where old.sourceScanID == scan.id {
                context.delete(old)
            }

            var added: [OutlineNode] = []
            let base = (target?.noteChildren.map(\.order).max() ?? -1) + 1
            for (i, bullet) in extraction.bullets.enumerated() {
                let note = OutlineNode(title: bullet.text, kind: .note)
                note.book = book
                note.parent = target
                note.noteText = bullet.text
                note.isVerbatim = bullet.verbatim
                note.sourcePage = page
                note.sourceScanID = scan.id
                note.order = base + i
                context.insert(note)
                added.append(note)
            }

            scan.status = .done
            try context.save()
            return Outcome(scan: scan, targetNode: target,
                           addedNotes: added, sectionHint: extraction.sectionHint)
        } catch {
            scan.status = .failed
            scan.errorMessage = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            try? context.save()
            throw error
        }
    }

    enum IngestError: LocalizedError {
        case noBook
        var errorDescription: String? { "This scan isn't linked to a book." }
    }
}
