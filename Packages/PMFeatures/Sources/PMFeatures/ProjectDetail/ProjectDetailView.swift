import SwiftUI
import Combine
import PMDomain
import PMDesignSystem
import PMServices

/// Tabbed view showing a project's full detail: overview, roadmap, documents, history.
public struct ProjectDetailView: View {
    @Bindable var viewModel: ProjectDetailViewModel
    var roadmapViewModel: ProjectRoadmapViewModel?
    var documentViewModel: DocumentViewModel?
    var analyticsViewModel: AnalyticsViewModel?
    var adversarialReviewManager: AdversarialReviewManager?
    var sessionRepo: SessionRepositoryProtocol?
    var codebaseRepo: CodebaseRepositoryProtocol?
    var codebaseIndexer: CodebaseIndexer?
    @State private var selectedTab: DetailTab = .roadmap
    @State private var showRetrospective = false
    @State private var showCodebaseSheet = false
    @State private var codebases: [Codebase] = []
    /// Timer-driven refresh so indexing state from CodebaseIndexer is reflected in the UI.
    @State private var indexingRefreshTick = false

    public init(
        viewModel: ProjectDetailViewModel,
        roadmapViewModel: ProjectRoadmapViewModel? = nil,
        documentViewModel: DocumentViewModel? = nil,
        analyticsViewModel: AnalyticsViewModel? = nil,
        adversarialReviewManager: AdversarialReviewManager? = nil,
        sessionRepo: SessionRepositoryProtocol? = nil,
        codebaseRepo: CodebaseRepositoryProtocol? = nil,
        codebaseIndexer: CodebaseIndexer? = nil
    ) {
        self.viewModel = viewModel
        self.roadmapViewModel = roadmapViewModel
        self.documentViewModel = documentViewModel
        self.analyticsViewModel = analyticsViewModel
        self.adversarialReviewManager = adversarialReviewManager
        self.sessionRepo = sessionRepo
        self.codebaseRepo = codebaseRepo
        self.codebaseIndexer = codebaseIndexer
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Retrospective prompt banner
            if let phase = viewModel.phaseNeedingRetrospective {
                retrospectiveBanner(phase: phase)
            }

            projectHeader
            Divider()
            tabContent
        }
        .navigationTitle(viewModel.project.name)
        .task { await viewModel.load(); await loadCodebases() }
        // Poll indexer state every 1s so the UI reflects ongoing indexing progress
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard codebaseIndexer != nil else { return }
            indexingRefreshTick.toggle()
            // Reload codebases if any indexing just finished (to pick up lastIndexedAt updates)
            let anyIndexing = codebases.contains { codebaseIndexer?.isIndexing($0.id) == true }
            if !anyIndexing && codebases.contains(where: { $0.lastIndexedAt == nil }) {
                Task { await loadCodebases() }
            }
        }
        .sheet(isPresented: $showCodebaseSheet, onDismiss: {
            Task {
                await loadCodebases()
                autoIndexNewCodebases()
            }
        }) {
            if let codebaseRepo {
                CodebaseAddSheet(projectId: viewModel.project.id, codebaseRepo: codebaseRepo)
            }
        }
        .sheet(isPresented: $showRetrospective) {
            if let manager = viewModel.retrospectiveManager {
                NavigationStack {
                    RetrospectiveView(manager: manager, project: viewModel.project)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    showRetrospective = false
                                    viewModel.dismissRetrospectivePrompt()
                                }
                            }
                        }
                }
                #if os(macOS)
                .frame(minWidth: 500, minHeight: 400)
                #endif
            }
        }
    }

    // MARK: - Retrospective Banner

    private func retrospectiveBanner(phase: Phase) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "flag.checkered")
                .foregroundStyle(.green)
            Text("Phase \"\(phase.name)\" is complete!")
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Button("Start Retrospective") {
                showRetrospective = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            if let manager = viewModel.retrospectiveManager {
                Menu("Snooze") {
                    Button("1 Day") {
                        manager.snooze(phase, days: 1)
                        viewModel.dismissRetrospectivePrompt()
                    }
                    Button("3 Days") {
                        manager.snooze(phase, days: 3)
                        viewModel.dismissRetrospectivePrompt()
                    }
                    Button("1 Week") {
                        manager.snooze(phase, days: 7)
                        viewModel.dismissRetrospectivePrompt()
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.green.opacity(0.08))
    }

    // MARK: - Header

    private var projectHeader: some View {
        HStack(spacing: 12) {
            if let slot = viewModel.project.focusSlotIndex {
                Circle()
                    .fill(SlotColour.forIndex(slot))
                    .frame(width: 12, height: 12)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.project.name)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 8) {
                    Label(viewModel.project.lifecycleState.rawValue.capitalized,
                          systemImage: viewModel.project.lifecycleState.iconName)
                        .foregroundStyle(viewModel.project.lifecycleState.color)
                        .font(.caption)

                    if let dod = viewModel.project.definitionOfDone, !dod.isEmpty {
                        Text("·").foregroundStyle(.quaternary)
                        Text(dod)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Phase progress summary
            let totalPhases = viewModel.phases.count
            let completedPhases = viewModel.phases.filter { $0.status == .completed }.count
            if totalPhases > 0 {
                PMProgressLabel(
                    progress: Double(completedPhases) / Double(totalPhases),
                    style: .fraction(total: totalPhases)
                )
            }
        }
        .padding()
    }

    // MARK: - Tabs

    private var tabContent: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            #if os(iOS)
            .pickerStyle(.menu)
            #else
            .pickerStyle(.segmented)
            #endif
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch selectedTab {
            case .roadmap:
                RoadmapView(viewModel: viewModel)
            case .timeline:
                if let roadmapVM = roadmapViewModel {
                    ProjectRoadmapView(viewModel: roadmapVM)
                } else {
                    PMEmptyState(icon: "map", title: "Timeline", message: "Timeline view not available.")
                }
            case .documents:
                VStack(spacing: 0) {
                    if let documentVM = documentViewModel {
                        DocumentEditorView(viewModel: documentVM)
                    } else {
                        PMEmptyState(icon: "doc", title: "Documents", message: "Document editing not available.")
                    }
                    if codebaseRepo != nil {
                        Divider()
                        codebaseSection
                    }
                }
            case .overview:
                OverviewTabView(viewModel: viewModel)
            case .analytics:
                if let analyticsVM = analyticsViewModel {
                    AnalyticsView(viewModel: analyticsVM, project: viewModel.project)
                } else {
                    PMEmptyState(icon: "chart.bar", title: "Analytics", message: "Analytics not available.")
                }
            case .review:
                if let reviewMgr = adversarialReviewManager {
                    AdversarialReviewView(manager: reviewMgr, project: viewModel.project)
                } else {
                    PMEmptyState(icon: "sparkles", title: "Review", message: "Adversarial review not available.")
                }
            case .sessions:
                if let sessionRepo {
                    SessionHistoryView(projectId: viewModel.project.id, sessionRepo: sessionRepo)
                } else {
                    PMEmptyState(icon: "bubble.left.and.bubble.right", title: "Sessions", message: "Session history not available.")
                }
            }
        }
    }
}

// MARK: - Codebase Section

extension ProjectDetailView {
    var codebaseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Codebases", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.headline)
                Spacer()
                Button {
                    showCodebaseSheet = true
                } label: {
                    Label("Add Codebase", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if codebases.isEmpty {
                Text("No codebases linked. Add one to give the AI access to your source code.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            } else {
                // Read indexer state (indexingRefreshTick forces re-evaluation each timer tick)
                let _ = indexingRefreshTick
                ForEach(codebases) { codebase in
                    let isIndexing = codebaseIndexer?.isIndexing(codebase.id) ?? false
                    let errorMsg = codebaseIndexer?.indexingError(for: codebase.id)
                    HStack(spacing: 8) {
                        Image(systemName: codebase.sourceType == .local ? "folder.fill" : "network")
                            .foregroundStyle(codebase.sourceType == .local ? .blue : .purple)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(codebase.name)
                                .font(.body)
                            if isIndexing {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .controlSize(.mini)
                                    Text("Indexing\u{2026}")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            } else if let error = errorMsg {
                                Text(error)
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                                    .lineLimit(1)
                            } else if let lastIndexed = codebase.lastIndexedAt {
                                Text("Indexed: \(lastIndexed, style: .relative) ago")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Not yet indexed")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(codebase.sourceType == .local ? "Local" : "GitHub")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(Capsule())
                        if codebaseIndexer != nil {
                            Button {
                                triggerIndexing(for: codebase)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.borderless)
                            .disabled(isIndexing)
                            .help("Index now")
                        }
                        Button(role: .destructive) {
                            Task { await deleteCodebase(codebase) }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Delete codebase")
                    }
                    .padding(.horizontal)
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { await deleteCodebase(codebase) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    func loadCodebases() async {
        guard let codebaseRepo else { return }
        codebases = (try? await codebaseRepo.fetchAll(forProject: viewModel.project.id)) ?? []
    }

    private func deleteCodebase(_ codebase: Codebase) async {
        guard let codebaseRepo else { return }
        await codebaseIndexer?.cleanupCodebase(codebase)
        try? await codebaseRepo.delete(id: codebase.id)
        codebaseIndexer?.clearError(for: codebase.id)
        await loadCodebases()
    }

    func triggerIndexing(for codebase: Codebase) {
        guard let codebaseIndexer, !codebaseIndexer.isIndexing(codebase.id) else { return }
        codebaseIndexer.clearError(for: codebase.id)
        Task {
            // indexCodebase tracks its own start/finish state
            try? await codebaseIndexer.indexCodebase(codebase)
            await loadCodebases()
        }
    }

    func autoIndexNewCodebases() {
        for codebase in codebases where codebase.lastIndexedAt == nil {
            triggerIndexing(for: codebase)
        }
    }
}

enum DetailTab: String, CaseIterable {
    case roadmap = "Roadmap"
    case timeline = "Timeline"
    case documents = "Documents"
    case analytics = "Analytics"
    case review = "Review"
    case sessions = "Sessions"
    case overview = "Overview"
}

// MARK: - Overview Tab

struct OverviewTabView: View {
    let viewModel: ProjectDetailViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let repoURL = viewModel.project.repositoryURL, !repoURL.isEmpty {
                    PMSectionHeader("Repository")
                    if let url = URL(string: repoURL) {
                        Link(repoURL, destination: url)
                            .font(.body)
                            .padding(.horizontal)
                    } else {
                        Text(repoURL)
                            .font(.body)
                            .padding(.horizontal)
                    }
                }

                if let dod = viewModel.project.definitionOfDone, !dod.isEmpty {
                    PMSectionHeader("Definition of Done")
                    Text(dod)
                        .font(.body)
                        .padding(.horizontal)
                }

                if let transcript = viewModel.project.quickCaptureTranscript, !transcript.isEmpty {
                    PMSectionHeader("Original Capture")
                    markdownDocumentView(transcript)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                if let notes = viewModel.project.notes, !notes.isEmpty {
                    PMSectionHeader("Notes")
                    Text(notes)
                        .font(.body)
                        .padding(.horizontal)
                }

                PMSectionHeader("Phases", subtitle: "\(viewModel.phases.count) phases")
                ForEach(viewModel.phases) { phase in
                    HStack {
                        Text(phase.name)
                        Spacer()
                        Text(phase.status.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                if viewModel.phases.isEmpty {
                    PMEmptyState(icon: "list.bullet", title: "No Phases", message: "Add phases in the Roadmap tab.")
                        .frame(height: 200)
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Helpers

    /// Render a document as a vertical stack of paragraphs with inline markdown formatting.
    @ViewBuilder
    private func markdownDocumentView(_ content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(content.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    Spacer().frame(height: 4)
                } else if line.hasPrefix("# ") {
                    Text(markdownInline(String(line.dropFirst(2))))
                        .font(.title2)
                        .fontWeight(.bold)
                        .textSelection(.enabled)
                } else if line.hasPrefix("## ") {
                    Text(markdownInline(String(line.dropFirst(3))))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .textSelection(.enabled)
                } else if line.hasPrefix("### ") {
                    Text(markdownInline(String(line.dropFirst(4))))
                        .font(.headline)
                        .textSelection(.enabled)
                } else if line.hasPrefix("#### ") {
                    Text(markdownInline(String(line.dropFirst(5))))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .textSelection(.enabled)
                } else if line.trimmingCharacters(in: .whitespaces).hasPrefix("- ") || line.trimmingCharacters(in: .whitespaces).hasPrefix("* ") {
                    let bullet = line.trimmingCharacters(in: .whitespaces)
                    let textContent = String(bullet.dropFirst(2))
                    HStack(alignment: .top, spacing: 6) {
                        Text("\u{2022}")
                        Text(markdownInline(textContent))
                            .textSelection(.enabled)
                    }
                    .font(.body)
                } else if line.trimmingCharacters(in: .whitespaces).hasPrefix("---") {
                    Divider()
                } else {
                    Text(markdownInline(line))
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func markdownInline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}
