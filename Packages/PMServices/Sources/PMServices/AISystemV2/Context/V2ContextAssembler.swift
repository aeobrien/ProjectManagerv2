import Foundation
import PMDomain
import PMUtilities

/// Mode-aware context assembler for the v2 AI system.
/// Produces Layer 3 (project context) in a standard format, respecting per-mode token budgets.
public struct V2ContextAssembler: Sendable {
    /// Approximate tokens per character ratio (conservative estimate).
    public static let tokensPerChar: Double = 0.3

    /// Total token budget for the full request (system prompt + context + history + response).
    public let totalBudget: Int

    /// Reserved tokens for the AI response.
    public let responseReserve: Int

    public init(totalBudget: Int = 100000, responseReserve: Int = 4000) {
        self.totalBudget = totalBudget
        self.responseReserve = responseReserve
    }

    /// Estimate token count for a string.
    public static func estimateTokens(_ text: String) -> Int {
        Int(ceil(Double(text.count) * tokensPerChar))
    }

    // MARK: - Context Data

    /// All data needed to assemble Layer 3 context for a single project.
    public struct ProjectData: Sendable {
        public let project: Project
        public let phases: [Phase]
        public let milestones: [Milestone]
        public let tasks: [PMTask]
        public let subtasksByTaskId: [UUID: [Subtask]]
        public let processProfile: ProcessProfile?
        public let deliverables: [Deliverable]
        public let documents: [Document]
        public let sessions: [Session]
        public let sessionSummaries: [SessionSummary]
        public let frequentlyDeferredTasks: [PMTask]
        public let estimateAccuracy: Float?
        public let suggestedMultiplier: Float?
        public let accuracyTrend: (older: Float, newer: Float)?
        public let codebaseContext: String?

        public init(
            project: Project,
            phases: [Phase] = [],
            milestones: [Milestone] = [],
            tasks: [PMTask] = [],
            subtasksByTaskId: [UUID: [Subtask]] = [:],
            processProfile: ProcessProfile? = nil,
            deliverables: [Deliverable] = [],
            documents: [Document] = [],
            sessions: [Session] = [],
            sessionSummaries: [SessionSummary] = [],
            frequentlyDeferredTasks: [PMTask] = [],
            estimateAccuracy: Float? = nil,
            suggestedMultiplier: Float? = nil,
            accuracyTrend: (older: Float, newer: Float)? = nil,
            codebaseContext: String? = nil
        ) {
            self.project = project
            self.phases = phases
            self.milestones = milestones
            self.tasks = tasks
            self.subtasksByTaskId = subtasksByTaskId
            self.processProfile = processProfile
            self.deliverables = deliverables
            self.documents = documents
            self.sessions = sessions
            self.sessionSummaries = sessionSummaries
            self.frequentlyDeferredTasks = frequentlyDeferredTasks
            self.estimateAccuracy = estimateAccuracy
            self.suggestedMultiplier = suggestedMultiplier
            self.accuracyTrend = accuracyTrend
            self.codebaseContext = codebaseContext
        }
    }

    /// Data for a portfolio-level project review (multiple projects).
    public struct PortfolioData: Sendable {
        public let projects: [ProjectSummaryData]

        public init(projects: [ProjectSummaryData] = []) {
            self.projects = projects
        }

        public struct ProjectSummaryData: Sendable {
            public let project: Project
            public let latestSummary: SessionSummary?
            public let sessionCount: Int
            public let daysSinceLastSession: Int?

            public init(
                project: Project,
                latestSummary: SessionSummary? = nil,
                sessionCount: Int = 0,
                daysSinceLastSession: Int? = nil
            ) {
                self.project = project
                self.latestSummary = latestSummary
                self.sessionCount = sessionCount
                self.daysSinceLastSession = daysSinceLastSession
            }
        }
    }

    // MARK: - Assembly

    /// Assemble Layer 3 context for a given mode and project.
    public func assembleLayer3(
        mode: SessionMode,
        subMode: SessionSubMode? = nil,
        projectData: ProjectData,
        portfolioData: PortfolioData? = nil
    ) -> String {
        assembleLayer3WithInfo(mode: mode, subMode: subMode, projectData: projectData, portfolioData: portfolioData).content
    }

    /// Internal assembly that also returns truncation metadata.
    private func assembleLayer3WithInfo(
        mode: SessionMode,
        subMode: SessionSubMode? = nil,
        projectData: ProjectData,
        portfolioData: PortfolioData? = nil
    ) -> Layer3Result {
        let config = V2ContextConfiguration.configuration(for: mode, subMode: subMode)
        let patterns = CrossSessionPatterns.compute(
            sessions: projectData.sessions,
            summaries: projectData.sessionSummaries,
            frequentlyDeferredTasks: projectData.frequentlyDeferredTasks
        )

        var sections: [PrioritisedSection] = []

        for component in config.components {
            let section = renderComponent(
                component,
                projectData: projectData,
                portfolioData: portfolioData,
                patterns: patterns,
                config: config
            )
            if let section {
                sections.append(section)
            }
        }

        // Sort by priority (lower number = higher priority)
        sections.sort { $0.priority < $1.priority }

        // Apply token budget — truncate lowest priority first
        return applyTokenBudget(sections: sections, budget: config.tokenBudget)
    }

    /// Assemble a full ContextPayload (system prompt + Layer 3 + conversation history).
    public func assemblePayload(
        systemPrompt: String,
        mode: SessionMode,
        subMode: SessionSubMode? = nil,
        projectData: ProjectData,
        portfolioData: PortfolioData? = nil,
        conversationHistory: [LLMMessage] = []
    ) -> ContextPayload {
        let layer3Result = assembleLayer3WithInfo(
            mode: mode,
            subMode: subMode,
            projectData: projectData,
            portfolioData: portfolioData
        )

        let fullSystemPrompt: String
        if layer3Result.content.isEmpty {
            fullSystemPrompt = systemPrompt
        } else {
            fullSystemPrompt = systemPrompt + "\n\n---\n\n" + layer3Result.content
        }

        var messages: [LLMMessage] = []
        messages.append(LLMMessage(role: .system, content: fullSystemPrompt))

        let systemTokens = Self.estimateTokens(fullSystemPrompt)
        var remainingBudget = totalBudget - systemTokens - responseReserve

        // Add history from most recent, truncating oldest if needed
        var historyMessages: [LLMMessage] = []
        for message in conversationHistory.reversed() {
            let messageTokens = Self.estimateTokens(message.content)
            if remainingBudget - messageTokens < 0 { break }
            remainingBudget -= messageTokens
            historyMessages.insert(message, at: 0)
        }

        let droppedHistoryCount = conversationHistory.count - historyMessages.count

        if droppedHistoryCount > 0 && !conversationHistory.isEmpty {
            messages.append(LLMMessage(
                role: .system,
                content: "[Earlier conversation history was truncated to fit within token budget]"
            ))
        }

        messages.append(contentsOf: historyMessages)

        let totalTokens = messages.reduce(0) { $0 + Self.estimateTokens($1.content) }

        let truncationInfo = ContextTruncationInfo(
            droppedSections: layer3Result.droppedSections,
            truncatedSections: layer3Result.truncatedSections,
            droppedHistoryMessages: droppedHistoryCount,
            layer3Budget: layer3Result.budget,
            layer3TokensBeforeTruncation: layer3Result.tokensBeforeTruncation
        )

        return ContextPayload(
            systemPrompt: fullSystemPrompt,
            messages: messages,
            estimatedTokens: totalTokens,
            truncationInfo: truncationInfo
        )
    }

    // MARK: - Component Rendering

    private struct PrioritisedSection {
        let label: String
        let priority: Int
        let content: String
        var tokens: Int { Self.estimateTokens(content) }

        private static func estimateTokens(_ text: String) -> Int {
            V2ContextAssembler.estimateTokens(text)
        }
    }

    /// Internal result of Layer 3 assembly with truncation metadata.
    private struct Layer3Result {
        let content: String
        let droppedSections: [String]
        let truncatedSections: [String]
        let budget: Int
        let tokensBeforeTruncation: Int
    }

    private func renderComponent(
        _ component: V2ContextConfiguration.Component,
        projectData: ProjectData,
        portfolioData: PortfolioData?,
        patterns: CrossSessionPatterns,
        config: V2ContextConfiguration
    ) -> PrioritisedSection? {
        let content: String?

        switch component.kind {
        case .projectOverview:
            content = formatProjectOverview(projectData.project)
        case .processProfile:
            content = formatProcessProfile(projectData.processProfile)
        case .documents:
            content = formatDocuments(deliverables: projectData.deliverables, documents: projectData.documents)
        case .sessionSummaries:
            content = formatSessionSummaries(
                projectData.sessionSummaries,
                fullCount: config.fullSummaryCount,
                condensedCount: config.condensedSummaryCount
            )
        case .projectStructure:
            content = formatProjectStructure(projectData)
        case .frequentlyDeferred:
            content = formatFrequentlyDeferred(projectData.frequentlyDeferredTasks)
        case .estimateCalibration:
            content = formatEstimateCalibration(
                accuracy: projectData.estimateAccuracy,
                multiplier: projectData.suggestedMultiplier,
                trend: projectData.accuracyTrend
            )
        case .patternsAndObservations:
            content = formatPatterns(patterns)
        case .activeSessionContext:
            content = nil // Populated externally by the ConversationManager
        case .portfolioSummary:
            content = formatPortfolio(portfolioData)
        case .codebaseContext:
            if let ctx = projectData.codebaseContext, !ctx.isEmpty {
                content = "RELEVANT CODE:\n\n\(ctx)"
                Log.ai.info("Including codebase context: \(ctx.count) chars")
            } else {
                content = nil
                Log.ai.debug("No codebase context available for assembly")
            }
        }

        guard let content, !content.isEmpty else { return nil }
        return PrioritisedSection(label: component.kind.rawValue, priority: component.priority, content: content)
    }

    // MARK: - Token Budget

    private func applyTokenBudget(sections: [PrioritisedSection], budget: Int) -> Layer3Result {
        let tokensBeforeTruncation = sections.reduce(0) { $0 + $1.tokens }
        var totalTokens = tokensBeforeTruncation

        if totalTokens <= budget {
            return Layer3Result(
                content: sections.map(\.content).joined(separator: "\n\n"),
                droppedSections: [],
                truncatedSections: [],
                budget: budget,
                tokensBeforeTruncation: tokensBeforeTruncation
            )
        }

        // Phase 1: Drop entire sections from lowest priority (highest number) until within budget
        var includedSections = sections
        var droppedSections: [String] = []
        while totalTokens > budget && includedSections.count > 1 {
            // Find the lowest-priority section (highest priority number)
            if let maxIdx = includedSections.indices.max(by: { includedSections[$0].priority < includedSections[$1].priority }) {
                let dropped = includedSections[maxIdx]
                Log.ai.info("Context budget: dropping '\(dropped.label)' (priority \(dropped.priority), \(dropped.tokens) tokens) — \(totalTokens)/\(budget) tokens")
                droppedSections.append(dropped.label)
                totalTokens -= dropped.tokens
                includedSections.remove(at: maxIdx)
            }
        }

        // Phase 2: If a single section still exceeds budget, truncate its content rather than dropping it
        var truncatedSections: [String] = []
        if totalTokens > budget, includedSections.count == 1 {
            truncatedSections.append(includedSections[0].label)
            let maxChars = Int(Double(budget) / Self.tokensPerChar)
            let original = includedSections[0].content
            let truncated = String(original.prefix(maxChars))
            // Try to break at a newline to avoid cutting mid-line
            let breakPoint = truncated.range(of: "\n", options: .backwards)?.lowerBound
                ?? truncated.endIndex
            let cleanTruncated = String(truncated[truncated.startIndex..<breakPoint])
            let trimmedChars = original.count - cleanTruncated.count
            includedSections[0] = PrioritisedSection(
                label: includedSections[0].label,
                priority: includedSections[0].priority,
                content: cleanTruncated + "\n[... truncated, \(trimmedChars) chars omitted to fit context budget]"
            )
        }

        return Layer3Result(
            content: includedSections.map(\.content).joined(separator: "\n\n"),
            droppedSections: droppedSections,
            truncatedSections: truncatedSections,
            budget: budget,
            tokensBeforeTruncation: tokensBeforeTruncation
        )
    }

    // MARK: - Formatters

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()

    private func formatProjectOverview(_ project: Project) -> String {
        var lines: [String] = []
        lines.append("PROJECT: \(project.name)")
        lines.append("State: \(project.lifecycleState.rawValue)")
        if let dod = project.definitionOfDone, !dod.isEmpty {
            lines.append("Definition of Done: \(dod)")
        }
        if let transcript = project.quickCaptureTranscript, !transcript.isEmpty {
            lines.append("Original Capture: \(transcript)")
        }
        if let notes = project.notes, !notes.isEmpty {
            lines.append("Notes: \(notes)")
        }
        return lines.joined(separator: "\n")
    }

    private func formatProcessProfile(_ profile: ProcessProfile?) -> String? {
        guard let profile else { return nil }

        var lines: [String] = ["PROCESS PROFILE:"]
        lines.append("Planning depth: \(profile.planningDepth.rawValue)")

        if !profile.recommendedDeliverables.isEmpty {
            lines.append("Recommended deliverables:")
            for rec in profile.recommendedDeliverables {
                let status = rec.status.rawValue
                var line = "  - \(rec.type.rawValue) (\(status))"
                if let rationale = rec.rationale {
                    line += " — \(rationale)"
                }
                lines.append(line)
            }
        }

        if !profile.suggestedModePath.isEmpty {
            lines.append("Suggested mode path: \(profile.suggestedModePath.joined(separator: " → "))")
        }

        return lines.joined(separator: "\n")
    }

    private func formatDocuments(deliverables: [Deliverable], documents: [Document]) -> String? {
        let completedDeliverables = deliverables.filter { $0.status == .completed || $0.status == .revised }
        let nonEmptyDocuments = documents.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard !completedDeliverables.isEmpty || !nonEmptyDocuments.isEmpty else { return nil }

        var lines: [String] = ["DOCUMENTS:"]

        // Research/reference documents first — these provide input context.
        // High char limit: users add these specifically to inform AI sessions.
        for doc in nonEmptyDocuments {
            lines.append("")
            lines.append("[\(doc.type.rawValue): \(doc.title)]")
            let maxChars = 25000
            if doc.content.count > maxChars {
                let truncated = String(doc.content.prefix(maxChars))
                lines.append(truncated)
                lines.append("[... truncated, \(doc.content.count) chars total]")
            } else {
                lines.append(doc.content)
            }
        }

        // Deliverables (AI-produced artifacts)
        for doc in completedDeliverables {
            lines.append("")
            lines.append("[\(doc.type.rawValue): \(doc.title)]")
            let maxChars = 8000
            if doc.content.count > maxChars {
                let truncated = String(doc.content.prefix(maxChars))
                lines.append(truncated)
                lines.append("[... truncated, \(doc.content.count) chars total]")
            } else {
                lines.append(doc.content)
            }
        }

        return lines.joined(separator: "\n")
    }

    private func formatSessionSummaries(
        _ summaries: [SessionSummary],
        fullCount: Int,
        condensedCount: Int
    ) -> String? {
        guard !summaries.isEmpty else { return nil }

        // Sort by end date descending (most recent first)
        let sorted = summaries.sorted { $0.endedAt > $1.endedAt }

        var lines: [String] = ["SESSION HISTORY:"]

        // Full summaries for the most recent N
        let fullSummaries = sorted.prefix(fullCount)
        for summary in fullSummaries {
            lines.append("")
            lines.append(formatFullSummary(summary))
        }

        // Condensed summaries for the next N
        let condensedStart = fullCount
        let condensedEnd = min(condensedStart + condensedCount, sorted.count)
        if condensedStart < sorted.count {
            let condensed = sorted[condensedStart..<condensedEnd]
            if !condensed.isEmpty {
                lines.append("")
                lines.append("Earlier sessions (condensed):")
                for summary in condensed {
                    lines.append(formatCondensedSummary(summary))
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private func formatFullSummary(_ summary: SessionSummary) -> String {
        var lines: [String] = []
        let modeLabel = summary.subMode.map { "\(summary.mode.rawValue)/\($0.rawValue)" } ?? summary.mode.rawValue
        lines.append("Session (\(modeLabel)) — \(dateFormatter.string(from: summary.startedAt)) to \(dateFormatter.string(from: summary.endedAt)):")

        if !summary.contentEstablished.decisions.isEmpty {
            lines.append("  Decisions: " + summary.contentEstablished.decisions.joined(separator: "; "))
        }
        if !summary.contentEstablished.factsLearned.isEmpty {
            lines.append("  Facts learned: " + summary.contentEstablished.factsLearned.joined(separator: "; "))
        }
        if !summary.contentEstablished.progressMade.isEmpty {
            lines.append("  Progress: " + summary.contentEstablished.progressMade.joined(separator: "; "))
        }
        if !summary.contentObserved.patterns.isEmpty {
            lines.append("  Patterns: " + summary.contentObserved.patterns.joined(separator: "; "))
        }
        if !summary.contentObserved.concerns.isEmpty {
            lines.append("  Concerns: " + summary.contentObserved.concerns.joined(separator: "; "))
        }
        if !summary.whatComesNext.nextActions.isEmpty {
            lines.append("  Next actions: " + summary.whatComesNext.nextActions.joined(separator: "; "))
        }
        if !summary.whatComesNext.openQuestions.isEmpty {
            lines.append("  Open questions: " + summary.whatComesNext.openQuestions.joined(separator: "; "))
        }

        return lines.joined(separator: "\n")
    }

    private func formatCondensedSummary(_ summary: SessionSummary) -> String {
        let modeLabel = summary.subMode.map { "\(summary.mode.rawValue)/\($0.rawValue)" } ?? summary.mode.rawValue
        var parts: [String] = []

        if !summary.contentEstablished.decisions.isEmpty {
            parts.append("decided: " + summary.contentEstablished.decisions.joined(separator: ", "))
        }
        if !summary.contentObserved.patterns.isEmpty {
            parts.append("patterns: " + summary.contentObserved.patterns.joined(separator: ", "))
        }
        if !summary.whatComesNext.nextActions.isEmpty {
            parts.append("next: " + summary.whatComesNext.nextActions.joined(separator: ", "))
        }

        let detail = parts.isEmpty ? "no notable content" : parts.joined(separator: "; ")
        return "  - \(dateFormatter.string(from: summary.startedAt)) (\(modeLabel)): \(detail)"
    }

    private func formatProjectStructure(_ data: ProjectData) -> String? {
        guard !data.phases.isEmpty else { return nil }

        let tasksByMilestone = Dictionary(grouping: data.tasks, by: \.milestoneId)
        let milestonesForPhase = Dictionary(grouping: data.milestones, by: \.phaseId)

        var lines: [String] = ["CURRENT STRUCTURE:"]

        for phase in data.phases {
            lines.append("PHASE: \(phase.name) (\(phase.status.rawValue))")
            let phaseMilestones = milestonesForPhase[phase.id] ?? []
            for ms in phaseMilestones {
                var msLine = "  MILESTONE: \(ms.name) (\(ms.status.rawValue))"
                if let deadline = ms.deadline {
                    msLine += " due: \(dateFormatter.string(from: deadline))"
                }
                lines.append(msLine)

                let msTasks = tasksByMilestone[ms.id] ?? []
                for task in msTasks {
                    var taskLine = "    TASK: \(task.name) (\(task.status.rawValue))"
                    if task.priority == .high { taskLine += " [HIGH]" }
                    if let effort = task.effortType { taskLine += " [\(effort.rawValue)]" }
                    if let blocked = task.blockedType {
                        taskLine += " [BLOCKED: \(blocked.rawValue)]"
                    }
                    if task.timesDeferred > 0 {
                        taskLine += " [deferred \(task.timesDeferred)x]"
                    }
                    lines.append(taskLine)

                    if let subtasks = data.subtasksByTaskId[task.id] {
                        for subtask in subtasks {
                            let check = subtask.isCompleted ? "x" : " "
                            lines.append("      [\(check)] \(subtask.name)")
                        }
                    }
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private func formatFrequentlyDeferred(_ tasks: [PMTask]) -> String? {
        guard !tasks.isEmpty else { return nil }

        var lines: [String] = ["FREQUENTLY DEFERRED:"]
        for task in tasks {
            lines.append("- \(task.name) (deferred \(task.timesDeferred)x)")
        }
        return lines.joined(separator: "\n")
    }

    private func formatEstimateCalibration(
        accuracy: Float?,
        multiplier: Float?,
        trend: (older: Float, newer: Float)?
    ) -> String? {
        guard let accuracy else { return nil }

        var lines: [String] = ["ESTIMATE CALIBRATION:"]
        lines.append("Average accuracy: \(String(format: "%.0f", accuracy * 100))% (actual vs estimated)")
        if let multiplier {
            lines.append("Suggested multiplier: \(String(format: "%.1f", multiplier))x")
        }
        if let trend {
            let direction = trend.newer >= trend.older ? "improving" : "declining"
            lines.append("Trend: \(direction) (\(String(format: "%.0f", trend.older * 100))% → \(String(format: "%.0f", trend.newer * 100))%)")
        }
        return lines.joined(separator: "\n")
    }

    private func formatPatterns(_ patterns: CrossSessionPatterns) -> String? {
        var lines: [String] = []

        if let days = patterns.daysSinceLastSession {
            lines.append("Days since last session: \(days)")
        }
        if let avg = patterns.averageSessionGap {
            lines.append("Average session gap: \(String(format: "%.1f", avg)) days")
        }
        if patterns.completedSessionCount > 0 {
            lines.append("Total completed sessions: \(patterns.completedSessionCount)")
        }
        if let trend = patterns.engagementTrend {
            lines.append("Engagement trend: \(trend.rawValue)")
        }
        if patterns.isReturn {
            lines.append("Note: User is returning after an extended break.")
        }
        if patterns.deferralCount > 0 {
            lines.append("Tasks deferred 3+ times: \(patterns.deferralCount)")
        }

        guard !lines.isEmpty else { return nil }
        return "PATTERNS AND OBSERVATIONS:\n" + lines.joined(separator: "\n")
    }

    private func formatPortfolio(_ portfolio: PortfolioData?) -> String? {
        guard let portfolio, !portfolio.projects.isEmpty else { return nil }

        var lines: [String] = ["PORTFOLIO OVERVIEW:"]
        for proj in portfolio.projects {
            var projLine = "- \(proj.project.name) (\(proj.project.lifecycleState.rawValue))"
            projLine += " — \(proj.sessionCount) sessions"
            if let days = proj.daysSinceLastSession {
                projLine += ", last active \(days)d ago"
            }
            lines.append(projLine)

            if let summary = proj.latestSummary {
                if !summary.whatComesNext.nextActions.isEmpty {
                    lines.append("  Next: " + summary.whatComesNext.nextActions.first!)
                }
                if !summary.contentObserved.concerns.isEmpty {
                    lines.append("  Concern: " + summary.contentObserved.concerns.first!)
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}
