import SwiftUI
import PMDomain
import PMDesignSystem

/// Guided onboarding flow for creating a new project from a brain dump.
public struct OnboardingView: View {
    @Bindable var manager: OnboardingFlowManager
    @State private var projectName: String
    @State private var selectedCategoryId: UUID?
    @State private var definitionOfDone = ""
    @State private var conversationInput = ""
    let categories: [PMDomain.Category]
    @Environment(\.dismiss) private var dismiss

    public init(manager: OnboardingFlowManager, categories: [PMDomain.Category]) {
        self.manager = manager
        self.categories = categories
        self._projectName = State(initialValue: manager.suggestedProjectName)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        stepContent
                    }
                    .padding()
                }
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        manager.reset()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(Array(stepLabels.enumerated()), id: \.offset) { index, label in
                HStack(spacing: 4) {
                    Circle()
                        .fill(index <= currentStepIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(index <= currentStepIndex ? .primary : .secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
                if index < stepLabels.count - 1 {
                    Rectangle()
                        .fill(index < currentStepIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var stepLabels: [String] {
        let firstStep = manager.isFromImport ? "Imported" : "Brain Dump"
        return [firstStep, "AI Discovery", "Structure", "Create", "Done"]
    }

    private var currentStepIndex: Int {
        switch manager.step {
        case .brainDump: 0
        case .aiDiscovery, .aiConversation: 1
        case .structureProposal: 2
        case .creatingProject: 3
        case .completed: 4
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch manager.step {
        case .brainDump:
            brainDumpStep
        case .aiDiscovery:
            aiDiscoveryStep
        case .aiConversation:
            aiConversationStep
        case .structureProposal:
            structureProposalStep
        case .creatingProject:
            creatingStep
        case .completed:
            completedStep
        }
    }

    // MARK: - Brain Dump

    private var brainDumpStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(manager.isFromImport ? "Imported project content" : "Describe your project idea")
                .font(.headline)

            Text(manager.isFromImport
                ? "Review the imported markdown below. You can edit it or add more context before the AI analyzes it."
                : "Write freely about what you want to build. The AI will help organize your thoughts into a structured project.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextEditor(text: $manager.brainDumpText)
                .frame(minHeight: 150, maxHeight: 300)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )

            TextField("Repository URL (optional)", text: $manager.repoURL)
                .textFieldStyle(.roundedBorder)

            Button {
                Task { await manager.startDiscovery() }
            } label: {
                if manager.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Analyze with AI", systemImage: "sparkles")
                }
            }
            .disabled(!manager.canStartDiscovery || manager.isLoading)
        }
    }

    // MARK: - AI Discovery

    private var aiDiscoveryStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Analysis")
                .font(.headline)

            if manager.isLoading {
                ProgressView("Analyzing your project idea...")
            } else {
                MarkdownText(manager.aiResponse)
                    .font(.body)

                HStack {
                    Text("Suggested complexity:")
                        .font(.subheadline)
                    Text(manager.proposedComplexity.rawValue.capitalized)
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    // MARK: - AI Conversation (Multi-Turn)

    private var aiConversationStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Discovery Conversation")
                    .font(.headline)
                Spacer()
                Text("Exchange \(manager.exchangeCount) of \(manager.maxExchanges)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }

            // Conversation history
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(manager.conversationHistory.enumerated()), id: \.offset) { _, message in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: message.role == .user ? "person.circle.fill" : "sparkles")
                                .foregroundStyle(message.role == .user ? .blue : .purple)
                                .frame(width: 20)

                            if message.role == .assistant {
                                MarkdownText(message.content)
                                    .font(.body)
                            } else {
                                Text(message.content)
                                    .font(.body)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 300)

            Divider()

            // Reply input
            HStack(alignment: .bottom, spacing: 8) {
                TextEditor(text: $conversationInput)
                    .frame(minHeight: 60, maxHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )

                VStack(spacing: 8) {
                    Button {
                        let input = conversationInput
                        conversationInput = ""
                        Task { await manager.continueDiscovery(userResponse: input) }
                    } label: {
                        if manager.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Reply", systemImage: "arrow.up.circle.fill")
                        }
                    }
                    .disabled(conversationInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isLoading)

                    Button {
                        manager.skipToStructure()
                    } label: {
                        Text("Skip")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(manager.isLoading)
                }
            }

            if let error = manager.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Structure Proposal

    private var structureProposalStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Proposed Structure")
                .font(.headline)

            Text("Review and select the items to include. Tap to toggle.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(manager.acceptedItemCount) of \(manager.proposedItems.count) items selected")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Array(manager.proposedItems.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 8) {
                    Image(systemName: item.accepted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.accepted ? .green : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(item.kind.rawValue.capitalized)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(item.name)
                                .font(.subheadline)
                        }
                        HStack(spacing: 6) {
                            if let parent = item.parentName {
                                Text("under \(parent)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            if let priority = item.priority, priority != .normal {
                                Text(priority.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(priority.color)
                            }
                            if let effort = item.effortType {
                                Text(effort.rawValue.camelCaseToWords)
                                    .font(.caption2)
                                    .foregroundStyle(effort.color)
                            }
                            if let estimate = item.timeEstimateMinutes {
                                Text("\(estimate)m")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    manager.toggleItem(at: index)
                }
            }

            // Document generation for medium/complex projects
            if manager.proposedComplexity != .simple {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Documents")
                        .font(.subheadline.weight(.semibold))

                    if manager.generatedVision != nil {
                        Label("Vision statement ready", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if manager.generatedTechBrief != nil {
                        Label("Technical brief ready", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    if manager.generatedVision == nil {
                        Button {
                            Task { await manager.generateDocuments() }
                        } label: {
                            if manager.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Generate Documents", systemImage: "doc.text")
                            }
                        }
                        .disabled(manager.isLoading)

                        Text("Documents will also be generated automatically when you create the project.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Divider()

            // Project details
            VStack(alignment: .leading, spacing: 8) {
                Text("Project Details")
                    .font(.subheadline.weight(.semibold))

                TextField("Project Name", text: $projectName)
                    .textFieldStyle(.roundedBorder)

                Picker("Category", selection: $selectedCategoryId) {
                    Text("Select...").tag(nil as UUID?)
                    ForEach(categories) { cat in
                        Text(cat.name).tag(cat.id as UUID?)
                    }
                }

                TextField("Definition of Done (optional)", text: $definitionOfDone)
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                guard let catId = selectedCategoryId else { return }
                Task {
                    await manager.createProject(
                        name: projectName,
                        categoryId: catId,
                        definitionOfDone: definitionOfDone.isEmpty ? nil : definitionOfDone
                    )
                }
            } label: {
                Label("Create Project", systemImage: "plus.circle")
            }
            .disabled(projectName.isEmpty || selectedCategoryId == nil || manager.isLoading)
        }
    }

    // MARK: - Creating

    private var creatingStep: some View {
        VStack(spacing: 12) {
            ProgressView("Creating project...")
            Text("Setting up phases, milestones, and tasks...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Completed

    private var completedStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Project Created")
                .font(.title2.weight(.semibold))

            if manager.createdProjectId != nil {
                Text("Your project has been set up with the selected structure.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                manager.reset()
                dismiss()
            } label: {
                Label("Done", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
