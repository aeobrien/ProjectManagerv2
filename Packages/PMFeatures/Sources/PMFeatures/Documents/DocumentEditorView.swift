import SwiftUI
import PMDomain
import PMDesignSystem

/// Document editor with split pane: edit on left, markdown preview on right.
public struct DocumentEditorView: View {
    @Bindable var viewModel: DocumentViewModel
    @State private var showMarkdownPreview = false
    @State private var showVersionHistory = false

    public init(viewModel: DocumentViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            documentHeader
            Divider()

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.documents.isEmpty {
                PMEmptyState(
                    icon: "doc.text",
                    title: "No Documents",
                    message: "Create a vision statement or technical brief to get started."
                ) {
                    Button("Create Document") {
                        Task {
                            await viewModel.createDocument(type: .visionStatement, title: "Vision Statement")
                        }
                    }
                }
            } else {
                #if os(macOS)
                HSplitView {
                    documentList
                        .frame(minWidth: 200, maxWidth: 250)

                    if viewModel.selectedDocument != nil {
                        editorPane
                    } else {
                        PMEmptyState(
                            icon: "doc.text.magnifyingglass",
                            title: "Select a Document",
                            message: "Choose a document from the list to view or edit."
                        )
                    }
                }
                #else
                if viewModel.selectedDocument != nil {
                    editorPane
                        .toolbar {
                            ToolbarItem(placement: .navigation) {
                                Button {
                                    viewModel.deselect()
                                } label: {
                                    Label("Documents", systemImage: "chevron.left")
                                }
                            }
                        }
                } else {
                    documentList
                }
                #endif
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Header

    private var documentHeader: some View {
        HStack {
            Text("Documents")
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()

            Menu {
                Button("Vision Statement") {
                    Task { await viewModel.createDocument(type: .visionStatement, title: "Vision Statement") }
                }
                Button("Technical Brief") {
                    Task { await viewModel.createDocument(type: .technicalBrief, title: "Technical Brief") }
                }
                Button("Other Document") {
                    Task { await viewModel.createDocument(type: .other, title: "Untitled") }
                }
            } label: {
                Image(systemName: "plus")
            }
        }
        .padding()
    }

    // MARK: - Document List

    private var documentList: some View {
        List(viewModel.documents, selection: Binding(
            get: { viewModel.selectedDocument?.id },
            set: { id in
                if let id, let doc = viewModel.documents.first(where: { $0.id == id }) {
                    viewModel.select(doc)
                }
            }
        )) { doc in
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: iconName(for: doc.type))
                        .foregroundStyle(.blue)
                    Text(doc.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                HStack {
                    Text("v\(doc.version)")
                    Text(doc.updatedAt, style: .date)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .contextMenu {
                Button("Delete", role: .destructive) {
                    Task { await viewModel.deleteDocument(doc) }
                }
            }
        }
    }

    // MARK: - Editor

    private var editorPane: some View {
        VStack(spacing: 0) {
            // Title bar — fixed height
            HStack {
                TextField("Title", text: $viewModel.editingTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .textFieldStyle(.plain)
                    .onChange(of: viewModel.editingTitle) {
                        viewModel.markEdited()
                    }

                if viewModel.hasUnsavedChanges {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                        .help("Unsaved changes")
                }

                if let doc = viewModel.selectedDocument {
                    Text("v\(doc.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle(isOn: $showMarkdownPreview) {
                    Image(systemName: showMarkdownPreview ? "eye.fill" : "eye")
                }
                .toggleStyle(.button)
                .help("Toggle Markdown Preview")

                Toggle(isOn: $showVersionHistory) {
                    Image(systemName: showVersionHistory ? "clock.fill" : "clock")
                }
                .toggleStyle(.button)
                .help("Toggle Version History")

                Button("Save") {
                    Task { await viewModel.save() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.hasUnsavedChanges)
                .keyboardShortcut("s", modifiers: .command)
            }
            .padding()

            Divider()

            // Content editor with optional markdown preview
            if showMarkdownPreview {
                #if os(macOS)
                HSplitView {
                    editorTextArea
                        .frame(minWidth: 200, maxHeight: .infinity)
                    markdownPreview
                        .frame(minWidth: 200, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #else
                markdownPreview
                #endif
            } else {
                editorTextArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            if showVersionHistory {
                versionHistoryPanel
            }
        }
    }

    // MARK: - Version History

    private var versionHistoryPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                Text("Version History")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            if viewModel.versionHistory.isEmpty {
                Text("No previous versions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.versionHistory) { version in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("v\(version.version) — \(version.title)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(version.savedAt, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Restore") {
                                    viewModel.restoreVersion(version)
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(.secondarySystemBackground))
        #endif
    }

    // MARK: - Editor Text Area

    private var editorTextArea: some View {
        TextEditor(text: $viewModel.editingContent)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(8)
            .onChange(of: viewModel.editingContent) {
                viewModel.markEdited()
            }
    }

    // MARK: - Markdown Preview

    private var markdownPreview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(LocalizedStringKey(viewModel.editingContent))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(.secondarySystemBackground))
        #endif
    }

    // MARK: - Helpers

    private func iconName(for type: DocumentType) -> String {
        switch type {
        case .visionStatement: "eye.fill"
        case .technicalBrief: "doc.text.fill"
        case .other: "doc.fill"
        }
    }
}

// MARK: - Preview

#Preview("Document Editor") {
    Text("Document Editor requires live dependencies")
        .frame(width: 600, height: 400)
}
