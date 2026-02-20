import Foundation
import PMDomain
import PMUtilities
import os

/// Manages the project knowledge base: indexing content and retrieving relevant context.
public final class KnowledgeBaseManager: Sendable {
    private let store: KnowledgeBaseStoreProtocol
    private let embeddingService: EmbeddingServiceProtocol
    private let chunker: TextChunker

    /// Default number of results to return.
    public let defaultTopK: Int

    /// Minimum similarity score to include in results.
    public let minScore: Float

    public init(
        store: KnowledgeBaseStoreProtocol,
        embeddingService: EmbeddingServiceProtocol,
        chunker: TextChunker = TextChunker(),
        defaultTopK: Int = 5,
        minScore: Float = 0.3
    ) {
        self.store = store
        self.embeddingService = embeddingService
        self.chunker = chunker
        self.defaultTopK = defaultTopK
        self.minScore = minScore
    }

    // MARK: - Indexing

    /// Index a piece of content. Chunks the text, generates embeddings, and stores them.
    public func index(
        projectId: UUID,
        sourceId: UUID,
        contentType: KBContentType,
        text: String
    ) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Remove old embeddings for this source (re-index)
        try await store.deleteBySource(sourceId: sourceId)

        // Chunk the text
        let chunks = chunker.chunk(trimmed)

        // Generate embeddings
        let vectors = try await embeddingService.embed(chunks)

        // Store
        var storedEmbeddings: [StoredEmbedding] = []
        for (i, chunk) in chunks.enumerated() {
            let stored = StoredEmbedding(
                chunkId: UUID(),
                projectId: projectId,
                sourceId: sourceId,
                contentType: contentType,
                text: chunk,
                embedding: vectors[i]
            )
            storedEmbeddings.append(stored)
        }

        try await store.storeBatch(storedEmbeddings)
        Log.ai.info("Indexed \(storedEmbeddings.count) chunks for source \(sourceId)")
    }

    /// Index a check-in record (transcript and summary).
    public func indexCheckIn(_ record: CheckInRecord) async throws {
        if !record.transcript.isEmpty {
            try await index(
                projectId: record.projectId,
                sourceId: record.id,
                contentType: .checkInTranscript,
                text: record.transcript
            )
        }
        if !record.aiSummary.isEmpty {
            // Use a deterministic "summary" ID derived from the record
            let summaryId = UUID(uuidString: record.id.uuidString.replacingOccurrences(of: "-", with: "").prefix(32).map { _ in "0" }.joined()) ?? UUID()
            try await index(
                projectId: record.projectId,
                sourceId: summaryId,
                contentType: .checkInSummary,
                text: record.aiSummary
            )
        }
    }

    /// Index a document.
    public func indexDocument(_ document: Document) async throws {
        let text = "\(document.title)\n\n\(document.content)"
        try await index(
            projectId: document.projectId,
            sourceId: document.id,
            contentType: .document,
            text: text
        )
    }

    /// Index task notes.
    public func indexTaskNotes(projectId: UUID, task: PMTask) async throws {
        guard let notes = task.notes, !notes.isEmpty else { return }
        try await index(
            projectId: projectId,
            sourceId: task.id,
            contentType: .taskNotes,
            text: "\(task.name): \(notes)"
        )
    }

    /// Remove all indexed content for a source.
    public func removeIndex(sourceId: UUID) async throws {
        try await store.deleteBySource(sourceId: sourceId)
    }

    /// Remove all indexed content for a project.
    public func clearProjectIndex(projectId: UUID) async throws {
        try await store.deleteAll(forProject: projectId)
    }

    // MARK: - Retrieval

    /// Search the knowledge base for content relevant to the query.
    public func search(
        query: String,
        projectId: UUID,
        topK: Int? = nil,
        contentTypes: [KBContentType]? = nil
    ) async throws -> [RetrievalResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Generate query embedding
        let queryVector = try await embeddingService.embed(trimmed)

        // Fetch all project embeddings
        var candidates = try await store.fetchAll(forProject: projectId)

        // Filter by content type if specified
        if let types = contentTypes {
            candidates = candidates.filter { types.contains($0.contentType) }
        }

        // Brute-force cosine similarity
        var results: [RetrievalResult] = candidates.compactMap { stored in
            let score = cosineSimilarity(queryVector, stored.embedding)
            guard score >= minScore else { return nil }
            return RetrievalResult(stored: stored, score: score)
        }

        // Sort by score descending
        results.sort { $0.score > $1.score }

        // Top-K
        let k = topK ?? defaultTopK
        return Array(results.prefix(k))
    }

    /// Retrieve relevant context formatted for inclusion in an AI prompt.
    public func retrieveContext(
        query: String,
        projectId: UUID,
        topK: Int? = nil,
        maxChars: Int = 2000
    ) async throws -> String {
        let results = try await search(query: query, projectId: projectId, topK: topK)

        guard !results.isEmpty else { return "" }

        var context = "--- Relevant project history ---\n"
        var totalChars = context.count

        for result in results {
            let entry = "[\(result.stored.contentType.rawValue)] \(result.stored.text)\n\n"
            if totalChars + entry.count > maxChars { break }
            context += entry
            totalChars += entry.count
        }

        return context
    }

    // MARK: - Info

    /// Number of indexed chunks for a project.
    public func chunkCount(forProject projectId: UUID) async throws -> Int {
        try await store.count(forProject: projectId)
    }

    /// Check if a source has been indexed.
    public func isIndexed(sourceId: UUID) async throws -> Bool {
        try await store.isIndexed(sourceId: sourceId)
    }
}
