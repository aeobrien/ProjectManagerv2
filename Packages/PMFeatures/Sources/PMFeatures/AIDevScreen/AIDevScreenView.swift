import SwiftUI
import PMDomain
import PMDesignSystem
import PMServices

/// Development screen for testing the AI System V2 pipeline.
/// Accessible via Settings → AI System V2 (Dev) in DEBUG builds only.
public struct AIDevScreenView: View {
    @Bindable var viewModel: AIDevScreenViewModel

    public init(viewModel: AIDevScreenViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            sessionInfoBar
            Divider()
            messageList
            if !viewModel.lastSignals.isEmpty {
                Divider()
                signalBar
            }
            if viewModel.modeCompleted {
                completionBanner
            }
            Divider()
            inputBar
        }
        .frame(minWidth: 600, minHeight: 500)
        .overlay {
            if viewModel.isCompleting {
                ZStack {
                    Color.black.opacity(0.3)
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Generating session summary...")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .ignoresSafeArea()
            }
        }
        .task {
            await viewModel.loadProjects()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text("AI System V2 Dev Screen")
                .font(.headline)

            Spacer()

            Picker("Project", selection: $viewModel.selectedProject) {
                Text("No Project").tag(nil as Project?)
                ForEach(viewModel.projects) { project in
                    Text(project.name).tag(project as Project?)
                }
            }
            .frame(maxWidth: 200)

            Picker("Mode", selection: $viewModel.selectedMode) {
                ForEach(SessionMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .frame(maxWidth: 150)

            if viewModel.selectedMode == .executionSupport {
                Picker("Sub-mode", selection: $viewModel.selectedSubMode) {
                    Text("None").tag(nil as SessionSubMode?)
                    ForEach(SessionSubMode.allCases, id: \.self) { sub in
                        Text(sub.displayName).tag(sub as SessionSubMode?)
                    }
                }
                .frame(maxWidth: 150)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Session Info

    private var sessionInfoBar: some View {
        HStack {
            Text(viewModel.sessionInfo)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if viewModel.activeSession != nil {
                if viewModel.modeCompleted {
                    Button("Complete Session") {
                        Task { await viewModel.completeSession() }
                    }
                    .font(.caption)
                    .tint(.green)
                }

                Button("Pause") {
                    Task { await viewModel.pauseSession() }
                }
                .font(.caption)

                Button("End Session") {
                    Task { await viewModel.endSession() }
                }
                .font(.caption)
                .tint(.orange)
            } else {
                Button("Start Session") {
                    Task { await viewModel.startSession() }
                }
                .font(.caption)
                .disabled(viewModel.selectedProject == nil)
            }

            Button("Clear") {
                viewModel.clearMessages()
            }
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.05))
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if viewModel.messages.isEmpty {
                        VStack(spacing: 8) {
                            Text("Select a project, choose a mode, and start a session.")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                            Text("For Exploration mode: describe your project idea after starting.")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                        .padding()
                    }
                    ForEach(viewModel.messages) { message in
                        messageRow(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func messageRow(message: DevScreenMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Text(roleLabel(message.role))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(roleColor(message.role))
                    .frame(width: 40, alignment: .trailing)

                Text(markdownAttributedString(message.content))
                    .font(.body)
                    .textSelection(.enabled)
            }

            // Show signals if present
            if !message.signals.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    ForEach(Array(message.signals.enumerated()), id: \.offset) { _, signal in
                        Text(signalLabel(signal))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(signalColor(signal).opacity(0.15))
                            .foregroundStyle(signalColor(signal))
                            .clipShape(Capsule())
                    }
                }
                .padding(.leading, 48)
            }

            // Show actions if present
            if !message.actions.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape.fill")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    Text("\(message.actions.count) action(s)")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                }
                .padding(.leading, 48)
            }
        }
    }

    // MARK: - Signal Bar

    private var signalBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("Signals:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(viewModel.lastSignals.enumerated()), id: \.offset) { _, signal in
                    signalDetail(signal)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(Color.orange.opacity(0.05))
    }

    @ViewBuilder
    private func signalDetail(_ signal: ResponseSignal) -> some View {
        switch signal {
        case .modeComplete(let mode):
            signalChip("MODE_COMPLETE: \(mode)", color: .green)
        case .processRecommendation(let deliverables):
            signalChip("RECOMMENDATION: \(deliverables)", color: .blue)
        case .planningDepth(let depth):
            signalChip("DEPTH: \(depth)", color: .blue)
        case .projectSummary(let summary):
            signalChip("SUMMARY: \(summary.prefix(50))...", color: .blue)
        case .sessionEnd:
            signalChip("SESSION_END", color: .orange)
        case .documentDraft(let type, _):
            signalChip("DRAFT: \(type)", color: .purple)
        case .structureProposal:
            signalChip("PROPOSAL", color: .purple)
        default:
            signalChip(signalLabel(signal), color: .gray)
        }
    }

    private func signalChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    // MARK: - Completion Banner

    private var completionBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.selectedMode.displayName) Complete")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("The AI has finished this mode. Click **Complete Session** to save the summary and signals.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Complete Session") {
                    Task { await viewModel.completeSession() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)
            }

            // Show captured recommendation if present
            if let recommendation = viewModel.capturedRecommendation {
                HStack(spacing: 4) {
                    Text("Recommended:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(recommendation)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.08))
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(alignment: .bottom) {
            ZStack(alignment: .topLeading) {
                if viewModel.inputText.isEmpty {
                    Text("Type a message...")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                }
                TextEditor(text: $viewModel.inputText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 36, maxHeight: 120)
                    .fixedSize(horizontal: false, vertical: true)
                    .disabled(viewModel.activeSession == nil || viewModel.isLoading)
            }
            .padding(4)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )

            VStack(spacing: 4) {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(!viewModel.canSend)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private func roleLabel(_ role: String) -> String {
        switch role {
        case "user": "You"
        case "assistant": "AI"
        case "system": "SYS"
        default: role
        }
    }

    private func roleColor(_ role: String) -> Color {
        switch role {
        case "user": .blue
        case "assistant": .green
        case "system": .orange
        default: .primary
        }
    }

    private func signalLabel(_ signal: ResponseSignal) -> String {
        switch signal {
        case .modeComplete(let mode): "MODE_COMPLETE(\(mode))"
        case .processRecommendation: "PROCESS_REC"
        case .planningDepth(let d): "DEPTH(\(d))"
        case .projectSummary: "SUMMARY"
        case .deliverablesProduced: "PRODUCED"
        case .deliverablesDeferred: "DEFERRED"
        case .structureSummary: "STRUCTURE"
        case .firstAction: "FIRST_ACTION"
        case .sessionEnd: "SESSION_END"
        case .documentDraft(let t, _): "DRAFT(\(t))"
        case .structureProposal: "PROPOSAL"
        }
    }

    private func signalColor(_ signal: ResponseSignal) -> Color {
        switch signal {
        case .modeComplete: .green
        case .sessionEnd: .orange
        case .documentDraft, .structureProposal: .purple
        default: .blue
        }
    }

    private func markdownAttributedString(_ content: String) -> AttributedString {
        (try? AttributedString(markdown: content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(content)
    }
}
