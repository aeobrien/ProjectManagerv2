import Foundation
import PMDomain
import PMUtilities
import os

// MARK: - Parsed Types

/// A project extracted from a markdown file, ready for onboarding.
public struct ParsedProject: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var sourceMarkdown: String

    public init(
        id: UUID = UUID(),
        name: String,
        sourceMarkdown: String = ""
    ) {
        self.id = id
        self.name = name
        self.sourceMarkdown = sourceMarkdown
    }
}

// MARK: - MarkdownImporter

/// Service that reads markdown files and extracts project name + source content.
/// The actual project structuring is handled by the onboarding flow.
public final class MarkdownImporter: Sendable {

    public init() {}

    /// Parse specific .md files into ParsedProjects.
    public func importFiles(
        urls: [URL],
        progress: @Sendable @MainActor (Int, Int) -> Void
    ) async throws -> [ParsedProject] {
        let mdFiles = urls.filter { $0.pathExtension.lowercased() == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var projects: [ParsedProject] = []
        let total = mdFiles.count

        for (index, file) in mdFiles.enumerated() {
            await progress(index + 1, total)
            do {
                let markdown = try String(contentsOf: file, encoding: .utf8)
                let project = parseMarkdown(markdown, filename: file.deletingPathExtension().lastPathComponent)
                projects.append(project)
                Log.data.info("Parsed project from \(file.lastPathComponent): \(project.name)")
            } catch {
                Log.data.error("Failed to read \(file.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return projects
    }

    /// Read all .md files from a directory and parse each into a ParsedProject.
    public func importDirectory(
        url: URL,
        progress: @Sendable @MainActor (Int, Int) -> Void
    ) async throws -> [ParsedProject] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        let mdFiles = contents.filter { $0.pathExtension.lowercased() == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var projects: [ParsedProject] = []
        let total = mdFiles.count

        for (index, file) in mdFiles.enumerated() {
            await progress(index + 1, total)
            do {
                let markdown = try String(contentsOf: file, encoding: .utf8)
                let project = parseMarkdown(markdown, filename: file.deletingPathExtension().lastPathComponent)
                projects.append(project)
                Log.data.info("Parsed project from \(file.lastPathComponent): \(project.name)")
            } catch {
                Log.data.error("Failed to read \(file.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return projects
    }

    /// Parse a single markdown string into a ParsedProject (name extraction only).
    public func parseMarkdown(_ markdown: String, filename: String) -> ParsedProject {
        let projectName = extractProjectName(from: markdown) ?? filename
        return ParsedProject(name: projectName, sourceMarkdown: markdown)
    }

    // MARK: - Name Extraction

    private func extractProjectName(from markdown: String) -> String? {
        let lines = markdown.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}
