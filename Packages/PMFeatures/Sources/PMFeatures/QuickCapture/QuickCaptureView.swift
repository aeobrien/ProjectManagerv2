import SwiftUI
import PMDomain
import PMDesignSystem

/// Lightweight quick capture sheet for creating Idea-state project stubs.
public struct QuickCaptureView: View {
    @Bindable var viewModel: QuickCaptureViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: QuickCaptureViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)
                Text("Quick Capture")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Transcript input
            VStack(alignment: .leading, spacing: 4) {
                Text("What's the idea?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $viewModel.transcript)
                    .font(.body)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            // Optional title
            VStack(alignment: .leading, spacing: 4) {
                Text("Title (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Auto-generated from description", text: $viewModel.title)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            // Category picker
            if !viewModel.categories.isEmpty {
                HStack {
                    Text("Category")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Category", selection: $viewModel.selectedCategoryId) {
                        Text("Auto").tag(UUID?.none)
                        ForEach(viewModel.categories) { cat in
                            Text(cat.name).tag(Optional(cat.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 200)
                }
            }

            // Error
            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Success
            if viewModel.didSave {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Idea captured!")
                        .font(.subheadline)
                }
            }

            // Actions
            HStack {
                if viewModel.didSave {
                    Button("Capture Another") {
                        viewModel.reset()
                    }
                    .buttonStyle(.bordered)

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Spacer()
                    Button("Save Idea") {
                        Task { await viewModel.save() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canSave)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
        .padding()
        .frame(width: 400)
        .task {
            await viewModel.loadCategories()
        }
    }
}

// MARK: - Preview

#Preview("Quick Capture") {
    QuickCaptureView(viewModel: QuickCaptureViewModel(
        projectRepo: PreviewProjectRepo(),
        categoryRepo: PreviewCategoryRepo()
    ))
}

// Simple preview mocks
private final class PreviewProjectRepo: ProjectRepositoryProtocol, @unchecked Sendable {
    func fetchAll() async throws -> [Project] { [] }
    func fetch(id: UUID) async throws -> Project? { nil }
    func fetchByLifecycleState(_ state: LifecycleState) async throws -> [Project] { [] }
    func fetchByCategory(_ categoryId: UUID) async throws -> [Project] { [] }
    func fetchFocused() async throws -> [Project] { [] }
    func save(_ project: Project) async throws {}
    func delete(id: UUID) async throws {}
    func search(query: String) async throws -> [Project] { [] }
}

private final class PreviewCategoryRepo: CategoryRepositoryProtocol, @unchecked Sendable {
    func fetchAll() async throws -> [PMDomain.Category] {
        [PMDomain.Category(name: "Software", isBuiltIn: true)]
    }
    func fetch(id: UUID) async throws -> PMDomain.Category? { nil }
    func save(_ category: PMDomain.Category) async throws {}
    func delete(id: UUID) async throws {}
    func seedBuiltInCategories() async throws {}
}
