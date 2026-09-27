import Testing
import Foundation
@testable import PMServices
import PMDomain

@Suite("AI System V2 — Smoke Tests")
struct AISystemV2SmokeTests {

    @Test("V2 namespace exists with version string")
    func namespaceVersion() {
        #expect(!AISystemV2.version.isEmpty)
        #expect(AISystemV2.version == "0.1.0")
    }

    // MARK: - MockV2LLMClient

    @Test("Mock returns queued responses in order")
    func queuedResponses() async throws {
        let mock = MockV2LLMClient()
        mock.queuedResponses = [
            LLMResponse(content: "First"),
            LLMResponse(content: "Second"),
            LLMResponse(content: "Third"),
        ]

        let config = LLMRequestConfig()

        let r1 = try await mock.send(messages: [LLMMessage(role: .user, content: "a")], config: config)
        let r2 = try await mock.send(messages: [LLMMessage(role: .user, content: "b")], config: config)
        let r3 = try await mock.send(messages: [LLMMessage(role: .user, content: "c")], config: config)

        #expect(r1.content == "First")
        #expect(r2.content == "Second")
        #expect(r3.content == "Third")
    }

    @Test("Mock falls back to default when queue exhausted")
    func defaultFallback() async throws {
        let mock = MockV2LLMClient()
        mock.queuedResponses = [LLMResponse(content: "Only one")]
        mock.defaultResponse = LLMResponse(content: "Fallback")

        let config = LLMRequestConfig()
        let msg = [LLMMessage(role: .user, content: "hi")]

        _ = try await mock.send(messages: msg, config: config)
        let r2 = try await mock.send(messages: msg, config: config)

        #expect(r2.content == "Fallback")
    }

    @Test("Mock tracks sent messages and configs")
    func callTracking() async throws {
        let mock = MockV2LLMClient()
        let config = LLMRequestConfig()

        let messages = [
            LLMMessage(role: .system, content: "You are a helper."),
            LLMMessage(role: .user, content: "Hello"),
        ]

        _ = try await mock.send(messages: messages, config: config)

        #expect(mock.callCount == 1)
        #expect(mock.lastSystemPrompt == "You are a helper.")
        #expect(mock.lastUserMessage == "Hello")
        #expect(mock.sentConfigs.count == 1)
    }

    @Test("Mock throws one-shot error then recovers")
    func oneShotError() async throws {
        let mock = MockV2LLMClient()
        mock.oneShotError = LLMError.rateLimited
        mock.defaultResponse = LLMResponse(content: "Recovered")

        let config = LLMRequestConfig()
        let msg = [LLMMessage(role: .user, content: "test")]

        do {
            _ = try await mock.send(messages: msg, config: config)
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error is LLMError)
        }

        let recovered = try await mock.send(messages: msg, config: config)
        #expect(recovered.content == "Recovered")
        #expect(mock.callCount == 2)
    }

    // MARK: - MockV2Responses

    @Test("Response builders produce correct signal content")
    func responseBuilders() {
        let plain = MockV2Responses.plain("Hi")
        #expect(plain.content == "Hi")

        let modeComplete = MockV2Responses.modeComplete()
        #expect(modeComplete.content.contains("[SIGNAL:MODE_COMPLETE]"))

        let docDraft = MockV2Responses.documentDraft(title: "Brief", body: "Content")
        #expect(docDraft.content.contains("[SIGNAL:DOCUMENT_DRAFT]"))
        #expect(docDraft.content.contains("title: Brief"))
        #expect(docDraft.content.contains("Content"))

        let structure = MockV2Responses.structureProposal(phases: ["Alpha", "Beta"])
        #expect(structure.content.contains("[SIGNAL:STRUCTURE_PROPOSAL]"))
        #expect(structure.content.contains("- Alpha"))
        #expect(structure.content.contains("- Beta"))

        let actions = MockV2Responses.withActions("Done", actions: "[ACTION:CREATE_TASK]")
        #expect(actions.content.contains("[ACTION:CREATE_TASK]"))

        let combined = MockV2Responses.combined(text: "Here", signals: ["[SIGNAL:A]", "[SIGNAL:B]"])
        #expect(combined.content.contains("[SIGNAL:A]"))
        #expect(combined.content.contains("[SIGNAL:B]"))
    }

    // MARK: - TestFixtures

    @Test("TestFixtures creates valid Project with defaults")
    func projectFixture() {
        let project = TestFixtures.project()
        #expect(!project.name.isEmpty)
        #expect(project.lifecycleState == .idea)
        #expect(project.focusSlotIndex == nil)
    }

    @Test("TestFixtures creates Project with custom values")
    func projectFixtureCustom() {
        let id = UUID()
        let catId = UUID()
        let project = TestFixtures.project(
            id: id,
            name: "Custom",
            categoryId: catId,
            lifecycleState: .focused,
            focusSlotIndex: 2,
            definitionOfDone: "Ship it",
            notes: "Important"
        )
        #expect(project.id == id)
        #expect(project.name == "Custom")
        #expect(project.categoryId == catId)
        #expect(project.lifecycleState == .focused)
        #expect(project.focusSlotIndex == 2)
        #expect(project.definitionOfDone == "Ship it")
        #expect(project.notes == "Important")
    }
}
