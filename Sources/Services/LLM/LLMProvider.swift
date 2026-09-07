import Foundation

/// One multimodal turn. Implementations return the assistant's text.
protocol LLMProvider: Sendable {
    func complete(request: LLMRequest) async throws -> String
}

enum LLMContent: Sendable {
    case text(String)
    case imageJPEG(Data)
}

struct LLMRequest: Sendable {
    var system: String
    var content: [LLMContent]
    var maxTokens: Int = 4096
    /// Maps to Anthropic `output_config.effort`.
    var effort: LLMEffort = .medium
}

enum LLMEffort: String, Sendable { case low, medium, high }

enum LLMError: LocalizedError {
    case missingAPIKey
    case http(status: Int, body: String)
    case decoding(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key set. Add one in Settings."
        case .http(let status, let body):
            return "Model request failed (\(status)). \(body)"
        case .decoding(let what):
            return "Couldn't read the model response: \(what)"
        case .emptyResponse:
            return "The model returned nothing."
        }
    }
}

/// Resolves the active provider from user settings. Add `HostedProxyProvider`
/// here when moving off the bring-your-own-key model.
enum LLMProviderFactory {
    static func current() -> LLMProvider {
        let model = LLMModel(rawValue: UserDefaults.standard.string(forKey: "settings.model") ?? "")
            ?? .opus5
        return AnthropicProvider(
            apiKey: KeychainStore.apiKey ?? "",
            model: model
        )
    }
}
