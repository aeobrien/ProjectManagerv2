import Testing
import Foundation
@testable import PMDomain

@Suite("SessionSummary")
struct SessionSummaryTests {

    // MARK: - Codable Round-Trip

    @Test("Full summary encodes and decodes correctly")
    func codableRoundTrip() throws {
        let sessionId = UUID()
        let summary = SessionSummary(
            sessionId: sessionId,
            mode: .exploration,
            subMode: .checkIn,
            completionStatus: .completed,
            deliverableType: "visionStatement",
            contentEstablished: .init(
                decisions: ["Use SwiftUI", "Target macOS 14+"],
                factsLearned: ["Project scope is medium"],
                progressMade: ["Defined core architecture"]
            ),
            contentObserved: .init(
                patterns: ["User prefers iterative approach"],
                concerns: ["Timeline might be tight"],
                strengths: ["Clear vision"]
            ),
            whatComesNext: .init(
                nextActions: ["Create technical brief", "Set up repo"],
                openQuestions: ["Which CI provider?"],
                suggestedMode: "definition"
            ),
            modeSpecific: .exploration(.init(
                projectSummary: "A project management app",
                recommendedDeliverables: ["visionStatement", "technicalBrief"],
                suggestedPlanningDepth: "fullRoadmap"
            )),
            startedAt: Date(timeIntervalSince1970: 1000),
            endedAt: Date(timeIntervalSince1970: 2000),
            duration: 1000,
            messageCount: 12,
            inputTokens: 5000,
            outputTokens: 3000
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(summary)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SessionSummary.self, from: data)

        #expect(decoded == summary)
        #expect(decoded.sessionId == sessionId)
        #expect(decoded.mode == .exploration)
        #expect(decoded.subMode == .checkIn)
        #expect(decoded.completionStatus == .completed)
        #expect(decoded.contentEstablished.decisions.count == 2)
        #expect(decoded.contentObserved.patterns.first == "User prefers iterative approach")
        #expect(decoded.whatComesNext.suggestedMode == "definition")
        #expect(decoded.duration == 1000)
        #expect(decoded.inputTokens == 5000)
    }

    // MARK: - ModeSpecificData Variants

    @Test("ExplorationData round-trip")
    func explorationDataCodable() throws {
        let data = SessionSummary.ModeSpecificData.exploration(.init(
            projectSummary: "Test",
            recommendedDeliverables: ["brief"],
            suggestedPlanningDepth: "taskList"
        ))
        let encoded = try JSONEncoder().encode(data)
        let decoded = try JSONDecoder().decode(SessionSummary.ModeSpecificData.self, from: encoded)
        #expect(decoded == data)
    }

    @Test("DefinitionData round-trip")
    func definitionDataCodable() throws {
        let data = SessionSummary.ModeSpecificData.definition(.init(
            deliverableType: "technicalBrief",
            deliverableStatus: "completed",
            revisionsCount: 3
        ))
        let encoded = try JSONEncoder().encode(data)
        let decoded = try JSONDecoder().decode(SessionSummary.ModeSpecificData.self, from: encoded)
        #expect(decoded == data)
    }

    @Test("PlanningData round-trip")
    func planningDataCodable() throws {
        let data = SessionSummary.ModeSpecificData.planning(.init(
            structureSummary: "Three phases",
            firstAction: "Set up the repo",
            phasesCreated: 3
        ))
        let encoded = try JSONEncoder().encode(data)
        let decoded = try JSONDecoder().decode(SessionSummary.ModeSpecificData.self, from: encoded)
        #expect(decoded == data)
    }

    @Test("ExecutionSupportData round-trip")
    func executionSupportDataCodable() throws {
        let data = SessionSummary.ModeSpecificData.executionSupport(.init(
            tasksCompleted: ["Task A"],
            tasksDeferred: ["Task B"],
            issuesFlagged: ["Blocker X"]
        ))
        let encoded = try JSONEncoder().encode(data)
        let decoded = try JSONDecoder().decode(SessionSummary.ModeSpecificData.self, from: encoded)
        #expect(decoded == data)
    }

    // MARK: - Default Initializers

    @Test("Default sections have empty arrays")
    func defaultSectionsEmpty() {
        let summary = SessionSummary(
            sessionId: UUID(),
            mode: .planning,
            completionStatus: .completed
        )
        #expect(summary.contentEstablished.decisions.isEmpty)
        #expect(summary.contentEstablished.factsLearned.isEmpty)
        #expect(summary.contentEstablished.progressMade.isEmpty)
        #expect(summary.contentObserved.patterns.isEmpty)
        #expect(summary.contentObserved.concerns.isEmpty)
        #expect(summary.contentObserved.strengths.isEmpty)
        #expect(summary.whatComesNext.nextActions.isEmpty)
        #expect(summary.whatComesNext.openQuestions.isEmpty)
        #expect(summary.whatComesNext.suggestedMode == nil)
        #expect(summary.modeSpecific == nil)
    }

    @Test("Summary without optional fields round-trips")
    func minimalSummaryRoundTrip() throws {
        let summary = SessionSummary(
            sessionId: UUID(),
            mode: .executionSupport,
            subMode: .retrospective,
            completionStatus: .incompleteAutoSummarised
        )
        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(SessionSummary.self, from: data)
        #expect(decoded == summary)
        #expect(decoded.modeSpecific == nil)
        #expect(decoded.deliverableType == nil)
        #expect(decoded.inputTokens == nil)
    }
}
