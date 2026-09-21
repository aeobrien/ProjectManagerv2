import Testing
import Foundation
@testable import PMServices
import PMDomain

@Suite("PromptComposer")
struct PromptComposerTests {
    let composer = PromptComposer(store: V2PromptTemplateStore(defaults: UserDefaults(suiteName: "test.promptComposer")!))

    // MARK: - Composition

    @Test("Composed prompt includes Layer 1 foundation")
    func includesFoundation() {
        let prompt = composer.compose(mode: .exploration)
        #expect(prompt.contains("collaborative thinking partner"))
        #expect(prompt.contains("ADHD"))
        #expect(prompt.contains("Challenge network"))
    }

    @Test("Composed prompt includes Layer 2 for exploration")
    func includesExplorationLayer2() {
        let prompt = composer.compose(mode: .exploration)
        #expect(prompt.contains("Exploration mode"))
        #expect(prompt.contains("CLARIFYING"))
        #expect(prompt.contains("PROCESS_RECOMMENDATION"))
    }

    @Test("Composed prompt includes Layer 2 for definition")
    func includesDefinitionLayer2() {
        let prompt = composer.compose(mode: .definition)
        #expect(prompt.contains("Definition mode"))
        #expect(prompt.contains("CONSTRUCTIVELY CRITICAL"))
        #expect(prompt.contains("DOCUMENT_DRAFT"))
    }

    @Test("Composed prompt includes Layer 2 for planning")
    func includesPlanningLayer2() {
        let prompt = composer.compose(mode: .planning)
        #expect(prompt.contains("Planning mode"))
        #expect(prompt.contains("PRACTICAL AND SPECIFIC"))
        #expect(prompt.contains("STRUCTURE_PROPOSAL"))
    }

    @Test("Composed prompt includes Layer 2 for execution support")
    func includesExecutionSupportLayer2() {
        let prompt = composer.compose(mode: .executionSupport)
        #expect(prompt.contains("Execution Support mode"))
        #expect(prompt.contains("SESSION_END"))
    }

    // MARK: - Sub-Mode

    @Test("Execution support with check-in sub-mode includes sub-mode guidance")
    func checkInSubMode() {
        let prompt = composer.compose(mode: .executionSupport, subMode: .checkIn)
        #expect(prompt.contains("Check-in"))
        #expect(prompt.contains("HONEST AND SUPPORTIVE"))
    }

    @Test("Execution support with return briefing sub-mode")
    func returnBriefingSubMode() {
        let prompt = composer.compose(mode: .executionSupport, subMode: .returnBriefing)
        #expect(prompt.contains("Return Briefing"))
        #expect(prompt.contains("WELCOMING"))
    }

    @Test("Execution support with project review sub-mode")
    func projectReviewSubMode() {
        let prompt = composer.compose(mode: .executionSupport, subMode: .projectReview)
        #expect(prompt.contains("Project Review"))
        #expect(prompt.contains("ANALYTICAL"))
    }

    @Test("Execution support with retrospective sub-mode")
    func retrospectiveSubMode() {
        let prompt = composer.compose(mode: .executionSupport, subMode: .retrospective)
        #expect(prompt.contains("Retrospective"))
        #expect(prompt.contains("REFLECTIVE"))
    }

    // MARK: - Variable Substitution

    @Test("Variables are substituted in exploration prompt")
    func explorationVariableSubstitution() {
        let prompt = composer.compose(
            mode: .exploration,
            variables: ["deliverable_catalogue": "visionStatement, technicalBrief"]
        )
        #expect(prompt.contains("visionStatement, technicalBrief"))
        #expect(!prompt.contains("{{deliverable_catalogue}}"))
    }

    @Test("Variables are substituted in definition prompt")
    func definitionVariableSubstitution() {
        let prompt = composer.compose(
            mode: .definition,
            variables: [
                "deliverable_list": "Vision Statement, Technical Brief",
                "current_deliverable": "Vision Statement",
                "deliverable_template_info_requirements": "1. Core intent\n2. Motivation",
                "deliverable_template_structure": "**Intent** — What this project is."
            ]
        )
        #expect(prompt.contains("Vision Statement, Technical Brief"))
        #expect(prompt.contains("1. Core intent"))
        #expect(!prompt.contains("{{deliverable_list}}"))
    }

    @Test("Variables are substituted in execution support prompt")
    func executionSupportVariableSubstitution() {
        let prompt = composer.compose(
            mode: .executionSupport,
            subMode: .checkIn,
            variables: ["sub_mode": "check_in"]
        )
        #expect(prompt.contains("check_in"))
        #expect(!prompt.contains("{{sub_mode}}"))
    }

    // MARK: - Layer 2 Isolation

    @Test("layer2Prompt returns only the mode prompt without foundation")
    func layer2Isolation() {
        let layer2 = composer.layer2Prompt(mode: .exploration)
        #expect(layer2.contains("Exploration mode"))
        #expect(!layer2.contains("collaborative thinking partner"))
    }

    // MARK: - Summary Prompt

    @Test("Summary prompt is available")
    func summaryPrompt() {
        let prompt = composer.summaryPrompt()
        #expect(prompt.contains("structured session summary"))
        #expect(prompt.contains("contentEstablished"))
        #expect(prompt.contains("contentObserved"))
        #expect(prompt.contains("whatComesNext"))
    }

    // MARK: - All Modes Produce Non-Empty Prompts

    @Test("Every mode produces a non-empty composed prompt")
    func allModesNonEmpty() {
        for mode in SessionMode.allCases {
            let prompt = composer.compose(mode: mode)
            #expect(!prompt.isEmpty, "Prompt for mode \(mode.rawValue) should not be empty")
            #expect(prompt.count > 500, "Prompt for mode \(mode.rawValue) should be substantial")
        }
    }

    @Test("Every sub-mode produces a non-empty composed prompt")
    func allSubModesNonEmpty() {
        for subMode in SessionSubMode.allCases {
            let prompt = composer.compose(mode: .executionSupport, subMode: subMode)
            #expect(!prompt.isEmpty, "Prompt for sub-mode \(subMode.rawValue) should not be empty")
        }
    }
}

@Suite("V2PromptTemplateStore")
struct V2PromptTemplateStoreTests {
    let suiteName = "test.v2PromptStore.\(UUID().uuidString)"

    func makeStore() -> V2PromptTemplateStore {
        V2PromptTemplateStore(defaults: UserDefaults(suiteName: suiteName)!)
    }

    @Test("Returns default template when no override")
    func defaultTemplate() {
        let store = makeStore()
        let template = store.template(for: .foundation)
        #expect(template.contains("collaborative thinking partner"))
    }

    @Test("Override replaces default")
    func overrideReplaces() {
        let store = makeStore()
        store.setOverride("Custom foundation", for: .foundation)
        #expect(store.template(for: .foundation) == "Custom foundation")
    }

    @Test("Reset reverts to default")
    func resetReverts() {
        let store = makeStore()
        store.setOverride("Custom", for: .foundation)
        store.resetToDefault(for: .foundation)
        #expect(store.template(for: .foundation).contains("collaborative thinking partner"))
    }

    @Test("hasOverride reports correctly")
    func hasOverride() {
        let store = makeStore()
        #expect(!store.hasOverride(for: .exploration))
        store.setOverride("Custom", for: .exploration)
        #expect(store.hasOverride(for: .exploration))
    }

    @Test("Render substitutes variables")
    func renderVariables() {
        let store = makeStore()
        store.setOverride("Hello {{name}}, mode is {{mode}}", for: .foundation)
        let result = store.render(.foundation, variables: ["name": "User", "mode": "test"])
        #expect(result == "Hello User, mode is test")
    }

    @Test("All keys have non-empty defaults")
    func allKeysHaveDefaults() {
        for key in V2PromptTemplateKey.allCases {
            let template = V2PromptDefaults.defaultTemplate(for: key)
            #expect(!template.isEmpty, "Default for \(key.rawValue) should not be empty")
        }
    }
}
