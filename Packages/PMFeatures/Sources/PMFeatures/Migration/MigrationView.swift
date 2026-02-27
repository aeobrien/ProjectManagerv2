import SwiftUI
import UniformTypeIdentifiers
import PMDomain
import PMDesignSystem
import PMServices

/// View for importing projects from markdown files and handing off to onboarding.
public struct MigrationView: View {
    @Bindable var viewModel: MigrationViewModel
    @State private var showFolderPicker = false
    @State private var showFilePicker = false
    @Environment(\.dismiss) private var dismiss

    /// Callback when user wants to start onboarding for an imported project.
    /// Parameters: markdown content, repo URL, project name.
    public var onStartOnboarding: ((String, String, String) -> Void)?

    public init(viewModel: MigrationViewModel, onStartOnboarding: ((String, String, String) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onStartOnboarding = onStartOnboarding
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepContent
            }
            .navigationTitle("Import Projects")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 500)
        #endif
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .selectFiles:
            selectFilesStep
        case .preOnboarding:
            preOnboardingStep
        }
    }

    // MARK: - Select Files

    private var selectFilesStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Import from Markdown")
                .font(.title2.weight(.semibold))

            Text("Select individual .md files or a folder of them. Each file becomes a project that goes through the onboarding flow — the AI will help you structure it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            HStack(spacing: 16) {
                Button {
                    showFilePicker = true
                } label: {
                    Label("Choose Files", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .fileImporter(
                    isPresented: $showFilePicker,
                    allowedContentTypes: [.plainText, .text],
                    allowsMultipleSelection: true
                ) { result in
                    handleFileSelection(result)
                }

                Button {
                    showFolderPicker = true
                } label: {
                    Label("Choose Folder", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                .fileImporter(
                    isPresented: $showFolderPicker,
                    allowedContentTypes: [.folder],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            let accessed = url.startAccessingSecurityScopedResource()
                            Task {
                                await viewModel.selectFolder(url)
                                if accessed { url.stopAccessingSecurityScopedResource() }
                            }
                        }
                    case .failure(let error):
                        viewModel.error = error.localizedDescription
                    }
                }
            }

            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding()
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let mdFiles = urls.filter { $0.pathExtension.lowercased() == "md" }
            guard !mdFiles.isEmpty else {
                viewModel.error = "No .md files selected."
                return
            }
            let accessTokens = mdFiles.map { ($0, $0.startAccessingSecurityScopedResource()) }
            Task {
                await viewModel.selectFiles(mdFiles)
                for (url, accessed) in accessTokens {
                    if accessed { url.stopAccessingSecurityScopedResource() }
                }
            }
        case .failure(let error):
            viewModel.error = error.localizedDescription
        }
    }

    // MARK: - Pre-Onboarding

    private var preOnboardingStep: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(viewModel.parsedProjects.count) projects ready for onboarding")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.parsedProjects) { project in
                        preOnboardingCard(project)
                    }
                }
                .padding()
            }
        }
    }

    private func preOnboardingCard(_ project: ParsedProject) -> some View {
        PMCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(project.name)
                    .font(.headline)

                // Markdown preview
                Text(viewModel.markdownPreview(for: project.id))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(5)

                // Repo URL field
                TextField(
                    "Repository URL (optional)",
                    text: Binding(
                        get: { viewModel.repoURLs[project.id] ?? "" },
                        set: { viewModel.repoURLs[project.id] = $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .font(.caption)

                Button {
                    if let data = viewModel.projectDataForOnboarding(id: project.id) {
                        onStartOnboarding?(data.markdown, data.repoURL, data.name)
                    }
                } label: {
                    Label("Start Onboarding", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}
