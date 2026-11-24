import Foundation
import PMDomain

/// Composes the full system prompt from Layer 1 (foundation) + Layer 2 (mode) with variable substitution.
public final class PromptComposer: Sendable {
    private let store: V2PromptTemplateStore

    public init(store: V2PromptTemplateStore = .shared) {
        self.store = store
    }

    /// Composes the full system prompt for a given mode and sub-mode.
    /// Layer 3 (project context) is not included here — it's assembled separately by the ContextAssembler.
    public func compose(
        mode: SessionMode,
        subMode: SessionSubMode? = nil,
        variables: [String: String] = [:]
    ) -> String {
        let layer1 = store.render(.foundation, variables: variables)
        let layer2 = composeLayer2(mode: mode, subMode: subMode, variables: variables)

        return """
        \(layer1)

        ---

        \(layer2)
        """
    }

    /// Returns just the Layer 2 prompt for a given mode/sub-mode (for testing/inspection).
    public func layer2Prompt(
        mode: SessionMode,
        subMode: SessionSubMode? = nil,
        variables: [String: String] = [:]
    ) -> String {
        composeLayer2(mode: mode, subMode: subMode, variables: variables)
    }

    /// Returns the summary generation prompt.
    public func summaryPrompt(variables: [String: String] = [:]) -> String {
        store.render(.summaryGeneration, variables: variables)
    }

    // MARK: - Private

    private func composeLayer2(
        mode: SessionMode,
        subMode: SessionSubMode?,
        variables: [String: String]
    ) -> String {
        let modeKey = layer2Key(for: mode)
        let modePrompt = store.render(modeKey, variables: variables)

        // For execution support, append sub-mode guidance
        if mode == .executionSupport, let subMode {
            let subModeKey = subModeLayer2Key(for: subMode)
            let subModePrompt = store.render(subModeKey, variables: variables)
            return """
            \(modePrompt)

            \(subModePrompt)
            """
        }

        return modePrompt
    }

    private func layer2Key(for mode: SessionMode) -> V2PromptTemplateKey {
        switch mode {
        case .exploration: .exploration
        case .definition: .definition
        case .planning: .planning
        case .executionSupport: .executionSupport
        }
    }

    private func subModeLayer2Key(for subMode: SessionSubMode) -> V2PromptTemplateKey {
        switch subMode {
        case .checkIn: .executionSupportCheckIn
        case .returnBriefing: .executionSupportReturnBriefing
        case .projectReview: .executionSupportProjectReview
        case .retrospective: .executionSupportRetrospective
        }
    }
}
