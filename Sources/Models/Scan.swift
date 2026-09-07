import Foundation
import SwiftData

enum ScanKind: String, Codable { case toc, page }

enum ScanStatus: String, Codable { case queued, processing, done, failed }

@Model
final class Scan {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var rawKind: String = ScanKind.page.rawValue
    var rawStatus: String = ScanStatus.queued.rawValue

    var ocrText: String = ""
    var ocrConfidence: Double = 0

    /// Heuristic page number from the running header/footer, if found.
    var detectedPage: Int?
    /// User-confirmed / corrected page number. Wins over `detectedPage`.
    var confirmedPage: Int?

    /// JPEG of the primary page image (deskewed by VisionKit).
    var imageData: Data?

    var errorMessage: String?

    var book: Book?

    init(kind: ScanKind) {
        self.rawKind = kind.rawValue
    }

    var kind: ScanKind {
        get { ScanKind(rawValue: rawKind) ?? .page }
        set { rawKind = newValue.rawValue }
    }

    var status: ScanStatus {
        get { ScanStatus(rawValue: rawStatus) ?? .queued }
        set { rawStatus = newValue.rawValue }
    }

    var effectivePage: Int? { confirmedPage ?? detectedPage }
}
