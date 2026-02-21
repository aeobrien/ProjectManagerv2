import SwiftUI
import PMDomain
import PMDesignSystem

/// Guided onboarding flow for creating a new project from a brain dump.
public struct OnboardingView: View {
    @Bindable var manager: OnboardingFlowManager
    @State private var projectName = ""
    @State private var selectedCategoryId: UUID?
    @State private var definitionOfDone = ""
    let categories: [PMDomain.Category]
    @Environment(\.dismiss) private var dismiss

    public init(manager: OnboardingFlowManager, categories: [PMDomain.Category]) {
        self.manager = manager
        self.categories = categories
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
        ["Brain Dump", "AI Discovery", "Structure", "Create", "Done"]
    }

    private var currentStepIndex: Int {
        switch manager.step {
        case .brainDump: 0
        case .aiDiscovery: 1
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
            Text("Describe your project idea")
                .font(.headline)

            Text("Write freely about what you want to build. The AI will help organize your thoughts into a structured project.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextEditor(text: $manager.brainDumpText)
                .frame(minHeight: 150, maxHeight: 300)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )

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
                Text(manager.aiResponse)
                    .font(.body)
                    .textSelection(.enabled)

                HStack {
                    Text("Suggested complexity:")
                        .font(.subheadline)
                    Text(manager.proposedComplexity.rawValue.capitalized)
                        .font(.subheadline.weight(.semibold))
                }
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
                        if let parent = item.parentName {
                            Text("under \(parent)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    manager.toggleItem(at: index)
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
