import SwiftUI
import PMDomain
import PMDesignSystem

/// Displays past AI session summaries for a project.
struct SessionHistoryView: View {
    let projectId: UUID
    let sessionRepo: SessionRepositoryProtocol

    @State private var sessions: [Session] = []
    @State private var summaries: [UUID: SessionSummary] = [:]
    @State private var expandedSession: UUID?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading sessions...")
                    .padding(.top, 40)
            } else if sessions.isEmpty {
                PMEmptyState(
                    icon: "bubble.left.and.bubble.right",
                    title: "No Sessions",
                    message: "AI sessions for this project will appear here after they're completed."
                )
                .frame(height: 200)
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(sessions) { session in
                        sessionCard(session)
                    }
                }
                .padding()
            }
        }
        .task {
            await loadSessions()
        }
    }

    // MARK: - Session Card

    private func sessionCard(_ session: Session) -> some View {
        PMCard {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Label(session.mode.displayName, systemImage: modeIcon(session.mode))
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let subMode = session.subMode {
                        Text("/ \(subMode.displayName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    statusBadge(session.status)
                }

                // Date info
                HStack(spacing: 12) {
                    Label(formatDate(session.createdAt), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let summary = summaries[session.id] {
                        Label("\(summary.messageCount) messages", systemImage: "text.bubble")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if summary.duration > 0 {
                            Label(formatDuration(summary.duration), systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Summary content (expandable)
                if let summary = summaries[session.id] {
                    let isExpanded = expandedSession == session.id

                    if isExpanded {
                        expandedSummaryView(summary)
                    } else {
                        compactSummaryView(summary)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedSession = isExpanded ? nil : session.id
                        }
                    } label: {
                        Text(isExpanded ? "Show less" : "Show more")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                } else {
                    Text("No summary available")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Summary Views

    private func compactSummaryView(_ summary: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !summary.contentEstablished.decisions.isEmpty {
                summaryRow(icon: "checkmark.circle", label: "Decisions", items: summary.contentEstablished.decisions, limit: 2)
            }
            if !summary.contentEstablished.progressMade.isEmpty {
                summaryRow(icon: "arrow.forward.circle", label: "Progress", items: summary.contentEstablished.progressMade, limit: 2)
            }
            if !summary.whatComesNext.nextActions.isEmpty {
                summaryRow(icon: "arrow.right", label: "Next", items: summary.whatComesNext.nextActions, limit: 1)
            }
        }
    }

    private func expandedSummaryView(_ summary: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Content Established
            if !summary.contentEstablished.decisions.isEmpty || !summary.contentEstablished.factsLearned.isEmpty || !summary.contentEstablished.progressMade.isEmpty {
                sectionHeader("Established")

                if !summary.contentEstablished.decisions.isEmpty {
                    summaryRow(icon: "checkmark.circle", label: "Decisions", items: summary.contentEstablished.decisions)
                }
                if !summary.contentEstablished.factsLearned.isEmpty {
                    summaryRow(icon: "lightbulb", label: "Facts Learned", items: summary.contentEstablished.factsLearned)
                }
                if !summary.contentEstablished.progressMade.isEmpty {
                    summaryRow(icon: "arrow.forward.circle", label: "Progress", items: summary.contentEstablished.progressMade)
                }
            }

            // Content Observed
            if !summary.contentObserved.patterns.isEmpty || !summary.contentObserved.concerns.isEmpty || !summary.contentObserved.strengths.isEmpty {
                sectionHeader("Observed")

                if !summary.contentObserved.patterns.isEmpty {
                    summaryRow(icon: "eye", label: "Patterns", items: summary.contentObserved.patterns)
                }
                if !summary.contentObserved.concerns.isEmpty {
                    summaryRow(icon: "exclamationmark.triangle", label: "Concerns", items: summary.contentObserved.concerns)
                }
                if !summary.contentObserved.strengths.isEmpty {
                    summaryRow(icon: "star", label: "Strengths", items: summary.contentObserved.strengths)
                }
            }

            // What Comes Next
            if !summary.whatComesNext.nextActions.isEmpty || !summary.whatComesNext.openQuestions.isEmpty {
                sectionHeader("What Comes Next")

                if !summary.whatComesNext.nextActions.isEmpty {
                    summaryRow(icon: "arrow.right", label: "Next Actions", items: summary.whatComesNext.nextActions)
                }
                if !summary.whatComesNext.openQuestions.isEmpty {
                    summaryRow(icon: "questionmark.circle", label: "Open Questions", items: summary.whatComesNext.openQuestions)
                }
                if let suggestedMode = summary.whatComesNext.suggestedMode {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text("Suggested next: \(suggestedMode)")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func summaryRow(icon: String, label: String, items: [String], limit: Int? = nil) -> some View {
        let displayItems = limit.map { Array(items.prefix($0)) } ?? items
        let truncated = limit.map { items.count > $0 } ?? false

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(displayItems.enumerated()), id: \.offset) { _, item in
                Text("  \(item)")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
            if truncated {
                Text("  +\(items.count - (limit ?? 0)) more...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Helpers

    private func statusBadge(_ status: SessionStatus) -> some View {
        Text(status.displayLabel)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.12))
            .foregroundStyle(statusColor(status))
            .clipShape(Capsule())
    }

    private func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .active: .blue
        case .paused: .orange
        case .completed: .green
        case .autoSummarised: .purple
        case .pendingAutoSummary: .yellow
        }
    }

    private func modeIcon(_ mode: SessionMode) -> String {
        switch mode {
        case .exploration: "magnifyingglass"
        case .definition: "doc.text"
        case .planning: "map"
        case .executionSupport: "gearshape.2"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }

    private func loadSessions() async {
        isLoading = true
        do {
            let allSessions = try await sessionRepo.fetchAll(forProject: projectId)
            // Sort by most recent first
            sessions = allSessions.sorted { $0.createdAt > $1.createdAt }

            // Load summaries for each session
            for session in sessions {
                if let summary = try await sessionRepo.fetchSummary(forSession: session.id) {
                    summaries[session.id] = summary
                }
            }
        } catch {
            // Silently fail — empty state will show
        }
        isLoading = false
    }
}

// MARK: - SessionStatus Display

extension SessionStatus {
    var displayLabel: String {
        switch self {
        case .active: "Active"
        case .paused: "Paused"
        case .completed: "Completed"
        case .autoSummarised: "Auto-summarised"
        case .pendingAutoSummary: "Pending Summary"
        }
    }
}
