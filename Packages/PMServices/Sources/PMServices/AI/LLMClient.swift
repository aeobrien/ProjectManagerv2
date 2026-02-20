import Foundation
import PMUtilities
import os

/// Supported LLM providers.
public enum LLMProvider: String, Sendable, Codable {
    case anthropic
    case openai
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

    public init(
        model: String = "claude-sonnet-4-20250514",
        maxTokens: Int = 4096,
        temperature: Double = 0.7,
        provider: LLMProvider = .anthropic
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.provider = provider
    }
}

/// Response from an LLM API call.
public struct LLMResponse: Sendable {
    public let content: String
    public let inputTokens: Int?
    public let outputTokens: Int?

    public init(content: String, inputTokens: Int? = nil, outputTokens: Int? = nil) {
        self.content = content
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

/// Errors from LLM API calls.
public enum LLMError: Error, Sendable, Equatable {
    case noAPIKey
    case invalidResponse
    case httpError(Int, String)
    case networkError(String)
    case rateLimited
    case tokenBudgetExceeded
}

/// Protocol for LLM API clients, enabling mocking.
public protocol LLMClientProtocol: Sendable {
    func send(messages: [LLMMessage], config: LLMRequestConfig) async throws -> LLMResponse
}

/// HTTP-based LLM client supporting Anthropic and OpenAI APIs.
public final class LLMClient: LLMClientProtocol, Sendable {
    private let session: URLSession
    private let keyProvider: APIKeyProvider

    public init(session: URLSession = .shared, keyProvider: APIKeyProvider = EnvironmentKeyProvider()) {
        self.session = session
        self.keyProvider = keyProvider
    }

    public func send(messages: [LLMMessage], config: LLMRequestConfig) async throws -> LLMResponse {
        switch config.provider {
        case .anthropic:
            return try await sendAnthropic(messages: messages, config: config)
        case .openai:
            return try await sendOpenAI(messages: messages, config: config)
        }
    }

    // MARK: - Anthropic

    private func sendAnthropic(messages: [LLMMessage], config: LLMRequestConfig) async throws -> LLMResponse {
        guard let apiKey = keyProvider.key(for: .anthropic) else { throw LLMError.noAPIKey }

        var url = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        url.httpMethod = "POST"
        url.setValue("application/json", forHTTPHeaderField: "content-type")
        url.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        url.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Separate system message from conversation messages
        let systemMessage = messages.first { $0.role == .system }?.content
        let conversationMessages = messages.filter { $0.role != .system }

        var body: [String: Any] = [
            "model": config.model,
            "max_tokens": config.maxTokens,
            "temperature": config.temperature,
            "messages": conversationMessages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]
        if let system = systemMessage {
            body["system"] = system
        }

        url.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        if httpResponse.statusCode == 429 { throw LLMError.rateLimited }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.httpError(httpResponse.statusCode, errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentArray = json["content"] as? [[String: Any]],
              let firstContent = contentArray.first,
              let text = firstContent["text"] as? String else {
            throw LLMError.invalidResponse
        }

        let usage = json["usage"] as? [String: Any]
        return LLMResponse(
            content: text,
            inputTokens: usage?["input_tokens"] as? Int,
            outputTokens: usage?["output_tokens"] as? Int
        )
    }

    // MARK: - OpenAI

    private func sendOpenAI(messages: [LLMMessage], config: LLMRequestConfig) async throws -> LLMResponse {
        guard let apiKey = keyProvider.key(for: .openai) else { throw LLMError.noAPIKey }

        var url = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        url.httpMethod = "POST"
        url.setValue("application/json", forHTTPHeaderField: "content-type")
        url.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")

        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": config.maxTokens,
            "temperature": config.temperature,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]

        url.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        if httpResponse.statusCode == 429 { throw LLMError.rateLimited }

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

        let usage = json["usage"] as? [String: Any]
        return LLMResponse(
            content: text,
            inputTokens: usage?["prompt_tokens"] as? Int,
            outputTokens: usage?["completion_tokens"] as? Int
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
