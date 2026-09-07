import Foundation

/// Models offered in Settings. IDs are the exact Anthropic API strings — do not
/// append date suffixes.
enum LLMModel: String, CaseIterable, Identifiable {
    case opus5 = "claude-opus-5"
    case sonnet5 = "claude-sonnet-5"
    case haiku45 = "claude-haiku-4-5"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .opus5: return "Claude Opus 5"
        case .sonnet5: return "Claude Sonnet 5"
        case .haiku45: return "Claude Haiku 4.5"
        }
    }

    /// Rough per-scan hint for the Settings picker (input+output, typical page).
    var costHint: String {
        switch self {
        case .opus5: return "highest quality · ~$0.02–0.05 / page"
        case .sonnet5: return "balanced · ~$0.01–0.02 / page"
        case .haiku45: return "cheapest/fastest · ~$0.002–0.005 / page"
        }
    }
}
