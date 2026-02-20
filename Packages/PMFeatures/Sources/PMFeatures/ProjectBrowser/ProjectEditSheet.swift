import SwiftUI
import PMDomain

/// Sheet for editing a project's metadata and performing lifecycle transitions.
struct ProjectEditSheet: View {
    @Bindable var viewModel: ProjectBrowserViewModel
    let project: Project
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selectedCategoryId: UUID
    @State private var definitionOfDone: String
    @State private var notes: String
    @State private var showDeleteConfirmation = false
    @State private var transitionTarget: LifecycleState?
    @State private var pauseReason = ""
    @State private var abandonReflection = ""

    init(viewModel: ProjectBrowserViewModel, project: Project) {
        self.viewModel = viewModel
        self.project = project
        _name = State(initialValue: project.name)
        _selectedCategoryId = State(initialValue: project.categoryId)
        _definitionOfDone = State(initialValue: project.definitionOfDone ?? "")
        _notes = State(initialValue: project.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Name", text: $name)

                    Picker("Category", selection: $selectedCategoryId) {
                        ForEach(viewModel.categories) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                }

                Section("Definition of Done") {
                    TextEditor(text: $definitionOfDone)
                        .frame(minHeight: 60)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }

                Section("Lifecycle") {
                    HStack {
                        Text("Current State")
                        Spacer()
                        Label(project.lifecycleState.rawValue.capitalized, systemImage: project.lifecycleState.iconName)
                            .foregroundStyle(project.lifecycleState.color)
                    }

                    let transitions = Array(viewModel.validTransitions(for: project))
                    if !transitions.isEmpty {
                        ForEach(transitions, id: \.self) { state in
                            Button {
                                if state == .paused || state == .abandoned {
                                    transitionTarget = state
                                } else {
                                    Task {
                                        await viewModel.transitionProject(project, to: state)
                                        dismiss()
                                    }
                                }
                            } label: {
                                Label("Move to \(state.rawValue.capitalized)", systemImage: state.iconName)
                            }
                        }
                    }
                }

                // Pause reason prompt
                if transitionTarget == .paused {
                    Section("Pause Reason") {
                        TextEditor(text: $pauseReason)
                            .frame(minHeight: 40)
                        Button("Confirm Pause") {
                            viewModel.pauseReason = pauseReason
                            Task {
                                await viewModel.transitionProject(project, to: .paused)
                                dismiss()
                            }
                        }
                        .disabled(pauseReason.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                // Abandonment reflection prompt
                if transitionTarget == .abandoned {
                    Section("Abandonment Reflection") {
                        TextEditor(text: $abandonReflection)
                            .frame(minHeight: 40)
                        Button("Confirm Abandon") {
                            viewModel.abandonmentReflection = abandonReflection
                            Task {
                                await viewModel.transitionProject(project, to: .abandoned)
                                dismiss()
                            }
                        }
                        .disabled(abandonReflection.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section {
                    Button("Delete Project", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = project
                        updated.name = name
                        updated.categoryId = selectedCategoryId
                        updated.definitionOfDone = definitionOfDone.isEmpty ? nil : definitionOfDone
                        updated.notes = notes.isEmpty ? nil : notes
                        Task {
                            await viewModel.updateProject(updated)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete Project?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteProject(project)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete \"\(project.name)\" and all its contents.")
            }
        }
        .frame(minWidth: 400, minHeight: 400)
    }
}
