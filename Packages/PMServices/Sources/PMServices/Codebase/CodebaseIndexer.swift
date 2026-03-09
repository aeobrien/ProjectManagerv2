import Foundation
import os
import PMDomain
import PMUtilities

/// Orchestrates codebase file scanning, git cloning, and indexing into the knowledge base.
public final class CodebaseIndexer: Sendable {
    private let kbManager: KnowledgeBaseManager
    private let codebaseRepo: CodebaseRepositoryProtocol
    private let documentRepo: DocumentRepositoryProtocol?
    private let llmClient: LLMClientProtocol?

    /// Thread-safe set of codebase IDs currently being indexed.
    private let _indexingIds = OSAllocatedUnfairLock(initialState: Set<UUID>())
    /// Thread-safe map of codebase ID → error message for failed indexing.
    private let _indexingErrors = OSAllocatedUnfairLock(initialState: [UUID: String]())

    /// Batch size for embedding — controls how many chunks are embedded per progress log.
    private static let embeddingBatchSize = 50

    public init(
        kbManager: KnowledgeBaseManager,
        codebaseRepo: CodebaseRepositoryProtocol,
        documentRepo: DocumentRepositoryProtocol? = nil,
        llmClient: LLMClientProtocol? = nil
    ) {
        self.kbManager = kbManager
        self.codebaseRepo = codebaseRepo
        self.documentRepo = documentRepo
        self.llmClient = llmClient
    }

    // MARK: - Indexing State (observable by views)

    /// Returns the set of codebase IDs currently being indexed.
    public var indexingIds: Set<UUID> {
        _indexingIds.withLock { $0 }
    }

    /// Returns the error message for a codebase, if indexing failed.
    public func indexingError(for id: UUID) -> String? {
        _indexingErrors.withLock { $0[id] }
    }

    /// Returns all current indexing errors.
    public var indexingErrors: [UUID: String] {
        _indexingErrors.withLock { $0 }
    }

    /// Whether a specific codebase is currently being indexed.
    public func isIndexing(_ id: UUID) -> Bool {
        _indexingIds.withLock { $0.contains(id) }
    }

    /// Clear the error for a codebase.
    public func clearError(for id: UUID) {
        _indexingErrors.withLock { $0.removeValue(forKey: id) }
    }

    private func markIndexingStarted(_ id: UUID) {
        _indexingIds.withLock { $0.insert(id) }
        _indexingErrors.withLock { $0.removeValue(forKey: id) }
    }

    private func markIndexingFinished(_ id: UUID, error: String? = nil) {
        _indexingIds.withLock { $0.remove(id) }
        if let error {
            _indexingErrors.withLock { $0[id] = error }
        }
    }

    // MARK: - Public API

    /// Index a codebase only if it hasn't been indexed in this app session yet.
    /// Use this on session start to avoid destroying and rebuilding the in-memory index unnecessarily.
    public func indexCodebaseIfNeeded(_ codebase: Codebase) async throws {
        let alreadyIndexed = try await kbManager.isIndexed(sourceId: codebase.id)
        if alreadyIndexed {
            Log.ai.info("Codebase '\(codebase.name)' already indexed in memory, skipping re-index")
            return
        }
        try await indexCodebase(codebase)
    }

    /// Force index or re-index a codebase. Clears existing chunks and rebuilds.
    /// Tracks indexing state so views can observe progress.
    public func indexCodebase(_ codebase: Codebase) async throws {
        markIndexingStarted(codebase.id)
        do {
            try await performIndexing(codebase)
            markIndexingFinished(codebase.id)
        } catch {
            markIndexingFinished(codebase.id, error: "Indexing failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func performIndexing(_ codebase: Codebase) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        Log.ai.info("Indexing codebase '\(codebase.name)' (\(codebase.sourceType.rawValue))")

        let rootURL: URL
        var updatedCodebase = codebase

        switch codebase.sourceType {
        case .local:
            rootURL = try resolveLocalAccess(codebase)
        case .github:
            rootURL = try await resolveGitHubAccess(codebase, updated: &updatedCodebase)
        }

        let files = try scanFiles(at: rootURL, sizeLimitMB: codebase.fileSizeLimitMB)
        Log.ai.info("[\(codebase.name)] Scanned \(files.count) files")

        // Clear existing KB entries for this codebase
        try await kbManager.removeIndex(sourceId: codebase.id)

        // Chunk all files
        let chunker = TextChunker(maxChunkSize: 500, overlap: 50)
        var allChunks: [String] = []

        for fileURL in files {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let relativePath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
            let headerComment = "// File: \(relativePath)\n"
            let rawChunks = chunker.chunk(content)
            let headeredChunks = rawChunks.map { headerComment + $0 }
            allChunks.append(contentsOf: headeredChunks)
        }

        Log.ai.info("[\(codebase.name)] Chunked into \(allChunks.count) chunks, starting embedding…")

        // Embed and store in batches with progress logging
        if !allChunks.isEmpty {
            let batchSize = Self.embeddingBatchSize
            let totalBatches = (allChunks.count + batchSize - 1) / batchSize

            for batchIndex in 0..<totalBatches {
                let start = batchIndex * batchSize
                let end = min(start + batchSize, allChunks.count)
                let batch = Array(allChunks[start..<end])

                try await kbManager.indexChunks(
                    projectId: codebase.projectId,
                    sourceId: codebase.id,
                    contentType: .sourceCode,
                    chunks: batch
                )

                Log.ai.info("[\(codebase.name)] Embedded batch \(batchIndex + 1)/\(totalBatches) (\(end)/\(allChunks.count) chunks)")

                // Yield to allow other async work (e.g. concurrent indexing) to proceed
                await Task.yield()
            }
        }

        // Update last indexed timestamp
        updatedCodebase.lastIndexedAt = Date()
        updatedCodebase.updatedAt = Date()
        try await codebaseRepo.save(updatedCodebase)

        // Generate an overview document from the indexed files
        let snapshot = buildCodebaseSnapshot(files: files, rootURL: rootURL)

        if codebase.sourceType == .local {
            stopLocalAccess(rootURL)
        }

        await generateOverviewDocument(codebase: updatedCodebase, snapshot: snapshot, fileCount: files.count)

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        Log.ai.info("[\(codebase.name)] Indexing complete: \(allChunks.count) chunks in \(String(format: "%.1f", elapsed))s")
    }

    /// Clean up all resources associated with a codebase (KB chunks, clone directory, overview document).
    /// Call this *before* deleting the codebase DB row. Best-effort — errors are logged, not thrown.
    public func cleanupCodebase(_ codebase: Codebase) async {
        Log.ai.info("Cleaning up codebase '\(codebase.name)' (id: \(codebase.id))")

        // 1. Remove in-memory KB chunks
        do {
            try await kbManager.removeIndex(sourceId: codebase.id)
            Log.ai.debug("Removed KB index for codebase '\(codebase.name)'")
        } catch {
            Log.ai.error("Failed to remove KB index for '\(codebase.name)': \(error)")
        }

        // 2. Delete clone directory for GitHub codebases
        if codebase.sourceType == .github, let clonedPath = codebase.clonedPath {
            let fm = FileManager.default
            if fm.fileExists(atPath: clonedPath) {
                do {
                    try fm.removeItem(atPath: clonedPath)
                    Log.ai.info("Deleted clone directory at \(clonedPath)")
                } catch {
                    Log.ai.error("Failed to delete clone directory at \(clonedPath): \(error)")
                }
            }
        }

        // 3. Delete the overview document
        if let documentRepo {
            do {
                let docs = try await documentRepo.fetchAll(forProject: codebase.projectId)
                let overviewTitle = "Codebase Overview: \(codebase.name)"
                if let overviewDoc = docs.first(where: { $0.title == overviewTitle }) {
                    try await documentRepo.delete(id: overviewDoc.id)
                    Log.ai.info("Deleted overview document '\(overviewTitle)'")
                }
            } catch {
                Log.ai.error("Failed to delete overview document for '\(codebase.name)': \(error)")
            }
        }
    }

    /// Retrieve relevant code snippets for a query.
    public func searchCode(projectId: UUID, query: String, limit: Int = 5) async throws -> [RetrievalResult] {
        try await kbManager.search(
            query: query,
            projectId: projectId,
            topK: limit,
            minScore: 0.1,
            contentTypes: [.sourceCode]
        )
    }

    /// Returns a file listing for a codebase, useful as fallback context when semantic search returns nothing.
    public func fileListingContext(for codebase: Codebase) -> String? {
        let rootURL: URL
        var needsStopAccess = false
        switch codebase.sourceType {
        case .local:
            guard let url = try? resolveLocalAccess(codebase) else { return nil }
            rootURL = url
            needsStopAccess = true
        case .github:
            guard let clonedPath = codebase.clonedPath else { return nil }
            rootURL = URL(fileURLWithPath: clonedPath)
        }
        defer { if needsStopAccess { stopLocalAccess(rootURL) } }

        guard let files = try? scanFiles(at: rootURL, sizeLimitMB: codebase.fileSizeLimitMB) else { return nil }

        let listing = files.map { url in
            url.path.replacingOccurrences(of: rootURL.path + "/", with: "")
        }

        return "CODEBASE FILE LISTING (\(codebase.name), \(listing.count) files):\n" + listing.joined(separator: "\n")
    }

    // MARK: - Overview Document Generation

    /// Build a condensed snapshot of the codebase: file tree grouped by directory + first ~20 lines per file.
    private func buildCodebaseSnapshot(files: [URL], rootURL: URL) -> String {
        let maxSnapshotChars = 30_000
        var snapshot = ""

        for fileURL in files {
            let relativePath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

            let lines = content.components(separatedBy: .newlines)
            let preview = lines.prefix(20).joined(separator: "\n")

            let entry = "=== \(relativePath) ===\n\(preview)\n\n"
            if snapshot.count + entry.count > maxSnapshotChars {
                snapshot += "... (\(files.count) files total, snapshot truncated)\n"
                break
            }
            snapshot += entry
        }

        return snapshot
    }

    /// Generate an overview document using the LLM, or fall back to the structural snapshot.
    private func generateOverviewDocument(codebase: Codebase, snapshot: String, fileCount: Int) async {
        guard let documentRepo else {
            Log.ai.debug("No documentRepo available, skipping overview document generation")
            return
        }
        guard !snapshot.isEmpty else { return }

        let overviewTitle = "Codebase Overview: \(codebase.name)"

        // Try LLM analysis first
        var overviewContent: String?
        if let llmClient {
            let systemPrompt = """
            You are a senior software engineer. Analyze the provided codebase snapshot and generate a concise, \
            well-structured overview in markdown. Focus on what would help someone understand the codebase quickly.
            """
            let userPrompt = """
            Project: \(codebase.name)
            Files: \(fileCount)

            Codebase snapshot (first ~20 lines per file):

            \(snapshot)

            Generate a markdown overview covering:
            1. **Architecture Overview** — high-level structure and patterns
            2. **Key Modules/Directories** — what each major directory contains
            3. **Important Files** — the most significant files and what they do
            4. **Tech Stack** — languages, frameworks, and key dependencies detected
            5. **Current State Summary** — what the codebase appears to do and its maturity level
            """

            do {
                let config = LLMRequestConfig(maxTokens: 4096, temperature: 0.3)
                let response = try await llmClient.send(
                    messages: [
                        LLMMessage(role: .system, content: systemPrompt),
                        LLMMessage(role: .user, content: userPrompt)
                    ],
                    config: config
                )
                overviewContent = response.content
                Log.ai.info("Generated LLM overview for codebase '\(codebase.name)' (\(response.content.count) chars)")
            } catch {
                Log.ai.error("LLM overview generation failed for '\(codebase.name)', falling back to snapshot: \(error)")
            }
        }

        // Fallback: use the structural snapshot directly
        if overviewContent == nil {
            overviewContent = """
            # Codebase Overview: \(codebase.name)

            *Auto-generated structural snapshot (\(fileCount) files). LLM analysis was not available.*

            \(snapshot)
            """
            Log.ai.info("Using structural snapshot fallback for overview document")
        }

        guard let content = overviewContent else { return }

        // Upsert the document: update existing or create new
        do {
            let existingDocs = try await documentRepo.fetchAll(forProject: codebase.projectId)
            let existing = existingDocs.first { $0.title.hasPrefix("Codebase Overview:") }

            if var doc = existing {
                doc.content = content
                doc.version += 1
                doc.updatedAt = Date()
                try await documentRepo.save(doc)
                Log.ai.info("Updated overview document '\(doc.title)' to v\(doc.version)")
            } else {
                let doc = Document(
                    projectId: codebase.projectId,
                    type: .other,
                    title: overviewTitle,
                    content: content
                )
                try await documentRepo.save(doc)
                Log.ai.info("Created overview document '\(overviewTitle)'")
            }
        } catch {
            Log.ai.error("Failed to save overview document for '\(codebase.name)': \(error)")
        }
    }

    // MARK: - Local Directory Access

    private func resolveLocalAccess(_ codebase: Codebase) throws -> URL {
        #if os(macOS)
        if let bookmarkData = codebase.bookmarkData {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                Log.ai.notice("Security-scoped bookmark is stale for '\(codebase.name)' — access may fail")
            }
            guard url.startAccessingSecurityScopedResource() else {
                Log.ai.error("startAccessingSecurityScopedResource failed for '\(codebase.name)' at \(url.path)")
                throw CodebaseIndexerError.accessDenied(codebase.name)
            }
            Log.ai.debug("Resolved bookmark for '\(codebase.name)' → \(url.path)")
            return url
        }
        #endif
        if let localPath = codebase.localPath {
            Log.ai.debug("Using localPath for '\(codebase.name)' → \(localPath) (no bookmark data)")
            return URL(fileURLWithPath: localPath)
        } else {
            throw CodebaseIndexerError.noPathAvailable(codebase.name)
        }
    }

    private func stopLocalAccess(_ url: URL) {
        #if os(macOS)
        url.stopAccessingSecurityScopedResource()
        #endif
    }

    // MARK: - GitHub Clone

    private func resolveGitHubAccess(_ codebase: Codebase, updated: inout Codebase) async throws -> URL {
        guard let githubURL = codebase.githubURL, !githubURL.isEmpty else {
            throw CodebaseIndexerError.noURLAvailable(codebase.name)
        }

        let cloneDir = Self.cloneDirectory(for: codebase.id)

        // If already cloned, pull latest; otherwise clone fresh
        if FileManager.default.fileExists(atPath: cloneDir.path) {
            try await gitPull(at: cloneDir)
        } else {
            try FileManager.default.createDirectory(at: cloneDir.deletingLastPathComponent(), withIntermediateDirectories: true)
            try await gitClone(url: githubURL, to: cloneDir)
        }

        updated.clonedPath = cloneDir.path
        return cloneDir
    }

    private static func cloneDirectory(for codebaseId: UUID) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("ProjectManager", isDirectory: true)
            .appendingPathComponent("Codebases", isDirectory: true)
            .appendingPathComponent(codebaseId.uuidString, isDirectory: true)
    }

    private func gitClone(url: String, to destination: URL) async throws {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["clone", "--depth", "1", url, destination.path]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw CodebaseIndexerError.cloneFailed(url, errorMsg)
        }

        Log.ai.info("Cloned \(url) to \(destination.path)")
        #else
        throw CodebaseIndexerError.cloneFailed(url, "Git clone is not supported on iOS")
        #endif
    }

    private func gitPull(at directory: URL) async throws {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["pull", "--ff-only"]
        process.currentDirectoryURL = directory

        try process.run()
        process.waitUntilExit()
        // Non-zero exit from pull is non-fatal — use existing clone
        #else
        Log.ai.debug("Git pull skipped on iOS for \(directory.path)")
        #endif
    }

    // MARK: - File Scanning

    /// Directories always skipped during scanning.
    private static let skippedDirectories: Set<String> = [
        ".git", "node_modules", "build", "DerivedData", ".build", "dist", "target",
        "__pycache__", ".venv", "venv", "Pods", ".next"
    ]

    /// Extensionless filenames to include.
    private static let allowedFilenames: Set<String> = [
        "dockerfile", "makefile", "cmakelists.txt", "gemfile", "rakefile", "podfile"
    ]

    /// Allowed file extensions for indexing.
    private static let allowedExtensions: Set<String> = [
        "swift", "py", "js", "jsx", "ts", "tsx", "md", "json", "yaml", "yml", "toml",
        "rs", "go", "java", "kt", "rb", "html", "css", "scss", "sql", "sh", "bash", "zsh",
        "c", "cpp", "h", "hpp", "m", "mm", "cs", "php", "r", "scala", "ex", "exs",
        "lua", "vim", "el", "clj", "hs", "ml", "proto", "graphql", "tf",
        "dockerfile", "makefile", "cmake", "gradle", "xml", "plist", "strings"
    ]

    private func scanFiles(at rootURL: URL, sizeLimitMB: Int) throws -> [URL] {
        let sizeLimitBytes = Int64(sizeLimitMB) * 1_048_576
        var totalSize: Int64 = 0
        var files: [URL] = []

        // Load .gitignore rules if present (mutable — nested .gitignore files are added during scan)
        var ignoreRules = GitignoreRules(rootURL: rootURL)

        let fm = FileManager.default

        // Don't use .skipsHiddenFiles — iCloud Drive stores evicted files as hidden
        // .filename.icloud placeholders. We filter hidden files manually instead.
        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isDirectoryKey, .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey],
            options: []
        ) else {
            Log.ai.error("FileManager.enumerator returned nil for \(rootURL.path)")
            return []
        }

        var evictedCount = 0
        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey, .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])

            // Handle directories
            if resourceValues.isDirectory == true {
                let dirName = name.lowercased()
                // Skip hidden directories (except .icloud containers which aren't directories)
                if dirName.hasPrefix(".") {
                    enumerator.skipDescendants()
                    continue
                }
                let relativePath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
                if Self.skippedDirectories.contains(dirName) || ignoreRules.isIgnored(relativePath + "/", isDirectory: true) {
                    enumerator.skipDescendants()
                    continue
                }
                // Load nested .gitignore if present
                let nestedGitignore = fileURL.appendingPathComponent(".gitignore")
                if FileManager.default.fileExists(atPath: nestedGitignore.path) {
                    ignoreRules.addRules(from: nestedGitignore, directoryRelativePath: relativePath)
                }
                continue
            }

            // Detect iCloud evicted placeholder files: .FileName.ext.icloud
            if name.hasPrefix(".") && name.hasSuffix(".icloud") {
                // Extract real filename: ".ContentView.swift.icloud" → "ContentView.swift"
                let stripped = String(name.dropFirst().dropLast(7)) // remove leading "." and trailing ".icloud"
                let realURL = fileURL.deletingLastPathComponent().appendingPathComponent(stripped)
                let realExt = realURL.pathExtension.lowercased()
                let realFilename = realURL.lastPathComponent.lowercased()

                // Only trigger download if the file type is one we'd index
                if Self.allowedExtensions.contains(realExt) || Self.allowedFilenames.contains(realFilename) {
                    // Trigger iCloud download for this file
                    do {
                        try fm.startDownloadingUbiquitousItem(at: realURL)
                    } catch {
                        // Non-fatal — file may not be ubiquitous or already downloading
                    }
                    evictedCount += 1
                }
                continue
            }

            // Skip other hidden files (.DS_Store, etc.)
            if name.hasPrefix(".") { continue }

            guard resourceValues.isRegularFile == true else { continue }

            // Compute path relative to root for gitignore matching
            let relativePath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")

            // Skip files matched by .gitignore
            if ignoreRules.isIgnored(relativePath, isDirectory: false) { continue }

            let ext = fileURL.pathExtension.lowercased()
            let filename = name.lowercased()
            guard Self.allowedExtensions.contains(ext) ||
                  Self.allowedFilenames.contains(filename) else {
                continue
            }

            let fileSize = Int64(resourceValues.fileSize ?? 0)
            if totalSize + fileSize > sizeLimitBytes {
                break
            }

            totalSize += fileSize
            files.append(fileURL)
        }

        if evictedCount > 0 {
            Log.ai.notice("scanFiles: \(evictedCount) files are evicted on iCloud Drive — triggered download. Re-index after files finish downloading.")
        }

        return files
    }
}

// MARK: - Errors

public enum CodebaseIndexerError: Error, Sendable {
    case accessDenied(String)
    case noPathAvailable(String)
    case noURLAvailable(String)
    case cloneFailed(String, String)
}

// MARK: - Gitignore Parser

/// Lightweight .gitignore parser that handles the most common patterns.
/// Loads rules from `.gitignore` files at any level and matches relative paths against them.
struct GitignoreRules {
    private var rules: [(pattern: String, isNegation: Bool, isDirectoryOnly: Bool, prefix: String)]

    init(rootURL: URL) {
        rules = []
        let gitignorePath = rootURL.appendingPathComponent(".gitignore")
        loadRules(from: gitignorePath, prefix: "")
    }

    /// Load rules from a nested `.gitignore` file.
    /// `directoryRelativePath` is the directory's path relative to the repo root (e.g. "Packages/Foo").
    mutating func addRules(from gitignoreURL: URL, directoryRelativePath: String) {
        loadRules(from: gitignoreURL, prefix: directoryRelativePath)
    }

    private mutating func loadRules(from gitignoreURL: URL, prefix: String) {
        guard let content = try? String(contentsOf: gitignoreURL, encoding: .utf8) else { return }

        let parsed: [(String, Bool, Bool, String)] = content.components(separatedBy: .newlines).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { return nil }

            var pattern = trimmed
            let isNegation = pattern.hasPrefix("!")
            if isNegation { pattern = String(pattern.dropFirst()) }

            let isDirectoryOnly = pattern.hasSuffix("/")
            if isDirectoryOnly { pattern = String(pattern.dropLast()) }

            // Remove leading slash (anchored to the gitignore's directory)
            if pattern.hasPrefix("/") { pattern = String(pattern.dropFirst()) }

            return (pattern, isNegation, isDirectoryOnly, prefix)
        }
        rules.append(contentsOf: parsed)
    }

    /// Check whether a relative path should be ignored.
    /// `relativePath` is relative to the repo root, e.g. "src/main.swift" or "build/".
    /// For directories, pass `isDirectory: true`.
    func isIgnored(_ relativePath: String, isDirectory: Bool) -> Bool {
        guard !rules.isEmpty else { return false }

        var ignored = false
        for rule in rules {
            if rule.isDirectoryOnly && !isDirectory { continue }

            // Determine the path to match against: strip the rule's prefix
            let matchPath: String
            if rule.prefix.isEmpty {
                matchPath = relativePath
            } else {
                let prefixWithSlash = rule.prefix + "/"
                guard relativePath.hasPrefix(prefixWithSlash) else { continue }
                matchPath = String(relativePath.dropFirst(prefixWithSlash.count))
            }

            if matches(pattern: rule.pattern, path: matchPath) {
                ignored = !rule.isNegation
            }
        }
        return ignored
    }

    /// Match a gitignore pattern against a relative path.
    /// Supports: plain names (match any component), paths with `/`, `*` wildcards, `**` globs.
    private func matches(pattern: String, path: String) -> Bool {
        // If pattern contains no slash, it matches against just the filename or any path component
        if !pattern.contains("/") {
            // Match against any path component
            let components = path.components(separatedBy: "/")
            return components.contains { fnmatch(pattern, component: $0) }
        }

        // Pattern contains a slash — match against the full relative path
        return fnmatchPath(pattern: pattern, path: path)
    }

    /// Simple fnmatch-style matching for a single component. Supports `*` and `?`.
    private func fnmatch(_ pattern: String, component: String) -> Bool {
        fnmatchPath(pattern: pattern, path: component)
    }

    /// Match a pattern against a path, supporting `*`, `?`, and `**`.
    private func fnmatchPath(pattern: String, path: String) -> Bool {
        var pi = pattern.startIndex
        var si = path.startIndex

        return fnmatchRecursive(pattern: pattern, pi: &pi, path: path, si: &si)
    }

    private func fnmatchRecursive(pattern: String, pi: inout String.Index, path: String, si: inout String.Index) -> Bool {
        let patternEnd = pattern.endIndex
        let pathEnd = path.endIndex

        while pi < patternEnd {
            let pc = pattern[pi]

            if pc == "*" {
                let nextPi = pattern.index(after: pi)
                // Check for **
                if nextPi < patternEnd && pattern[nextPi] == "*" {
                    // `**` matches any number of directories
                    let afterStars = pattern.index(after: nextPi)
                    // Skip trailing slash after ** if present
                    let resumePattern: String.Index
                    if afterStars < patternEnd && pattern[afterStars] == "/" {
                        resumePattern = pattern.index(after: afterStars)
                    } else {
                        resumePattern = afterStars
                    }

                    // If nothing left in pattern, match everything
                    if resumePattern >= patternEnd { return true }

                    // Try matching the rest of the pattern at every `/` boundary and at start
                    var tryIdx = si
                    while tryIdx <= pathEnd {
                        var testPi = resumePattern
                        var testSi = tryIdx
                        if fnmatchRecursive(pattern: pattern, pi: &testPi, path: path, si: &testSi) {
                            return true
                        }
                        guard tryIdx < pathEnd else { break }
                        tryIdx = path.index(after: tryIdx)
                    }
                    return false
                }

                // Single `*` — matches anything except `/`
                let nextPatternIdx = pattern.index(after: pi)
                if nextPatternIdx >= patternEnd {
                    // `*` at end — match if no more `/` in remaining path
                    return !path[si...].contains("/")
                }

                // Try consuming 0..n non-slash characters
                var tryIdx = si
                while tryIdx <= pathEnd {
                    if tryIdx < pathEnd && path[tryIdx] == "/" {
                        // Can't consume past /
                        var testPi = nextPatternIdx
                        var testSi = tryIdx
                        if fnmatchRecursive(pattern: pattern, pi: &testPi, path: path, si: &testSi) {
                            return true
                        }
                        break
                    }
                    var testPi = nextPatternIdx
                    var testSi = tryIdx
                    if fnmatchRecursive(pattern: pattern, pi: &testPi, path: path, si: &testSi) {
                        return true
                    }
                    guard tryIdx < pathEnd else { break }
                    tryIdx = path.index(after: tryIdx)
                }
                return false
            } else if pc == "?" {
                guard si < pathEnd && path[si] != "/" else { return false }
                pi = pattern.index(after: pi)
                si = path.index(after: si)
            } else {
                guard si < pathEnd && path[si] == pc else { return false }
                pi = pattern.index(after: pi)
                si = path.index(after: si)
            }
        }

        return si >= pathEnd
    }
}
