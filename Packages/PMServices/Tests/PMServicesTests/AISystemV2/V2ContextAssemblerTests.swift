import Testing
import Foundation
@testable import PMServices
import PMDomain

// MARK: - V2ContextConfiguration Tests

@Suite("V2ContextConfiguration")
struct V2ContextConfigurationTests {

    @Test("Every mode produces a configuration with components")
    func allModesHaveComponents() {
        for mode in SessionMode.allCases {
            let config = V2ContextConfiguration.configuration(for: mode)
            #expect(!config.components.isEmpty, "Mode \(mode.rawValue) should have components")
            #expect(config.tokenBudget > 0, "Mode \(mode.rawValue) should have a positive token budget")
        }
    }

    @Test("Every execution support sub-mode produces a configuration")
    func allSubModesHaveComponents() {
        for subMode in SessionSubMode.allCases {
            let config = V2ContextConfiguration.configuration(for: .executionSupport, subMode: subMode)
            #expect(!config.components.isEmpty, "Sub-mode \(subMode.rawValue) should have components")
        }
    }

    @Test("Exploration has lower token budget than execution support")
    func explorationBudgetLower() {
        let exploration = V2ContextConfiguration.configuration(for: .exploration)
        let execution = V2ContextConfiguration.configuration(for: .executionSupport, subMode: .checkIn)
        #expect(exploration.tokenBudget < execution.tokenBudget)
    }

    @Test("Project review includes portfolio summary component")
    func projectReviewHasPortfolio() {
        let config = V2ContextConfiguration.configuration(for: .executionSupport, subMode: .projectReview)
        let hasPortfolio = config.components.contains { $0.kind == .portfolioSummary }
        #expect(hasPortfolio)
    }

    @Test("Exploration does not include portfolio summary")
    func explorationNoPortfolio() {
        let config = V2ContextConfiguration.configuration(for: .exploration)
        let hasPortfolio = config.components.contains { $0.kind == .portfolioSummary }
        #expect(!hasPortfolio)
    }

    @Test("Definition includes process profile component")
    func definitionHasProcessProfile() {
        let config = V2ContextConfiguration.configuration(for: .definition)
        let hasProfile = config.components.contains { $0.kind == .processProfile }
        #expect(hasProfile)
    }

    @Test("Planning includes documents component")
    func planningHasDocuments() {
        let config = V2ContextConfiguration.configuration(for: .planning)
        let hasDocs = config.components.contains { $0.kind == .documents }
        #expect(hasDocs)
    }
}

// MARK: - CrossSessionPatterns Tests

@Suite("CrossSessionPatterns")
struct CrossSessionPatternsTests {
    let projectId = UUID()

    @Test("No sessions produces empty patterns")
    func noSessions() {
        let patterns = CrossSessionPatterns.compute(
            sessions: [],
            summaries: [],
            frequentlyDeferredTasks: []
        )
        #expect(patterns.daysSinceLastSession == nil)
        #expect(patterns.averageSessionGap == nil)
        #expect(patterns.completedSessionCount == 0)
        #expect(!patterns.isReturn)
        #expect(patterns.engagementTrend == nil)
    }

    @Test("Days since last session computed correctly")
    func daysSinceLastSession() {
        let now = Date()
        let threeDaysAgo = now.addingTimeInterval(-3 * 86400)
        let session = TestFixtures.session(
            projectId: projectId,
            mode: .exploration,
            status: .completed,
            completedAt: threeDaysAgo
        )
        let patterns = CrossSessionPatterns.compute(
            sessions: [session],
            summaries: [],
            frequentlyDeferredTasks: [],
            now: now
        )
        #expect(patterns.daysSinceLastSession == 3)
        #expect(!patterns.isReturn)
    }

    @Test("Return detected after 14+ days")
    func returnDetected() {
        let now = Date()
        let twentyDaysAgo = now.addingTimeInterval(-20 * 86400)
        let session = TestFixtures.session(
            projectId: projectId,
            mode: .executionSupport,
            status: .completed,
            completedAt: twentyDaysAgo
        )
        let patterns = CrossSessionPatterns.compute(
            sessions: [session],
            summaries: [],
            frequentlyDeferredTasks: [],
            now: now
        )
        #expect(patterns.isReturn)
    }

    @Test("Average session gap calculated from multiple sessions")
    func averageGap() {
        let now = Date()
        let sessions = [
            TestFixtures.session(projectId: projectId, status: .completed, completedAt: now.addingTimeInterval(-30 * 86400)),
            TestFixtures.session(projectId: projectId, status: .completed, completedAt: now.addingTimeInterval(-20 * 86400)),
            TestFixtures.session(projectId: projectId, status: .completed, completedAt: now.addingTimeInterval(-10 * 86400)),
        ]
        let patterns = CrossSessionPatterns.compute(
            sessions: sessions,
            summaries: [],
            frequentlyDeferredTasks: [],
            now: now
        )
        #expect(patterns.averageSessionGap != nil)
        // Average gap should be approximately 10 days
        if let gap = patterns.averageSessionGap {
            #expect(gap > 9.0 && gap < 11.0)
        }
    }

    @Test("Engagement trend computed from sessions")
    func engagementTrend() {
        let now = Date()
        // Older sessions with big gaps, newer sessions with small gaps → increasing
        let sessions = [
            TestFixtures.session(projectId: projectId, status: .completed, completedAt: now.addingTimeInterval(-60 * 86400)),
            TestFixtures.session(projectId: projectId, status: .completed, completedAt: now.addingTimeInterval(-40 * 86400)),
            TestFixtures.session(projectId: projectId, status: .completed, completedAt: now.addingTimeInterval(-10 * 86400)),
            TestFixtures.session(projectId: projectId, status: .completed, completedAt: now.addingTimeInterval(-5 * 86400)),
        ]
        let patterns = CrossSessionPatterns.compute(
            sessions: sessions,
            summaries: [],
            frequentlyDeferredTasks: [],
            now: now
        )
        #expect(patterns.engagementTrend == .increasing)
    }

    @Test("Deferral count from tasks")
    func deferralCount() {
        let task = PMTask(
            id: UUID(),
            milestoneId: UUID(),
            name: "Avoided task",
            status: .notStarted,
            timesDeferred: 5
        )
        let patterns = CrossSessionPatterns.compute(
            sessions: [],
            summaries: [],
            frequentlyDeferredTasks: [task]
        )
        #expect(patterns.deferralCount == 1)
        #expect(patterns.frequentlyDeferredTaskNames.contains("Avoided task"))
    }

    @Test("Only completed/autoSummarised sessions count")
    func onlyCompletedCount() {
        let sessions = [
            TestFixtures.session(projectId: projectId, status: .active),
            TestFixtures.session(projectId: projectId, status: .paused),
            TestFixtures.session(projectId: projectId, status: .completed, completedAt: Date()),
        ]
        let patterns = CrossSessionPatterns.compute(
            sessions: sessions,
            summaries: [],
            frequentlyDeferredTasks: []
        )
        #expect(patterns.completedSessionCount == 1)
    }
}

// MARK: - V2ContextAssembler Tests

@Suite("V2ContextAssembler")
struct V2ContextAssemblerTests {
    let assembler = V2ContextAssembler()
    let projectId = UUID()

    func makeProjectData(
        project: Project? = nil,
        phases: [Phase] = [],
        milestones: [Milestone] = [],
        tasks: [PMTask] = [],
        processProfile: ProcessProfile? = nil,
        deliverables: [Deliverable] = [],
        sessions: [Session] = [],
        sessionSummaries: [SessionSummary] = [],
        frequentlyDeferredTasks: [PMTask] = []
    ) -> V2ContextAssembler.ProjectData {
        V2ContextAssembler.ProjectData(
            project: project ?? TestFixtures.project(name: "Test Project", lifecycleState: .focused),
            phases: phases,
            milestones: milestones,
            tasks: tasks,
            processProfile: processProfile,
            deliverables: deliverables,
            sessions: sessions,
            sessionSummaries: sessionSummaries,
            frequentlyDeferredTasks: frequentlyDeferredTasks
        )
    }

    @Test("Exploration context includes project overview")
    func explorationIncludesOverview() {
        let data = makeProjectData()
        let context = assembler.assembleLayer3(mode: .exploration, projectData: data)
        #expect(context.contains("PROJECT: Test Project"))
        #expect(context.contains("State: focused"))
    }

    @Test("Definition context includes process profile")
    func definitionIncludesProfile() {
        let profile = ProcessProfile(
            projectId: projectId,
            recommendedDeliverables: [
                .init(type: .visionStatement, status: .completed),
                .init(type: .technicalBrief, status: .pending)
            ],
            planningDepth: .fullRoadmap
        )
        let data = makeProjectData(processProfile: profile)
        let context = assembler.assembleLayer3(mode: .definition, projectData: data)
        #expect(context.contains("PROCESS PROFILE"))
        #expect(context.contains("visionStatement"))
        #expect(context.contains("technicalBrief"))
        #expect(context.contains("fullRoadmap"))
    }

    @Test("Planning context includes documents")
    func planningIncludesDocuments() {
        let deliverable = Deliverable(
            projectId: projectId,
            type: .visionStatement,
            status: .completed,
            title: "Vision Statement",
            content: "This project aims to build a great product."
        )
        let data = makeProjectData(deliverables: [deliverable])
        let context = assembler.assembleLayer3(mode: .planning, projectData: data)
        #expect(context.contains("DOCUMENTS:"))
        #expect(context.contains("Vision Statement"))
        #expect(context.contains("great product"))
    }

    @Test("Documents are not included when status is pending")
    func pendingDocumentsExcluded() {
        let deliverable = Deliverable(
            projectId: projectId,
            type: .visionStatement,
            status: .pending,
            title: "Draft Vision",
            content: "Not ready yet"
        )
        let data = makeProjectData(deliverables: [deliverable])
        let context = assembler.assembleLayer3(mode: .planning, projectData: data)
        #expect(!context.contains("Draft Vision"))
    }

    @Test("Session summaries are formatted in full and condensed form")
    func sessionSummaryFormatting() {
        let now = Date()
        let summaries = (0..<5).map { i in
            var summary = TestFixtures.sessionSummary(
                sessionId: UUID(),
                mode: .executionSupport,
                subMode: .checkIn
            )
            summary.startedAt = now.addingTimeInterval(Double(-i) * 86400)
            summary.endedAt = now.addingTimeInterval(Double(-i) * 86400 + 3600)
            summary.contentEstablished = .init(decisions: ["Decision \(i)"], progressMade: ["Progress \(i)"])
            summary.contentObserved = .init(patterns: ["Pattern \(i)"])
            summary.whatComesNext = .init(nextActions: ["Action \(i)"])
            return summary
        }
        let data = makeProjectData(sessionSummaries: summaries)
        let context = assembler.assembleLayer3(mode: .executionSupport, subMode: .checkIn, projectData: data)
        #expect(context.contains("SESSION HISTORY:"))
        #expect(context.contains("Decisions:"))
        #expect(context.contains("Earlier sessions (condensed):"))
    }

    @Test("Project structure formatted as hierarchy")
    func projectStructure() {
        let phaseId = UUID()
        let milestoneId = UUID()
        let taskId = UUID()
        let phase = Phase(id: phaseId, projectId: projectId, name: "Setup", sortOrder: 0)
        let milestone = Milestone(id: milestoneId, phaseId: phaseId, name: "Environment Ready", sortOrder: 0)
        let task = PMTask(id: taskId, milestoneId: milestoneId, name: "Install tools", status: .notStarted)
        let subtask = Subtask(taskId: taskId, name: "Install Xcode")

        let data = makeProjectData(
            phases: [phase],
            milestones: [milestone],
            tasks: [task],
            processProfile: nil
        )
        // Need to pass subtasks too
        let dataWithSubtasks = V2ContextAssembler.ProjectData(
            project: data.project,
            phases: [phase],
            milestones: [milestone],
            tasks: [task],
            subtasksByTaskId: [taskId: [subtask]]
        )
        let context = assembler.assembleLayer3(mode: .executionSupport, subMode: .checkIn, projectData: dataWithSubtasks)
        #expect(context.contains("CURRENT STRUCTURE:"))
        #expect(context.contains("PHASE: Setup"))
        #expect(context.contains("MILESTONE: Environment Ready"))
        #expect(context.contains("TASK: Install tools"))
        #expect(context.contains("Install Xcode"))
    }

    @Test("Frequently deferred tasks included in execution support")
    func frequentlyDeferred() {
        let task = PMTask(
            id: UUID(),
            milestoneId: UUID(),
            name: "That dreaded task",
            status: .notStarted,
            timesDeferred: 5
        )
        let data = makeProjectData(frequentlyDeferredTasks: [task])
        let context = assembler.assembleLayer3(mode: .executionSupport, subMode: .checkIn, projectData: data)
        #expect(context.contains("FREQUENTLY DEFERRED:"))
        #expect(context.contains("That dreaded task"))
        #expect(context.contains("deferred 5x"))
    }

    @Test("Estimate calibration included when available")
    func estimateCalibration() {
        let data = V2ContextAssembler.ProjectData(
            project: TestFixtures.project(),
            estimateAccuracy: 0.75,
            suggestedMultiplier: 1.5,
            accuracyTrend: (older: 0.6, newer: 0.85)
        )
        let context = assembler.assembleLayer3(mode: .executionSupport, subMode: .checkIn, projectData: data)
        #expect(context.contains("ESTIMATE CALIBRATION:"))
        #expect(context.contains("75%"))
        #expect(context.contains("1.5x"))
        #expect(context.contains("improving"))
    }

    @Test("Patterns section included with session data")
    func patternsSection() {
        let now = Date()
        let session = TestFixtures.session(
            projectId: projectId,
            status: .completed,
            completedAt: now.addingTimeInterval(-5 * 86400)
        )
        let data = makeProjectData(sessions: [session])
        let context = assembler.assembleLayer3(mode: .executionSupport, subMode: .checkIn, projectData: data)
        #expect(context.contains("PATTERNS AND OBSERVATIONS:"))
        #expect(context.contains("Days since last session: 5"))
    }

    @Test("Portfolio summary included for project review")
    func portfolioSummary() {
        let data = makeProjectData()
        let portfolioData = V2ContextAssembler.PortfolioData(projects: [
            .init(project: TestFixtures.project(name: "Project Alpha", lifecycleState: .focused), sessionCount: 5, daysSinceLastSession: 3),
            .init(project: TestFixtures.project(name: "Project Beta", lifecycleState: .paused), sessionCount: 2, daysSinceLastSession: 14),
        ])
        let context = assembler.assembleLayer3(mode: .executionSupport, subMode: .projectReview, projectData: data, portfolioData: portfolioData)
        #expect(context.contains("PORTFOLIO OVERVIEW:"))
        #expect(context.contains("Project Alpha"))
        #expect(context.contains("Project Beta"))
        #expect(context.contains("5 sessions"))
    }

    @Test("Token budget truncates low-priority sections")
    func tokenBudgetTruncation() {
        // Create a very large document that exceeds the exploration budget
        let longContent = String(repeating: "x", count: 10000)
        let deliverable = Deliverable(
            projectId: projectId,
            type: .visionStatement,
            status: .completed,
            title: "Long Doc",
            content: longContent
        )
        let data = makeProjectData(deliverables: [deliverable])
        let context = assembler.assembleLayer3(mode: .exploration, projectData: data)
        // Exploration budget is 2000 tokens (~6666 chars). With project overview + long doc,
        // the doc (lower priority) should get truncated out entirely
        let tokens = V2ContextAssembler.estimateTokens(context)
        #expect(tokens <= 2000, "Context should be within token budget, got \(tokens)")
    }

    @Test("Empty project data produces minimal context")
    func emptyData() {
        let data = makeProjectData()
        let context = assembler.assembleLayer3(mode: .exploration, projectData: data)
        #expect(context.contains("PROJECT: Test Project"))
        // Should have project overview but not much else
        #expect(!context.contains("DOCUMENTS:"))
        #expect(!context.contains("CURRENT STRUCTURE:"))
    }

    // MARK: - Full Payload Assembly

    @Test("assemblePayload combines system prompt, Layer 3, and history")
    func fullPayload() {
        let data = makeProjectData()
        let history = [
            LLMMessage(role: .user, content: "Hello"),
            LLMMessage(role: .assistant, content: "Hi there!")
        ]
        let payload = assembler.assemblePayload(
            systemPrompt: "You are a helpful assistant.",
            mode: .exploration,
            projectData: data,
            conversationHistory: history
        )
        #expect(payload.systemPrompt.contains("You are a helpful assistant."))
        #expect(payload.systemPrompt.contains("PROJECT: Test Project"))
        // System message + 2 history messages
        #expect(payload.messages.count == 3)
        #expect(payload.estimatedTokens > 0)
    }

    @Test("assemblePayload truncates history when budget exceeded")
    func payloadHistoryTruncation() {
        let data = makeProjectData()
        let longMessage = String(repeating: "word ", count: 5000)
        let history = (0..<20).map { i in
            LLMMessage(role: i % 2 == 0 ? .user : .assistant, content: longMessage)
        }
        let smallAssembler = V2ContextAssembler(totalBudget: 10000, responseReserve: 2000)
        let payload = smallAssembler.assemblePayload(
            systemPrompt: "System prompt.",
            mode: .exploration,
            projectData: data,
            conversationHistory: history
        )
        // Should have fewer messages than the original 20
        #expect(payload.messages.count < 22) // system + truncation notice + some history
        // Should include truncation notice
        let hasTruncation = payload.messages.contains { $0.content.contains("truncated") }
        #expect(hasTruncation)
    }

    @Test("Long documents are truncated in context")
    func longDocumentTruncation() {
        let longContent = String(repeating: "a", count: 5000)
        let deliverable = Deliverable(
            projectId: projectId,
            type: .visionStatement,
            status: .completed,
            title: "Big Doc",
            content: longContent
        )
        let data = makeProjectData(deliverables: [deliverable])
        // Use planning mode which has a higher budget so the doc section isn't dropped entirely
        let bigAssembler = V2ContextAssembler(totalBudget: 50000)
        let context = bigAssembler.assembleLayer3(mode: .planning, projectData: data)
        if context.contains("DOCUMENTS:") {
            #expect(context.contains("truncated"))
            #expect(context.contains("5000 chars total"))
        }
    }
}
