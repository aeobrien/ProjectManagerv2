import SwiftUI
import PMDomain
import PMDesignSystem
import PMServices

/// View for managing project check-ins — quick logs or full AI conversations.
public struct CheckInView: View {
    let manager: CheckInFlowManager
    let project: Project
    @State private var selectedDepth: CheckInDepth = .quickLog
    @State private var userMessage = ""
    @State private var response: String?
    @State private var pendingConfirmation: BundledConfirmation?
    @State private var isRunning = false

    public init(manager: CheckInFlowManager, project: Project) {
        self.manager = manager
        self.project = project
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                depthPicker
                messageInput
                actionButtons
                responseSection
                errorSection
            }
            .padding()
        }
        .navigationTitle("Check-In: \(project.name)")
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            let urgency = manager.urgency(for: project, lastCheckIn: manager.lastCreatedRecord)
            HStack(spacing: 8) {
                Image(systemName: urgencyIcon(urgency))
                    .foregroundStyle(urgencyColor(urgency))
                Text(urgencyLabel(urgency))
                    .font(.subheadline)
                    .foregroundStyle(urgencyColor(urgency))
            }

            let days = manager.daysSinceCheckIn(manager.lastCreatedRecord)
            if days > 0 {
                Text("Last check-in: \(days) day\(days == 1 ? "" : "s") ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No previous check-ins")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Depth Picker

    private var depthPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Check-In Type")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Depth", selection: $selectedDepth) {
                Text("Quick Log").tag(CheckInDepth.quickLog)
                Text("Full Conversation").tag(CheckInDepth.fullConversation)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Message Input

    private var messageInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selectedDepth == .quickLog ? "What did you work on?" : "How is the project going?")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $userMessage)
                .frame(minHeight: 80, maxHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack {
            Button {
                Task { await runCheckIn() }
            } label: {
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Start Check-In", systemImage: "checkmark.circle")
                }
            }
            .disabled(userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRunning)

            Spacer()

            Menu("Snooze") {
                Button("1 Day") { manager.snooze(projectId: project.id, duration: .oneDay) }
                Button("3 Days") { manager.snooze(projectId: project.id, duration: .threeDays) }
                Button("1 Week") { manager.snooze(projectId: project.id, duration: .oneWeek) }
            }
        }
    }

    // MARK: - Response

    @ViewBuilder
    private var responseSection: some View {
        if let response {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("AI Summary")
                    .font(.headline)

                MarkdownText(response)
                    .font(.body)
            }
        }

        if let confirmation = pendingConfirmation {
            PMCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested Actions (\(confirmation.changes.count))")
                        .font(.subheadline.weight(.semibold))

                    ForEach(Array(confirmation.changes.enumerated()), id: \.offset) { _, change in
                        Text("- \(change.description)")
                            .font(.caption)
                    }

                    HStack {
                        Button("Apply") {
                            Task { await manager.applyConfirmation(confirmation) }
                            pendingConfirmation = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button("Skip") {
                            pendingConfirmation = nil
                        }
                        .controlSize(.small)
                    }
                }
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

    private func runCheckIn() async {
        isRunning = true
        defer { isRunning = false }

        if let result = await manager.performCheckIn(
            project: project,
            depth: selectedDepth,
            userMessage: userMessage
        ) {
            response = result.response
            pendingConfirmation = result.confirmation
            userMessage = ""
        }
    }

    private func urgencyIcon(_ urgency: CheckInUrgency) -> String {
        switch urgency {
        case .none: "checkmark.circle"
        case .gentle: "info.circle"
        case .moderate: "exclamationmark.circle"
        case .prominent: "exclamationmark.triangle"
        }
    }

    private func urgencyColor(_ urgency: CheckInUrgency) -> Color {
        switch urgency {
        case .none: .green
        case .gentle: .blue
        case .moderate: .orange
        case .prominent: .red
        }
    }

    private func urgencyLabel(_ urgency: CheckInUrgency) -> String {
        switch urgency {
        case .none: "Up to date"
        case .gentle: "Check-in suggested"
        case .moderate: "Check-in recommended"
        case .prominent: "Check-in overdue"
        }
    }
}
