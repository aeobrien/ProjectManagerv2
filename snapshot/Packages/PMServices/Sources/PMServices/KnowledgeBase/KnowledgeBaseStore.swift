import Foundation

/// Protocol for knowledge base storage, enabling testing with in-memory implementations.
public protocol KnowledgeBaseStoreProtocol: Sendable {
    /// Store an embedding for a chunk.
    func store(_ embedding: StoredEmbedding) async throws

    /// Store multiple embeddings.
    func storeBatch(_ embeddings: [StoredEmbedding]) async throws

    /// Retrieve all embeddings for a project.
    func fetchAll(forProject projectId: UUID) async throws -> [StoredEmbedding]

    /// Delete all embeddings for a source entity.
    func deleteBySource(sourceId: UUID) async throws

    /// Delete all embeddings for a project.
    func deleteAll(forProject projectId: UUID) async throws

    /// Check if a source entity has been indexed.
    func isIndexed(sourceId: UUID) async throws -> Bool

    /// Count of indexed chunks for a project.
    func count(forProject projectId: UUID) async throws -> Int
}

/// In-memory knowledge base store for testing and lightweight use.
public actor InMemoryKnowledgeBaseStore: KnowledgeBaseStoreProtocol {
    private var embeddings: [StoredEmbedding] = []

    public init() {}

    public func store(_ embedding: StoredEmbedding) throws {
        embeddings.append(embedding)
    }

    public func storeBatch(_ embeddings: [StoredEmbedding]) throws {
        self.embeddings.append(contentsOf: embeddings)
    }

    public func fetchAll(forProject projectId: UUID) throws -> [StoredEmbedding] {
        embeddings.filter { $0.projectId == projectId }
    }

    public func deleteBySource(sourceId: UUID) throws {
        embeddings.removeAll { $0.sourceId == sourceId }
    }

    public func deleteAll(forProject projectId: UUID) throws {
        embeddings.removeAll { $0.projectId == projectId }
    }

    public func isIndexed(sourceId: UUID) throws -> Bool {
        embeddings.contains { $0.sourceId == sourceId }
    }

    public func count(forProject projectId: UUID) throws -> Int {
        embeddings.filter { $0.projectId == projectId }.count
    }
}
