import Testing
import Foundation
@testable import PMDomain

// MARK: - Enum Tests

@Suite("Enums")
struct EnumTests {

    @Test("LifecycleState has all 6 cases")
    func lifecycleStateCases() {
        #expect(LifecycleState.allCases.count == 6)
        #expect(LifecycleState.allCases.contains(.focused))
        #expect(LifecycleState.allCases.contains(.queued))
        #expect(LifecycleState.allCases.contains(.idea))
        #expect(LifecycleState.allCases.contains(.completed))
        #expect(LifecycleState.allCases.contains(.paused))
        #expect(LifecycleState.allCases.contains(.abandoned))
    }

    @Test("ItemStatus has 5 cases")
    func itemStatusCases() {
        #expect(ItemStatus.allCases.count == 5)
    }

    @Test("EffortType has 6 cases")
    func effortTypeCases() {
        #expect(EffortType.allCases.count == 6)
    }

    @Test("BlockedType has 5 cases")
    func blockedTypeCases() {
        #expect(BlockedType.allCases.count == 5)
    }

    @Test("KanbanColumn has 3 cases")
    func kanbanColumnCases() {
        #expect(KanbanColumn.allCases.count == 3)
    }

    @Test("Priority sort values order correctly")
    func prioritySortValues() {
        #expect(Priority.high.sortValue < Priority.normal.sortValue)
        #expect(Priority.normal.sortValue < Priority.low.sortValue)
    }

    @Test("ConversationType has 7 cases")
    func conversationTypeCases() {
        #expect(ConversationType.allCases.count == 7)
    }

    @Test("Enums are Codable round-trip")
    func enumCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for state in LifecycleState.allCases {
            let data = try encoder.encode(state)
            let decoded = try decoder.decode(LifecycleState.self, from: data)
            #expect(decoded == state)
        }

        for status in ItemStatus.allCases {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(ItemStatus.self, from: data)
            #expect(decoded == status)
        }
    }
}

// MARK: - Entity Tests

@Suite("Entities")
struct EntityTests {

    @Test("Project default values")
    func projectDefaults() {
        let project = Project(name: "Test", categoryId: UUID())
        #expect(project.lifecycleState == .idea)
        #expect(project.focusSlotIndex == nil)
        #expect(project.pauseReason == nil)
    }

    @Test("Project is Codable round-trip")
    func projectCodable() throws {
        let project = Project(name: "Test", categoryId: UUID(), lifecycleState: .focused, focusSlotIndex: 2)
        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: data)
        #expect(decoded == project)
    }

    @Test("PMTask default values")
    func taskDefaults() {
        let task = PMTask(milestoneId: UUID(), name: "Do thing")
        #expect(task.status == .notStarted)
        #expect(task.priority == .normal)
        #expect(task.kanbanColumn == .toDo)
        #expect(task.timesDeferred == 0)
        #expect(task.isTimeboxed == false)
    }

    @Test("PMTask is Codable round-trip")
    func taskCodable() throws {
        let task = PMTask(milestoneId: UUID(), name: "Test", status: .blocked, blockedType: .tooLarge)
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(PMTask.self, from: data)
        #expect(decoded == task)
    }

    @Test("Category built-in categories")
    func builtInCategories() {
        let categories = Category.builtInCategories
        #expect(categories.count == 6)
        #expect(categories.allSatisfy { $0.isBuiltIn })
        #expect(categories[0].name == "Software")
    }

    @Test("Phase default values")
    func phaseDefaults() {
        let phase = Phase(projectId: UUID(), name: "Research")
        #expect(phase.status == .notStarted)
        #expect(phase.sortOrder == 0)
    }

    @Test("Milestone default values")
    func milestoneDefaults() {
        let m = Milestone(phaseId: UUID(), name: "v1 release")
        #expect(m.status == .notStarted)
        #expect(m.priority == .normal)
    }

    @Test("Subtask default values")
    func subtaskDefaults() {
        let s = Subtask(taskId: UUID(), name: "Step 1")
        #expect(s.isCompleted == false)
        #expect(s.sortOrder == 0)
    }

    @Test("Document version starts at 1")
    func documentVersion() {
        let doc = Document(projectId: UUID(), type: .visionStatement, title: "Vision")
        #expect(doc.version == 1)
    }

    @Test("Conversation contains messages")
    func conversationMessages() {
        let msg = ChatMessage(role: .user, content: "Hello")
        let convo = Conversation(conversationType: .general, messages: [msg])
        #expect(convo.messages.count == 1)
        #expect(convo.messages[0].role == .user)
    }

    @Test("CheckInRecord default values")
    func checkInDefaults() {
        let record = CheckInRecord(projectId: UUID(), depth: .quickLog)
        #expect(record.transcript == "")
        #expect(record.tasksCompleted.isEmpty)
    }

    @Test("Dependency stores source and target types")
    func dependencyTypes() {
        let dep = Dependency(sourceType: .milestone, sourceId: UUID(), targetType: .task, targetId: UUID())
        #expect(dep.sourceType == .milestone)
        #expect(dep.targetType == .task)
    }
}

// MARK: - Computed Property Tests

@Suite("Computed Properties")
struct ComputedPropertyTests {

    // MARK: PMTask

    @Test("effectiveDeadline uses task deadline first")
    func effectiveDeadlineOwn() {
        let taskDeadline = Date().addingTimeInterval(86400)
        let task = PMTask(milestoneId: UUID(), name: "T", deadline: taskDeadline)
        let milestoneDeadline = Date().addingTimeInterval(172800)
        #expect(task.effectiveDeadline(milestoneDeadline: milestoneDeadline) == taskDeadline)
    }

    @Test("effectiveDeadline falls back to milestone deadline")
    func effectiveDeadlineFallback() {
        let task = PMTask(milestoneId: UUID(), name: "T")
        let milestoneDeadline = Date().addingTimeInterval(172800)
        #expect(task.effectiveDeadline(milestoneDeadline: milestoneDeadline) == milestoneDeadline)
    }

    @Test("effectiveDeadline returns nil when no deadlines")
    func effectiveDeadlineNil() {
        let task = PMTask(milestoneId: UUID(), name: "T")
        #expect(task.effectiveDeadline(milestoneDeadline: nil) == nil)
    }

    @Test("isApproachingDeadline within threshold")
    func approachingDeadline() {
        let now = Date()
        let deadline = Calendar.current.date(byAdding: .day, value: 2, to: now)!
        let task = PMTask(milestoneId: UUID(), name: "T", deadline: deadline)
        #expect(task.isApproachingDeadline(milestoneDeadline: nil, withinDays: 3, now: now) == true)
    }

    @Test("isApproachingDeadline outside threshold")
    func notApproachingDeadline() {
        let now = Date()
        let deadline = Calendar.current.date(byAdding: .day, value: 10, to: now)!
        let task = PMTask(milestoneId: UUID(), name: "T", deadline: deadline)
        #expect(task.isApproachingDeadline(milestoneDeadline: nil, withinDays: 3, now: now) == false)
    }

    @Test("isApproachingDeadline false for completed tasks")
    func approachingDeadlineCompleted() {
        let now = Date()
        let deadline = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let task = PMTask(milestoneId: UUID(), name: "T", status: .completed, deadline: deadline)
        #expect(task.isApproachingDeadline(milestoneDeadline: nil, now: now) == false)
    }

    @Test("isOverdue when past deadline")
    func overdueTask() {
        let now = Date()
        let deadline = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let task = PMTask(milestoneId: UUID(), name: "T", deadline: deadline)
        #expect(task.isOverdue(milestoneDeadline: nil, now: now) == true)
    }

    @Test("isOverdue false when before deadline")
    func notOverdue() {
        let now = Date()
        let deadline = Calendar.current.date(byAdding: .day, value: 5, to: now)!
        let task = PMTask(milestoneId: UUID(), name: "T", deadline: deadline)
        #expect(task.isOverdue(milestoneDeadline: nil, now: now) == false)
    }

    @Test("isFrequentlyDeferred with default threshold")
    func frequentlyDeferred() {
        let task = PMTask(milestoneId: UUID(), name: "T", timesDeferred: 3)
        #expect(task.isFrequentlyDeferred() == true)
    }

    @Test("isFrequentlyDeferred below threshold")
    func notFrequentlyDeferred() {
        let task = PMTask(milestoneId: UUID(), name: "T", timesDeferred: 1)
        #expect(task.isFrequentlyDeferred() == false)
    }

    // MARK: Milestone

    @Test("Milestone progressPercent")
    func milestoneProgress() {
        let m = Milestone(phaseId: UUID(), name: "M")
        let tasks = [
            PMTask(milestoneId: m.id, name: "T1", status: .completed),
            PMTask(milestoneId: m.id, name: "T2", status: .inProgress),
            PMTask(milestoneId: m.id, name: "T3", status: .notStarted),
            PMTask(milestoneId: m.id, name: "T4", status: .completed),
        ]
        #expect(m.progressPercent(tasks: tasks) == 50.0)
    }

    @Test("Milestone progressPercent with no tasks")
    func milestoneProgressEmpty() {
        let m = Milestone(phaseId: UUID(), name: "M")
        #expect(m.progressPercent(tasks: []) == 0)
    }

    @Test("Milestone hasUnresolvedBlocks")
    func milestoneBlocked() {
        let m = Milestone(phaseId: UUID(), name: "M")
        let tasks = [
            PMTask(milestoneId: m.id, name: "T1", status: .blocked, blockedType: .tooLarge),
            PMTask(milestoneId: m.id, name: "T2", status: .inProgress),
        ]
        #expect(m.hasUnresolvedBlocks(tasks: tasks) == true)
    }

    @Test("Milestone hasUnresolvedBlocks false when none blocked")
    func milestoneNotBlocked() {
        let m = Milestone(phaseId: UUID(), name: "M")
        let tasks = [
            PMTask(milestoneId: m.id, name: "T1", status: .inProgress),
        ]
        #expect(m.hasUnresolvedBlocks(tasks: tasks) == false)
    }

    @Test("Milestone waitingItemsDueSoon")
    func waitingDueSoon() {
        let now = Date()
        let m = Milestone(phaseId: UUID(), name: "M")
        let tasks = [
            PMTask(milestoneId: m.id, name: "T1", status: .waiting,
                   waitingReason: "Parts", waitingCheckBackDate: now.addingTimeInterval(-3600)),
            PMTask(milestoneId: m.id, name: "T2", status: .waiting,
                   waitingReason: "Parts", waitingCheckBackDate: now.addingTimeInterval(86400)),
        ]
        let due = m.waitingItemsDueSoon(tasks: tasks, now: now)
        #expect(due.count == 1)
        #expect(due[0].name == "T1")
    }

    @Test("Milestone estimateAccuracy")
    func estimateAccuracy() {
        let m = Milestone(phaseId: UUID(), name: "M")
        let tasks = [
            PMTask(milestoneId: m.id, name: "T1", status: .completed,
                   timeEstimateMinutes: 60, actualMinutes: 90, completedAt: Date()),
            PMTask(milestoneId: m.id, name: "T2", status: .completed,
                   timeEstimateMinutes: 40, actualMinutes: 30, completedAt: Date()),
        ]
        let accuracy = m.estimateAccuracy(tasks: tasks)
        // (90 + 30) / (60 + 40) = 120 / 100 = 1.2
        #expect(accuracy == 1.2)
    }

    @Test("Milestone estimateAccuracy nil when no data")
    func estimateAccuracyNil() {
        let m = Milestone(phaseId: UUID(), name: "M")
        #expect(m.estimateAccuracy(tasks: []) == nil)
    }

    // MARK: Phase

    @Test("Phase progressPercent from tasks")
    func phaseProgress() {
        let phase = Phase(projectId: UUID(), name: "P")
        let m1 = Milestone(phaseId: phase.id, name: "M1")
        let m2 = Milestone(phaseId: phase.id, name: "M2")
        let tasksByMilestone: [UUID: [PMTask]] = [
            m1.id: [
                PMTask(milestoneId: m1.id, name: "T1", status: .completed),
                PMTask(milestoneId: m1.id, name: "T2", status: .completed),
            ],
            m2.id: [
                PMTask(milestoneId: m2.id, name: "T3", status: .inProgress),
                PMTask(milestoneId: m2.id, name: "T4", status: .notStarted),
            ],
        ]
        #expect(phase.progressPercent(milestones: [m1, m2], tasksByMilestone: tasksByMilestone) == 50.0)
    }

    @Test("Phase progressPercent falls back to milestone-level")
    func phaseProgressMilestoneFallback() {
        let phase = Phase(projectId: UUID(), name: "P")
        let m1 = Milestone(phaseId: phase.id, name: "M1", status: .completed)
        let m2 = Milestone(phaseId: phase.id, name: "M2")
        let progress = phase.progressPercent(milestones: [m1, m2], tasksByMilestone: [:])
        #expect(progress == 50.0)
    }

    // MARK: Project

    @Test("Project isStale when not worked on recently")
    func projectStale() {
        let now = Date()
        let project = Project(
            name: "Test", categoryId: UUID(), lifecycleState: .focused,
            lastWorkedOn: Calendar.current.date(byAdding: .day, value: -15, to: now)
        )
        #expect(project.isStale(now: now) == true)
    }

    @Test("Project not stale when recently worked on")
    func projectNotStale() {
        let now = Date()
        let project = Project(
            name: "Test", categoryId: UUID(), lifecycleState: .focused,
            lastWorkedOn: Calendar.current.date(byAdding: .day, value: -3, to: now)
        )
        #expect(project.isStale(now: now) == false)
    }

    @Test("Project isStale false for non-active states")
    func projectStaleInactive() {
        let now = Date()
        let project = Project(
            name: "Test", categoryId: UUID(), lifecycleState: .completed,
            lastWorkedOn: Calendar.current.date(byAdding: .day, value: -30, to: now)
        )
        #expect(project.isStale(now: now) == false)
    }

    @Test("Project isStale true when never worked on")
    func projectStaleNeverWorked() {
        let project = Project(name: "Test", categoryId: UUID(), lifecycleState: .focused)
        #expect(project.isStale() == true)
    }

    @Test("Project daysSinceCheckIn")
    func daysSinceCheckIn() {
        let now = Date()
        let checkIn = Calendar.current.date(byAdding: .day, value: -5, to: now)!
        let project = Project(name: "Test", categoryId: UUID())
        let days = project.daysSinceCheckIn(lastCheckInDate: checkIn, now: now)
        #expect(days == 5)
    }

    @Test("Project daysSinceCheckIn nil when no check-in")
    func daysSinceCheckInNil() {
        let project = Project(name: "Test", categoryId: UUID())
        #expect(project.daysSinceCheckIn(lastCheckInDate: nil) == nil)
    }
}

// MARK: - FocusManager Tests

@Suite("FocusManager")
struct FocusManagerTests {

    let categoryA = UUID()
    let categoryB = UUID()
    let categoryC = UUID()

    func makeProject(name: String = "P", categoryId: UUID? = nil, state: LifecycleState = .queued) -> Project {
        Project(name: name, categoryId: categoryId ?? categoryA, lifecycleState: state)
    }

    @Test("Can focus project on empty board")
    func focusOnEmpty() {
        let project = makeProject()
        let result = FocusManager.canFocus(project: project, currentFocused: [])
        #expect(result == .eligible)
    }

    @Test("Cannot focus when board is full")
    func focusBoardFull() {
        let focused = (0..<5).map { i in
            var p = makeProject(name: "P\(i)", categoryId: [categoryA, categoryB, categoryC][i % 3])
            p.lifecycleState = .focused
            p.focusSlotIndex = i
            return p
        }
        let project = makeProject(categoryId: categoryC)
        let result = FocusManager.canFocus(project: project, currentFocused: focused)
        #expect(result == .ineligible(reason: .boardFull))
    }

    @Test("Cannot focus when category limit reached")
    func focusCategoryLimit() {
        let focused = [
            makeProject(name: "P1", categoryId: categoryA),
            makeProject(name: "P2", categoryId: categoryA),
        ]
        let project = makeProject(name: "P3", categoryId: categoryA)
        let result = FocusManager.canFocus(project: project, currentFocused: focused)
        #expect(result == .ineligible(reason: .categoryLimitReached))
    }

    @Test("Cannot focus already-focused project")
    func focusAlreadyFocused() {
        var project = makeProject()
        project.lifecycleState = .focused
        let result = FocusManager.canFocus(project: project, currentFocused: [project])
        #expect(result == .ineligible(reason: .alreadyFocused))
    }

    @Test("Cannot focus completed project")
    func focusCompleted() {
        let project = makeProject(state: .completed)
        let result = FocusManager.canFocus(project: project, currentFocused: [])
        #expect(result == .ineligible(reason: .invalidState))
    }

    @Test("Can focus idea project")
    func focusIdea() {
        let project = makeProject(state: .idea)
        let result = FocusManager.canFocus(project: project, currentFocused: [])
        #expect(result == .eligible)
    }

    @Test("focus() assigns slot and sets state")
    func focusAssignsSlot() {
        let project = makeProject()
        let result = FocusManager.focus(project: project, currentFocused: [])
        #expect(result != nil)
        #expect(result?.focusSlotIndex == 0)
        #expect(result?.lifecycleState == .focused)
    }

    @Test("focus() assigns next available slot")
    func focusNextSlot() {
        var existing = makeProject(name: "E", categoryId: categoryB)
        existing.lifecycleState = .focused
        existing.focusSlotIndex = 0
        let project = makeProject(name: "N")
        let result = FocusManager.focus(project: project, currentFocused: [existing])
        #expect(result?.focusSlotIndex == 1)
    }

    @Test("focus() fills gap in slot indices")
    func focusFillsGap() {
        var p0 = makeProject(name: "P0", categoryId: categoryB)
        p0.focusSlotIndex = 0
        var p2 = makeProject(name: "P2", categoryId: categoryC)
        p2.focusSlotIndex = 2
        let project = makeProject(name: "New")
        let result = FocusManager.focus(project: project, currentFocused: [p0, p2])
        #expect(result?.focusSlotIndex == 1)
    }

    @Test("focus() returns nil for ineligible project")
    func focusIneligibleNil() {
        let project = makeProject(state: .completed)
        let result = FocusManager.focus(project: project, currentFocused: [])
        #expect(result == nil)
    }

    @Test("unfocus() clears slot and sets destination state")
    func unfocusProject() {
        var project = makeProject()
        project.lifecycleState = .focused
        project.focusSlotIndex = 2
        let result = FocusManager.unfocus(project: project, to: .paused)
        #expect(result.focusSlotIndex == nil)
        #expect(result.lifecycleState == .paused)
    }

    @Test("unfocus() defaults to queued")
    func unfocusDefaultsQueued() {
        var project = makeProject()
        project.lifecycleState = .focused
        project.focusSlotIndex = 0
        let result = FocusManager.unfocus(project: project)
        #expect(result.lifecycleState == .queued)
    }

    // MARK: Task Visibility

    @Test("curateVisibleTasks respects maxVisible")
    func curateMaxVisible() {
        let mid = UUID()
        let tasks = (0..<10).map { PMTask(milestoneId: mid, name: "T\($0)", sortOrder: $0) }
        let visible = FocusManager.curateVisibleTasks(tasks: tasks, maxVisible: 3)
        #expect(visible.count == 3)
    }

    @Test("curateVisibleTasks excludes completed")
    func curateExcludesCompleted() {
        let mid = UUID()
        let tasks = [
            PMTask(milestoneId: mid, name: "Done", status: .completed),
            PMTask(milestoneId: mid, name: "Active", status: .inProgress),
        ]
        let visible = FocusManager.curateVisibleTasks(tasks: tasks, maxVisible: 5)
        #expect(visible.count == 1)
        #expect(visible[0].name == "Active")
    }

    @Test("curateVisibleTasks prioritises in-progress")
    func curatePrioritisesInProgress() {
        let mid = UUID()
        let tasks = [
            PMTask(milestoneId: mid, name: "NotStarted", sortOrder: 0),
            PMTask(milestoneId: mid, name: "InProgress", sortOrder: 1, status: .inProgress),
        ]
        let visible = FocusManager.curateVisibleTasks(tasks: tasks, maxVisible: 5)
        #expect(visible[0].name == "InProgress")
    }

    @Test("curateVisibleTasks sorts by priority then sort order")
    func curateSortsPriority() {
        let mid = UUID()
        let tasks = [
            PMTask(milestoneId: mid, name: "Low", sortOrder: 0, priority: .low),
            PMTask(milestoneId: mid, name: "High", sortOrder: 1, priority: .high),
            PMTask(milestoneId: mid, name: "Normal", sortOrder: 2, priority: .normal),
        ]
        let visible = FocusManager.curateVisibleTasks(tasks: tasks, maxVisible: 3)
        #expect(visible[0].name == "High")
        #expect(visible[1].name == "Normal")
        #expect(visible[2].name == "Low")
    }

    @Test("curateVisibleTasks clamps to valid range")
    func curateClamps() {
        let mid = UUID()
        let tasks = (0..<20).map { PMTask(milestoneId: mid, name: "T\($0)", sortOrder: $0) }
        let visible = FocusManager.curateVisibleTasks(tasks: tasks, maxVisible: 50)
        #expect(visible.count == 10) // clamped to max 10
    }

    // MARK: Health Signals

    @Test("healthSignals detects stale project")
    func healthStale() {
        let now = Date()
        let project = Project(
            name: "Test", categoryId: UUID(), lifecycleState: .focused,
            lastWorkedOn: Calendar.current.date(byAdding: .day, value: -20, to: now)
        )
        let signals = FocusManager.healthSignals(project: project, tasks: [], lastCheckInDate: nil, now: now)
        #expect(signals.isStale == true)
        #expect(signals.needsAttention == true)
    }

    @Test("healthSignals counts blocked and deferred tasks")
    func healthBlockedDeferred() {
        let mid = UUID()
        let project = Project(name: "Test", categoryId: UUID(), lifecycleState: .focused, lastWorkedOn: Date())
        let tasks = [
            PMTask(milestoneId: mid, name: "T1", status: .blocked, blockedType: .tooLarge),
            PMTask(milestoneId: mid, name: "T2", timesDeferred: 5),
        ]
        let signals = FocusManager.healthSignals(project: project, tasks: tasks, lastCheckInDate: Date())
        #expect(signals.blockedTaskCount == 1)
        #expect(signals.frequentlyDeferredCount == 1)
        #expect(signals.needsAttention == true)
    }

    @Test("healthSignals healthy project")
    func healthHealthy() {
        let project = Project(name: "Test", categoryId: UUID(), lifecycleState: .focused, lastWorkedOn: Date())
        let signals = FocusManager.healthSignals(project: project, tasks: [], lastCheckInDate: Date())
        #expect(signals.needsAttention == false)
    }

    // MARK: Diversity

    @Test("diversityViolations empty when diverse")
    func diversityOk() {
        let p1 = Project(name: "P1", categoryId: categoryA, lifecycleState: .focused)
        let p2 = Project(name: "P2", categoryId: categoryB, lifecycleState: .focused)
        let p3 = Project(name: "P3", categoryId: categoryA, lifecycleState: .focused)
        let violations = FocusManager.diversityViolations(focusedProjects: [p1, p2, p3])
        #expect(violations.isEmpty)
    }

    @Test("diversityViolations detects over-concentration")
    func diversityViolation() {
        let p1 = Project(name: "P1", categoryId: categoryA, lifecycleState: .focused)
        let p2 = Project(name: "P2", categoryId: categoryA, lifecycleState: .focused)
        let p3 = Project(name: "P3", categoryId: categoryA, lifecycleState: .focused)
        let violations = FocusManager.diversityViolations(focusedProjects: [p1, p2, p3])
        #expect(violations.count == 1)
        #expect(violations[0].categoryId == categoryA)
        #expect(violations[0].projectCount == 3)
    }
}

// MARK: - Validation Tests

@Suite("Validation")
struct ValidationTests {

    // MARK: Focus Slot

    @Test("Valid focus slot indices")
    func validFocusSlots() {
        #expect(Validation.isValidFocusSlot(nil) == true)
        #expect(Validation.isValidFocusSlot(0) == true)
        #expect(Validation.isValidFocusSlot(4) == true)
    }

    @Test("Invalid focus slot indices")
    func invalidFocusSlots() {
        #expect(Validation.isValidFocusSlot(-1) == false)
        #expect(Validation.isValidFocusSlot(5) == false)
        #expect(Validation.isValidFocusSlot(100) == false)
    }

    // MARK: Lifecycle Transitions

    @Test("Valid lifecycle transitions from idea")
    func transitionsFromIdea() {
        #expect(Validation.canTransition(from: .idea, to: .queued) == true)
        #expect(Validation.canTransition(from: .idea, to: .abandoned) == true)
        #expect(Validation.canTransition(from: .idea, to: .focused) == false)
    }

    @Test("Valid lifecycle transitions from focused")
    func transitionsFromFocused() {
        #expect(Validation.canTransition(from: .focused, to: .queued) == true)
        #expect(Validation.canTransition(from: .focused, to: .paused) == true)
        #expect(Validation.canTransition(from: .focused, to: .completed) == true)
        #expect(Validation.canTransition(from: .focused, to: .abandoned) == true)
        #expect(Validation.canTransition(from: .focused, to: .idea) == false)
    }

    @Test("Valid lifecycle transitions from completed")
    func transitionsFromCompleted() {
        #expect(Validation.canTransition(from: .completed, to: .queued) == true)
        #expect(Validation.canTransition(from: .completed, to: .focused) == false)
    }

    @Test("Valid lifecycle transitions from abandoned")
    func transitionsFromAbandoned() {
        #expect(Validation.canTransition(from: .abandoned, to: .idea) == true)
        #expect(Validation.canTransition(from: .abandoned, to: .queued) == true)
        #expect(Validation.canTransition(from: .abandoned, to: .focused) == false)
    }

    // MARK: Category Diversity

    @Test("wouldViolateDiversity false when under limit")
    func diversityUnderLimit() {
        let catId = UUID()
        let projects = [Project(name: "P1", categoryId: catId)]
        #expect(Validation.wouldViolateDiversity(categoryId: catId, currentFocused: projects) == false)
    }

    @Test("wouldViolateDiversity true when at limit")
    func diversityAtLimit() {
        let catId = UUID()
        let projects = [
            Project(name: "P1", categoryId: catId),
            Project(name: "P2", categoryId: catId),
        ]
        #expect(Validation.wouldViolateDiversity(categoryId: catId, currentFocused: projects) == true)
    }

    // MARK: Entity Validation

    @Test("Valid project passes validation")
    func validProject() {
        let project = Project(name: "Test", categoryId: UUID())
        let errors = Validation.validate(project: project)
        #expect(errors.isEmpty)
    }

    @Test("Project with empty name fails validation")
    func projectEmptyName() {
        let project = Project(name: "  ", categoryId: UUID())
        let errors = Validation.validate(project: project)
        #expect(errors.contains(.emptyName(entity: "Project")))
    }

    @Test("Focused project without slot fails")
    func focusedWithoutSlot() {
        let project = Project(name: "Test", categoryId: UUID(), lifecycleState: .focused)
        let errors = Validation.validate(project: project)
        #expect(errors.contains(.focusedWithoutSlot))
    }

    @Test("Non-focused project with slot fails")
    func slotWithoutFocused() {
        let project = Project(name: "Test", categoryId: UUID(), lifecycleState: .queued, focusSlotIndex: 2)
        let errors = Validation.validate(project: project)
        #expect(errors.contains(.slotWithoutFocused))
    }

    @Test("Paused project without reason fails")
    func pausedWithoutReason() {
        let project = Project(name: "Test", categoryId: UUID(), lifecycleState: .paused)
        let errors = Validation.validate(project: project)
        #expect(errors.contains(.pausedWithoutReason))
    }

    @Test("Abandoned project without reflection fails")
    func abandonedWithoutReflection() {
        let project = Project(name: "Test", categoryId: UUID(), lifecycleState: .abandoned)
        let errors = Validation.validate(project: project)
        #expect(errors.contains(.abandonedWithoutReflection))
    }

    @Test("Valid task passes validation")
    func validTask() {
        let task = PMTask(milestoneId: UUID(), name: "Do thing")
        let errors = Validation.validate(task: task)
        #expect(errors.isEmpty)
    }

    @Test("Blocked task without type fails")
    func blockedWithoutType() {
        let task = PMTask(milestoneId: UUID(), name: "T", status: .blocked)
        let errors = Validation.validate(task: task)
        #expect(errors.contains(.blockedWithoutType))
    }

    @Test("Waiting task without reason fails")
    func waitingWithoutReason() {
        let task = PMTask(milestoneId: UUID(), name: "T", status: .waiting)
        let errors = Validation.validate(task: task)
        #expect(errors.contains(.waitingWithoutReason))
    }

    @Test("Task with invalid time estimate fails")
    func invalidEstimate() {
        let task = PMTask(milestoneId: UUID(), name: "T", timeEstimateMinutes: 0)
        let errors = Validation.validate(task: task)
        #expect(errors.contains(.invalidTimeEstimate))
    }
}
