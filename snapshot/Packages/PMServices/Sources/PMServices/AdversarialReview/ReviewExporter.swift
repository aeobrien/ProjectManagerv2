import Foundation
import PMDomain
import PMUtilities
import os

// MARK: - Export/Import Types

/// A package of documents exported for external adversarial review.
public struct ReviewExportPackage: Codable, Sendable, Equatable {
    public let projectId: UUID
    public let projectName: String
    public let exportedAt: Date
    public let documents: [ExportedReviewDocument]
    public let brainDumpTranscript: String?

    public init(
        projectId: UUID,
        projectName: String,
        exportedAt: Date = Date(),
        documents: [ExportedReviewDocument],
        brainDumpTranscript: String? = nil
    ) {
        self.projectId = projectId
        self.projectName = projectName
        self.exportedAt = exportedAt
        self.documents = documents
        self.brainDumpTranscript = brainDumpTranscript
    }
}

/// A single document within the export package.
public struct ExportedReviewDocument: Codable, Sendable, Equatable {
    public let documentId: UUID
    public let type: DocumentType
    public let title: String
    public let content: String
    public let version: Int

    public init(documentId: UUID, type: DocumentType, title: String, content: String, version: Int) {
        self.documentId = documentId
        self.type = type
        self.title = title
        self.content = content
        self.version = version
    }
}

/// A critique from an external reviewer.
public struct ReviewCritique: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let reviewerName: String
    public let documentType: DocumentType?
    public let concerns: [String]
    public let suggestions: [String]
    public let overallAssessment: String
    public let receivedAt: Date

    public init(
        id: UUID = UUID(),
        reviewerName: String,
        documentType: DocumentType? = nil,
        concerns: [String],
        suggestions: [String],
        overallAssessment: String,
        receivedAt: Date = Date()
    ) {
        self.id = id
        self.reviewerName = reviewerName
        self.documentType = documentType
        self.concerns = concerns
        self.suggestions = suggestions
        self.overallAssessment = overallAssessment
        self.receivedAt = receivedAt
    }
}

/// The full critique import package from the external pipeline.
public struct CritiqueImportPackage: Codable, Sendable, Equatable {
    public let projectId: UUID
    public let critiques: [ReviewCritique]
    public let pipelineMetadata: PipelineMetadata?

    public init(projectId: UUID, critiques: [ReviewCritique], pipelineMetadata: PipelineMetadata? = nil) {
        self.projectId = projectId
        self.critiques = critiques
        self.pipelineMetadata = pipelineMetadata
    }
}

/// Metadata about the external review pipeline run.
public struct PipelineMetadata: Codable, Sendable, Equatable {
    public let pipelineName: String
    public let runId: String?
    public let startedAt: Date?
    public let completedAt: Date?

    public init(pipelineName: String, runId: String? = nil, startedAt: Date? = nil, completedAt: Date? = nil) {
        self.pipelineName = pipelineName
        self.runId = runId
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}

// MARK: - Review Exporter

/// Exports project documents for external adversarial review and imports critiques.
public struct ReviewExporter: Sendable {
    public init() {}

    /// Build an export package from project documents.
    public func buildExportPackage(
        project: Project,
        documents: [Document],
        brainDumpTranscript: String? = nil
    ) -> ReviewExportPackage {
        let exportedDocs = documents.map { doc in
            ExportedReviewDocument(
                documentId: doc.id,
                type: doc.type,
                title: doc.title,
                content: doc.content,
                version: doc.version
            )
        }

        return ReviewExportPackage(
            projectId: project.id,
            projectName: project.name,
            documents: exportedDocs,
            brainDumpTranscript: brainDumpTranscript
        )
    }

    /// Encode an export package to JSON data.
    public func encodePackage(_ package: ReviewExportPackage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(package)
    }

    /// Decode a critique import package from JSON data.
    public func decodeCritiques(_ data: Data) throws -> CritiqueImportPackage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CritiqueImportPackage.self, from: data)
    }

    /// Write export package to a file URL.
    public func exportToFile(_ package: ReviewExportPackage, url: URL) throws {
        let data = try encodePackage(package)
        try data.write(to: url, options: .atomic)
        Log.data.info("Exported review package to \(url.lastPathComponent)")
    }

    /// Import critiques from a file URL.
    public func importFromFile(_ url: URL) throws -> CritiqueImportPackage {
        let data = try Data(contentsOf: url)
        return try decodeCritiques(data)
    }

    /// Build a synthesis prompt from original documents and critiques.
    public func buildSynthesisPrompt(
        exportPackage: ReviewExportPackage,
        critiques: [ReviewCritique]
    ) -> String {
        var prompt = "You are reviewing critiques of project documents for \"\(exportPackage.projectName)\".\n\n"

        prompt += "## Original Documents\n\n"
        for doc in exportPackage.documents {
            prompt += "### \(doc.title) (\(doc.type.rawValue))\n\(doc.content)\n\n"
        }

        if let transcript = exportPackage.brainDumpTranscript {
            prompt += "### Brain Dump Transcript\n\(transcript)\n\n"
        }

        prompt += "## Reviewer Critiques\n\n"
        for critique in critiques {
            prompt += "### Reviewer: \(critique.reviewerName)\n"
            if !critique.concerns.isEmpty {
                prompt += "**Concerns:**\n"
                for concern in critique.concerns {
                    prompt += "- \(concern)\n"
                }
            }
            if !critique.suggestions.isEmpty {
                prompt += "**Suggestions:**\n"
                for suggestion in critique.suggestions {
                    prompt += "- \(suggestion)\n"
                }
            }
            prompt += "**Overall:** \(critique.overallAssessment)\n\n"
        }

        prompt += """
        ## Your Task

        1. Identify overlapping concerns across reviewers.
        2. Note any divergent opinions.
        3. Recommend which critiques to address and which to set aside.
        4. Produce revised versions of each document incorporating the valid critiques.
        5. Explain what changed and why.

        Respond with the synthesis and revised documents.
        """

        return prompt
    }
}
