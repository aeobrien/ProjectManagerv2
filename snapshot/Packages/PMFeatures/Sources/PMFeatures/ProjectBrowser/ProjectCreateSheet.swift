import SwiftUI
import PMDomain

/// Sheet for creating a new project.
struct ProjectCreateSheet: View {
    @Bindable var viewModel: ProjectBrowserViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedCategoryId: UUID?
    @State private var definitionOfDone = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $name)

                    Picker("Category", selection: $selectedCategoryId) {
                        Text("Select a category").tag(UUID?.none)
                        ForEach(viewModel.categories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                }

                Section("Definition of Done (Optional)") {
                    TextEditor(text: $definitionOfDone)
                        .frame(minHeight: 60)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard let categoryId = selectedCategoryId else { return }
                        Task {
                            await viewModel.createProject(
                                name: name,
                                categoryId: categoryId,
                                definitionOfDone: definitionOfDone.isEmpty ? nil : definitionOfDone
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selectedCategoryId == nil)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        #endif
    }
}
