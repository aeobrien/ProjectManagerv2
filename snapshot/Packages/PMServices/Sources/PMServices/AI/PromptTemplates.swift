import Foundation
import PMDomain

/// Prompt templates for each conversation type with behavioural contract.
/// Templates are loaded from PromptTemplateStore, which supports user overrides via UserDefaults.
public enum PromptTemplates {
    private static var store: PromptTemplateStore { .shared }

    // MARK: - Behavioural Contract

    /// Core behavioural contract embedded in all system prompts.
    public static var behaviouralContract: String {
        store.template(for: .behaviouralContract)
    }

    // MARK: - Action Block Documentation

    /// Documentation for structured action blocks, included in system prompts.
    public static var actionBlockDocs: String {
        store.template(for: .actionBlockDocs)
    }

    // MARK: - System Prompts

    /// System prompt for quick log check-ins.
    public static func checkInQuickLog(projectName: String) -> String {
        let body = store.render(.checkInQuickLog, variables: ["projectName": projectName])
        return """
        \(behaviouralContract)

        \(body)

        \(actionBlockDocs)
        """
    }

    /// System prompt for full conversation check-ins.
    public static func checkInFull(projectName: String) -> String {
        let body = store.render(.checkInFull, variables: ["projectName": projectName])
        return """
        \(behaviouralContract)

        \(body)

        \(actionBlockDocs)
        """
    }

    /// System prompt for project onboarding (default, used by systemPrompt(for:)).
    public static func onboarding() -> String {
        onboarding(exchangeNumber: 1, maxExchanges: 3)
    }

    /// Exchange-aware system prompt for project onboarding.
    public static func onboarding(exchangeNumber: Int, maxExchanges: Int) -> String {
        let isFinal = exchangeNumber >= maxExchanges
        let vars = [
            "exchangeNumber": "\(exchangeNumber)",
            "maxExchanges": "\(maxExchanges)"
        ]

        let body: String
        if isFinal {
            let mainBody = store.render(.onboarding, variables: vars)
            let finalInstructions = store.render(.onboardingFinalExchange, variables: vars)
            // Replace the non-final instruction with the final one
            let mainLines = mainBody.components(separatedBy: "\n")
            let trimmed = mainLines.filter { !$0.contains("You may ask follow-up questions") }.joined(separator: "\n")
            body = trimmed + "\n\n" + finalInstructions
        } else {
            body = store.render(.onboarding, variables: vars)
        }

        return """
        \(behaviouralContract)

        \(body)

        \(actionBlockDocs)
        """
    }

    /// System prompt for vision discovery on an imported project (default).
    public static func visionDiscovery(projectName: String) -> String {
        visionDiscovery(projectName: projectName, exchangeNumber: 1, maxExchanges: 3)
    }

    /// Exchange-aware system prompt for vision discovery on an imported project.
    public static func visionDiscovery(projectName: String, exchangeNumber: Int, maxExchanges: Int) -> String {
        let isFinal = exchangeNumber >= maxExchanges
        let vars = [
            "projectName": projectName,
            "exchangeNumber": "\(exchangeNumber)",
            "maxExchanges": "\(maxExchanges)"
        ]

        let body: String
        if isFinal {
            let mainBody = store.render(.visionDiscovery, variables: vars)
            let finalInstructions = store.render(.visionDiscoveryFinalExchange, variables: vars)
            let mainLines = mainBody.components(separatedBy: "\n")
            let trimmed = mainLines.filter { !$0.contains("If you have enough information") }.joined(separator: "\n")
            body = trimmed + "\n\n" + finalInstructions
        } else {
            body = store.render(.visionDiscovery, variables: vars)
        }

        return """
        \(behaviouralContract)

        \(body)
        """
    }

    /// System prompt for project review.
    public static func review(projectName: String) -> String {
        let body = store.render(.review, variables: ["projectName": projectName])
        return """
        \(behaviouralContract)

        \(body)

        \(actionBlockDocs)
        """
    }

    /// System prompt for retrospective.
    public static func retrospective(projectName: String) -> String {
        let body = store.render(.retrospective, variables: ["projectName": projectName])
        return """
        \(behaviouralContract)

        \(body)

        \(actionBlockDocs)
        """
    }

    /// System prompt for re-entry briefing.
    public static func reEntry(projectName: String) -> String {
        let body = store.render(.reEntry, variables: ["projectName": projectName])
        return """
        \(behaviouralContract)

        \(body)

        \(actionBlockDocs)
        """
    }

    /// System prompt for general conversation.
    public static func general() -> String {
        let body = store.template(for: .general)
        return """
        \(behaviouralContract)

        \(body)

        \(actionBlockDocs)
        """
    }

    // MARK: - Document Templates

    /// Structured template for vision statement generation.
    public static var visionStatementTemplate: String {
        store.template(for: .visionStatementTemplate)
    }

    /// Structured template for technical brief generation.
    public static var technicalBriefTemplate: String {
        store.template(for: .technicalBriefTemplate)
    }

    // MARK: - Migration Import

    /// Prompt for extracting structured project data from an Obsidian markdown file.
    public static func markdownImport() -> String {
        """
        You are a project data extraction assistant. Given a markdown file describing a project, \
        extract structured data from it. Return your response in the exact format below.

        EXTRACTION RULES:
        - Extract the project name from the first # heading.
        - Map any Tags section to the closest built-in category: Software, Music, Hardware/Electronics, Creative, Life Admin, Research/Learning. \
          Default to Software if unclear.
        - Extract phases from "Implementation Roadmap" or "Phases" or "Milestones" sections. \
          Each ## or ### heading in that section becomes a phase.
        - Extract tasks from "Next Steps" or checkbox items (- [ ] or - [x]). \
          Preserve completion status. If a completed item has a date annotation, extract it.
        - Group tasks under the most relevant phase. If no clear mapping, use a "General" milestone.
        - Find a Definition of Done from "Success Metrics" or "Definition of Done" or "Goals" sections.
        - Extract GitHub/repository URLs from "Repositories", "Links", or inline URLs matching github.com.
        - Extract any "Open Questions" or "Unknowns" section as notes.

        RESPONSE FORMAT:
        [METADATA]
        category: <closest built-in category name>
        repositoryURL: <URL or empty>
        definitionOfDone: <text or empty>
        notes: <text or empty>
        [/METADATA]

        Then for each phase, milestone, and task use ACTION blocks:

        [ACTION: CREATE_PHASE] projectId: PLACEHOLDER name: <phase name> [/ACTION]
        [ACTION: CREATE_MILESTONE] phaseId: PHASE_<phase name> name: <milestone name> [/ACTION]
        [ACTION: CREATE_TASK] milestoneId: MILESTONE_<milestone name> name: <task name> priority: normal effortType: quickWin [/ACTION]

        For completed tasks, add a COMPLETE marker after the CREATE_TASK:
        [COMPLETED_TASK: <task name>]

        Keep phase and milestone names concise. Every task must belong to a milestone, \
        and every milestone must belong to a phase. If the markdown has no clear phase structure, \
        create a single phase called "Main" with a "General" milestone.
        """
    }

    /// Returns the appropriate system prompt for a conversation type.
    public static func systemPrompt(for type: ConversationType, projectName: String? = nil) -> String {
        switch type {
        case .checkInQuickLog: checkInQuickLog(projectName: projectName ?? "Unknown")
        case .checkInFull, .checkIn: checkInFull(projectName: projectName ?? "Unknown")
        case .onboarding: onboarding()
        case .review: review(projectName: projectName ?? "Unknown")
        case .retrospective: retrospective(projectName: projectName ?? "Unknown")
        case .reEntry: reEntry(projectName: projectName ?? "Unknown")
        case .visionDiscovery: visionDiscovery(projectName: projectName ?? "Unknown")
        case .brainDump, .planning, .general: general()
        }
    }
}
