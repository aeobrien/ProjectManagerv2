import SwiftUI
import PMDomain
import PMDesignSystem
import PMServices

/// Full chat interface with message bubbles, voice input, and action confirmation.
public struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var voiceManager = VoiceInputManager()
    @State private var showVoiceInput = false
    @State private var showCapabilities = false
    @State private var showHistory = false

    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider()
            messageList
            Divider()

            if let confirmation = viewModel.pendingConfirmation {
                confirmationBar(confirmation)
                Divider()
            }

            inputBar
        }
        .task {
            await viewModel.loadProjects()
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack {
            // Project selector
            Picker("Project", selection: $viewModel.selectedProjectId) {
                Text("General").tag(UUID?.none)
                ForEach(viewModel.projects) { project in
                    Text(project.name).tag(Optional(project.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 200)

            // Conversation type
            Picker("Mode", selection: $viewModel.conversationType) {
                Text("General").tag(ConversationType.general)
                Text("Quick Log").tag(ConversationType.checkInQuickLog)
                Text("Full Check-in").tag(ConversationType.checkInFull)
                Text("Review").tag(ConversationType.review)
            }
            .labelsHidden()
            .frame(maxWidth: 150)

            Spacer()

            Button {
                showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Conversation history")
            .popover(isPresented: $showHistory) {
                conversationHistoryPopover
            }

            Button {
                showCapabilities = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("AI capabilities")
            .popover(isPresented: $showCapabilities) {
                aiCapabilitiesPopover
            }

            Button {
                viewModel.clearChat()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear conversation")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - AI Capabilities Popover

    private var aiCapabilitiesPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Actions")
                .font(.headline)

            let trustDescription: String = {
                switch viewModel.aiTrustLevel {
                case "autoMinor": return "Minor actions are auto-applied. Major actions require your confirmation."
                case "autoAll": return "All actions are auto-applied without confirmation."
                default: return "All actions require your confirmation before being applied."
                }
            }()

            Text(trustDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            let minorLabel: String = viewModel.aiTrustLevel == "autoMinor" ? "Auto-applied (minor)" : "Minor actions"
            VStack(alignment: .leading, spacing: 6) {
                Text(minorLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                ForEach(AIAction.capabilitiesList.filter { !$0.isMajor }, id: \.action) { cap in
                    capabilityRow(cap.action, description: cap.description)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Major actions")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                ForEach(AIAction.capabilitiesList.filter { $0.isMajor }, id: \.action) { cap in
                    capabilityRow(cap.action, description: cap.description)
                }
            }
        }
        .padding()
        .frame(width: 320)
    }

    private func capabilityRow(_ action: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(action)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Conversation History Popover

    private var conversationHistoryPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Conversations")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.clearChat()
                    showHistory = false
                } label: {
                    Label("New", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            Divider()

            if viewModel.savedConversations.isEmpty {
                Text("No saved conversations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        let sorted = viewModel.savedConversations.sorted { $0.updatedAt > $1.updatedAt }
                        ForEach(sorted) { conversation in
                            conversationRow(conversation)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding()
        .frame(width: 320)
        .task { await viewModel.loadConversations() }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        Button {
            viewModel.resumeConversation(conversation)
            showHistory = false
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(conversation.conversationType.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                    Spacer()
                    Text(conversation.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let firstMessage = conversation.messages.first {
                    Text(String(firstMessage.content.prefix(60)))
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Text("\(conversation.messages.count) messages")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteConversation(id: conversation.id) }
            }
        }
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // Return briefing card
                    if let briefing = viewModel.returnBriefing {
                        returnBriefingCard(briefing)
                    }

                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Thinking...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    if let error = viewModel.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) {
                if let lastId = viewModel.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Confirmation Bar

    private func confirmationBar(_ confirmation: BundledConfirmation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
                Text("AI proposed \(confirmation.changes.count) changes")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }

            ForEach(Array(confirmation.changes.enumerated()), id: \.element.id) { index, change in
                HStack {
                    Button {
                        viewModel.toggleChange(at: index)
                    } label: {
                        Image(systemName: change.accepted ? "checkmark.square.fill" : "square")
                            .foregroundStyle(change.accepted ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)

                    Text(change.description)
                        .font(.caption)
                        .strikethrough(!change.accepted)
                        .foregroundStyle(change.accepted ? .primary : .secondary)
                }
            }

            HStack {
                Button("Apply (\(confirmation.acceptedCount))") {
                    Task { await viewModel.applyConfirmation() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(confirmation.acceptedCount == 0)

                Button("Cancel") {
                    viewModel.cancelConfirmation()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.blue.opacity(0.05))
    }

    // MARK: - Return Briefing Card

    private func returnBriefingCard(_ briefing: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .foregroundStyle(.purple)
                Text("Welcome Back")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    viewModel.dismissReturnBriefing()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            MarkdownText(briefing)
                .font(.callout)
                .foregroundStyle(.primary)
        }
        .padding()
        .background(.purple.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.purple.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 8) {
            if showVoiceInput {
                VoiceInputView(manager: voiceManager) { transcript in
                    showVoiceInput = false
                    Task { await viewModel.sendVoiceTranscript(transcript) }
                }
                .padding(.horizontal)
            }

            HStack(spacing: 8) {
                Button {
                    showVoiceInput.toggle()
                    if !showVoiceInput { voiceManager.cancel() }
                } label: {
                    Image(systemName: showVoiceInput ? "keyboard" : "mic.fill")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                TextField("Type a message...", text: $viewModel.inputText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task { await viewModel.send() }
                    }

                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.canSend ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSend)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                messageText
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(backgroundColor, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .textSelection(.enabled)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if message.role != .user { Spacer(minLength: 60) }
        }
    }

    /// Render markdown for assistant messages; plain text for user messages.
    @ViewBuilder
    private var messageText: some View {
        if message.role == .assistant {
            MarkdownText(message.content)
        } else {
            Text(message.content)
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user: .blue
        case .assistant:
            #if os(macOS)
            Color(.controlBackgroundColor)
            #else
            Color(.systemGray6)
            #endif
        case .system: .secondary.opacity(0.2)
        }
    }
}

// MARK: - Preview

#Preview("Chat") {
    Text("Chat requires live dependencies")
        .frame(width: 500, height: 400)
}
