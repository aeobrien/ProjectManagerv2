import SwiftUI
import PMDomain
import PMDesignSystem
import PMServices

/// Full chat interface with message bubbles, voice input, and action confirmation.
public struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var voiceManager = VoiceInputManager()
    @State private var showVoiceInput = false

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
                Text("Onboarding").tag(ConversationType.onboarding)
            }
            .labelsHidden()
            .frame(maxWidth: 150)

            Spacer()

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

            Text(briefing)
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
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(backgroundColor, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(message.role == .user ? .white : .primary)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if message.role != .user { Spacer(minLength: 60) }
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
