import Foundation
import Vision
import UIKit

struct OCRLine {
    let text: String
    let confidence: Double
    /// Vision-normalised rect: origin bottom-left, 0...1.
    let boundingBox: CGRect
}

struct OCRResult {
    let lines: [OCRLine]
    var fullText: String { lines.map(\.text).joined(separator: "\n") }
    var averageConfidence: Double {
        guard !lines.isEmpty else { return 0 }
        return lines.map(\.confidence).reduce(0, +) / Double(lines.count)
    }
}

enum OCRService {
    static func recognize(_ image: UIImage) async throws -> OCRResult {
        guard let cg = image.cgImage else { return OCRResult(lines: []) }

        return try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { request, error in
                if let error { cont.resume(throwing: error); return }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines: [OCRLine] = observations.compactMap { obs in
                    guard let top = obs.topCandidates(1).first else { return nil }
                    return OCRLine(
                        text: top.string,
                        confidence: Double(top.confidence),
                        boundingBox: obs.boundingBox
                    )
                }
                cont.resume(returning: OCRResult(lines: lines))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
            do { try handler.perform([request]) }
            catch { cont.resume(throwing: error) }
        }
    }
}
