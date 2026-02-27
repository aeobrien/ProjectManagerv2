import Foundation
import PMUtilities

/// Parses AI responses for structured signals alongside ACTION blocks.
/// Signals use bracket notation: [SIGNAL_NAME: value] for single-line signals,
/// and [SIGNAL_NAME]...[/SIGNAL_NAME] for block signals.
public struct ResponseSignalParser: Sendable {
    private let actionParser: ActionParser

    public init(actionParser: ActionParser = ActionParser()) {
        self.actionParser = actionParser
    }

    /// Parse a full AI response, extracting signals, actions (if enabled), and natural language.
    public func parse(_ response: String, parseActions: Bool = false) -> ParsedV2Response {
        var text = response
        var signals: [ResponseSignal] = []

        // Extract block signals first (they contain multiline content)
        text = extractBlockSignals(from: text, into: &signals)

        // Extract single-line signals
        text = extractLineSignals(from: text, into: &signals)

        // Parse actions if enabled
        let actions: [AIAction]
        if parseActions {
            let parsed = actionParser.parse(text)
            text = parsed.naturalLanguage
            actions = parsed.actions
        } else {
            actions = []
        }

        // Clean up excess whitespace from signal removal
        let cleanedText = text
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ParsedV2Response(
            naturalLanguage: cleanedText,
            signals: signals,
            actions: actions
        )
    }

    // MARK: - Block Signals

    private func extractBlockSignals(from text: String, into signals: inout [ResponseSignal]) -> String {
        var result = text

        // [DOCUMENT_DRAFT: type]...[/DOCUMENT_DRAFT]
        result = extractBlock(
            from: result,
            tag: "DOCUMENT_DRAFT",
            into: &signals
        ) { type, content in
            .documentDraft(type: type ?? "unknown", content: content)
        }

        // [STRUCTURE_PROPOSAL]...[/STRUCTURE_PROPOSAL]
        result = extractBlock(
            from: result,
            tag: "STRUCTURE_PROPOSAL",
            into: &signals
        ) { _, content in
            .structureProposal(content: content)
        }

        return result
    }

    private func extractBlock(
        from text: String,
        tag: String,
        into signals: inout [ResponseSignal],
        builder: (String?, String) -> ResponseSignal
    ) -> String {
        // Pattern matches [TAG: optional_param]content[/TAG] or [TAG]content[/TAG]
        let pattern = #"\["# + tag + #"(?::\s*([^\]]*))?\](.*?)\[/"# + tag + #"\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return text
        }

        var result = text
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))

        for match in matches.reversed() {
            let paramRange = match.range(at: 1)
            let param: String?
            if paramRange.location != NSNotFound, let range = Range(paramRange, in: result) {
                param = String(result[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                param = nil
            }

            if let contentRange = Range(match.range(at: 2), in: result),
               let fullRange = Range(match.range, in: result) {
                let content = String(result[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                signals.append(builder(param, content))
                result.removeSubrange(fullRange)
            }
        }

        return result
    }

    // MARK: - Line Signals

    private func extractLineSignals(from text: String, into signals: inout [ResponseSignal]) -> String {
        var result = text

        // Single-line signals: [SIGNAL_NAME: value]
        let lineSignals: [(String, (String) -> ResponseSignal)] = [
            ("MODE_COMPLETE", { .modeComplete(mode: $0) }),
            ("PROCESS_RECOMMENDATION", { .processRecommendation(deliverables: $0) }),
            ("PLANNING_DEPTH", { .planningDepth(depth: $0) }),
            ("PROJECT_SUMMARY", { .projectSummary(summary: $0) }),
            ("DELIVERABLES_PRODUCED", { .deliverablesProduced(types: $0) }),
            ("DELIVERABLES_DEFERRED", { .deliverablesDeferred(types: $0) }),
            ("STRUCTURE_SUMMARY", { .structureSummary(summary: $0) }),
            ("FIRST_ACTION", { .firstAction(action: $0) }),
        ]

        for (tag, builder) in lineSignals {
            let pattern = #"\["# + tag + #":\s*([^\]]+)\]"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
                for match in matches.reversed() {
                    if let valueRange = Range(match.range(at: 1), in: result),
                       let fullRange = Range(match.range, in: result) {
                        let value = String(result[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        signals.append(builder(value))
                        result.removeSubrange(fullRange)
                    }
                }
            }
        }

        // [SESSION_END] — no value
        let sessionEndPattern = #"\[SESSION_END\]"#
        if let regex = try? NSRegularExpression(pattern: sessionEndPattern, options: []) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: result) {
                    signals.append(.sessionEnd)
                    result.removeSubrange(fullRange)
                }
            }
        }

        return result
    }
}
