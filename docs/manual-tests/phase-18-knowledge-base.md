# Phase 18: Knowledge Base (RAG) — Manual Test Brief

## Automated Tests
- **29 tests** in 6 suites, passing via `cd Packages/PMServices && swift test`

### Suites
1. **TextChunkerTests** (6 tests) — Validates text chunking with sentence break detection, paragraph break detection, chunk size limits, empty input, single-sentence input, and overlapping chunk boundaries.
2. **CosineSimilarityTests** (3 tests) — Validates cosine similarity computation for identical vectors, orthogonal vectors, and partially similar vectors.
3. **InMemoryKnowledgeBaseStoreTests** (5 tests) — Validates the actor-based in-memory store for adding embeddings, retrieving by ID, listing all embeddings, deleting embeddings, and concurrent access safety under Swift 6 concurrency.
4. **KnowledgeBaseManagerTests** (10 tests) — Validates content indexing for check-ins, documents, and task notes, brute-force cosine similarity search returning ranked results, context retrieval for AI prompts with the 2000-character limit, re-indexing updated content, and handling missing or empty content.
5. **KBContentTypeTests** (3 tests) — Validates the KBContentType enum for all 5 content types, raw value round-tripping, and display name correctness.
6. **KnowledgeBaseErrorTests** (2 tests) — Validates error descriptions and equality for knowledge base error cases.

## Manual Verification Checklist
- [ ] EmbeddingService generates NLEmbedding sentence embeddings for input text
- [ ] TextChunker splits long text into chunks at sentence boundaries
- [ ] TextChunker splits long text into chunks at paragraph boundaries when appropriate
- [ ] TextChunker respects the configured maximum chunk size
- [ ] InMemoryKnowledgeBaseStore stores and retrieves embeddings by ID
- [ ] InMemoryKnowledgeBaseStore handles concurrent read/write access without data races
- [ ] KnowledgeBaseManager indexes check-in content and makes it searchable
- [ ] KnowledgeBaseManager indexes document content and makes it searchable
- [ ] KnowledgeBaseManager indexes task note content and makes it searchable
- [ ] Searching the knowledge base returns results ranked by cosine similarity
- [ ] Context retrieval for AI prompts returns relevant chunks within the 2000-character limit
- [ ] Re-indexing updated content replaces the old embeddings with new ones
- [ ] All 5 KBContentType values are recognized and have correct display names
- [ ] Querying with no indexed content returns an empty result set

## Files Created/Modified
### New Files
- `Packages/PMServices/Sources/PMServices/KnowledgeBase/EmbeddingService.swift` — NLEmbedding sentence embeddings, KBContentType enum (5 content types), TextChunk/StoredEmbedding/RetrievalResult structs, and TextChunker with sentence/paragraph break detection
- `Packages/PMServices/Sources/PMServices/KnowledgeBase/KnowledgeBaseStore.swift` — KnowledgeBaseStore protocol and InMemoryKnowledgeBaseStore (actor-based for Swift 6 concurrency)
- `Packages/PMServices/Sources/PMServices/KnowledgeBase/KnowledgeBaseManager.swift` — Content indexing for check-ins, documents, and task notes, brute-force cosine similarity search, and context retrieval for AI prompts with 2000-character cap
