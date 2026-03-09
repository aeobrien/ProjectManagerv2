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
            deliverableStatusBar
            contextTruncationBanner
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
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 500)
        #endif
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
        .sheet(isPresented: $viewModel.showArtifactOverlay) {
            artifactOverlay
        }
        .task {
            await viewModel.loadProjects()
        }
        .onDisappear {
            Task { await viewModel.autoPauseIfNeeded() }
        }
        .onDisappear {
            Task { await viewModel.autoPauseIfNeeded() }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        #if os(iOS)
        VStack(spacing: 8) {
            Text("AI System V2 Dev Screen")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Project", selection: $viewModel.selectedProject) {
                Text("No Project").tag(nil as Project?)
                ForEach(viewModel.projects) { project in
                    Text(project.name).tag(project as Project?)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Picker("Mode", selection: $viewModel.selectedMode) {
                    ForEach(SessionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                if viewModel.selectedMode == .executionSupport {
                    Picker("Sub-mode", selection: $viewModel.selectedSubMode) {
                        Text("None").tag(nil as SessionSubMode?)
                        ForEach(SessionSubMode.allCases, id: \.self) { sub in
                            Text(sub.displayName).tag(sub as SessionSubMode?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        #else
        HStack {
            Text("AI System V2 Dev Screen")
                .font(.headline)

            Spacer()

            Picker("Project", selection: $viewModel.selectedProject) {
                Text("No Project").tag(nil as Project?)
                ForEach(viewModel.projects) { project in
                    HStack(spacing: 6) {
                        Text(project.name)
                        if let modes = viewModel.projectCompletedModes[project.id], !modes.isEmpty {
                            AIProgressIndicator(completedModes: modes)
                        }
                    }
                    .tag(project as Project?)
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
        #endif
    }

    // MARK: - Session Info

    private var sessionInfoBar: some View {
        #if os(iOS)
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.sessionInfo)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                if viewModel.activeSession != nil {
                    if viewModel.modeCompleted {
                        Button("Complete") {
                            Task { await viewModel.completeSession() }
                        }
                        .font(.caption)
                        .tint(.green)
                    }

                    Button("Pause") {
                        Task { await viewModel.pauseSession() }
                    }
                    .font(.caption)

                    Button("End") {
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

                Spacer()

                Button("Clear") {
                    viewModel.clearMessages()
                }
                .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.05))
        #else
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
        #endif
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

            // Show inline artifact card for document drafts
            // Use resolved drafts from draftHistory (not raw signal types, which may be "unknown")
            ForEach(Array(draftIndicesForMessage(message).enumerated()), id: \.offset) { _, draftIndex in
                let draft = viewModel.draftHistory[draftIndex]
                artifactCard(type: draft.type, content: draft.content)
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

    /// Map a message to the indices in draftHistory that correspond to its documentDraft signals.
    private func draftIndicesForMessage(_ message: DevScreenMessage) -> [Int] {
        // Count documentDraft signals in all messages before this one
        var offset = 0
        for msg in viewModel.messages {
            if msg.id == message.id { break }
            offset += msg.signals.filter { if case .documentDraft = $0 { return true }; return false }.count
        }
        let draftCount = message.signals.filter { if case .documentDraft = $0 { return true }; return false }.count
        let end = min(offset + draftCount, viewModel.draftHistory.count)
        guard offset < end else { return [] }
        return Array(offset..<end)
    }

    // MARK: - Artifact Card

    private func artifactCard(type: String, content: String) -> some View {
        let previewLines = content.components(separatedBy: .newlines).prefix(4).joined(separator: "\n")
        let draftVersion = viewModel.draftHistory.filter({ $0.type == type }).count
        let typeName = DeliverableType.fromSignalType(type)?.displayName ?? type

        return Button {
            viewModel.currentDraft = (type: type, content: content)
            viewModel.showArtifactOverlay = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.purple)
                    Text("\(typeName) — Draft v\(draftVersion)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)
                    Spacer()
                    Text("Tap to review")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(previewLines)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.purple.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.leading, 48)
    }

    // MARK: - Deliverable Status Bar

    @ViewBuilder
    private var deliverableStatusBar: some View {
        if viewModel.selectedMode == .definition && !viewModel.deliverableStatuses.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Text("Deliverables:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    ForEach(Array(viewModel.deliverableStatuses.sorted(by: { $0.key.rawValue < $1.key.rawValue })), id: \.key) { type, status in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(deliverableStatusColor(status))
                                .frame(width: 6, height: 6)
                            Text(type.displayName)
                                .font(.caption2)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
            .background(Color.purple.opacity(0.04))
        }
    }

    private func deliverableStatusColor(_ status: DeliverableStatus) -> Color {
        switch status {
        case .pending: .gray
        case .inProgress: .orange
        case .completed: .green
        case .revised: .blue
        }
    }

    // MARK: - Context Truncation Banner

    @ViewBuilder
    private var contextTruncationBanner: some View {
        if let warning = viewModel.contextTruncationWarning {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)

                Text("Context trimmed: \(warning)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    viewModel.contextTruncationWarning = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color.yellow.opacity(0.08))
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
            }

            Button("Complete Session") {
                Task { await viewModel.completeSession() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .trailing)

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
            #if os(macOS)
            .background(Color(nsColor: .textBackgroundColor))
            #else
            .background(Color(.systemBackground))
            #endif
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

    // MARK: - Artifact Overlay

    private var artifactOverlay: some View {
        VStack(spacing: 0) {
            // Header
            if let draft = viewModel.currentDraft {
                let draftVersion = viewModel.draftHistory.filter({ $0.type == draft.type }).count
                let typeName = DeliverableType.fromSignalType(draft.type)?.displayName ?? draft.type

                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.purple)
                    Text("\(typeName) — Draft v\(draftVersion)")
                        .font(.headline)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.showArtifactOverlay = false
                    }
                }
                .padding()

                Divider()

                // Scrollable markdown-rendered content
                ScrollView {
                    markdownDocumentView(draft.content)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                // Footer buttons
                HStack(spacing: 12) {
                    Button("Request Revision") {
                        viewModel.showArtifactOverlay = false
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Approve & Save") {
                        Task { await viewModel.approveDraft() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding()
            } else {
                Text("No draft available")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 400)
        #endif
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

    /// Render a document as a vertical stack of paragraphs with inline markdown formatting.
    /// Each line break is preserved, and headings get larger/bolder text.
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

    /// Inline markdown rendering (bold, italic, code, links) that preserves whitespace.
    private func markdownInline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}
