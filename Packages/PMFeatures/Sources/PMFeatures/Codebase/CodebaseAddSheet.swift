import SwiftUI
import PMDomain
import PMUtilities
import UniformTypeIdentifiers

/// Sheet for adding a codebase to a project — local directory or GitHub URL.
public struct CodebaseAddSheet: View {
    let projectId: UUID
    let codebaseRepo: CodebaseRepositoryProtocol
    @Environment(\.dismiss) var dismiss

    @State private var sourceType: Codebase.SourceType = .local
    @State private var githubURL: String = ""
    @State private var name: String = ""
    @State private var fileSizeLimitMB: Int = 25
    @State private var showFolderPicker = false
    @State private var selectedURL: URL?
    @State private var bookmarkData: Data?
    @State private var errorMessage: String?
    @State private var isSaving = false

    public init(projectId: UUID, codebaseRepo: CodebaseRepositoryProtocol) {
        self.projectId = projectId
        self.codebaseRepo = codebaseRepo
    }

    public var body: some View {
        NavigationStack {
            Form {
                Picker("Source", selection: $sourceType) {
                    Text("Local Directory").tag(Codebase.SourceType.local)
                    Text("GitHub").tag(Codebase.SourceType.github)
                }
                .pickerStyle(.segmented)

                switch sourceType {
                case .local:
                    localSection
                case .github:
                    githubSection
                }

                Section("Options") {
                    TextField("Display Name", text: $name)
                    Stepper("Size Limit: \(fileSizeLimitMB) MB", value: $fileSizeLimitMB, in: 5...200, step: 5)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Codebase")
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 300)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await save() }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .fileImporter(
                isPresented: $showFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                handleFolderSelection(result)
            }
        }
    }

    // MARK: - Sections

    private var localSection: some View {
        Section("Local Directory") {
            if let url = selectedURL {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                    Text(url.lastPathComponent)
                        .lineLimit(1)
                    Spacer()
                    Button("Change") { showFolderPicker = true }
                        .buttonStyle(.borderless)
                }
            } else {
                Button("Select Folder...") {
                    showFolderPicker = true
                }
            }
        }
    }

    private var githubSection: some View {
        Section("GitHub Repository") {
            TextField("https://github.com/user/repo", text: $githubURL)
                #if os(macOS)
                .textFieldStyle(.roundedBorder)
                #endif
        }
    }

    // MARK: - Logic

    private var canSave: Bool {
        switch sourceType {
        case .local:
            return selectedURL != nil
        case .github:
            let trimmed = githubURL.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.hasPrefix("https://github.com/") && trimmed.count > 25
        }
    }

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // Must access the security-scoped resource before creating a bookmark
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access the selected folder."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            selectedURL = url
            if name.isEmpty {
                name = url.lastPathComponent
            }
            // Create security-scoped bookmark (macOS only)
            #if os(macOS)
            do {
                bookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            } catch {
                Log.ai.error("Failed to create bookmark: \(error)")
                errorMessage = "Could not create folder bookmark: \(error.localizedDescription)"
            }
            #endif
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let effectiveName: String
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            switch sourceType {
            case .local:
                effectiveName = selectedURL?.lastPathComponent ?? "Local Codebase"
            case .github:
                effectiveName = githubURL.components(separatedBy: "/").last ?? "GitHub Repo"
            }
        } else {
            effectiveName = name
        }

        let codebase = Codebase(
            projectId: projectId,
            name: effectiveName,
            sourceType: sourceType,
            localPath: selectedURL?.path,
            githubURL: sourceType == .github ? githubURL.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            bookmarkData: bookmarkData,
            fileSizeLimitMB: fileSizeLimitMB
        )

        do {
            try await codebaseRepo.save(codebase)
            Log.ai.info("Added codebase '\(effectiveName)' to project \(self.projectId)")
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}
