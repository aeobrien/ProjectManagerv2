import Foundation
import PMDomain
import PMServices
import PMUtilities

/// A display message for the dev screen conversation.
public struct DevScreenMessage: Identifiable, Sendable {
    public let id = UUID()
    public let role: String
    public let content: String
    public let signals: [ResponseSignal]
    public let actions: [AIAction]
    public let timestamp: Date

    public init(role: String, content: String, signals: [ResponseSignal] = [], actions: [AIAction] = [], timestamp: Date = Date()) {
        self.role = role
        self.content = content
        self.signals = signals
        self.actions = actions
        self.timestamp = timestamp
    }
}

/// ViewModel for the AI System V2 development/testing screen.
/// Wired to the real V2 pipeline: ConversationManager + ResponseSignalParser.
@Observable @MainActor
public final class AIDevScreenViewModel {
    private let projectRepo: ProjectRepositoryProtocol
    private let phaseRepo: PhaseRepositoryProtocol
    private let milestoneRepo: MilestoneRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol
    private let subtaskRepo: SubtaskRepositoryProtocol
    private let checkInRepo: CheckInRepositoryProtocol
    private let sessionRepo: SessionRepositoryProtocol
    private let processProfileRepo: ProcessProfileRepositoryProtocol
    private let deliverableRepo: DeliverableRepositoryProtocol
    private let conversationManager: ConversationManager
    private let signalParser: ResponseSignalParser

    // MARK: - State

    var projects: [Project] = []
    var selectedProject: Project?
    var selectedMode: SessionMode = .exploration
    var selectedSubMode: SessionSubMode?
    var messages: [DevScreenMessage] = []
    var inputText: String = ""
    var isLoading = false
    var isCompleting = false
    var errorMessage: String?

    /// The active session, if any.
    var activeSession: Session?

    /// Signals detected in the most recent response.
    var lastSignals: [ResponseSignal] = []

    /// Whether mode completion was signalled.
    var modeCompleted = false

    /// The process recommendation extracted from signals, if any.
    var capturedRecommendation: String?

    var sessionInfo: String {
        let projectName = selectedProject?.name ?? "None"
        let modeLabel = selectedSubMode.map { "\(selectedMode.displayName)/\($0.displayName)" } ?? selectedMode.displayName
        let sessionStatus = activeSession.map { "Session: \($0.status.rawValue)" } ?? "No session"
        return "Project: \(projectName) | Mode: \(modeLabel) | \(sessionStatus)"
    }

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && selectedProject != nil
        && !isLoading
    }

    // MARK: - Init

    public init(
        projectRepo: ProjectRepositoryProtocol,
        phaseRepo: PhaseRepositoryProtocol,
        milestoneRepo: MilestoneRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
        subtaskRepo: SubtaskRepositoryProtocol,
        checkInRepo: CheckInRepositoryProtocol,
        sessionRepo: SessionRepositoryProtocol,
        processProfileRepo: ProcessProfileRepositoryProtocol,
        deliverableRepo: DeliverableRepositoryProtocol,
        conversationManager: ConversationManager,
        signalParser: ResponseSignalParser = ResponseSignalParser()
    ) {
        self.projectRepo = projectRepo
        self.phaseRepo = phaseRepo
        self.milestoneRepo = milestoneRepo
        self.taskRepo = taskRepo
        self.subtaskRepo = subtaskRepo
        self.checkInRepo = checkInRepo
        self.sessionRepo = sessionRepo
        self.processProfileRepo = processProfileRepo
        self.deliverableRepo = deliverableRepo
        self.conversationManager = conversationManager
        self.signalParser = signalParser
    }

    // MARK: - Actions

    func loadProjects() async {
        do {
            projects = try await projectRepo.fetchAll()
            Log.ai.debug("AIDevScreen loaded \(self.projects.count) projects")
        } catch {
            errorMessage = error.localizedDescription
            Log.ai.error("AIDevScreen failed to load projects: \(error)")
        }
    }

    func startSession() async {
        guard let project = selectedProject else {
            errorMessage = "Select a project first"
            return
        }

        do {
            // Check for existing paused session
            if let paused = try await conversationManager.pausedSession(forProject: project.id) {
                activeSession = try await conversationManager.resumeSession(paused.id)
                // Load existing messages
                let sessionMessages = try await conversationManager.messages(forSession: paused.id)
                messages = sessionMessages.map { msg in
                    DevScreenMessage(
                        role: msg.role == .user ? "user" : "assistant",
                        content: msg.content,
                        timestamp: msg.timestamp
                    )
                }
                Log.ai.info("AIDevScreen resumed session \(paused.id)")
            } else {
                activeSession = try await conversationManager.startSession(
                    projectId: project.id,
                    mode: selectedMode,
                    subMode: selectedSubMode
                )
                messages.removeAll()
                modeCompleted = false
                capturedRecommendation = nil
                lastSignals = []
                Log.ai.info("AIDevScreen started new \(self.selectedMode.rawValue) session")
            }
        } catch {
            errorMessage = error.localizedDescription
            Log.ai.error("AIDevScreen failed to start session: \(error)")
        }
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let session = activeSession, let project = selectedProject else { return }

        inputText = ""
        messages.append(DevScreenMessage(role: "user", content: text))
        isLoading = true
        errorMessage = nil

        do {
            let projectData = try await assembleProjectData(for: project)
            let modeConfig = ModeConfigurationRegistry.configuration(for: session.mode, subMode: session.subMode)

            let result = try await conversationManager.sendMessage(
                text,
                sessionId: session.id,
                projectData: projectData,
                config: ConversationConfig(
                    parseActions: modeConfig.parseActions
                )
            )

            // Parse signals from the raw response
            let parsed = signalParser.parse(result.naturalLanguage, parseActions: false)

            lastSignals = parsed.signals
            modeCompleted = parsed.signals.contains { if case .modeComplete = $0 { return true }; return false }

            // Capture process recommendation for the completion banner
            for signal in parsed.signals {
                if case .processRecommendation(let deliverables) = signal {
                    capturedRecommendation = deliverables
                }
            }

            messages.append(DevScreenMessage(
                role: "assistant",
                content: parsed.naturalLanguage,
                signals: parsed.signals,
                actions: result.actions
            ))

            Log.ai.info("AIDevScreen response: \(parsed.signals.count) signals, \(result.actions.count) actions")
        } catch {
            errorMessage = error.localizedDescription
            messages.append(DevScreenMessage(role: "system", content: "Error: \(error.localizedDescription)"))
            Log.ai.error("AIDevScreen send failed: \(error)")
        }

        isLoading = false
    }

    func completeSession() async {
        guard let session = activeSession else { return }
        isCompleting = true

        do {
            let summary = try await conversationManager.completeSession(session.id)
            messages.append(DevScreenMessage(
                role: "system",
                content: "Session completed. Summary generated with \(summary.contentEstablished.decisions.count) decisions, \(summary.contentEstablished.factsLearned.count) facts learned, \(summary.contentEstablished.progressMade.count) progress items."
            ))
            activeSession = nil
            Log.ai.info("AIDevScreen session completed")
        } catch {
            errorMessage = error.localizedDescription
            Log.ai.error("AIDevScreen complete failed: \(error)")
        }

        isCompleting = false
    }

    func pauseSession() async {
        guard let session = activeSession else { return }

        do {
            _ = try await conversationManager.pauseSession(session.id)
            messages.append(DevScreenMessage(role: "system", content: "Session paused. You can resume it later by starting a session on the same project."))
            activeSession = nil
            Log.ai.info("AIDevScreen session paused")
        } catch {
            errorMessage = error.localizedDescription
            Log.ai.error("AIDevScreen pause failed: \(error)")
        }
    }

    func endSession() async {
        guard let session = activeSession else { return }

        do {
            _ = try await conversationManager.endSession(session.id)
            messages.append(DevScreenMessage(role: "system", content: "Session ended by user."))
            activeSession = nil
            Log.ai.info("AIDevScreen session ended")
        } catch {
            // If the session was already completed (e.g. via completeSession), just clean up
            messages.append(DevScreenMessage(role: "system", content: "Session ended."))
            activeSession = nil
            Log.ai.error("AIDevScreen end failed: \(error)")
        }
    }

    func clearMessages() {
        messages.removeAll()
        activeSession = nil
        modeCompleted = false
        capturedRecommendation = nil
        lastSignals = []
    }

    // MARK: - Project Data Assembly

    private func assembleProjectData(for project: Project) async throws -> V2ContextAssembler.ProjectData {
        let phases = try await phaseRepo.fetchAll(forProject: project.id)

        var allMilestones: [Milestone] = []
        for phase in phases {
            let phaseMilestones = try await milestoneRepo.fetchAll(forPhase: phase.id)
            allMilestones.append(contentsOf: phaseMilestones)
        }

        var allTasks: [PMDomain.PMTask] = []
        for milestone in allMilestones {
            let milestoneTasks = try await taskRepo.fetchAll(forMilestone: milestone.id)
            allTasks.append(contentsOf: milestoneTasks)
        }

        var subtasksByTask: [UUID: [Subtask]] = [:]
        for task in allTasks {
            let subtasks = try await subtaskRepo.fetchAll(forTask: task.id)
            if !subtasks.isEmpty {
                subtasksByTask[task.id] = subtasks
            }
        }

        let processProfile = try await processProfileRepo.fetch(forProject: project.id)
        let deliverables = try await deliverableRepo.fetchAll(forProject: project.id)
        let sessions = try await sessionRepo.fetchAll(forProject: project.id)

        var summaries: [SessionSummary] = []
        for session in sessions {
            if let summary = try await sessionRepo.fetchSummary(forSession: session.id) {
                summaries.append(summary)
            }
        }

        let frequentlyDeferred = allTasks.filter { $0.timesDeferred >= 3 }

        return V2ContextAssembler.ProjectData(
            project: project,
            phases: phases,
            milestones: allMilestones,
            tasks: allTasks,
            subtasksByTaskId: subtasksByTask,
            processProfile: processProfile,
            deliverables: deliverables,
            sessions: sessions,
            sessionSummaries: summaries,
            frequentlyDeferredTasks: frequentlyDeferred
        )
    }
}
