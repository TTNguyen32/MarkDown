import Foundation

struct BookMetadata {
    var title: String
    var author: String
    var isbn: String?
    var coverURL: String?
    var pageCount: Int?
}

/// Google Books volume lookup (no key needed for light use).
enum BookMetadataService {
    static func search(_ query: String) async throws -> [BookMetadata] {
        guard let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.googleapis.com/books/v1/volumes?maxResults=8&q=\(q)")
        else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let payload = try JSONDecoder().decode(Response.self, from: data)
        return (payload.items ?? []).map { item in
            let v = item.volumeInfo
            let isbn = v.industryIdentifiers?
                .first(where: { $0.type == "ISBN_13" || $0.type == "ISBN_10" })?.identifier
            return BookMetadata(
                title: v.title ?? query,
                author: v.authors?.joined(separator: ", ") ?? "",
                isbn: isbn,
                coverURL: v.imageLinks?.thumbnail?.replacingOccurrences(of: "http://", with: "https://"),
                pageCount: v.pageCount
            )
        }
    }

    private struct Response: Decodable {
        let items: [Item]?
        struct Item: Decodable { let volumeInfo: VolumeInfo }
        struct VolumeInfo: Decodable {
            let title: String?
            let authors: [String]?
            let pageCount: Int?
            let industryIdentifiers: [ID]?
            let imageLinks: ImageLinks?
            struct ID: Decodable { let type: String; let identifier: String }
            struct ImageLinks: Decodable { let thumbnail: String? }
        }
    }
}
