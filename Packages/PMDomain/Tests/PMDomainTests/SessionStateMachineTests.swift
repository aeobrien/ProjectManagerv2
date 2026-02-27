import Testing
import Foundation
@testable import PMDomain

@Suite("SessionStateMachine")
struct SessionStateMachineTests {

    // MARK: - Valid Transitions

    @Test("Active can transition to paused or completed")
    func activeTransitions() {
        let valid = SessionStateMachine.validTransitions(from: .active)
        #expect(valid.contains(.paused))
        #expect(valid.contains(.completed))
        #expect(valid.count == 2)
    }

    @Test("Paused can transition to active, completed, autoSummarised, or pendingAutoSummary")
    func pausedTransitions() {
        let valid = SessionStateMachine.validTransitions(from: .paused)
        #expect(valid.contains(.active))
        #expect(valid.contains(.completed))
        #expect(valid.contains(.autoSummarised))
        #expect(valid.contains(.pendingAutoSummary))
        #expect(valid.count == 4)
    }

    @Test("PendingAutoSummary can only transition to autoSummarised")
    func pendingTransitions() {
        let valid = SessionStateMachine.validTransitions(from: .pendingAutoSummary)
        #expect(valid == [.autoSummarised])
    }

    @Test("Completed is terminal")
    func completedTerminal() {
        let valid = SessionStateMachine.validTransitions(from: .completed)
        #expect(valid.isEmpty)
    }

    @Test("AutoSummarised is terminal")
    func autoSummarisedTerminal() {
        let valid = SessionStateMachine.validTransitions(from: .autoSummarised)
        #expect(valid.isEmpty)
    }

    // MARK: - Transition Function

    @Test("Valid transition returns target status")
    func validTransitionReturns() {
        let result = SessionStateMachine.transition(from: .active, to: .paused)
        #expect(result == .paused)
    }

    @Test("Invalid transition returns nil")
    func invalidTransitionReturnsNil() {
        let result = SessionStateMachine.transition(from: .completed, to: .active)
        #expect(result == nil)
    }

    @Test("Cannot transition active directly to autoSummarised")
    func cannotSkipToAutoSummarised() {
        let result = SessionStateMachine.transition(from: .active, to: .autoSummarised)
        #expect(result == nil)
    }

    // MARK: - Active Slot

    @Test("Active occupies an active slot")
    func activeOccupiesSlot() {
        #expect(SessionStateMachine.occupiesActiveSlot(.active) == true)
    }

    @Test("Paused occupies an active slot")
    func pausedOccupiesSlot() {
        #expect(SessionStateMachine.occupiesActiveSlot(.paused) == true)
    }

    @Test("Completed does not occupy an active slot")
    func completedDoesNotOccupySlot() {
        #expect(SessionStateMachine.occupiesActiveSlot(.completed) == false)
    }

    @Test("AutoSummarised does not occupy an active slot")
    func autoSummarisedDoesNotOccupySlot() {
        #expect(SessionStateMachine.occupiesActiveSlot(.autoSummarised) == false)
    }

    @Test("PendingAutoSummary does not occupy an active slot")
    func pendingDoesNotOccupySlot() {
        #expect(SessionStateMachine.occupiesActiveSlot(.pendingAutoSummary) == false)
    }

    // MARK: - Auto-Summarisation Eligibility

    @Test("Paused session past timeout is eligible")
    func eligibleAfterTimeout() {
        let session = Session(
            projectId: UUID(),
            mode: .exploration,
            status: .paused,
            lastActiveAt: Date().addingTimeInterval(-25 * 60 * 60) // 25 hours ago
        )
        #expect(SessionStateMachine.isEligibleForAutoSummarisation(session, timeoutInterval: 24 * 60 * 60))
    }

    @Test("Paused session before timeout is not eligible")
    func notEligibleBeforeTimeout() {
        let session = Session(
            projectId: UUID(),
            mode: .exploration,
            status: .paused,
            lastActiveAt: Date().addingTimeInterval(-23 * 60 * 60) // 23 hours ago
        )
        #expect(!SessionStateMachine.isEligibleForAutoSummarisation(session, timeoutInterval: 24 * 60 * 60))
    }

    @Test("Active session is never eligible for auto-summarisation")
    func activeNotEligible() {
        let session = Session(
            projectId: UUID(),
            mode: .exploration,
            status: .active,
            lastActiveAt: Date().addingTimeInterval(-48 * 60 * 60)
        )
        #expect(!SessionStateMachine.isEligibleForAutoSummarisation(session))
    }

    @Test("Completed session is never eligible for auto-summarisation")
    func completedNotEligible() {
        let session = Session(
            projectId: UUID(),
            mode: .exploration,
            status: .completed,
            lastActiveAt: Date().addingTimeInterval(-48 * 60 * 60)
        )
        #expect(!SessionStateMachine.isEligibleForAutoSummarisation(session))
    }

    @Test("Custom timeout interval is respected")
    func customTimeoutInterval() {
        let session = Session(
            projectId: UUID(),
            mode: .exploration,
            status: .paused,
            lastActiveAt: Date().addingTimeInterval(-2 * 60 * 60) // 2 hours ago
        )
        #expect(SessionStateMachine.isEligibleForAutoSummarisation(session, timeoutInterval: 1 * 60 * 60))
        #expect(!SessionStateMachine.isEligibleForAutoSummarisation(session, timeoutInterval: 3 * 60 * 60))
    }
}
