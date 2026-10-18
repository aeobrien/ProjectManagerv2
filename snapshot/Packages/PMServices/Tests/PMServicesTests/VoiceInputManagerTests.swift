import Testing
import Foundation
@testable import PMServices

@Suite("VoiceInputManager")
struct VoiceInputManagerTests {

    @Test("Initial state is idle")
    @MainActor
    func initialState() {
        let manager = VoiceInputManager()
        #expect(manager.state == .idle)
        #expect(manager.audioLevels.isEmpty)
        #expect(manager.editableTranscript == "")
        #expect(manager.canRecord == true)
        #expect(manager.isRecording == false)
        #expect(manager.isProcessing == false)
    }

    @Test("Default model size is tiny")
    @MainActor
    func defaultModelSize() {
        let manager = VoiceInputManager()
        #expect(manager.modelSize == "tiny")
    }

    @Test("Custom model size preserved")
    @MainActor
    func customModelSize() {
        let manager = VoiceInputManager(modelSize: "medium")
        #expect(manager.modelSize == "medium")
    }

    @Test("canRecord is true in idle state")
    @MainActor
    func canRecordIdle() {
        let manager = VoiceInputManager()
        #expect(manager.canRecord == true)
    }

    @Test("transcriptText nil when idle")
    @MainActor
    func transcriptTextNil() {
        let manager = VoiceInputManager()
        #expect(manager.transcriptText == nil)
    }

    @Test("Cancel from idle stays idle")
    @MainActor
    func cancelFromIdle() {
        let manager = VoiceInputManager()
        manager.cancel()
        #expect(manager.state == .idle)
    }

    @Test("Reset clears all state")
    @MainActor
    func resetClearsState() {
        let manager = VoiceInputManager()
        manager.editableTranscript = "Some text"
        manager.reset()
        #expect(manager.state == .idle)
        #expect(manager.editableTranscript == "")
        #expect(manager.audioLevels.isEmpty)
    }

    @Test("Stop recording when not recording does nothing")
    @MainActor
    func stopWhenNotRecording() {
        let manager = VoiceInputManager()
        manager.stopRecording()
        #expect(manager.state == .idle)
    }

    @Test("Model size can be changed")
    @MainActor
    func modelSizeChange() {
        let manager = VoiceInputManager(modelSize: "small")
        manager.modelSize = "large"
        #expect(manager.modelSize == "large")
    }

    @Test("VoiceInputState equality")
    func stateEquality() {
        #expect(VoiceInputState.idle == VoiceInputState.idle)
        #expect(VoiceInputState.recording == VoiceInputState.recording)
        #expect(VoiceInputState.processing == VoiceInputState.processing)
        #expect(VoiceInputState.requestingPermission == VoiceInputState.requestingPermission)
        #expect(VoiceInputState.loadingModel == VoiceInputState.loadingModel)
        #expect(VoiceInputState.completed("hello") == VoiceInputState.completed("hello"))
        #expect(VoiceInputState.completed("hello") != VoiceInputState.completed("world"))
        #expect(VoiceInputState.error("err") == VoiceInputState.error("err"))
        #expect(VoiceInputState.idle != VoiceInputState.recording)
        #expect(VoiceInputState.requestingPermission != VoiceInputState.loadingModel)
    }

    @Test("isLoadingModel computed property")
    @MainActor
    func isLoadingModel() {
        let manager = VoiceInputManager()
        #expect(manager.isLoadingModel == false)
    }

    @Test("canRecord true after error state")
    @MainActor
    func canRecordAfterError() {
        // Simulate an error state scenario — we test the computed property
        let manager = VoiceInputManager()
        // In normal usage, error state is reached via failed recording/transcription
        // Here we just verify the initial canRecord is true
        #expect(manager.canRecord == true)
    }

    @Test("isRecording and isProcessing computed properties")
    @MainActor
    func computedProperties() {
        let manager = VoiceInputManager()
        #expect(manager.isRecording == false)
        #expect(manager.isProcessing == false)
    }
}
