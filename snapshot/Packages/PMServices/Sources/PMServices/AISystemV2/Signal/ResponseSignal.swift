import Foundation

/// Structured signals extracted from AI responses, distinct from ACTION blocks.
public enum ResponseSignal: Sendable, Equatable {
    /// The current mode's criteria are met.
    case modeComplete(mode: String)
    /// Recommended deliverables from Exploration completion.
    case processRecommendation(deliverables: String)
    /// Suggested planning depth from Exploration completion.
    case planningDepth(depth: String)
    /// Project summary from Exploration completion.
    case projectSummary(summary: String)
    /// Deliverables produced during Definition.
    case deliverablesProduced(types: String)
    /// Deliverables deferred during Definition.
    case deliverablesDeferred(types: String)
    /// Structure summary from Planning completion.
    case structureSummary(summary: String)
    /// First action from Planning completion.
    case firstAction(action: String)
    /// End of an Execution Support session.
    case sessionEnd
    /// A document draft artifact.
    case documentDraft(type: String, content: String)
    /// A structural proposal artifact.
    case structureProposal(content: String)
}

/// The result of parsing an AI response for both signals and natural language.
public struct ParsedV2Response: Sendable {
    /// The natural language portion of the response (signals stripped out).
    public let naturalLanguage: String
    /// Any structured signals found in the response.
    public let signals: [ResponseSignal]
    /// Any ACTION blocks found (only when action parsing is enabled).
    public let actions: [AIAction]

    public init(
        naturalLanguage: String,
        signals: [ResponseSignal] = [],
        actions: [AIAction] = []
    ) {
        self.naturalLanguage = naturalLanguage
        self.signals = signals
        self.actions = actions
    }
}
