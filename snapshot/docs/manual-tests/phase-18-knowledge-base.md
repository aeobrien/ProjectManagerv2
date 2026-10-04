# Phase 18: Knowledge Base (RAG) — Manual Test Brief

## Automated Tests
- **29 tests** in 6 suites, passing via `cd Packages/PMServices && swift test`

### Suites
1. **TextChunkerTests** (4 tests) — Validates empty text returns no chunks, short text returns single chunk, long text splits into multiple chunks, and chunks respect max size.
2. **CosineSimilarityTests** (5 tests) — Validates identical vectors (similarity 1), orthogonal vectors (similarity 0), empty vectors (returns 0), mismatched lengths (returns 0), and opposite vectors (similarity -1).
3. **InMemoryKnowledgeBaseStoreTests** (6 tests) — Validates store and fetch embeddings, batch storage, delete by source, delete all for project, isIndexed check, and project isolation.
4. **KnowledgeBaseManagerTests** (12 tests) — Validates text indexing with chunk creation, empty text indexing (no-op), re-indexing replaces old embeddings, search returns results, search with content type filter, empty query search, context retrieval formatting, document indexing, check-in indexing, index removal, project index clearing, and embedding error propagation.
5. **KBContentTypeTests** (1 test) — Validates raw values for all 5 content types.
6. **KnowledgeBaseErrorTests** (1 test) — Validates error equality and inequality.

## Manual Verification Checklist

### Embedding & Chunking
- [ ] EmbeddingService generates NLEmbedding sentence embeddings for input text
- [ ] TextChunker splits long text into chunks at sentence boundaries
- [ ] TextChunker splits long text into chunks at paragraph boundaries when appropriate
- [ ] TextChunker respects the configured maximum chunk size

### Storage
- [ ] InMemoryKnowledgeBaseStore stores and retrieves embeddings by project
- [ ] InMemoryKnowledgeBaseStore handles concurrent read/write access without data races
- [ ] Project isolation: embeddings from one project are not visible to another

### Incremental Indexing
- [ ] After completing a check-in, the transcript and AI summary are indexed in the KB
- [ ] After saving a document (explicit save), the document content is indexed in the KB
- [ ] After updating a task with notes, the task notes are indexed in the KB
- [ ] Re-indexing updated content replaces the old embeddings (no duplicates)

### Retrieval & AI Integration
- [ ] KnowledgeBaseManager indexes check-in content and makes it searchable
- [ ] KnowledgeBaseManager indexes document content and makes it searchable
- [ ] KnowledgeBaseManager indexes task note content and makes it searchable
- [ ] Searching the knowledge base returns results ranked by cosine similarity
- [ ] Context retrieval for AI prompts returns relevant chunks within the 2000-character limit
- [ ] In Chat, sending a message with a selected project retrieves KB context and includes it in the AI prompt
- [ ] All 5 KBContentType values are recognized
- [ ] Querying with no indexed content returns an empty result set

### App Wiring
- [ ] KnowledgeBaseManager is created in macOS ContentView initialize()
- [ ] KnowledgeBaseManager is created in iOS iOSContentView initialize()
- [ ] ChatViewModel receives a ContextAssembler with the KnowledgeBaseManager attached
- [ ] CheckInFlowManager receives a ContextAssembler with the KnowledgeBaseManager attached
- [ ] CheckInFlowManager has knowledgeBaseManager set for incremental indexing
- [ ] DocumentViewModel receives knowledgeBaseManager for document indexing on save
- [ ] ProjectDetailViewModel receives knowledgeBaseManager for task notes indexing on update

## Files

### Source Files
- `Packages/PMServices/Sources/PMServices/KnowledgeBase/EmbeddingService.swift` — NLEmbedding sentence embeddings, KBContentType enum (5 content types), TextChunk/StoredEmbedding/RetrievalResult structs, TextChunker with sentence/paragraph break detection, cosineSimilarity function
- `Packages/PMServices/Sources/PMServices/KnowledgeBase/KnowledgeBaseStore.swift` — KnowledgeBaseStoreProtocol and InMemoryKnowledgeBaseStore (actor-based for Swift 6 concurrency)
- `Packages/PMServices/Sources/PMServices/KnowledgeBase/KnowledgeBaseManager.swift` — Content indexing for check-ins, documents, and task notes, brute-force cosine similarity search, and context retrieval for AI prompts with 2000-character cap
- `Packages/PMServices/Sources/PMServices/AI/ContextAssembler.swift` — Optional knowledgeBase property; retrieves KB context from last user message and injects into system prompt

### Incremental Indexing Hooks
- `Packages/PMFeatures/Sources/PMFeatures/CheckIn/CheckInFlowManager.swift` — `knowledgeBaseManager` property; indexes check-in after save via `Task.detached`
- `Packages/PMFeatures/Sources/PMFeatures/Documents/DocumentViewModel.swift` — `knowledgeBaseManager` parameter; indexes document after explicit save via `Task.detached`
- `Packages/PMFeatures/Sources/PMFeatures/ProjectDetail/ProjectDetailViewModel.swift` — `knowledgeBaseManager` property; indexes task notes after updateTask via `Task.detached`

### App Wiring
- `ProjectManager/Sources/ContentView.swift` — Creates EmbeddingService, InMemoryKnowledgeBaseStore, KnowledgeBaseManager; passes to ContextAssembler, CheckInFlowManager, ChatViewModel, DocumentViewModel, ProjectDetailViewModel
- `ProjectManageriOS/Sources/iOSContentView.swift` — Same wiring as macOS

### Tests
- `Packages/PMServices/Tests/PMServicesTests/KnowledgeBaseTests.swift` — 29 tests covering chunking, cosine similarity, store CRUD, manager indexing/search/retrieval, error handling
