import Testing
import Foundation
@testable import PMServices
import PMDomain

@Suite("ResponseSignalParser")
struct ResponseSignalParserTests {
    let parser = ResponseSignalParser()

    // MARK: - No Signals

    @Test("Plain text returns unchanged")
    func plainText() {
        let result = parser.parse("Hello, let's talk about your project.")
        #expect(result.naturalLanguage == "Hello, let's talk about your project.")
        #expect(result.signals.isEmpty)
        #expect(result.actions.isEmpty)
    }

    // MARK: - Line Signals

    @Test("MODE_COMPLETE signal extracted")
    func modeComplete() {
        let result = parser.parse("Great work!\n\n[MODE_COMPLETE: exploration]")
        #expect(result.naturalLanguage == "Great work!")
        #expect(result.signals.count == 1)
        if case .modeComplete(let mode) = result.signals.first {
            #expect(mode == "exploration")
        } else {
            Issue.record("Expected modeComplete signal")
        }
    }

    @Test("PROCESS_RECOMMENDATION signal extracted")
    func processRecommendation() {
        let result = parser.parse("I recommend:\n[PROCESS_RECOMMENDATION: visionStatement, technicalBrief]")
        #expect(result.signals.count == 1)
        if case .processRecommendation(let deliverables) = result.signals.first {
            #expect(deliverables.contains("visionStatement"))
            #expect(deliverables.contains("technicalBrief"))
        } else {
            Issue.record("Expected processRecommendation signal")
        }
    }

    @Test("PLANNING_DEPTH signal extracted")
    func planningDepth() {
        let result = parser.parse("[PLANNING_DEPTH: fullRoadmap]")
        if case .planningDepth(let depth) = result.signals.first {
            #expect(depth == "fullRoadmap")
        } else {
            Issue.record("Expected planningDepth signal")
        }
    }

    @Test("PROJECT_SUMMARY signal extracted")
    func projectSummary() {
        let result = parser.parse("[PROJECT_SUMMARY: A task management app for personal projects]")
        if case .projectSummary(let summary) = result.signals.first {
            #expect(summary.contains("task management"))
        } else {
            Issue.record("Expected projectSummary signal")
        }
    }

    @Test("DELIVERABLES_PRODUCED signal extracted")
    func deliverablesProduced() {
        let result = parser.parse("[DELIVERABLES_PRODUCED: visionStatement, technicalBrief]")
        if case .deliverablesProduced(let types) = result.signals.first {
            #expect(types.contains("visionStatement"))
        } else {
            Issue.record("Expected deliverablesProduced signal")
        }
    }

    @Test("DELIVERABLES_DEFERRED signal extracted")
    func deliverablesDeferred() {
        let result = parser.parse("[DELIVERABLES_DEFERRED: researchPlan]")
        if case .deliverablesDeferred(let types) = result.signals.first {
            #expect(types == "researchPlan")
        } else {
            Issue.record("Expected deliverablesDeferred signal")
        }
    }

    @Test("STRUCTURE_SUMMARY signal extracted")
    func structureSummary() {
        let result = parser.parse("[STRUCTURE_SUMMARY: 3 phases, 8 milestones, 24 tasks]")
        if case .structureSummary(let summary) = result.signals.first {
            #expect(summary.contains("3 phases"))
        } else {
            Issue.record("Expected structureSummary signal")
        }
    }

    @Test("FIRST_ACTION signal extracted")
    func firstAction() {
        let result = parser.parse("[FIRST_ACTION: Set up the development environment]")
        if case .firstAction(let action) = result.signals.first {
            #expect(action.contains("development environment"))
        } else {
            Issue.record("Expected firstAction signal")
        }
    }

    @Test("SESSION_END signal extracted")
    func sessionEnd() {
        let result = parser.parse("Good session!\n\n[SESSION_END]")
        #expect(result.naturalLanguage == "Good session!")
        #expect(result.signals.contains(.sessionEnd))
    }

    // MARK: - Block Signals

    @Test("DOCUMENT_DRAFT block extracted")
    func documentDraft() {
        let response = """
        Here's a draft for your vision statement:

        [DOCUMENT_DRAFT: visionStatement]
        # Vision Statement

        This project aims to create a powerful task manager.
        [/DOCUMENT_DRAFT]

        Let me know what you think.
        """
        let result = parser.parse(response)
        #expect(result.naturalLanguage.contains("Here's a draft"))
        #expect(result.naturalLanguage.contains("Let me know"))
        #expect(!result.naturalLanguage.contains("# Vision Statement"))

        let draftSignals = result.signals.filter {
            if case .documentDraft = $0 { return true }
            return false
        }
        #expect(draftSignals.count == 1)
        if case .documentDraft(let type, let content) = draftSignals.first {
            #expect(type == "visionStatement")
            #expect(content.contains("# Vision Statement"))
            #expect(content.contains("powerful task manager"))
        }
    }

    @Test("STRUCTURE_PROPOSAL block extracted")
    func structureProposal() {
        let response = """
        I'd suggest this structure:

        [STRUCTURE_PROPOSAL]
        Phase 1: Foundation
          Milestone 1.1: Environment Setup
            Task: Install development tools
            Task: Set up project repository
        Phase 2: Core Features
          Milestone 2.1: Data Model
        [/STRUCTURE_PROPOSAL]

        What do you think?
        """
        let result = parser.parse(response)
        #expect(result.naturalLanguage.contains("I'd suggest"))
        #expect(result.naturalLanguage.contains("What do you think?"))

        let proposalSignals = result.signals.filter {
            if case .structureProposal = $0 { return true }
            return false
        }
        #expect(proposalSignals.count == 1)
        if case .structureProposal(let content) = proposalSignals.first {
            #expect(content.contains("Phase 1: Foundation"))
            #expect(content.contains("Install development tools"))
        }
    }

    // MARK: - Multiple Signals

    @Test("Multiple signals extracted from one response")
    func multipleSignals() {
        let response = """
        I think we've covered everything for exploration.

        [MODE_COMPLETE: exploration]
        [PROCESS_RECOMMENDATION: visionStatement, technicalBrief]
        [PLANNING_DEPTH: fullRoadmap]
        [PROJECT_SUMMARY: A personal task management app designed for ADHD users]
        """
        let result = parser.parse(response)
        #expect(result.signals.count == 4)
        #expect(result.naturalLanguage.contains("covered everything"))
    }

    // MARK: - Action Parsing Integration

    @Test("Actions parsed when enabled")
    func actionsWithSignals() {
        let response = """
        I'll create that for you.

        [ACTION: CREATE_TASK] milestoneId: \(UUID().uuidString), name: "New Task", priority: normal [/ACTION]

        [SESSION_END]
        """
        let result = parser.parse(response, parseActions: true)
        #expect(result.signals.contains(.sessionEnd))
        #expect(!result.actions.isEmpty)
        #expect(result.naturalLanguage.contains("I'll create that"))
    }

    @Test("Actions not parsed when disabled")
    func actionsIgnoredWhenDisabled() {
        let response = """
        Some text.

        [ACTION: CREATE_TASK] milestoneId: \(UUID().uuidString), name: "Task" [/ACTION]
        """
        let result = parser.parse(response, parseActions: false)
        #expect(result.actions.isEmpty)
        // The action block text remains in natural language since we didn't parse it
        #expect(result.naturalLanguage.contains("ACTION"))
    }

    // MARK: - Edge Cases

    @Test("Malformed signal is ignored")
    func malformedSignal() {
        let result = parser.parse("Hello [MODE_COMPLETE] without colon")
        // [MODE_COMPLETE] without colon/value should be ignored (our pattern requires ": value")
        #expect(result.signals.isEmpty)
        #expect(result.naturalLanguage.contains("MODE_COMPLETE"))
    }

    @Test("Empty response returns empty result")
    func emptyResponse() {
        let result = parser.parse("")
        #expect(result.naturalLanguage.isEmpty)
        #expect(result.signals.isEmpty)
    }

    @Test("DOCUMENT_DRAFT without type still parsed")
    func documentDraftNoType() {
        let response = "[DOCUMENT_DRAFT]Some content[/DOCUMENT_DRAFT]"
        let result = parser.parse(response)
        if case .documentDraft(let type, _) = result.signals.first {
            #expect(type == "unknown")
        } else {
            Issue.record("Expected documentDraft signal")
        }
    }
}

// MARK: - ModeConfiguration Tests

@Suite("ModeConfigurationRegistry")
struct ModeConfigurationRegistryTests {

    @Test("Every mode has a configuration")
    func allModesHaveConfig() {
        for mode in SessionMode.allCases {
            let config = ModeConfigurationRegistry.configuration(for: mode)
            #expect(config.mode == mode)
        }
    }

    @Test("Every sub-mode has a configuration")
    func allSubModesHaveConfig() {
        for subMode in SessionSubMode.allCases {
            let config = ModeConfigurationRegistry.configuration(for: .executionSupport, subMode: subMode)
            #expect(config.mode == .executionSupport)
            #expect(config.subMode == subMode)
        }
    }

    @Test("Exploration does not parse actions")
    func explorationNoActions() {
        let config = ModeConfigurationRegistry.configuration(for: .exploration)
        #expect(!config.parseActions)
    }

    @Test("Planning parses actions and supports artifacts")
    func planningConfig() {
        let config = ModeConfigurationRegistry.configuration(for: .planning)
        #expect(config.parseActions)
        #expect(config.supportsArtifacts)
    }

    @Test("Definition supports artifacts but not actions")
    func definitionConfig() {
        let config = ModeConfigurationRegistry.configuration(for: .definition)
        #expect(!config.parseActions)
        #expect(config.supportsArtifacts)
    }

    @Test("Check-in parses actions")
    func checkInConfig() {
        let config = ModeConfigurationRegistry.configuration(for: .executionSupport, subMode: .checkIn)
        #expect(config.parseActions)
    }

    @Test("Retrospective does not parse actions")
    func retrospectiveConfig() {
        let config = ModeConfigurationRegistry.configuration(for: .executionSupport, subMode: .retrospective)
        #expect(!config.parseActions)
    }

    @Test("Exploration expects MODE_COMPLETE and PROCESS_RECOMMENDATION signals")
    func explorationExpectedSignals() {
        let config = ModeConfigurationRegistry.configuration(for: .exploration)
        #expect(config.expectedSignals.contains("MODE_COMPLETE"))
        #expect(config.expectedSignals.contains("PROCESS_RECOMMENDATION"))
    }

    @Test("Execution support expects SESSION_END signal")
    func executionSupportExpectedSignals() {
        for subMode in SessionSubMode.allCases {
            let config = ModeConfigurationRegistry.configuration(for: .executionSupport, subMode: subMode)
            #expect(config.expectedSignals.contains("SESSION_END"))
        }
    }
}
