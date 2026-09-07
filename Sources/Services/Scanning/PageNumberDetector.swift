import Foundation
import CoreGraphics

/// Best-effort printed page number from the running header / footer.
/// Returns nil when nothing convincing is in the margins — the caller then
/// asks the user or falls back to sequential increment.
enum PageNumberDetector {
    /// Fraction of page height treated as top/bottom margin.
    static let marginBand: CGFloat = 0.12

    static func detect(in ocr: OCRResult) -> Int? {
        let candidates = ocr.lines.filter { line in
            // Vision boundingBox origin is bottom-left.
            let y = line.boundingBox.midY
            return y > (1 - marginBand) || y < marginBand
        }

        var best: (page: Int, score: Double)?
        for line in candidates {
            guard let page = parsePageNumber(line.text) else { continue }
            // Prefer shorter, higher-confidence lines closer to the edge.
            let edgeDistance = min(line.boundingBox.midY, 1 - line.boundingBox.midY)
            let score = line.confidence + (0.12 - edgeDistance) - Double(line.text.count) * 0.01
            if best == nil || score > best!.score {
                best = (page, score)
            }
        }
        return best?.page
    }

    /// Accepts "213", "Page 213", "— 213 —", "213 CHAPTER TITLE", lowercase roman.
    static func parsePageNumber(_ raw: String) -> Int? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let m = s.range(of: #"(?i)\bpage\s+(\d{1,4})\b"#, options: .regularExpression) {
            return Int(s[m].replacingOccurrences(of: "Page ", with: "",
                                                options: [.caseInsensitive]).trimmingCharacters(in: .letters.union(.whitespaces)))
        }

        // A line that is essentially just a number, maybe wrapped in dashes/dots.
        let stripped = s.trimmingCharacters(in: CharacterSet(charactersIn: "—–-·.•* "))
        if stripped.count <= 4, stripped.allSatisfy(\.isNumber), let n = Int(stripped) {
            return n
        }

        // Number at the very start or end of a short header line.
        if s.count <= 40 {
            if let lead = s.prefix(while: \.isNumber).nonEmpty, let n = Int(lead) { return n }
            if let trail = String(s.reversed().prefix(while: \.isNumber)).nonEmpty,
               let n = Int(String(trail.reversed())) { return n }
        }

        if let roman = romanToInt(stripped.lowercased()) { return roman }
        return nil
    }

    static func romanToInt(_ s: String) -> Int? {
        guard !s.isEmpty, s.count <= 8,
              s.allSatisfy({ "ivxlcdm".contains($0) }) else { return nil }
        let map: [Character: Int] = ["i": 1, "v": 5, "x": 10, "l": 50,
                                     "c": 100, "d": 500, "m": 1000]
        var total = 0
        var prev = 0
        for ch in s.reversed() {
            guard let v = map[ch] else { return nil }
            total += v < prev ? -v : v
            prev = v
        }
        return total > 0 ? total : nil
    }
}

private extension StringProtocol {
    var nonEmpty: String? { isEmpty ? nil : String(self) }
}
