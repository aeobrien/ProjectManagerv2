import Foundation
import PMDomain
import PMUtilities

/// Generates structured session summaries by sending conversation history to an LLM.
public final class SummaryGenerationService: Sendable {
    private let llmClient: LLMClientProtocol
    private let repo: SessionRepositoryProtocol

    public init(llmClient: LLMClientProtocol, repo: SessionRepositoryProtocol) {
        self.llmClient = llmClient
        self.repo = repo
    }

    /// Generates and saves a summary for the given session.
    @discardableResult
    public func generateSummary(
        for sessionId: UUID,
        completionStatus: SessionCompletionStatus
    ) async throws -> SessionSummary {
        guard let session = try await repo.fetch(id: sessionId) else {
            throw SessionError.sessionNotFound
        }
        let messages = try await repo.fetchMessages(forSession: sessionId)
        guard !messages.isEmpty else {
            throw SummaryError.noMessages
        }

        let systemPrompt = summarySystemPrompt
        let userPrompt = buildSummaryPrompt(session: session, messages: messages)

        let response = try await llmClient.send(
            messages: [
                LLMMessage(role: .system, content: systemPrompt),
                LLMMessage(role: .user, content: userPrompt)
            ],
            config: LLMRequestConfig(maxTokens: 2048, temperature: 0.3)
        )

        let summary = parseSummaryResponse(
            response.content,
            session: session,
            messages: messages,
            completionStatus: completionStatus,
            inputTokens: response.inputTokens,
            outputTokens: response.outputTokens
        )

        try await repo.saveSummary(summary)

        // Link summary to session
        if var updated = try await repo.fetch(id: sessionId) {
            updated.summaryId = summary.id
            try await repo.save(updated)
        }

        Log.ai.info("Generated summary \(summary.id) for session \(sessionId)")
        return summary
    }

    // MARK: - Private

    private var summarySystemPrompt: String {
        """
        You are a session summariser for a project management app. Given a conversation transcript, \
        produce a structured JSON summary. Respond ONLY with valid JSON matching this schema:
        {
          "contentEstablished": {
            "decisions": ["string"],
            "factsLearned": ["string"],
            "progressMade": ["string"]
          },
          "contentObserved": {
            "patterns": ["string"],
            "concerns": ["string"],
            "strengths": ["string"]
          },
          "whatComesNext": {
            "nextActions": ["string"],
            "openQuestions": ["string"],
            "suggestedMode": "string or null"
          }
        }
        Be concise. Each array item should be one clear sentence.
        """
    }

    private func buildSummaryPrompt(session: Session, messages: [SessionMessage]) -> String {
        let transcript = messages.map { msg in
            let role = msg.role == .user ? "User" : "Assistant"
            return "\(role): \(msg.content)"
        }.joined(separator: "\n\n")

        return """
        Summarise this \(session.mode.rawValue) session\(session.subMode.map { " (\($0.rawValue))" } ?? ""):

        \(transcript)
        """
    }

    private func parseSummaryResponse(
        _ content: String,
        session: Session,
        messages: [SessionMessage],
        completionStatus: SessionCompletionStatus,
        inputTokens: Int?,
        outputTokens: Int?
    ) -> SessionSummary {
        let startedAt = messages.first?.timestamp ?? session.createdAt
        let endedAt = messages.last?.timestamp ?? Date()
        let duration = Int(endedAt.timeIntervalSince(startedAt))

        // Try to parse JSON response, stripping markdown code fences if present
        let cleaned = Self.extractJSON(from: content)
        if let data = cleaned.data(using: .utf8),
           let json = try? JSONDecoder().decode(SummaryJSON.self, from: data) {
            return SessionSummary(
                sessionId: session.id,
                mode: session.mode,
                subMode: session.subMode,
                completionStatus: completionStatus,
                contentEstablished: .init(
                    decisions: json.contentEstablished.decisions,
                    factsLearned: json.contentEstablished.factsLearned,
                    progressMade: json.contentEstablished.progressMade
                ),
                contentObserved: .init(
                    patterns: json.contentObserved.patterns,
                    concerns: json.contentObserved.concerns,
                    strengths: json.contentObserved.strengths
                ),
                whatComesNext: .init(
                    nextActions: json.whatComesNext.nextActions,
                    openQuestions: json.whatComesNext.openQuestions,
                    suggestedMode: json.whatComesNext.suggestedMode
                ),
                startedAt: startedAt,
                endedAt: endedAt,
                duration: duration,
                messageCount: messages.count,
                inputTokens: inputTokens,
                outputTokens: outputTokens
            )
        }

        // Fallback: create a summary by extracting what we can from the raw text
        Log.ai.error("Failed to parse summary JSON, creating fallback summary from raw text")

        // Try to extract meaningful content from the conversation itself
        let userMessages = messages.filter { $0.role == .user }.map(\.content)
        let assistantMessages = messages.filter { $0.role == .assistant }.map(\.content)

        // Use the last assistant message as a progress indicator
        let lastAssistantContent = assistantMessages.last ?? ""
        let progressItems: [String]
        if lastAssistantContent.count > 20 {
            // Truncate to a reasonable length for the summary
            progressItems = [String(lastAssistantContent.prefix(300))]
        } else {
            progressItems = []
        }

        // Use user messages to extract basic facts
        let factsLearned = userMessages.prefix(3).map { msg in
            String(msg.prefix(200))
        }

        return SessionSummary(
            sessionId: session.id,
            mode: session.mode,
            subMode: session.subMode,
            completionStatus: completionStatus,
            contentEstablished: .init(
                decisions: [],
                factsLearned: factsLearned,
                progressMade: progressItems
            ),
            startedAt: startedAt,
            endedAt: endedAt,
            duration: duration,
            messageCount: messages.count,
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )
    }

    /// Extracts JSON from a string, stripping markdown code fences if present.
    static func extractJSON(from content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for ```json ... ``` or ``` ... ``` wrapping
        if trimmed.hasPrefix("```") {
            var lines = trimmed.components(separatedBy: "\n")
            // Remove opening fence (```json or ```)
            if !lines.isEmpty && lines[0].hasPrefix("```") {
                lines.removeFirst()
            }
            // Remove closing fence
            if let last = lines.last, last.trimmingCharacters(in: .whitespaces) == "```" {
                lines.removeLast()
            }
            return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try to find JSON object boundaries if there's surrounding text
        if let startIdx = trimmed.firstIndex(of: "{"),
           let endIdx = trimmed.lastIndex(of: "}") {
            return String(trimmed[startIdx...endIdx])
        }

        return trimmed
    }
}

// MARK: - JSON Parsing Types

private struct SummaryJSON: Decodable {
    let contentEstablished: ContentEstablishedJSON
    let contentObserved: ContentObservedJSON
    let whatComesNext: WhatComesNextJSON
}

private struct ContentEstablishedJSON: Decodable {
    let decisions: [String]
    let factsLearned: [String]
    let progressMade: [String]
}

private struct ContentObservedJSON: Decodable {
    let patterns: [String]
    let concerns: [String]
    let strengths: [String]
}

private struct WhatComesNextJSON: Decodable {
    let nextActions: [String]
    let openQuestions: [String]
    let suggestedMode: String?
}
