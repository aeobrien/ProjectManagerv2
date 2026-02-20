import Foundation
import NaturalLanguage

/// Content types that can be indexed in the knowledge base.
public enum KBContentType: String, Sendable, Codable {
    case checkInTranscript
    case checkInSummary
    case document
    case taskNotes
    case conversationMessage
}

/// A text chunk with metadata, ready for embedding.
public struct TextChunk: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let projectId: UUID
    public let sourceId: UUID       // ID of the source entity (check-in, document, etc.)
    public let contentType: KBContentType
    public let text: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        sourceId: UUID,
        contentType: KBContentType,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.sourceId = sourceId
        self.contentType = contentType
        self.text = text
        self.createdAt = createdAt
    }
}

/// A stored embedding with its associated chunk metadata.
public struct StoredEmbedding: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let chunkId: UUID
    public let projectId: UUID
    public let sourceId: UUID
    public let contentType: KBContentType
    public let text: String
    public let embedding: [Float]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        chunkId: UUID,
        projectId: UUID,
        sourceId: UUID,
        contentType: KBContentType,
        text: String,
        embedding: [Float],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.chunkId = chunkId
        self.projectId = projectId
        self.sourceId = sourceId
        self.contentType = contentType
        self.text = text
        self.embedding = embedding
        self.createdAt = createdAt
    }
}

/// A search result with relevance score.
public struct RetrievalResult: Sendable {
    public let stored: StoredEmbedding
    public let score: Float

    public init(stored: StoredEmbedding, score: Float) {
        self.stored = stored
        self.score = score
    }
}

/// Protocol for embedding generation, enabling testing with mock embeddings.
public protocol EmbeddingServiceProtocol: Sendable {
    func embed(_ text: String) async throws -> [Float]
    func embed(_ texts: [String]) async throws -> [[Float]]
    var dimension: Int { get }
}

/// Generates text embeddings using Apple's NLContextualEmbedding.
public final class EmbeddingService: EmbeddingServiceProtocol, Sendable {
    private let modelId: String

    /// The embedding dimension.
    public let dimension: Int

    public init(modelId: String = "com.apple.nlcontextualembedding.v1", dimension: Int = 512) {
        self.modelId = modelId
        self.dimension = dimension
    }

    /// Generate an embedding for a single text.
    public func embed(_ text: String) async throws -> [Float] {
        let results = try await embed([text])
        guard let first = results.first else {
            throw KnowledgeBaseError.embeddingFailed("No embedding generated")
        }
        return first
    }

    /// Generate embeddings for multiple texts.
    public func embed(_ texts: [String]) async throws -> [[Float]] {
        try texts.map { text in
            guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else {
                throw KnowledgeBaseError.embeddingFailed("Sentence embedding model not available")
            }
            guard let vector = embedding.vector(for: text) else {
                throw KnowledgeBaseError.embeddingFailed("Failed to generate vector for text")
            }
            return vector.map { Float($0) }
        }
    }
}

/// Errors from the knowledge base system.
public enum KnowledgeBaseError: Error, Sendable, Equatable {
    case embeddingFailed(String)
    case storeError(String)
    case indexingError(String)
    case projectNotFound
}

// MARK: - Chunking

/// Splits text into chunks suitable for embedding.
public struct TextChunker: Sendable {
    /// Maximum characters per chunk.
    public let maxChunkSize: Int

    /// Overlap between consecutive chunks.
    public let overlap: Int

    public init(maxChunkSize: Int = 500, overlap: Int = 50) {
        self.maxChunkSize = maxChunkSize
        self.overlap = overlap
    }

    /// Split text into overlapping chunks.
    public func chunk(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Short text — return as single chunk
        if trimmed.count <= maxChunkSize {
            return [trimmed]
        }

        var chunks: [String] = []
        var startIndex = trimmed.startIndex

        while startIndex < trimmed.endIndex {
            let endOffset = trimmed.distance(from: startIndex, to: trimmed.endIndex)
            let chunkLength = min(maxChunkSize, endOffset)
            let endIndex = trimmed.index(startIndex, offsetBy: chunkLength)

            // Try to break at a sentence or paragraph boundary
            let chunk = String(trimmed[startIndex..<endIndex])
            let breakPoint = findBreakPoint(in: chunk)

            if breakPoint < chunk.count && breakPoint > overlap {
                let breakIndex = chunk.index(chunk.startIndex, offsetBy: breakPoint)
                chunks.append(String(chunk[..<breakIndex]).trimmingCharacters(in: .whitespacesAndNewlines))

                // Advance with overlap
                let advance = max(breakPoint - overlap, 1)
                startIndex = trimmed.index(startIndex, offsetBy: advance)
            } else {
                chunks.append(chunk.trimmingCharacters(in: .whitespacesAndNewlines))

                let advance = max(chunkLength - overlap, 1)
                startIndex = trimmed.index(startIndex, offsetBy: advance)
            }
        }

        return chunks.filter { !$0.isEmpty }
    }

    /// Find the best break point (paragraph > sentence > word boundary).
    private func findBreakPoint(in text: String) -> Int {
        // Look for paragraph break
        if let range = text.range(of: "\n\n", options: .backwards) {
            let offset = text.distance(from: text.startIndex, to: range.upperBound)
            if offset > text.count / 3 { return offset }
        }

        // Look for sentence break
        if let range = text.range(of: ". ", options: .backwards) {
            let offset = text.distance(from: text.startIndex, to: range.upperBound)
            if offset > text.count / 3 { return offset }
        }

        // Look for newline
        if let range = text.range(of: "\n", options: .backwards) {
            let offset = text.distance(from: text.startIndex, to: range.upperBound)
            if offset > text.count / 3 { return offset }
        }

        return text.count
    }
}

// MARK: - Cosine Similarity

/// Compute cosine similarity between two vectors.
public func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    guard a.count == b.count, !a.isEmpty else { return 0 }

    var dot: Float = 0
    var normA: Float = 0
    var normB: Float = 0

    for i in 0..<a.count {
        dot += a[i] * b[i]
        normA += a[i] * a[i]
        normB += b[i] * b[i]
    }

    let denom = sqrt(normA) * sqrt(normB)
    guard denom > 0 else { return 0 }
    return dot / denom
}
