import Foundation

/// Direct HTTPS to the Anthropic Messages API. Fine for solo / TestFlight where
/// the user supplies their own key; put a proxy in front for public release.
struct AnthropicProvider: LLMProvider {
    let apiKey: String
    let model: LLMModel
    var endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    var apiVersion = "2023-06-01"

    func complete(request: LLMRequest) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey }

        let body = MessagesBody(
            model: model.rawValue,
            max_tokens: request.maxTokens,
            system: request.system,
            output_config: .init(effort: request.effort.rawValue),
            messages: [
                .init(role: "user", content: request.content.map(Block.init(content:)))
            ]
        )

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONEncoder().encode(body)
        urlRequest.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            throw LLMError.http(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }

        let decoded: MessagesResponse
        do {
            decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        } catch {
            throw LLMError.decoding(error.localizedDescription)
        }

        let text = decoded.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined()
        guard !text.isEmpty else { throw LLMError.emptyResponse }
        return text
    }
}

// MARK: - Wire types

private struct MessagesBody: Encodable {
    let model: String
    let max_tokens: Int
    let system: String
    let output_config: OutputConfig
    let messages: [Message]

    struct OutputConfig: Encodable { let effort: String }
    struct Message: Encodable { let role: String; let content: [Block] }
}

/// A content block: `text` or base64 `image`.
private struct Block: Encodable {
    let type: String
    let text: String?
    let source: ImageSource?

    struct ImageSource: Encodable {
        let type = "base64"
        let media_type = "image/jpeg"
        let data: String
    }

    init(content: LLMContent) {
        switch content {
        case .text(let s):
            type = "text"; text = s; source = nil
        case .imageJPEG(let d):
            type = "image"; text = nil
            source = ImageSource(data: d.base64EncodedString())
        }
    }

    enum CodingKeys: String, CodingKey { case type, text, source }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(source, forKey: .source)
    }
}

private struct MessagesResponse: Decodable {
    let content: [ContentBlock]
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
}
