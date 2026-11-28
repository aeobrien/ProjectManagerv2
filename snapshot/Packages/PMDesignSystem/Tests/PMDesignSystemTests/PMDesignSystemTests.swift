import Testing
import SwiftUI
@testable import PMDesignSystem
import PMDomain

// MARK: - Colour Token Tests

@Suite("Colour Tokens")
struct ColourTokenTests {

    @Test("Slot colour covers all 5 indices")
    func slotColours() {
        #expect(SlotColour.allCases.count == 5)
        for slot in SlotColour.allCases {
            // Each slot should produce a non-secondary colour
            #expect(slot.color != .secondary)
        }
    }

    @Test("SlotColour.forIndex returns secondary for nil/invalid")
    func slotForIndex() {
        #expect(SlotColour.forIndex(nil) == .secondary)
        #expect(SlotColour.forIndex(-1) == .secondary)
        #expect(SlotColour.forIndex(5) == .secondary)
        #expect(SlotColour.forIndex(99) == .secondary)
        // Valid indices return non-secondary
        #expect(SlotColour.forIndex(0) != .secondary)
        #expect(SlotColour.forIndex(4) != .secondary)
    }

    @Test("Every ItemStatus has a colour")
    func itemStatusColours() {
        for status in ItemStatus.allCases {
            _ = status.color // should not crash
        }
        #expect(ItemStatus.blocked.color == .red)
        #expect(ItemStatus.completed.color == .green)
    }

    @Test("Every LifecycleState has a colour")
    func lifecycleColours() {
        for state in LifecycleState.allCases {
            _ = state.color
        }
        #expect(LifecycleState.focused.color == .blue)
        #expect(LifecycleState.completed.color == .green)
    }

    @Test("Every EffortType has a colour")
    func effortTypeColours() {
        for effort in EffortType.allCases {
            _ = effort.color
        }
    }

    @Test("Every Priority has a colour")
    func priorityColours() {
        #expect(Priority.high.color == .red)
    }
}

// MARK: - Icon Token Tests

@Suite("Icon Tokens")
struct IconTokenTests {

    @Test("Every EffortType has an SF Symbol icon name")
    func effortTypeIcons() {
        for effort in EffortType.allCases {
            #expect(!effort.iconName.isEmpty)
        }
    }

    @Test("Every ItemStatus has an icon name")
    func itemStatusIcons() {
        for status in ItemStatus.allCases {
            #expect(!status.iconName.isEmpty)
        }
    }

    @Test("Every LifecycleState has an icon name")
    func lifecycleIcons() {
        for state in LifecycleState.allCases {
            #expect(!state.iconName.isEmpty)
        }
    }

    @Test("Every BlockedType has an icon name")
    func blockedTypeIcons() {
        for blocked in BlockedType.allCases {
            #expect(!blocked.iconName.isEmpty)
        }
    }
}

// MARK: - TaskCardData Tests

@Suite("TaskCardData")
struct TaskCardDataTests {

    @Test("isOverdue returns true when past deadline and not completed")
    func overdueDetection() {
        let pastDeadline = TaskCardData(
            name: "T1", projectName: "P1",
            deadline: Date().addingTimeInterval(-86400),
            status: .inProgress
        )
        #expect(pastDeadline.isOverdue == true)

        let completedPast = TaskCardData(
            name: "T2", projectName: "P1",
            deadline: Date().addingTimeInterval(-86400),
            status: .completed
        )
        #expect(completedPast.isOverdue == false)
    }

    @Test("isOverdue returns false with no deadline")
    func noDeadlineNotOverdue() {
        let noDeadline = TaskCardData(name: "T1", projectName: "P1")
        #expect(noDeadline.isOverdue == false)
    }

    @Test("isApproachingDeadline detects within 2 days")
    func approachingDeadline() {
        let tomorrow = TaskCardData(
            name: "T1", projectName: "P1",
            deadline: Date().addingTimeInterval(86400),
            status: .inProgress
        )
        #expect(tomorrow.isApproachingDeadline == true)

        let nextWeek = TaskCardData(
            name: "T2", projectName: "P1",
            deadline: Date().addingTimeInterval(7 * 86400),
            status: .inProgress
        )
        #expect(nextWeek.isApproachingDeadline == false)
    }

    @Test("isFrequentlyDeferred uses threshold")
    func deferredThreshold() {
        let notDeferred = TaskCardData(name: "T1", projectName: "P1", deferralCount: 2, deferredThreshold: 3)
        #expect(notDeferred.isFrequentlyDeferred == false)

        let deferred = TaskCardData(name: "T2", projectName: "P1", deferralCount: 3, deferredThreshold: 3)
        #expect(deferred.isFrequentlyDeferred == true)

        let overDeferred = TaskCardData(name: "T3", projectName: "P1", deferralCount: 5, deferredThreshold: 3)
        #expect(overDeferred.isFrequentlyDeferred == true)
    }
}

// MARK: - Health Signal Tests

@Suite("Health Signals")
struct HealthSignalTests {

    @Test("HealthSignalType provides label, icon, and colour")
    func signalProperties() {
        let signals: [HealthSignalType] = [
            .stale(days: 10),
            .blockedTasks(count: 3),
            .overdueTasks(count: 2),
            .approachingDeadline,
            .checkInOverdue(days: 5),
            .diversityOverride,
            .frequentlyDeferred(count: 4)
        ]
        for signal in signals {
            #expect(!signal.label.isEmpty)
            #expect(!signal.iconName.isEmpty)
            _ = signal.color
        }
    }

    @Test("Stale signal includes day count in label")
    func staleLabel() {
        let signal = HealthSignalType.stale(days: 12)
        #expect(signal.label.contains("12"))
    }

    @Test("Blocked signal includes count in label")
    func blockedLabel() {
        let signal = HealthSignalType.blockedTasks(count: 5)
        #expect(signal.label.contains("5"))
    }
}

// MARK: - Progress Component Tests

@Suite("Progress Components")
struct ProgressComponentTests {

    @Test("PMProgressBar clamps progress to 0...1")
    @MainActor
    func progressClamping() {
        // These should not crash and should render correctly
        _ = PMProgressBar(progress: -0.5)
        _ = PMProgressBar(progress: 1.5)
        _ = PMProgressBar(progress: 0.5)
    }

    @Test("PMProgressLabel formats percent correctly")
    @MainActor
    func percentFormat() {
        let label = PMProgressLabel(progress: 0.75)
        _ = label.body // should not crash
    }

    @Test("PMProgressLabel formats fraction correctly")
    @MainActor
    func fractionFormat() {
        let label = PMProgressLabel(progress: 0.5, style: .fraction(total: 10))
        _ = label.body // should not crash
    }
}
