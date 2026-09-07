import Foundation

/// System prompts + response shapes for the two LLM tasks. Both ask for bare
/// JSON; `JSONExtractor` tolerates stray prose / code fences.
enum Prompts {

    // MARK: TOC parse

    static let tocSystem = """
    You are given one or more photographed pages from the table of contents of a book.
    Extract the hierarchical outline.

    Return ONLY a JSON array, each element:
      { "title": string, "level": "part" | "chapter" | "section", "startPage": integer | null }

    Rules:
    - "level" reflects nesting: parts contain chapters, chapters contain sections.
      If the book has no parts, use "chapter" for top level.
    - "startPage" is the printed page number shown for that entry. Use null if none is shown.
    - Preserve document order. Do not invent entries. Do not include front/back matter
      unless it appears in the contents (e.g. "Introduction", "Appendix").
    - No commentary, no markdown — just the JSON array.
    """

    struct TOCEntry: Decodable {
        let title: String
        let level: String
        let startPage: Int?

        var kind: NodeKind {
            switch level.lowercased() {
            case "part": return .part
            case "section": return .section
            default: return .chapter
            }
        }
    }

    // MARK: Page extract

    static func pageExtractSystem(bookTitle: String, breadcrumb: String, page: Int?) -> String {
        """
        You are helping build a study mindmap of the book "\(bookTitle)".
        The user photographed a single page. Its OCR text follows in the user message.
        Based on the outline, this page belongs under: \(breadcrumb.isEmpty ? "(unplaced)" : breadcrumb)\
        \(page.map { " (printed page \($0))" } ?? "").

        Extract the substantive ideas as atomic bullet points.

        Return ONLY this JSON object:
          {
            "bullets": [ { "text": string, "verbatim": boolean } ],
            "sectionHint": string | null
          }

        Rules:
        - 3 to 8 bullets. Each is ONE idea, self-contained, in your own words (paraphrase).
        - Set "verbatim": true ONLY for a short defining sentence or a quotable line that
          loses meaning when paraphrased, and keep it under 30 words. Never more than 2
          verbatim bullets per page.
        - Skip running headers, page numbers, footnote plumbing, and publisher boilerplate.
        - If the page visibly starts a new chapter or section, put its heading text in
          "sectionHint"; otherwise null.
        - No commentary outside the JSON.
        """
    }

    struct PageExtraction: Decodable {
        let bullets: [Bullet]
        let sectionHint: String?
        struct Bullet: Decodable {
            let text: String
            let verbatim: Bool
        }
    }
}

/// Pulls the first balanced JSON value out of a model response.
enum JSONExtractor {
    static func firstJSONObjectOrArray(in raw: String) -> Data? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = s.firstIndex(where: { $0 == "{" || $0 == "[" }) else { return nil }
        let open = s[start]
        let close: Character = open == "{" ? "}" : "]"
        var depth = 0
        var inString = false
        var escaped = false
        var idx = start
        while idx < s.endIndex {
            let ch = s[idx]
            if inString {
                if escaped { escaped = false }
                else if ch == "\\" { escaped = true }
                else if ch == "\"" { inString = false }
            } else {
                if ch == "\"" { inString = true }
                else if ch == open { depth += 1 }
                else if ch == close {
                    depth -= 1
                    if depth == 0 {
                        return String(s[start...idx]).data(using: .utf8)
                    }
                }
            }
            idx = s.index(after: idx)
        }
        return nil
    }

    static func decode<T: Decodable>(_ type: T.Type, from raw: String) throws -> T {
        guard let data = firstJSONObjectOrArray(in: raw) else {
            throw LLMError.decoding("no JSON found in response")
        }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw LLMError.decoding(error.localizedDescription) }
    }
}
