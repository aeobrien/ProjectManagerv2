import SwiftUI
import PMDomain
import PMDesignSystem

/// View for conducting project retrospectives after phase completions.
public struct RetrospectiveView: View {
    @Bindable var manager: RetrospectiveFlowManager
    let project: Project
    @State private var followUpText = ""

    public init(manager: RetrospectiveFlowManager, project: Project) {
        self.manager = manager
        self.project = project
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepContent
                errorSection
            }
            .padding()
        }
        .navigationTitle("Retrospective: \(project.name)")
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch manager.step {
        case .idle:
            idleView
        case .promptUser:
            promptView
        case .reflecting:
            reflectionView
        case .aiConversation:
            conversationView
        case .completed:
            completedView
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let phase = manager.targetPhase {
                PMCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Phase completed: \(phase.name)", systemImage: "flag.checkered")
                            .font(.headline)

                        Text("A retrospective helps capture what you learned and improve your workflow.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Return briefing
            if let briefing = manager.returnBriefing {
                PMCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Return Briefing", systemImage: "doc.text")
                            .font(.subheadline.weight(.semibold))
                        Text(briefing)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
            }

            Button {
                manager.beginReflection()
            } label: {
                Label("Start Retrospective", systemImage: "text.bubble")
            }
            .buttonStyle(.borderedProminent)

            if manager.isDormant(project) {
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz")
                        .foregroundStyle(.orange)
                    Text("This project has been dormant")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Generate Return Briefing") {
                    Task { await manager.generateReturnBriefing(for: project) }
                }
                .controlSize(.small)
            }
        }
    }

    // MARK: - Prompt

    private var promptView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ready for Retrospective")
                .font(.headline)

            if let phase = manager.targetPhase {
                Text("Phase \"\(phase.name)\" is complete. Take a moment to reflect on what went well and what could improve.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Begin Reflection") {
                    manager.beginReflection()
                }
                .buttonStyle(.borderedProminent)

                if let phase = manager.targetPhase {
                    Menu("Snooze") {
                        Button("1 Day") { manager.snooze(phase, days: 1) }
                        Button("3 Days") { manager.snooze(phase, days: 3) }
                        Button("1 Week") { manager.snooze(phase, days: 7) }
                    }
                }
            }
        }
    }

    // MARK: - Reflection

    private var reflectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Reflection")
                .font(.headline)

            Text("What went well? What was challenging? What would you do differently?")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $manager.reflectionText)
                .frame(minHeight: 120, maxHeight: 250)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )

            Button {
                Task { await manager.submitReflection() }
            } label: {
                if manager.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Submit Reflection", systemImage: "paperplane")
                }
            }
            .disabled(manager.reflectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isLoading)
        }
    }

    // MARK: - Conversation

    private var conversationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Discussion")
                .font(.headline)

            // Messages
            ForEach(Array(manager.messages.enumerated()), id: \.offset) { _, message in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: message.role == "user" ? "person.circle" : "sparkles")
                        .foregroundStyle(message.role == "user" ? .blue : .purple)

                    Text(message.content)
                        .font(.body)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 4)
            }

            if let summary = manager.aiSummary {
                PMCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Summary", systemImage: "doc.text")
                            .font(.subheadline.weight(.semibold))
                        Text(summary)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
            }

            // Follow-up input
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

            Button {
                Task { await manager.completeRetrospective() }
            } label: {
                Label("Complete Retrospective", systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Retrospective Complete")
                .font(.title2.weight(.semibold))

            if let summary = manager.aiSummary {
                Text(summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Start Fresh") {
                manager.reset()
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Error

    @ViewBuilder
    private var errorSection: some View {
        if let error = manager.error {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}
