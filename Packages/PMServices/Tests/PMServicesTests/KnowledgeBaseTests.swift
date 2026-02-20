import Testing
import Foundation
@testable import PMServices
@testable import PMDomain

// MARK: - Mock Embedding Service

final class MockEmbeddingService: EmbeddingServiceProtocol, @unchecked Sendable {
    let dimension: Int = 4
    var shouldThrow = false

    /// Returns a deterministic embedding based on the text hash.
    func embed(_ text: String) async throws -> [Float] {
        if shouldThrow { throw KnowledgeBaseError.embeddingFailed("Mock error") }
        return deterministicVector(for: text)
    }

    func embed(_ texts: [String]) async throws -> [[Float]] {
        if shouldThrow { throw KnowledgeBaseError.embeddingFailed("Mock error") }
        return texts.map { deterministicVector(for: $0) }
    }

    private func deterministicVector(for text: String) -> [Float] {
        let hash = text.hashValue
        let a = Float(hash & 0xFF) / 255.0
        let b = Float((hash >> 8) & 0xFF) / 255.0
        let c = Float((hash >> 16) & 0xFF) / 255.0
        let d = Float((hash >> 24) & 0xFF) / 255.0
        return [a, b, c, d]
    }
}

// MARK: - TextChunker Tests

@Suite("TextChunker")
struct TextChunkerTests {

    @Test("Empty text returns no chunks")
    func emptyText() {
        let chunker = TextChunker()
        #expect(chunker.chunk("").isEmpty)
        #expect(chunker.chunk("   ").isEmpty)
    }

    @Test("Short text returns single chunk")
    func shortText() {
        let chunker = TextChunker(maxChunkSize: 500)
        let chunks = chunker.chunk("Hello world")
        #expect(chunks.count == 1)
        #expect(chunks.first == "Hello world")
    }

    @Test("Long text splits into multiple chunks")
    func longText() {
        let chunker = TextChunker(maxChunkSize: 50, overlap: 10)
        let text = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 10)
        let chunks = chunker.chunk(text)
        #expect(chunks.count > 1)
        for chunk in chunks {
            #expect(!chunk.isEmpty)
        }
    }

    @Test("Chunks respect max size")
    func maxSize() {
        let chunker = TextChunker(maxChunkSize: 100, overlap: 10)
        let text = String(repeating: "Word. ", count: 100)
        let chunks = chunker.chunk(text)
        for chunk in chunks {
            #expect(chunk.count <= 100)
        }
    }
}

// MARK: - Cosine Similarity Tests

@Suite("CosineSimilarity")
struct CosineSimilarityTests {

    @Test("Identical vectors have similarity 1")
    func identical() {
        let v = [Float](repeating: 0.5, count: 4)
        let score = cosineSimilarity(v, v)
        #expect(abs(score - 1.0) < 0.001)
    }

    @Test("Orthogonal vectors have similarity 0")
    func orthogonal() {
        let a: [Float] = [1, 0, 0, 0]
        let b: [Float] = [0, 1, 0, 0]
        let score = cosineSimilarity(a, b)
        #expect(abs(score) < 0.001)
    }

    @Test("Empty vectors return 0")
    func empty() {
        let score = cosineSimilarity([], [])
        #expect(score == 0)
    }

    @Test("Mismatched lengths return 0")
    func mismatched() {
        let score = cosineSimilarity([1, 2], [1, 2, 3])
        #expect(score == 0)
    }

    @Test("Opposite vectors have similarity -1")
    func opposite() {
        let a: [Float] = [1, 0, 0, 0]
        let b: [Float] = [-1, 0, 0, 0]
        let score = cosineSimilarity(a, b)
        #expect(abs(score + 1.0) < 0.001)
    }
}

// MARK: - InMemoryKnowledgeBaseStore Tests

@Suite("InMemoryKnowledgeBaseStore")
struct InMemoryKnowledgeBaseStoreTests {

    @Test("Store and fetch embeddings")
    func storeAndFetch() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let projectId = UUID()
        let embedding = StoredEmbedding(
            chunkId: UUID(),
            projectId: projectId,
            sourceId: UUID(),
            contentType: .document,
            text: "Test text",
            embedding: [0.1, 0.2, 0.3]
        )

        try await store.store(embedding)
        let results = try await store.fetchAll(forProject: projectId)

        #expect(results.count == 1)
        #expect(results.first?.text == "Test text")
    }

    @Test("Store batch")
    func storeBatch() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let projectId = UUID()
        let embeddings = (0..<5).map { i in
            StoredEmbedding(
                chunkId: UUID(),
                projectId: projectId,
                sourceId: UUID(),
                contentType: .taskNotes,
                text: "Chunk \(i)",
                embedding: [Float(i)]
            )
        }

        try await store.storeBatch(embeddings)
        let count = try await store.count(forProject: projectId)
        #expect(count == 5)
    }

    @Test("Delete by source")
    func deleteBySource() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let projectId = UUID()
        let sourceId = UUID()

        try await store.store(StoredEmbedding(
            chunkId: UUID(), projectId: projectId, sourceId: sourceId,
            contentType: .document, text: "A", embedding: [1]
        ))
        try await store.store(StoredEmbedding(
            chunkId: UUID(), projectId: projectId, sourceId: UUID(),
            contentType: .document, text: "B", embedding: [2]
        ))

        try await store.deleteBySource(sourceId: sourceId)

        let results = try await store.fetchAll(forProject: projectId)
        #expect(results.count == 1)
        #expect(results.first?.text == "B")
    }

    @Test("Delete all for project")
    func deleteAllForProject() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let projectId = UUID()
        let otherProjectId = UUID()

        try await store.store(StoredEmbedding(
            chunkId: UUID(), projectId: projectId, sourceId: UUID(),
            contentType: .document, text: "A", embedding: [1]
        ))
        try await store.store(StoredEmbedding(
            chunkId: UUID(), projectId: otherProjectId, sourceId: UUID(),
            contentType: .document, text: "B", embedding: [2]
        ))

        try await store.deleteAll(forProject: projectId)

        #expect(try await store.count(forProject: projectId) == 0)
        #expect(try await store.count(forProject: otherProjectId) == 1)
    }

    @Test("isIndexed")
    func isIndexed() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let sourceId = UUID()

        #expect(try await store.isIndexed(sourceId: sourceId) == false)

        try await store.store(StoredEmbedding(
            chunkId: UUID(), projectId: UUID(), sourceId: sourceId,
            contentType: .document, text: "A", embedding: [1]
        ))

        #expect(try await store.isIndexed(sourceId: sourceId) == true)
    }

    @Test("Project isolation")
    func projectIsolation() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let project1 = UUID()
        let project2 = UUID()

        try await store.store(StoredEmbedding(
            chunkId: UUID(), projectId: project1, sourceId: UUID(),
            contentType: .document, text: "P1", embedding: [1]
        ))
        try await store.store(StoredEmbedding(
            chunkId: UUID(), projectId: project2, sourceId: UUID(),
            contentType: .document, text: "P2", embedding: [2]
        ))

        let results1 = try await store.fetchAll(forProject: project1)
        #expect(results1.count == 1)
        #expect(results1.first?.text == "P1")
    }
}

// MARK: - KnowledgeBaseManager Tests

@Suite("KnowledgeBaseManager")
struct KnowledgeBaseManagerTests {

    @Test("Index text creates chunks and embeddings")
    func indexText() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let embedding = MockEmbeddingService()
        let manager = KnowledgeBaseManager(store: store, embeddingService: embedding)
        let projectId = UUID()
        let sourceId = UUID()

        try await manager.index(
            projectId: projectId,
            sourceId: sourceId,
            contentType: .document,
            text: "Short document content"
        )

        let count = try await manager.chunkCount(forProject: projectId)
        #expect(count >= 1)
        #expect(try await manager.isIndexed(sourceId: sourceId))
    }

    @Test("Index empty text does nothing")
    func indexEmpty() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let embedding = MockEmbeddingService()
        let manager = KnowledgeBaseManager(store: store, embeddingService: embedding)
        let projectId = UUID()

        try await manager.index(projectId: projectId, sourceId: UUID(), contentType: .document, text: "   ")

        let count = try await manager.chunkCount(forProject: projectId)
        #expect(count == 0)
    }

    @Test("Re-indexing replaces old embeddings")
    func reIndex() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let embedding = MockEmbeddingService()
        let manager = KnowledgeBaseManager(store: store, embeddingService: embedding)
        let projectId = UUID()
        let sourceId = UUID()

        try await manager.index(projectId: projectId, sourceId: sourceId, contentType: .document, text: "Version 1")
        try await manager.index(projectId: projectId, sourceId: sourceId, contentType: .document, text: "Version 2")

        let results = try await store.fetchAll(forProject: projectId)
        #expect(results.count == 1) // Only latest version
        #expect(results.first?.text == "Version 2")
    }

    @Test("Search returns relevant results")
    func search() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let embedding = MockEmbeddingService()
        let manager = KnowledgeBaseManager(store: store, embeddingService: embedding, minScore: 0.0)
        let projectId = UUID()

        try await manager.index(projectId: projectId, sourceId: UUID(), contentType: .document, text: "Swift concurrency patterns")
        try await manager.index(projectId: projectId, sourceId: UUID(), contentType: .taskNotes, text: "Fix login bug")

        let results = try await manager.search(query: "concurrency", projectId: projectId)
        #expect(!results.isEmpty)
    }

    @Test("Search with content type filter")
    func searchWithFilter() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let embedding = MockEmbeddingService()
        let manager = KnowledgeBaseManager(store: store, embeddingService: embedding, minScore: 0.0)
        let projectId = UUID()

        try await manager.index(projectId: projectId, sourceId: UUID(), contentType: .document, text: "Document content")
        try await manager.index(projectId: projectId, sourceId: UUID(), contentType: .taskNotes, text: "Task notes")

        let results = try await manager.search(
            query: "content",
            projectId: projectId,
            contentTypes: [.document]
        )
        for result in results {
            #expect(result.stored.contentType == .document)
        }
    }

    @Test("Search empty query returns empty")
    func searchEmpty() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let embedding = MockEmbeddingService()
        let manager = KnowledgeBaseManager(store: store, embeddingService: embedding)

        let results = try await manager.search(query: "  ", projectId: UUID())
        #expect(results.isEmpty)
    }

    @Test("Retrieve context formats results")
    func retrieveContext() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let embedding = MockEmbeddingService()
        let manager = KnowledgeBaseManager(store: store, embeddingService: embedding, minScore: 0.0)
        let projectId = UUID()

        try await manager.index(projectId: projectId, sourceId: UUID(), contentType: .document, text: "Project architecture notes")

        let context = try await manager.retrieveContext(query: "architecture", projectId: projectId)
        #expect(context.contains("Relevant project history"))
    }

    @Test("Index document")
    func indexDocument() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let embedding = MockEmbeddingService()
        let manager = KnowledgeBaseManager(store: store, embeddingService: embedding)
        let projectId = UUID()

        let doc = Document(projectId: projectId, type: .visionStatement, title: "Vision", content: "Build something great")
        try await manager.indexDocument(doc)

        #expect(try await manager.isIndexed(sourceId: doc.id))
    }

    @Test("Index check-in")
    func indexCheckIn() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let embedding = MockEmbeddingService()
        let manager = KnowledgeBaseManager(store: store, embeddingService: embedding)

        let projectId = UUID()
        let record = CheckInRecord(
            projectId: projectId,
            depth: .quickLog,
            transcript: "Worked on the login feature today",
            aiSummary: "Progress on authentication"
        )

        try await manager.indexCheckIn(record)

        #expect(try await manager.isIndexed(sourceId: record.id))
    }

    @Test("Remove index")
    func removeIndex() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let embedding = MockEmbeddingService()
        let manager = KnowledgeBaseManager(store: store, embeddingService: embedding)
        let projectId = UUID()
        let sourceId = UUID()

        try await manager.index(projectId: projectId, sourceId: sourceId, contentType: .document, text: "Some content")
        #expect(try await manager.isIndexed(sourceId: sourceId))

        try await manager.removeIndex(sourceId: sourceId)
        #expect(try await manager.isIndexed(sourceId: sourceId) == false)
    }

    @Test("Clear project index")
    func clearProjectIndex() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let embedding = MockEmbeddingService()
        let manager = KnowledgeBaseManager(store: store, embeddingService: embedding)
        let projectId = UUID()

        try await manager.index(projectId: projectId, sourceId: UUID(), contentType: .document, text: "Content 1")
        try await manager.index(projectId: projectId, sourceId: UUID(), contentType: .taskNotes, text: "Content 2")

        try await manager.clearProjectIndex(projectId: projectId)
        #expect(try await manager.chunkCount(forProject: projectId) == 0)
    }

    @Test("Embedding error propagates")
    func embeddingError() async throws {
        let store = InMemoryKnowledgeBaseStore()
        let embedding = MockEmbeddingService()
        embedding.shouldThrow = true
        let manager = KnowledgeBaseManager(store: store, embeddingService: embedding)

        await #expect(throws: KnowledgeBaseError.self) {
            try await manager.index(projectId: UUID(), sourceId: UUID(), contentType: .document, text: "Content")
        }
    }
}

// MARK: - KBContentType Tests

@Suite("KBContentType")
struct KBContentTypeTests {

    @Test("Raw values")
    func rawValues() {
        #expect(KBContentType.checkInTranscript.rawValue == "checkInTranscript")
        #expect(KBContentType.document.rawValue == "document")
        #expect(KBContentType.taskNotes.rawValue == "taskNotes")
        #expect(KBContentType.conversationMessage.rawValue == "conversationMessage")
        #expect(KBContentType.checkInSummary.rawValue == "checkInSummary")
    }
}

// MARK: - KnowledgeBaseError Tests

@Suite("KnowledgeBaseError")
struct KnowledgeBaseErrorTests {

    @Test("Equality")
    func equality() {
        #expect(KnowledgeBaseError.embeddingFailed("A") == KnowledgeBaseError.embeddingFailed("A"))
        #expect(KnowledgeBaseError.embeddingFailed("A") != KnowledgeBaseError.storeError("A"))
        #expect(KnowledgeBaseError.projectNotFound == KnowledgeBaseError.projectNotFound)
    }
}
