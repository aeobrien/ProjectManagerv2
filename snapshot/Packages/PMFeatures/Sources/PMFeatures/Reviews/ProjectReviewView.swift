import SwiftUI
import PMDomain
import PMDesignSystem

/// View for AI-powered project portfolio reviews — patterns, alerts, and recommendations.
public struct ProjectReviewView: View {
    let manager: ProjectReviewManager
    @State private var followUpText = ""

    public init(manager: ProjectReviewManager) {
        self.manager = manager
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                patternsSection
                waitingAlertsSection
                conversationSection
                errorSection
            }
            .padding()
        }
        .navigationTitle("Project Review")
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Portfolio Review")
                .font(.title2.weight(.semibold))

            Text("AI-powered analysis of your active projects to identify patterns, blockers, and recommendations.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                Task { await manager.startReview() }
            } label: {
                if manager.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label(manager.reviewResponse == nil ? "Start Review" : "Refresh Review", systemImage: "sparkles")
                }
            }
            .disabled(manager.isLoading)
        }
    }

    // MARK: - Patterns

    @ViewBuilder
    private var patternsSection: some View {
        if !manager.crossProjectPatterns.isEmpty {
            PMCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Cross-Project Patterns", systemImage: "exclamationmark.triangle")
                        .font(.headline)
                        .foregroundStyle(.orange)

                    ForEach(manager.crossProjectPatterns, id: \.description) { pattern in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: patternIcon(pattern.type))
                                .foregroundStyle(patternColor(pattern.type))
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                if let name = pattern.projectName {
                                    Text(name)
                                        .font(.subheadline.weight(.semibold))
                                }
                                Text(pattern.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Waiting Alerts

    @ViewBuilder
    private var waitingAlertsSection: some View {
        if !manager.waitingItemAlerts.isEmpty {
            PMCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Waiting Items", systemImage: "clock.badge.exclamationmark")
                        .font(.headline)

                    ForEach(manager.waitingItemAlerts, id: \.taskName) { alert in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(alert.taskName)
                                    .font(.subheadline)
                                Text(alert.projectName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if alert.isPastDue {
                                Text("Past due")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else {
                                Text("Check: \(alert.checkBackDate, style: .date)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Conversation

    @ViewBuilder
    private var conversationSection: some View {
        if !manager.messages.isEmpty {
            Divider()

            ForEach(Array(manager.messages.enumerated()), id: \.offset) { _, message in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: message.role == "user" ? "person.circle" : "sparkles")
                        .foregroundStyle(message.role == "user" ? .blue : .purple)

                    if message.role == "user" {
                        Text(message.content)
                            .font(.body)
                            .textSelection(.enabled)
                    } else {
                        MarkdownText(message.content)
                            .font(.body)
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                TextField("Ask a follow-up...", text: $followUpText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    let text = followUpText
                    followUpText = ""
                    Task { await manager.sendFollowUp(text) }
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isLoading)
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = manager.error {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Helpers

    private func patternIcon(_ type: PatternType) -> String {
        switch type {
        case .stall: "pause.circle"
        case .blockedAccumulation: "xmark.circle"
        case .deferralPattern: "arrow.uturn.backward"
        case .waitingAccumulation: "clock.fill"
        }
    }

    private func patternColor(_ type: PatternType) -> Color {
        switch type {
        case .stall: .orange
        case .blockedAccumulation: .red
        case .deferralPattern: .yellow
        case .waitingAccumulation: .blue
        }
    }
}
