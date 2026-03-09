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
    private let documentRepo: DocumentRepositoryProtocol?
    private let codebaseIndexer: CodebaseIndexer?
    private let codebaseRepo: CodebaseRepositoryProtocol?

    // MARK: - State

    var projects: [Project] = []
    var projectCompletedModes: [UUID: Set<SessionMode>] = [:]
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

    /// The most recent document draft from signals.
    var currentDraft: (type: String, content: String)?

    /// All drafts received in this session with version tracking.
    var draftHistory: [(type: String, content: String, version: Int)] = []

    /// Controls the artifact overlay sheet.
    var showArtifactOverlay = false

    /// Tracks deliverable statuses for the current project.
    var deliverableStatuses: [DeliverableType: DeliverableStatus] = [:]

    /// Context truncation warning from the most recent message, if any.
    var contextTruncationWarning: String?

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
        signalParser: ResponseSignalParser = ResponseSignalParser(),
        documentRepo: DocumentRepositoryProtocol? = nil,
        codebaseIndexer: CodebaseIndexer? = nil,
        codebaseRepo: CodebaseRepositoryProtocol? = nil
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
        self.documentRepo = documentRepo
        self.codebaseIndexer = codebaseIndexer
        self.codebaseRepo = codebaseRepo
    }

    // MARK: - Actions

    func loadProjects() async {
        do {
            projects = try await projectRepo.fetchAll()
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

            // Load completed AI onboarding modes per project
            var modes: [UUID: Set<SessionMode>] = [:]
            for project in projects {
                let sessions = (try? await sessionRepo.fetchAll(forProject: project.id)) ?? []
                let completed = Set(sessions
                    .filter { $0.status == .completed || $0.status == .autoSummarised }
                    .map(\.mode))
                if !completed.isEmpty {
                    modes[project.id] = completed
                }
            }
            projectCompletedModes = modes

            Log.ai.debug("AIDevScreen loaded \(self.projects.count) projects")
        } catch {
            errorMessage = error.localizedDescription
            Log.ai.error("AIDevScreen failed to load projects: \(error)")
        }
    }

    /// Auto-pause the active session when the sheet is dismissed.
    /// Called from onDisappear to prevent orphaned active sessions.
    func autoPauseIfNeeded() async {
        guard activeSession != nil else { return }
        Log.ai.info("AIDevScreen auto-pausing session on dismiss")
        await pauseSession()
    }

    func startSession() async {
        guard let project = selectedProject else {
            errorMessage = "Select a project first"
            return
        }

        do {
            // Check for resumable session matching project + mode + subMode
            if let resumable = try await conversationManager.resumableSession(
                forProject: project.id,
                mode: selectedMode,
                subMode: selectedSubMode
            ) {
                activeSession = try await conversationManager.resumeSession(resumable.id)
                // Clean up any other stale sessions for this project
                try await conversationManager.cleanupStaleSessions(forProject: project.id, excluding: resumable.id)
                // Load existing messages, re-parsing signals from assistant messages
                let sessionMessages = try await conversationManager.messages(forSession: resumable.id)
                messages = sessionMessages.map { msg in
                    if msg.role == .assistant {
                        let parsed = signalParser.parse(msg.content, parseActions: false)
                        return DevScreenMessage(
                            role: "assistant",
                            content: parsed.naturalLanguage,
                            signals: parsed.signals,
                            timestamp: msg.timestamp
                        )
                    } else {
                        return DevScreenMessage(
                            role: "user",
                            content: msg.content,
                            timestamp: msg.timestamp
                        )
                    }
                }
                // Rebuild draft history from resumed messages
                rebuildDraftHistory()
                Log.ai.info("AIDevScreen resumed session \(resumable.id) (was \(resumable.status.rawValue))")
                await loadDeliverableStatuses()
            } else {
                // Clean up stale sessions before creating a new one
                try await conversationManager.cleanupStaleSessions(forProject: project.id, excluding: nil)
                activeSession = try await conversationManager.startSession(
                    projectId: project.id,
                    mode: selectedMode,
                    subMode: selectedSubMode
                )
                messages.removeAll()
                modeCompleted = false
                capturedRecommendation = nil
                currentDraft = nil
                draftHistory = []
                lastSignals = []
                Log.ai.info("AIDevScreen started new \(self.selectedMode.rawValue) session")
                await loadDeliverableStatuses()
            }

            // Ensure codebases are indexed (skips if already in memory)
            if let indexer = codebaseIndexer, let cbRepo = codebaseRepo {
                let codebases = (try? await cbRepo.fetchAll(forProject: project.id)) ?? []
                for codebase in codebases {
                    do {
                        try await indexer.indexCodebaseIfNeeded(codebase)
                    } catch {
                        Log.ai.error("Failed to index codebase '\(codebase.name)': \(error)")
                    }
                }
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

            // Update truncation warning
            if let info = result.truncationInfo, info.wasTruncated {
                contextTruncationWarning = info.summary
                Log.ai.notice("Context truncation: \(info.summary)")
            } else {
                contextTruncationWarning = nil
            }

            // Parse signals from the raw response
            let parsed = signalParser.parse(result.naturalLanguage, parseActions: false)

            lastSignals = parsed.signals
            modeCompleted = parsed.signals.contains { if case .modeComplete = $0 { return true }; return false }

            // Capture process recommendation and document drafts from signals
            for signal in parsed.signals {
                if case .processRecommendation(let deliverables) = signal {
                    capturedRecommendation = deliverables
                }
                if case .documentDraft(let rawType, let content) = signal {
                    // Normalise the type string to a known DeliverableType
                    var resolvedType = DeliverableType.fromSignalType(rawType)
                    // If the LLM omitted the type (comes through as "unknown"), infer from context
                    if resolvedType == nil && (rawType == "unknown" || rawType.isEmpty) {
                        resolvedType = inferDeliverableType()
                        Log.ai.info("AIDevScreen inferred draft type: \(resolvedType?.rawValue ?? "nil") (raw was '\(rawType)')")
                    }
                    let typeKey = resolvedType?.rawValue ?? rawType
                    let version = (draftHistory.filter { $0.type == typeKey }.count) + 1
                    currentDraft = (type: typeKey, content: content)
                    draftHistory.append((type: typeKey, content: content, version: version))
                    if let resolvedType {
                        deliverableStatuses[resolvedType] = .inProgress
                    }
                    Log.ai.info("AIDevScreen captured draft: \(typeKey) v\(version) (raw: \(rawType))")
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

            // Seed pending deliverables from exploration recommendation
            if session.mode == .exploration, let recommendation = capturedRecommendation {
                await seedDeliverablesFromRecommendation(recommendation, projectId: session.projectId)
                Log.ai.info("AIDevScreen seeded deliverables from exploration recommendation")
            }

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
        currentDraft = nil
        draftHistory = []
        deliverableStatuses = [:]
        lastSignals = []
    }

    /// Approve the current draft and save it as a Deliverable entity.
    func approveDraft() async {
        guard let draft = currentDraft, let project = selectedProject else {
            Log.ai.error("AIDevScreen approveDraft: no current draft or project")
            return
        }

        guard let deliverableType = DeliverableType.fromSignalType(draft.type) else {
            errorMessage = "Unknown deliverable type: \(draft.type)"
            Log.ai.error("AIDevScreen approveDraft: unrecognised type '\(draft.type)'")
            showArtifactOverlay = false
            return
        }

        Log.ai.info("AIDevScreen approving draft: \(deliverableType.rawValue)")

        do {
            // Check for existing deliverable of this type
            let existing = try await deliverableRepo.fetchAll(forProject: project.id, type: deliverableType)

            if var deliverable = existing.first {
                // Update existing deliverable
                let version = deliverable.versionHistory.count + 1
                deliverable.content = draft.content
                deliverable.status = .completed
                deliverable.updatedAt = Date()
                deliverable.versionHistory.append(Deliverable.DeliverableVersion(
                    version: version,
                    content: draft.content,
                    changeNote: "Approved from definition session",
                    savedAt: Date()
                ))
                try await deliverableRepo.save(deliverable)
                Log.ai.info("AIDevScreen updated deliverable \(deliverable.id) to v\(version)")
            } else {
                // Create new deliverable
                let deliverable = Deliverable(
                    projectId: project.id,
                    type: deliverableType,
                    status: .completed,
                    title: deliverableType.displayName,
                    content: draft.content,
                    versionHistory: [
                        Deliverable.DeliverableVersion(
                            version: 1,
                            content: draft.content,
                            changeNote: "Initial draft approved",
                            savedAt: Date()
                        )
                    ]
                )
                try await deliverableRepo.save(deliverable)
                Log.ai.info("AIDevScreen created deliverable \(deliverable.id)")
            }

            // Also save/update a Document so it appears in the Documents tab
            if let documentRepo {
                let docType = documentType(from: deliverableType)
                let existingDocs = try await documentRepo.fetchByType(docType, projectId: project.id)

                if var doc = existingDocs.first {
                    doc.content = draft.content
                    doc.version += 1
                    doc.updatedAt = Date()
                    try await documentRepo.save(doc)
                    Log.ai.info("AIDevScreen updated document '\(doc.title)' to v\(doc.version)")
                } else {
                    let doc = Document(
                        projectId: project.id,
                        type: docType,
                        title: deliverableType.displayName,
                        content: draft.content
                    )
                    try await documentRepo.save(doc)
                    Log.ai.info("AIDevScreen created document '\(doc.title)'")
                }
            }

            deliverableStatuses[deliverableType] = .completed
            showArtifactOverlay = false
            messages.append(DevScreenMessage(
                role: "system",
                content: "\(deliverableType.displayName) approved and saved."
            ))
        } catch {
            errorMessage = "Failed to save deliverable: \(error.localizedDescription)"
            Log.ai.error("AIDevScreen approve draft failed: \(error)")
        }
    }

    /// Map a DeliverableType to the corresponding DocumentType for the Documents tab.
    private func documentType(from deliverableType: DeliverableType) -> DocumentType {
        switch deliverableType {
        case .visionStatement: return .visionStatement
        case .technicalBrief: return .technicalBrief
        case .setupSpecification, .researchPlan, .creativeBrief: return .other
        }
    }

    /// Load deliverable statuses for the current project.
    func loadDeliverableStatuses() async {
        guard let project = selectedProject else { return }
        do {
            let deliverables = try await deliverableRepo.fetchAll(forProject: project.id)
            var statuses: [DeliverableType: DeliverableStatus] = [:]
            for d in deliverables {
                statuses[d.type] = d.status
            }
            deliverableStatuses = statuses
        } catch {
            Log.ai.error("AIDevScreen failed to load deliverable statuses: \(error)")
        }
    }

    /// Rebuild draft history from loaded messages (used after resume).
    private func rebuildDraftHistory() {
        draftHistory = []
        currentDraft = nil
        for message in messages {
            for signal in message.signals {
                if case .documentDraft(let rawType, let content) = signal {
                    let resolvedType = DeliverableType.fromSignalType(rawType)
                    let typeKey = resolvedType?.rawValue ?? rawType
                    let version = (draftHistory.filter { $0.type == typeKey }.count) + 1
                    draftHistory.append((type: typeKey, content: content, version: version))
                    currentDraft = (type: typeKey, content: content)
                }
            }
        }
        if !draftHistory.isEmpty {
            Log.ai.info("AIDevScreen rebuilt \(self.draftHistory.count) drafts from resumed session")
        }
    }

    /// Infer the deliverable type when the LLM omits it from the DOCUMENT_DRAFT tag.
    /// Falls back to the first in-progress or pending deliverable for this project.
    private func inferDeliverableType() -> DeliverableType? {
        // Check which deliverable is currently in-progress or pending
        if let inProgress = deliverableStatuses.first(where: { $0.value == .inProgress })?.key {
            return inProgress
        }
        if let pending = deliverableStatuses.first(where: { $0.value == .pending })?.key {
            return pending
        }
        return nil
    }

    /// Seed pending deliverables from an exploration recommendation.
    private func seedDeliverablesFromRecommendation(_ recommendation: String, projectId: UUID) async {
        let typeStrings = recommendation.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for typeString in typeStrings {
            guard let deliverableType = DeliverableType(rawValue: typeString) else { continue }
            // Only create if one doesn't already exist
            let existing = (try? await deliverableRepo.fetchAll(forProject: projectId, type: deliverableType)) ?? []
            if existing.isEmpty {
                let deliverable = Deliverable(
                    projectId: projectId,
                    type: deliverableType,
                    status: .pending,
                    title: typeString
                )
                try? await deliverableRepo.save(deliverable)
                deliverableStatuses[deliverableType] = .pending
                Log.ai.info("AIDevScreen seeded pending deliverable: \(typeString)")
            }
        }
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
        let documents = (try? await documentRepo?.fetchAll(forProject: project.id)) ?? []
        let sessions = try await sessionRepo.fetchAll(forProject: project.id)

        var summaries: [SessionSummary] = []
        for session in sessions {
            if let summary = try await sessionRepo.fetchSummary(forSession: session.id) {
                summaries.append(summary)
            }
        }

        let frequentlyDeferred = allTasks.filter { $0.timesDeferred >= 3 }

        // Fetch relevant code context based on last user message
        var codeContext: String?
        if let indexer = codebaseIndexer, codebaseRepo != nil {
            let query = messages.last(where: { $0.role == "user" })?.content ?? project.name
            Log.ai.debug("Codebase search query: '\(query.prefix(100))'")
            do {
                let results = try await indexer.searchCode(projectId: project.id, query: query, limit: 5)
                Log.ai.info("Codebase search returned \(results.count) results (scores: \(results.map { String(format: "%.3f", $0.score) }.joined(separator: ", ")))")
                if !results.isEmpty {
                    codeContext = results.map { "// \($0.stored.text)" }.joined(separator: "\n\n")
                    Log.ai.debug("Codebase context size: \(codeContext?.count ?? 0) chars")
                }
            } catch {
                Log.ai.error("Codebase search failed: \(error)")
            }

            // Note: file listing fallback removed — the overview document generated during
            // indexing is included automatically via the documents context component.
        } else {
            Log.ai.debug("No codebaseIndexer available for project context")
        }

        return V2ContextAssembler.ProjectData(
            project: project,
            phases: phases,
            milestones: allMilestones,
            tasks: allTasks,
            subtasksByTaskId: subtasksByTask,
            processProfile: processProfile,
            deliverables: deliverables,
            documents: documents,
            sessions: sessions,
            sessionSummaries: summaries,
            frequentlyDeferredTasks: frequentlyDeferred,
            codebaseContext: codeContext
        )
    }
}
