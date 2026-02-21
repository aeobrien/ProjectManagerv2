import SwiftUI
import PMDomain
import PMDesignSystem
import PMServices

/// View for the adversarial review pipeline — export, import critiques, synthesise, revise.
public struct AdversarialReviewView: View {
    let manager: AdversarialReviewManager
    let project: Project
    @State private var followUpText = ""
    @State private var importData: String = ""
    @State private var showImportSheet = false

    public init(manager: AdversarialReviewManager, project: Project) {
        self.manager = manager
        self.project = project
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepIndicator
                stepContent
                errorSection
            }
            .padding()
        }
        .navigationTitle("Adversarial Review")
        .sheet(isPresented: $showImportSheet) {
            importSheet
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
    }

    private var stepLabels: [String] {
        ["Export", "Critiques", "Synthesise", "Revise", "Done"]
    }

    private var currentStepIndex: Int {
        switch manager.step {
        case .idle, .exporting: 0
        case .awaitingCritiques: 1
        case .critiquesReceived, .synthesising: 2
        case .reviewingRevisions: 3
        case .completed: 4
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch manager.step {
        case .idle:
            idleView
        case .exporting:
            exportingView
        case .awaitingCritiques:
            awaitingCritiquesView
        case .critiquesReceived:
            critiquesReceivedView
        case .synthesising:
            synthesisingView
        case .reviewingRevisions:
            revisionsView
        case .completed:
            completedView
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adversarial Review Pipeline")
                .font(.headline)

            Text("Export your project documents for external review by other AI models, then import their critiques for synthesis.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                Task { await manager.exportForReview(project: project) }
            } label: {
                Label("Export for Review", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Exporting

    private var exportingView: some View {
        VStack(spacing: 12) {
            ProgressView("Preparing export package...")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Awaiting Critiques

    private var awaitingCritiquesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Ready")
                .font(.headline)

            if let pkg = manager.exportPackage {
                PMCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Package: \(pkg.projectName)")
                            .font(.subheadline)
                        Text("\(pkg.documents.count) documents exported")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    if let data = try? manager.exportPackageData() {
                        let json = String(data: data, encoding: .utf8) ?? ""
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(json, forType: .string)
                        #else
                        UIPasteboard.general.string = json
                        #endif
                    }
                } label: {
                    Label("Copy Export JSON", systemImage: "doc.on.clipboard")
                }
                .controlSize(.small)
            }

            Text("Send the export package to other AI models for critique, then import their responses.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showImportSheet = true
            } label: {
                Label("Import Critiques", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Critiques Received

    private var critiquesReceivedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Critiques Received")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(manager.critiques.count)")
                        .font(.title2.weight(.semibold))
                    Text("Critiques")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 2) {
                    Text("\(manager.totalConcernCount)")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("Concerns")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 2) {
                    Text("\(manager.totalSuggestionCount)")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.blue)
                    Text("Suggestions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 2) {
                    Text("\(manager.overlappingConcernCount)")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.red)
                    Text("Overlapping")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task { await manager.synthesise() }
            } label: {
                Label("Synthesise Critiques", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Synthesising

    private var synthesisingView: some View {
        VStack(spacing: 12) {
            ProgressView("Synthesising critiques...")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Revisions

    private var revisionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review Revisions")
                .font(.headline)

            if let synthesis = manager.synthesisResponse {
                PMCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Synthesis", systemImage: "doc.text")
                            .font(.subheadline.weight(.semibold))
                        Text(synthesis)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
            }

            // Messages
            ForEach(Array(manager.messages.enumerated()), id: \.offset) { _, message in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: message.role == "user" ? "person.circle" : "sparkles")
                        .foregroundStyle(message.role == "user" ? .blue : .purple)
                    Text(message.content)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }

            // Revised documents
            if !manager.revisedDocuments.isEmpty {
                Text("Revised Documents (\(manager.revisedDocuments.count))")
                    .font(.subheadline.weight(.semibold))

                ForEach(manager.revisedDocuments) { doc in
                    PMCard {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(doc.title)
                                .font(.subheadline.weight(.semibold))
                            Text(doc.changesSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Follow-up
            HStack {
                TextField("Ask a follow-up...", text: $followUpText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    let text = followUpText
                    followUpText = ""
                    Task { await manager.sendFollowUp(text) }
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(followUpText.isEmpty || manager.isLoading)
            }

            Button {
                Task { await manager.approveRevisions() }
            } label: {
                Label("Approve Revisions", systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Review Complete")
                .font(.title2.weight(.semibold))

            Text("All critiques have been synthesised and revisions approved.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Start New Review") {
                manager.reset()
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Import Sheet

    private var importSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Paste the critique JSON from external AI reviews:")
                    .font(.subheadline)

                TextEditor(text: $importData)
                    .frame(minHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )

                Button("Import") {
                    if let data = importData.data(using: .utf8) {
                        manager.importCritiques(from: data)
                        showImportSheet = false
                        importData = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(importData.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("Import Critiques")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showImportSheet = false }
                }
            }
        }
    }

    // MARK: - Error

    @ViewBuilder
    private var errorSection: some View {
        if let error = manager.error {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}
