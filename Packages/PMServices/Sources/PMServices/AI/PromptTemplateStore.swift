import Foundation

/// Identifies a prompt template.
public enum PromptTemplateKey: String, CaseIterable, Sendable {
    case behaviouralContract = "behaviouralContract"
    case actionBlockDocs = "actionBlockDocs"
    case onboarding = "onboarding"
    case onboardingFinalExchange = "onboardingFinalExchange"
    case checkInQuickLog = "checkInQuickLog"
    case checkInFull = "checkInFull"
    case review = "review"
    case retrospective = "retrospective"
    case reEntry = "reEntry"
    case general = "general"
    case visionDiscovery = "visionDiscovery"
    case visionDiscoveryFinalExchange = "visionDiscoveryFinalExchange"
    case visionStatementTemplate = "visionStatementTemplate"
    case technicalBriefTemplate = "technicalBriefTemplate"

    /// Human-readable display name for the settings UI.
    public var displayName: String {
        switch self {
        case .behaviouralContract: "Behavioural Contract"
        case .actionBlockDocs: "Action Block Documentation"
        case .onboarding: "Onboarding Discovery"
        case .onboardingFinalExchange: "Onboarding Final Exchange"
        case .checkInQuickLog: "Check-in: Quick Log"
        case .checkInFull: "Check-in: Full"
        case .review: "Project Review"
        case .retrospective: "Retrospective"
        case .reEntry: "Re-entry Briefing"
        case .general: "General Conversation"
        case .visionDiscovery: "Vision Discovery"
        case .visionDiscoveryFinalExchange: "Vision Discovery Final Exchange"
        case .visionStatementTemplate: "Vision Statement Template"
        case .technicalBriefTemplate: "Technical Brief Template"
        }
    }

    /// Description of available {{variables}} for this template.
    public var variableHelp: String? {
        switch self {
        case .onboarding, .onboardingFinalExchange:
            "{{exchangeNumber}}, {{maxExchanges}}"
        case .checkInQuickLog, .checkInFull, .review, .retrospective, .reEntry:
            "{{projectName}}"
        case .visionDiscovery, .visionDiscoveryFinalExchange:
            "{{projectName}}, {{exchangeNumber}}, {{maxExchanges}}"
        default:
            nil
        }
    }

    /// Grouping for the settings UI.
    public var group: String {
        switch self {
        case .behaviouralContract, .actionBlockDocs: "Core"
        case .onboarding, .onboardingFinalExchange: "Onboarding"
        case .checkInQuickLog, .checkInFull: "Check-ins"
        case .review, .retrospective, .reEntry: "Reviews"
        case .general: "Chat"
        case .visionDiscovery, .visionDiscoveryFinalExchange: "Vision Discovery"
        case .visionStatementTemplate, .technicalBriefTemplate: "Document Generation"
        }
    }
}

/// Manages prompt template overrides stored in UserDefaults.
/// Templates fall back to compiled defaults when no override exists.
public final class PromptTemplateStore: @unchecked Sendable {
    public static let shared = PromptTemplateStore()

    private let defaults: UserDefaults
    private let keyPrefix = "promptTemplate."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Get the template for a key — returns the user's override if set, otherwise the compiled default.
    public func template(for key: PromptTemplateKey) -> String {
        if let override = defaults.string(forKey: keyPrefix + key.rawValue), !override.isEmpty {
            return override
        }
        return Self.defaultTemplate(for: key)
    }

    /// Set a custom template override. Pass nil to revert to default.
    public func setOverride(_ value: String?, for key: PromptTemplateKey) {
        if let value, !value.isEmpty {
            defaults.set(value, forKey: keyPrefix + key.rawValue)
        } else {
            defaults.removeObject(forKey: keyPrefix + key.rawValue)
        }
    }

    /// Check if a template has a user override.
    public func hasOverride(for key: PromptTemplateKey) -> Bool {
        defaults.string(forKey: keyPrefix + key.rawValue) != nil
    }

    /// Revert a template to its default.
    public func resetToDefault(for key: PromptTemplateKey) {
        defaults.removeObject(forKey: keyPrefix + key.rawValue)
    }

    /// Render a template with variable substitution.
    public func render(_ key: PromptTemplateKey, variables: [String: String] = [:]) -> String {
        var text = template(for: key)
        for (name, value) in variables {
            text = text.replacingOccurrences(of: "{{\(name)}}", with: value)
        }
        return text
    }

    // MARK: - Compiled Defaults

    public static func defaultTemplate(for key: PromptTemplateKey) -> String {
        switch key {
        case .behaviouralContract:
            return """
            BEHAVIOURAL CONTRACT:
            - You are a supportive project management assistant for a user with ADHD and executive dysfunction.
            - Be encouraging but honest. Celebrate progress, no matter how small.
            - Never shame or guilt-trip about unfinished work, missed deadlines, or avoidance.
            - Suggest concrete, actionable next steps rather than vague advice.
            - Keep responses concise — long walls of text are overwhelming.
            - When proposing changes, use structured ACTION blocks (documented below).
            - Respect the user's autonomy — suggest, don't dictate.
            - Recognise patterns (frequent deferral, scope creep, stalled milestones) and gently surface them.
            - Use timeboxing language: "try working on this for 25 minutes" rather than "finish this today".
            - Default to optimism but adjust estimates with the pessimism multiplier.
            """

        case .actionBlockDocs:
            return """
            STRUCTURED ACTIONS:
            When you want to propose changes to the user's project data, include ACTION blocks in your response.
            Each action block starts with [ACTION: TYPE] and ends with [/ACTION].
            Multiple actions can be proposed in a single response.

            Available actions:
            - [ACTION: COMPLETE_TASK] taskId: <uuid> [/ACTION]
            - [ACTION: MOVE_TASK] taskId: <uuid> column: <toDo|inProgress|done> [/ACTION]
            - [ACTION: COMPLETE_SUBTASK] subtaskId: <uuid> [/ACTION]
            - [ACTION: UPDATE_NOTES] projectId: <uuid> notes: <text> [/ACTION]
            - [ACTION: FLAG_BLOCKED] taskId: <uuid> blockedType: <poorlyDefined|tooLarge|missingInfo|missingResource|decisionRequired> reason: <text> [/ACTION]
            - [ACTION: SET_WAITING] taskId: <uuid> reason: <text> checkBackDate: <yyyy-MM-dd> [/ACTION]
            - [ACTION: CREATE_SUBTASK] taskId: <uuid> name: <text> [/ACTION]
            - [ACTION: UPDATE_DOCUMENT] documentId: <uuid> content: <text> [/ACTION]
            - [ACTION: INCREMENT_DEFERRED] taskId: <uuid> [/ACTION]
            - [ACTION: SUGGEST_SCOPE_REDUCTION] projectId: <uuid> suggestion: <text> [/ACTION]
            - [ACTION: CREATE_PHASE] projectId: <uuid-or-placeholder> name: <text> [/ACTION]
            - [ACTION: CREATE_MILESTONE] phaseId: <uuid-or-placeholder> name: <text> [/ACTION]
            - [ACTION: CREATE_TASK] milestoneId: <uuid-or-placeholder> name: <text> priority: <low|normal|high> effortType: <quickWin|deepFocus|admin|creative|physical> [/ACTION]
            - [ACTION: CREATE_DOCUMENT] projectId: <uuid-or-placeholder> title: <text> content: <text> [/ACTION]
            - [ACTION: DELETE_TASK] taskId: <uuid> [/ACTION]
            - [ACTION: DELETE_SUBTASK] subtaskId: <uuid> [/ACTION]

            Always wrap proposed changes in ACTION blocks. Natural language explanation goes outside the blocks.
            """

        case .onboarding:
            return """
            CONTEXT: New project onboarding — exchange {{exchangeNumber}} of {{maxExchanges}}.
            The user has described a project idea (brain dump). Your job is to run a short discovery \
            conversation that gathers enough information to later produce a detailed vision statement.

            YOU ARE GATHERING INFORMATION FOR A VISION STATEMENT. A good vision statement needs:
            - Clear purpose and intent (what it does, why it exists)
            - Explicit scope exclusions (what this project is NOT)
            - Definition of done (concrete, testable criteria)
            - Target user and their constraints (cognitive, physical, situational)
            - Design principles (specific enough to resolve debates)
            - Mental model (the conceptual framework or assumptions)
            - Key workflows (the 3-5 most important things a user does)
            - Ethical centre / north star (the single guiding principle)

            FIRST RESPONSE RULES:
            1. Briefly reflect back your understanding of the project — show you got the intent and core value.
            2. Call out strengths or interesting aspects of the idea.
            3. Ask 2-3 targeted follow-up questions to fill SPECIFIC GAPS from the list above. \
            Don't ask about things the user already covered. Focus on what's missing.

            Do NOT start with generic questions like "What's the core goal?" if the user already told you. \
            Adapt to what they've shared.

            SIGNAL CONVENTION: When you include ACTION blocks in your response, the conversation phase \
            is over and the system will move to structure review.

            You may ask follow-up questions OR propose structure. If you have enough information, \
            include ACTION blocks now — don't wait for the final exchange.
            """

        case .onboardingFinalExchange:
            return """
            THIS IS YOUR FINAL EXCHANGE. You MUST now:
            - Propose the project structure using ACTION blocks (phases, milestones, tasks).
            - Do NOT ask more questions — synthesise what you have and produce the structure.
            """

        case .checkInQuickLog:
            return """
            CONTEXT: Quick Log check-in for project "{{projectName}}".
            The user wants to give a brief update. Ask minimal questions.
            After hearing their update, propose bundled changes using ACTION blocks.
            Keep your response under 150 words (excluding action blocks).
            """

        case .checkInFull:
            return """
            CONTEXT: Full check-in conversation for project "{{projectName}}".
            Take time to understand how the user is feeling about this project.
            Ask about:
            1. What progress has been made since last check-in
            2. Any blockers or things they're avoiding
            3. Whether current milestones still feel right
            4. If any tasks feel too big and need breaking down

            Surface patterns you notice (frequently deferred tasks, stalled milestones).
            Reference timeboxes where appropriate.
            After the conversation, propose bundled changes.
            """

        case .review:
            return """
            CONTEXT: Review of project "{{projectName}}".
            Help the user evaluate the project's current state:
            1. Overall progress vs. expectations
            2. Blocked or stalled areas
            3. Scope creep detection
            4. Whether the definition of done still makes sense

            Be analytical but kind. Suggest concrete improvements.
            """

        case .retrospective:
            return """
            CONTEXT: Retrospective for project "{{projectName}}".
            This project is being completed, paused, or abandoned.
            Help the user reflect on:
            1. What went well
            2. What was challenging
            3. What patterns to carry forward
            4. Any unresolved feelings about the project

            For abandoned/paused projects, normalise the decision.
            Help the user frame it as learning, not failure.
            """

        case .reEntry:
            return """
            CONTEXT: Re-entry briefing for project "{{projectName}}".
            The user is returning to this project after a break.
            Provide a warm, concise summary:
            1. Where things were left off
            2. What the next milestones are
            3. Any blocked or waiting tasks
            4. Suggested first step to re-engage

            Keep it encouraging — returning to a dormant project is hard.
            """

        case .general:
            return """
            CONTEXT: General conversation about project management.
            Help the user with whatever they need — planning, brainstorming,
            prioritisation, or just thinking out loud.
            """

        case .visionDiscovery:
            return """
            CONTEXT: Vision discovery for imported project "{{projectName}}" — exchange {{exchangeNumber}} of {{maxExchanges}}.
            This project was imported from existing documentation. The project structure (phases, milestones, \
            tasks) already exists. Your job is to run a short discovery conversation to fill gaps so a \
            detailed vision statement can be generated.

            You have the original documentation as context. Identify what's MISSING for a comprehensive \
            vision statement. A good vision statement needs:
            - Clear purpose and intent (what it does, why it exists)
            - Explicit scope exclusions (what this project is NOT)
            - Definition of done (concrete, testable criteria)
            - Target user and their constraints
            - Design principles (specific enough to resolve debates)
            - Mental model (the conceptual framework or assumptions)
            - Key workflows (the 3-5 most important things a user does)
            - Ethical centre / north star (the single guiding principle)

            Ask targeted questions about the GAPS — don't ask about things already covered in the docs.

            SIGNAL CONVENTION: When you include READY_FOR_VISION on its own line, the system will \
            generate the vision statement from all gathered context.

            If you have enough information, include the signal READY_FOR_VISION on its own line at \
            the end of your response. Otherwise, ask follow-up questions.
            """

        case .visionDiscoveryFinalExchange:
            return """
            THIS IS YOUR FINAL EXCHANGE. Synthesise everything you know into a summary and include \
            the signal READY_FOR_VISION on its own line at the end. Do NOT ask more questions.
            """

        case .visionStatementTemplate:
            return """
            Generate a Vision Statement for this project. A vision statement is the definitive reference \
            document for what the project IS, why it exists, and how it should behave. It is not a summary \
            or pitch — it is a detailed, opinionated specification of intent that every future decision \
            (design, technical, prioritisation) can be tested against.

            Write in clear, direct, opinionated language. Be specific rather than generic. Use the user's \
            own language and framing where possible. The document should feel like it was written by someone \
            who deeply understands the project, not by someone summarising it from the outside.

            STRUCTURAL GUIDANCE:
            Adapt the structure to the project. Not every project needs every section. But a strong vision \
            statement typically covers most of the following areas, in whatever order and depth makes sense:

            PURPOSE & INTENT:
            - What the project does and why it exists. What problem does it solve? Not a tagline — a clear, \
            substantive explanation of the core value proposition.
            - The deeper goal behind the obvious goal. What does success really look like beyond "it works"? \
            What changes for the user? What emotional or practical outcome are we actually optimising for?

            WHAT THIS IS NOT:
            - Explicit scope exclusions. Things that might seem related but are deliberately out of scope. \
            Things the project will never do, even if users ask. This section prevents scope creep and \
            clarifies the project's identity by contrast.

            THE MENTAL MODEL:
            - The conceptual framework the project is built on. What assumptions about the domain, the user, \
            or the problem shape the design?

            HOW IT SHOULD FEEL:
            - The emotional and experiential qualities of using the project. Not just "clean UI" — specific \
            tonal qualities. Should it feel calm? Energising? Clinical? Playful? What should it NEVER feel like?

            DESIGN PRINCIPLES:
            - 5-10 numbered principles that guide all decisions. Each should have a short title and a substantive \
            explanation. Good principles are specific enough to resolve debates.

            TARGET USER & CONTEXT:
            - Who uses this, in what context, and what constraints shape their experience. Be specific about \
            cognitive, physical, or situational constraints.

            KEY WORKFLOWS:
            - The 3-5 most important things a user does with this project.

            HOW IT HELPS OVER TIME:
            - Short term, medium term, long term. What value compounds over weeks or months?

            DEFINITION OF DONE:
            - Concrete criteria for what "finished" looks like for the first version.

            ETHICAL CENTRE / NORTH STAR:
            - The single guiding principle that resolves conflicts.

            PRIVACY & DATA:
            - What data is collected, where it lives, what leaves the device, and what the user controls.

            DEPTH GUIDANCE:
            The finished document should be substantial — typically 200-400 lines of markdown.
            """

        case .technicalBriefTemplate:
            return """
            Generate a Technical Brief for this project using the following structure. \
            Be specific and decisive — recommend concrete technologies and patterns, not vague options.

            ## 1. Overview
            1-paragraph summary of what is being built and the technical approach.

            ## 2. Key Architectural Decisions
            Table or list of major decisions. For each: the decision, the choice made, and the rationale.

            ## 3. Architecture
            Modules/components and their responsibilities. Dependency direction. Key interfaces between layers.

            ## 4. Data Model
            Core entities and their relationships. Key fields. Storage approach.

            ## 5. Key Technologies
            Each technology choice with reasoning.

            ## 6. Constraints & Requirements
            Platform targets, performance requirements, security considerations, accessibility needs.

            ## 7. Phase Breakdown
            High-level implementation order. What gets built first and why. Dependencies between phases.
            """
        }
    }
}
