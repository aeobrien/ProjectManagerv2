import Foundation
import PMDomain
import PMServices
import PMUtilities
import os

/// Steps in the adversarial review pipeline.
public enum AdversarialReviewStep: String, Sendable, Equatable {
    case idle
    case exporting
    case awaitingCritiques
    case critiquesReceived
    case synthesising
    case reviewingRevisions
    case completed
}

/// A revised document proposed after synthesis.
public struct RevisedDocument: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let originalDocumentId: UUID
    public let type: DocumentType
    public let title: String
    public let revisedContent: String
    public let changesSummary: String

    public init(
        id: UUID = UUID(),
        originalDocumentId: UUID,
        type: DocumentType,
        title: String,
        revisedContent: String,
        changesSummary: String
    ) {
        self.id = id
        self.originalDocumentId = originalDocumentId
        self.type = type
        self.title = title
        self.revisedContent = revisedContent
        self.changesSummary = changesSummary
    }
}

/// Manages the adversarial review pipeline for complex project onboarding.
@Observable
@MainActor
public final class AdversarialReviewManager {
    // MARK: - State

    public private(set) var step: AdversarialReviewStep = .idle
    public private(set) var isLoading = false
    public private(set) var error: String?

    public private(set) var exportPackage: ReviewExportPackage?
    public private(set) var critiques: [ReviewCritique] = []
    public private(set) var synthesisResponse: String?
    public private(set) var revisedDocuments: [RevisedDocument] = []
    public private(set) var messages: [(role: String, content: String)] = []

    // MARK: - Dependencies

    private let documentRepo: DocumentRepositoryProtocol
    private let llmClient: LLMClientProtocol
    private let exporter: ReviewExporter

    // MARK: - Init

    public init(
        documentRepo: DocumentRepositoryProtocol,
        llmClient: LLMClientProtocol,
        exporter: ReviewExporter = ReviewExporter()
    ) {
        self.documentRepo = documentRepo
        self.llmClient = llmClient
        self.exporter = exporter
    }

    // MARK: - Export

    /// Export documents for a project for external review.
    public func exportForReview(
        project: Project,
        brainDumpTranscript: String? = nil
    ) async {
        isLoading = true
        error = nil

        do {
            let documents = try await documentRepo.fetchAll(forProject: project.id)
            guard !documents.isEmpty else {
                error = "No documents to export for review."
                isLoading = false
                return
            }

            let package = exporter.buildExportPackage(
                project: project,
                documents: documents,
                brainDumpTranscript: brainDumpTranscript
            )

            exportPackage = package
            step = .awaitingCritiques

            Log.ai.info("Exported \(documents.count) documents for adversarial review")
        } catch {
            self.error = "Export failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Get the export package as JSON data (for clipboard, file, or API).
    public func exportPackageData() throws -> Data? {
        guard let package = exportPackage else { return nil }
        return try exporter.encodePackage(package)
    }

    // MARK: - Import Critiques

    /// Import critiques from JSON data.
    public func importCritiques(from data: Data) {
        do {
            let importPackage = try exporter.decodeCritiques(data)
            critiques = importPackage.critiques
            step = .critiquesReceived
            Log.ai.info("Imported \(self.critiques.count) critiques")
        } catch {
            self.error = "Failed to import critiques: \(error.localizedDescription)"
        }
    }

    /// Import critiques directly (e.g., from UI input).
    public func importCritiques(_ newCritiques: [ReviewCritique]) {
        guard !newCritiques.isEmpty else {
            error = "No critiques provided."
            return
        }
        critiques = newCritiques
        step = .critiquesReceived
        Log.ai.info("Imported \(newCritiques.count) critiques directly")
    }

    // MARK: - Synthesis

    /// Run AI synthesis of original documents and critiques.
    public func synthesise() async {
        guard let package = exportPackage else {
            error = "No export package available. Export documents first."
            return
        }
        guard !critiques.isEmpty else {
            error = "No critiques to synthesise. Import critiques first."
            return
        }

        isLoading = true
        step = .synthesising
        messages = []

        let prompt = exporter.buildSynthesisPrompt(
            exportPackage: package,
            critiques: critiques
        )

        messages.append((role: "user", content: prompt))

        do {
            let llmMessages = messages.map {
                LLMMessage(role: $0.role == "user" ? .user : .assistant, content: $0.content)
            }
            let config = LLMRequestConfig()
            let response = try await llmClient.send(messages: llmMessages, config: config)

            synthesisResponse = response.content
            messages.append((role: "assistant", content: response.content))
            step = .reviewingRevisions

            Log.ai.info("Adversarial synthesis completed")
        } catch {
            self.error = "Synthesis failed: \(error.localizedDescription)"
            step = .critiquesReceived
        }

        isLoading = false
    }

    /// Send a follow-up message during synthesis review.
    public func sendFollowUp(_ message: String) async {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isLoading = true
        messages.append((role: "user", content: text))

        do {
            let llmMessages = messages.map {
                LLMMessage(role: $0.role == "user" ? .user : .assistant, content: $0.content)
            }
            let config = LLMRequestConfig()
            let response = try await llmClient.send(messages: llmMessages, config: config)

            synthesisResponse = response.content
            messages.append((role: "assistant", content: response.content))
        } catch {
            self.error = "Follow-up failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Approve Revisions

    /// Add a revised document for approval.
    public func addRevisedDocument(_ revised: RevisedDocument) {
        revisedDocuments.append(revised)
    }

    /// Approve revised documents and save them back to the document store.
    public func approveRevisions() async {
        guard !revisedDocuments.isEmpty else {
            error = "No revised documents to approve."
            return
        }

        isLoading = true

        do {
            for revised in revisedDocuments {
                if var doc = try await documentRepo.fetch(id: revised.originalDocumentId) {
                    doc.content = revised.revisedContent
                    doc.version += 1
                    doc.updatedAt = Date()
                    try await documentRepo.save(doc)
                }
            }

            step = .completed
            Log.ai.info("Approved \(self.revisedDocuments.count) revised documents")
        } catch {
            self.error = "Failed to save revisions: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Reset

    public func reset() {
        step = .idle
        isLoading = false
        error = nil
        exportPackage = nil
        critiques = []
        synthesisResponse = nil
        revisedDocuments = []
        messages = []
    }

    // MARK: - Computed

    /// Number of overlapping concerns (mentioned by multiple reviewers).
    public var overlappingConcernCount: Int {
        guard critiques.count >= 2 else { return 0 }
        let allConcerns = critiques.flatMap(\.concerns)
        var seen: [String: Int] = [:]
        for concern in allConcerns {
            let normalized = concern.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            seen[normalized, default: 0] += 1
        }
        return seen.values.filter { $0 > 1 }.count
    }

    /// Total number of concerns across all critiques.
    public var totalConcernCount: Int {
        critiques.reduce(0) { $0 + $1.concerns.count }
    }

    /// Total number of suggestions across all critiques.
    public var totalSuggestionCount: Int {
        critiques.reduce(0) { $0 + $1.suggestions.count }
    }
}
