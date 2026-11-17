import Foundation
import PMDomain
import PMServices
import PMUtilities
import os

/// Steps in the migration flow.
public enum MigrationStep: Sendable {
    case selectFiles
    case preOnboarding
}

/// ViewModel for the markdown import flow.
/// Handles file selection and displays parsed projects for handoff to onboarding.
@Observable @MainActor
public final class MigrationViewModel {
    // State
    var step: MigrationStep = .selectFiles
    var parsedProjects: [ParsedProject] = []
    var repoURLs: [UUID: String] = [:]
    var progress: (current: Int, total: Int) = (0, 0)
    var error: String?

    // Dependencies
    private let importer: MarkdownImporter

    public init(importer: MarkdownImporter) {
        self.importer = importer
    }

    // MARK: - Actions

    func selectFolder(_ url: URL) async {
        error = nil

        do {
            let projects = try await importer.importDirectory(url: url) { [weak self] current, total in
                self?.progress = (current, total)
            }
            parsedProjects = projects
            step = .preOnboarding
        } catch {
            self.error = error.localizedDescription
            step = .selectFiles
        }
    }

    func selectFiles(_ urls: [URL]) async {
        error = nil

        do {
            let projects = try await importer.importFiles(urls: urls) { [weak self] current, total in
                self?.progress = (current, total)
            }
            parsedProjects = projects
            step = .preOnboarding
        } catch {
            self.error = error.localizedDescription
            step = .selectFiles
        }
    }

    /// Get project data needed to start onboarding for a specific parsed project.
    func projectDataForOnboarding(id: UUID) -> (markdown: String, repoURL: String, name: String)? {
        guard let project = parsedProjects.first(where: { $0.id == id }) else { return nil }
        let repoURL = repoURLs[id] ?? ""
        return (markdown: project.sourceMarkdown, repoURL: repoURL, name: project.name)
    }

    /// Get a preview (first ~5 lines) of the markdown content.
    func markdownPreview(for id: UUID) -> String {
        guard let project = parsedProjects.first(where: { $0.id == id }) else { return "" }
        let lines = project.sourceMarkdown.components(separatedBy: "\n")
        return lines.prefix(5).joined(separator: "\n")
    }

    func reset() {
        step = .selectFiles
        parsedProjects = []
        repoURLs = [:]
        progress = (0, 0)
        error = nil
    }
}
