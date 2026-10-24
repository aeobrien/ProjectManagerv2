import Foundation
import PMUtilities
import os

/// Supported LLM providers.
public enum LLMProvider: String, Sendable, Codable, CaseIterable {
    case anthropic
    case openai
}

/// Known Anthropic model identifiers.
public enum AnthropicModel: String, Sendable, CaseIterable {
    case opus = "claude-opus-4-6"
    case sonnet = "claude-sonnet-4-6"
    case haiku = "claude-haiku-4-5-20251001"

    public var displayName: String {
        switch self {
        case .opus: "Claude Opus 4.6"
        case .sonnet: "Claude Sonnet 4.6"
        case .haiku: "Claude Haiku 4.5"
        }
    }

    /// Whether this model supports adaptive thinking.
    public var supportsAdaptiveThinking: Bool {
        switch self {
        case .opus, .sonnet: true
        case .haiku: false
        }
    }
}

/// Known OpenAI model identifiers.
public enum OpenAIModel: String, Sendable, CaseIterable {
    case gpt52 = "gpt-5.2"
    case gpt41 = "gpt-4.1"
    case gpt5Mini = "gpt-5-mini"

    public var displayName: String {
        switch self {
        case .gpt52: "GPT-5.2"
        case .gpt41: "GPT-4.1"
        case .gpt5Mini: "GPT-5 Mini"
        }
    }
}

/// Effort level for Anthropic adaptive thinking.
public enum ThinkingEffort: String, Sendable {
    case low
    case medium
    case high
    case max
}

/// A single message in a conversation.
public struct LLMMessage: Sendable, Codable, Equatable {
    public enum Role: String, Sendable, Codable {
        case system
        case user
        case assistant
    }

    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

/// Configuration for an LLM request.
public struct LLMRequestConfig: Sendable {
    public let model: String
    public let maxTokens: Int
    public let temperature: Double
    public let provider: LLMProvider
    /// When set, enables adaptive thinking on supported Anthropic models.
    public let thinkingEffort: ThinkingEffort?

    public init(
        model: String? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        provider: LLMProvider? = nil,
        thinkingEffort: ThinkingEffort? = nil
    ) {
        let resolvedProvider = provider ?? {
            let saved = UserDefaults.standard.string(forKey: "settings.aiProvider") ?? "anthropic"
            return LLMProvider(rawValue: saved) ?? .anthropic
        }()
        self.provider = resolvedProvider

        // Read model from settings, falling back to defaults
        let savedModel = UserDefaults.standard.string(forKey: "settings.aiModel") ?? ""
        let defaultModel = resolvedProvider == .openai ? OpenAIModel.gpt52.rawValue : AnthropicModel.opus.rawValue
        self.model = model ?? (savedModel.isEmpty ? defaultModel : savedModel)

        self.thinkingEffort = thinkingEffort

        // When adaptive thinking is enabled, Anthropic needs higher max_tokens
        // to accommodate both thinking tokens and the response itself.
        // 32K gives enough room for large document generation (e.g. setup specifications).
        if thinkingEffort != nil && resolvedProvider == .anthropic {
            self.temperature = 1.0
            self.maxTokens = maxTokens ?? 32_000
        } else {
            self.temperature = temperature ?? 0.7
            self.maxTokens = maxTokens ?? 4096
        }
    }
}

/// Response from an LLM API call.
public struct LLMResponse: Sendable {
    public let content: String
    public let inputTokens: Int?
    public let outputTokens: Int?
    /// The reason the model stopped generating.
    /// "end_turn" = complete, "max_tokens" = truncated due to token limit.
    public let stopReason: String?

    /// Whether the response was truncated due to hitting the max_tokens limit.
    public var wasTruncated: Bool {
        stopReason == "max_tokens" || stopReason == "length"
    }

    public init(content: String, inputTokens: Int? = nil, outputTokens: Int? = nil, stopReason: String? = nil) {
        self.content = content
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.stopReason = stopReason
    }
}

/// Errors from LLM API calls.
public enum LLMError: Error, Sendable, Equatable, LocalizedError {
    case noAPIKey
    case invalidResponse
    case httpError(Int, String)
    case networkError(String)
    case rateLimited
    case overloaded
    case tokenBudgetExceeded

    public var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Add your key in Settings → AI Assistant."
        case .invalidResponse:
            return "Received an unexpected response from the AI service."
        case .httpError(let code, _):
            return "The AI service returned an error (HTTP \(code)). Try again in a moment."
        case .networkError:
            return "Unable to reach the AI service. Check your internet connection and try again."
        case .rateLimited:
            return "Too many requests — the AI service is rate-limiting. Wait a minute and try again."
        case .overloaded:
            return "The AI service is temporarily overloaded. Try again in a few minutes."
        case .tokenBudgetExceeded:
            return "The conversation is too long for the AI to process. Try clearing the chat and starting fresh."
        }
    }
}

/// Protocol for LLM API clients, enabling mocking.
public protocol LLMClientProtocol: Sendable {
    func send(messages: [LLMMessage], config: LLMRequestConfig) async throws -> LLMResponse
}

/// HTTP-based LLM client supporting Anthropic and OpenAI APIs.
public final class LLMClient: LLMClientProtocol, Sendable {
    private let session: URLSession
    private let keyProvider: APIKeyProvider

    /// Timeout for LLM API requests (10 minutes).
    /// Definition mode with extended thinking can take several minutes for large documents.
    static let requestTimeout: TimeInterval = 600

    public init(session: URLSession? = nil, keyProvider: APIKeyProvider = SettingsKeyProvider()) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = Self.requestTimeout
            config.timeoutIntervalForResource = Self.requestTimeout
            self.session = URLSession(configuration: config)
        }
        self.keyProvider = keyProvider
    }

    public func send(messages: [LLMMessage], config: LLMRequestConfig) async throws -> LLMResponse {
        // Retry on overloaded/rate-limited errors with exponential backoff
        var lastError: Error?
        for attempt in 0...2 {
            do {
                switch config.provider {
                case .anthropic:
                    return try await sendAnthropic(messages: messages, config: config)
                case .openai:
                    return try await sendOpenAI(messages: messages, config: config)
                }
            } catch LLMError.overloaded, LLMError.rateLimited {
                lastError = LLMError.overloaded
                if attempt < 2 {
                    let delay = UInt64(pow(2.0, Double(attempt + 1))) * 1_000_000_000
                    try? await Task.sleep(nanoseconds: delay)
                    Log.ai.info("AI service overloaded, retrying (attempt \(attempt + 1))")
                }
            }
        }
        throw lastError ?? LLMError.overloaded
    }

    // MARK: - Anthropic

    private func sendAnthropic(messages: [LLMMessage], config: LLMRequestConfig) async throws -> LLMResponse {
        guard let apiKey = keyProvider.key(for: .anthropic) else { throw LLMError.noAPIKey }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.timeoutInterval = Self.requestTimeout
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Separate system message from conversation messages
        let systemMessage = messages.first { $0.role == .system }?.content
        let conversationMessages = messages.filter { $0.role != .system }

        var body: [String: Any] = [
            "model": config.model,
            "max_tokens": config.maxTokens,
            "messages": conversationMessages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]

        if let system = systemMessage {
            body["system"] = system
        }

        // Adaptive thinking for Opus 4.6 / Sonnet 4.6
        if let effort = config.thinkingEffort {
            let modelSupportsAdaptive = AnthropicModel.allCases
                .first(where: { $0.rawValue == config.model })?
                .supportsAdaptiveThinking ?? false

            if modelSupportsAdaptive {
                body["thinking"] = ["type": "adaptive"] as [String: Any]
                body["output_config"] = ["effort": effort.rawValue] as [String: Any]
                body["temperature"] = 1 // Required by Anthropic when thinking is active
                Log.ai.debug("Anthropic request with adaptive thinking, effort: \(effort.rawValue)")
            } else {
                // Non-adaptive models: use standard temperature
                body["temperature"] = config.temperature
            }
        } else {
            body["temperature"] = config.temperature
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        if httpResponse.statusCode == 429 { throw LLMError.rateLimited }
        if httpResponse.statusCode == 529 { throw LLMError.overloaded }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            Log.ai.error("Anthropic API error \(httpResponse.statusCode): \(errorBody)")
            throw LLMError.httpError(httpResponse.statusCode, errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentArray = json["content"] as? [[String: Any]] else {
            throw LLMError.invalidResponse
        }

        let stopReason = json["stop_reason"] as? String

        // Extract text blocks (skip thinking/redacted_thinking blocks)
        let textBlocks = contentArray
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }

        guard !textBlocks.isEmpty else {
            // Fallback: if no "type" field, try old-style response
            if let firstContent = contentArray.first, let text = firstContent["text"] as? String {
                let usage = json["usage"] as? [String: Any]
                return LLMResponse(
                    content: text,
                    inputTokens: usage?["input_tokens"] as? Int,
                    outputTokens: usage?["output_tokens"] as? Int,
                    stopReason: stopReason
                )
            }
            throw LLMError.invalidResponse
        }

        let combinedText = textBlocks.joined(separator: "\n\n")
        let usage = json["usage"] as? [String: Any]

        if stopReason == "max_tokens" {
            Log.ai.notice("Anthropic response truncated (stop_reason=max_tokens, output_tokens=\(usage?["output_tokens"] as? Int ?? 0))")
        }

        return LLMResponse(
            content: combinedText,
            inputTokens: usage?["input_tokens"] as? Int,
            outputTokens: usage?["output_tokens"] as? Int,
            stopReason: stopReason
        )
    }

    // MARK: - OpenAI

    private func sendOpenAI(messages: [LLMMessage], config: LLMRequestConfig) async throws -> LLMResponse {
        guard let apiKey = keyProvider.key(for: .openai) else { throw LLMError.noAPIKey }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.timeoutInterval = Self.requestTimeout
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")

        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": config.maxTokens,
            "temperature": config.temperature,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        if httpResponse.statusCode == 429 { throw LLMError.rateLimited }
        if httpResponse.statusCode == 529 { throw LLMError.overloaded }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.httpError(httpResponse.statusCode, errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw LLMError.invalidResponse
        }

        let stopReason = firstChoice["finish_reason"] as? String
        let usage = json["usage"] as? [String: Any]
        return LLMResponse(
            content: text,
            inputTokens: usage?["prompt_tokens"] as? Int,
            outputTokens: usage?["completion_tokens"] as? Int,
            stopReason: stopReason
        )
    }

    // MARK: - Network

    private func performRequest(_ request: URLRequest, retries: Int = 2) async throws -> (Data, URLResponse) {
        var lastError: Error?
        for attempt in 0...retries {
            do {
                return try await session.data(for: request)
            } catch {
                lastError = error
                // Don't retry on timeouts — the request genuinely took too long,
                // and retrying would compound the wait (e.g. 10min x 3 = 30min hang).
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == -1001 {
                    Log.ai.error("LLM request timed out after \(Self.requestTimeout)s — not retrying")
                    break
                }
                if attempt < retries {
                    let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                    try? await Task.sleep(nanoseconds: delay)
                    Log.ai.info("Retrying LLM request (attempt \(attempt + 1))")
                }
            }
        }
        throw LLMError.networkError(lastError?.localizedDescription ?? "Unknown network error")
    }
}

// MARK: - API Key Provider

/// Protocol for retrieving API keys.
public protocol APIKeyProvider: Sendable {
    func key(for provider: LLMProvider) -> String?
}

/// Reads API keys from environment variables.
public struct EnvironmentKeyProvider: APIKeyProvider, Sendable {
    public init() {}

    public func key(for provider: LLMProvider) -> String? {
        switch provider {
        case .anthropic: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        case .openai: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        }
    }
}

/// Reads API keys from Keychain (Settings), falling back to iCloud KV store, then environment variables.
public struct SettingsKeyProvider: APIKeyProvider, Sendable {
    public init() {}

    public func key(for provider: LLMProvider) -> String? {
        // 1. Try Keychain (primary store)
        if let keychainKey = KeychainHelper.load(key: "settings.aiApiKey"), !keychainKey.isEmpty {
            return keychainKey
        }
        // 2. Try iCloud KV store (cross-device sync may have the key even if Keychain save failed)
        let kvStore = NSUbiquitousKeyValueStore.default
        if let cloudKey = kvStore.string(forKey: "settings.aiApiKey"), !cloudKey.isEmpty {
            // Attempt to repair Keychain for next time
            KeychainHelper.save(key: "settings.aiApiKey", value: cloudKey)
            return cloudKey
        }
        // 3. Fall back to environment variables
        switch provider {
        case .anthropic: return ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        case .openai: return ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        }
    }
}
