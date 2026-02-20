import Testing
import Foundation
@testable import PMServices
@testable import PMDomain

// MARK: - Mock Export Backend

final class MockExportBackend: ExportBackendProtocol, @unchecked Sendable {
    var exportedPayloads: [ExportPayload] = []
    var shouldThrow: ExportError?

    func export(payload: ExportPayload, config: ExportConfig) async throws {
        if let error = shouldThrow { throw error }
        exportedPayloads.append(payload)
    }
}

// MARK: - ExportPayload Tests

@Suite("ExportPayload")
struct ExportPayloadTests {

    @Test("ExportedTask creation")
    func exportedTask() {
        let task = ExportedTask(
            id: UUID(),
            name: "Build login",
            definitionOfDone: "User can log in",
            adjustedEstimateMinutes: 120,
            deadline: Date(),
            milestoneName: "MVP",
            projectName: "App",
            categoryName: "Software",
            status: "inProgress",
            priority: "high",
            effortType: "deepFocus",
            dependencyNames: ["Design UI"],
            kanbanColumn: "inProgress"
        )
        #expect(task.name == "Build login")
        #expect(task.adjustedEstimateMinutes == 120)
        #expect(task.dependencyNames.count == 1)
    }

    @Test("ExportedProjectSummary creation")
    func projectSummary() {
        let summary = ExportedProjectSummary(
            id: UUID(),
            name: "App",
            categoryName: "Software",
            lifecycleState: "active",
            focusSlotIndex: 0,
            taskCount: 10,
            completedTaskCount: 3
        )
        #expect(summary.name == "App")
        #expect(summary.taskCount == 10)
        #expect(summary.completedTaskCount == 3)
    }

    @Test("Payload JSON encoding")
    func jsonEncoding() throws {
        let payload = ExportPayload(
            projects: [
                ExportedProjectSummary(
                    id: UUID(), name: "Test", categoryName: "Cat",
                    lifecycleState: "active", focusSlotIndex: nil,
                    taskCount: 1, completedTaskCount: 0
                )
            ],
            tasks: [
                ExportedTask(
                    id: UUID(), name: "Task 1", definitionOfDone: "Done",
                    adjustedEstimateMinutes: nil, deadline: nil,
                    milestoneName: "M1", projectName: "Test",
                    categoryName: "Cat", status: "notStarted",
                    priority: "normal", effortType: nil,
                    dependencyNames: [], kanbanColumn: "toDo"
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        #expect(data.count > 0)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportPayload.self, from: data)
        #expect(decoded.projects.count == 1)
        #expect(decoded.tasks.count == 1)
    }

    @Test("ExportPayloadBuilder builds payload")
    func buildPayload() {
        let builder = ExportPayloadBuilder()
        let catId = UUID()
        let projectId = UUID()
        let phaseId = UUID()
        let msId = UUID()

        let projects = [Project(name: "App", categoryId: catId, lifecycleState: .focused)]
        let categories = [PMDomain.Category(name: "Software")]
        let milestones = [Milestone(id: msId, phaseId: phaseId, name: "MVP")]
        let tasks = [PMTask(milestoneId: msId, name: "Build login")]

        let payload = builder.build(
            projects: projects,
            categories: categories,
            milestones: milestones,
            tasks: tasks,
            dependencyNames: [:]
        )

        #expect(payload.tasks.count == 1)
        #expect(payload.tasks.first?.name == "Build login")
        #expect(payload.tasks.first?.milestoneName == "MVP")
    }
}

// MARK: - ExportConfig Tests

@Suite("ExportConfig")
struct ExportConfigTests {

    @Test("Default config")
    func defaults() {
        let config = ExportConfig()
        #expect(config.destination == .api)
        #expect(config.apiEndpoint == nil)
        #expect(config.debounceSeconds == 5)
    }

    @Test("Config equality")
    func equality() {
        let a = ExportConfig(destination: .api, apiEndpoint: "https://example.com")
        let b = ExportConfig(destination: .api, apiEndpoint: "https://example.com")
        #expect(a == b)
    }
}

// MARK: - ExportService Tests

@Suite("ExportService")
struct ExportServiceTests {

    @Test("Export success")
    func exportSuccess() async {
        let backend = MockExportBackend()
        let service = ExportService(backend: backend)
        let payload = ExportPayload(projects: [], tasks: [])

        let result = await service.export(payload: payload)

        #expect(result == .success)
        #expect(backend.exportedPayloads.count == 1)
    }

    @Test("Export tracks status")
    func exportTracksStatus() async {
        let backend = MockExportBackend()
        let service = ExportService(backend: backend)
        let payload = ExportPayload(projects: [], tasks: [])

        _ = await service.export(payload: payload)

        let status = await service.currentStatus()
        #expect(status.lastExportDate != nil)
        #expect(status.lastResult == .success)
        #expect(status.exportCount == 1)
    }

    @Test("Export network error")
    func exportNetworkError() async {
        let backend = MockExportBackend()
        backend.shouldThrow = .networkError("Connection refused")
        let service = ExportService(backend: backend)
        let payload = ExportPayload(projects: [], tasks: [])

        let result = await service.export(payload: payload)

        #expect(result == .networkError)
        let status = await service.currentStatus()
        #expect(status.exportCount == 0) // Failed export doesn't increment
    }

    @Test("Export auth error")
    func exportAuthError() async {
        let backend = MockExportBackend()
        backend.shouldThrow = .authError("Unauthorized")
        let service = ExportService(backend: backend)
        let payload = ExportPayload(projects: [], tasks: [])

        let result = await service.export(payload: payload)
        #expect(result == .authError)
    }

    @Test("Export config error")
    func exportConfigError() async {
        let backend = MockExportBackend()
        backend.shouldThrow = .invalidConfig("Missing endpoint")
        let service = ExportService(backend: backend)
        let payload = ExportPayload(projects: [], tasks: [])

        let result = await service.export(payload: payload)
        #expect(result == .configError)
    }

    @Test("Debounce should export")
    func debounce() async {
        let config = ExportConfig(debounceSeconds: 60)
        let backend = MockExportBackend()
        let service = ExportService(backend: backend, config: config)

        #expect(await service.shouldExport() == true)

        await service.recordTrigger()
        #expect(await service.shouldExport() == false)
    }

    @Test("Update config")
    func updateConfig() async {
        let backend = MockExportBackend()
        let service = ExportService(backend: backend)

        let newConfig = ExportConfig(destination: .jsonFile, filePath: "/tmp/export.json")
        await service.updateConfig(newConfig)

        let current = await service.currentConfig()
        #expect(current.destination == .jsonFile)
        #expect(current.filePath == "/tmp/export.json")
    }

    @Test("Multiple exports increment count")
    func multipleExports() async {
        let backend = MockExportBackend()
        let service = ExportService(backend: backend)
        let payload = ExportPayload(projects: [], tasks: [])

        _ = await service.export(payload: payload)
        _ = await service.export(payload: payload)
        _ = await service.export(payload: payload)

        let status = await service.currentStatus()
        #expect(status.exportCount == 3)
    }
}

// MARK: - ExportError Tests

@Suite("ExportError")
struct ExportErrorTests {

    @Test("Equality")
    func equality() {
        #expect(ExportError.invalidConfig("A") == ExportError.invalidConfig("A"))
        #expect(ExportError.networkError("A") != ExportError.authError("A"))
    }
}

// MARK: - ExportDestination Tests

@Suite("ExportDestination")
struct ExportDestinationTests {

    @Test("Raw values")
    func rawValues() {
        #expect(ExportDestination.api.rawValue == "api")
        #expect(ExportDestination.jsonFile.rawValue == "jsonFile")
    }
}

// MARK: - ExportResult Tests

@Suite("ExportResult")
struct ExportResultTests {

    @Test("All results")
    func allResults() {
        #expect(ExportResult.success.rawValue == "success")
        #expect(ExportResult.networkError.rawValue == "networkError")
        #expect(ExportResult.authError.rawValue == "authError")
        #expect(ExportResult.configError.rawValue == "configError")
        #expect(ExportResult.encodingError.rawValue == "encodingError")
    }
}
