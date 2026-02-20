import Foundation
import PMDomain
import PMUtilities
import os

/// Export destination type.
public enum ExportDestination: String, Sendable, Codable {
    case api       // HTTP POST to configured endpoint
    case jsonFile  // Write JSON to a file path
}

/// Configuration for the export service.
public struct ExportConfig: Sendable, Codable, Equatable {
    public var destination: ExportDestination
    public var apiEndpoint: String?
    public var apiKey: String?
    public var filePath: String?
    public var debounceSeconds: TimeInterval

    public init(
        destination: ExportDestination = .api,
        apiEndpoint: String? = nil,
        apiKey: String? = nil,
        filePath: String? = nil,
        debounceSeconds: TimeInterval = 5
    ) {
        self.destination = destination
        self.apiEndpoint = apiEndpoint
        self.apiKey = apiKey
        self.filePath = filePath
        self.debounceSeconds = debounceSeconds
    }
}

/// Export status tracking.
public struct ExportStatus: Sendable, Equatable {
    public let lastExportDate: Date?
    public let lastResult: ExportResult?
    public let exportCount: Int

    public init(lastExportDate: Date? = nil, lastResult: ExportResult? = nil, exportCount: Int = 0) {
        self.lastExportDate = lastExportDate
        self.lastResult = lastResult
        self.exportCount = exportCount
    }
}

/// Result of an export operation.
public enum ExportResult: String, Sendable, Equatable {
    case success
    case networkError
    case authError
    case configError
    case encodingError
}

/// Protocol for export backends (API, file, MySQL).
public protocol ExportBackendProtocol: Sendable {
    func export(payload: ExportPayload, config: ExportConfig) async throws
}

/// HTTP API export backend.
public struct APIExportBackend: ExportBackendProtocol, Sendable {
    public init() {}

    public func export(payload: ExportPayload, config: ExportConfig) async throws {
        guard let endpoint = config.apiEndpoint, let url = URL(string: endpoint) else {
            throw ExportError.invalidConfig("API endpoint not configured")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let apiKey = config.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(payload)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExportError.networkError("Invalid response")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw ExportError.authError("Authentication failed (HTTP \(httpResponse.statusCode))")
            }
            throw ExportError.networkError("HTTP \(httpResponse.statusCode)")
        }
    }
}

/// JSON file export backend.
public struct FileExportBackend: ExportBackendProtocol, Sendable {
    public init() {}

    public func export(payload: ExportPayload, config: ExportConfig) async throws {
        guard let path = config.filePath else {
            throw ExportError.invalidConfig("File path not configured")
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)

        try data.write(to: URL(fileURLWithPath: path))
    }
}

/// Export errors.
public enum ExportError: Error, Sendable, Equatable {
    case invalidConfig(String)
    case networkError(String)
    case authError(String)
    case encodingError(String)
}

/// Manages exports with debouncing and status tracking.
public actor ExportService {
    private let backend: ExportBackendProtocol
    private let payloadBuilder: ExportPayloadBuilder
    private var config: ExportConfig
    private var status: ExportStatus
    private var lastTriggerDate: Date?

    public init(
        backend: ExportBackendProtocol,
        payloadBuilder: ExportPayloadBuilder = ExportPayloadBuilder(),
        config: ExportConfig = ExportConfig()
    ) {
        self.backend = backend
        self.payloadBuilder = payloadBuilder
        self.config = config
        self.status = ExportStatus()
    }

    /// Perform an export with the given payload.
    public func export(payload: ExportPayload) async -> ExportResult {
        do {
            try await backend.export(payload: payload, config: config)
            status = ExportStatus(
                lastExportDate: Date(),
                lastResult: .success,
                exportCount: status.exportCount + 1
            )
            Log.data.info("Export successful (\(payload.tasks.count) tasks, \(payload.projects.count) projects)")
            return .success
        } catch let error as ExportError {
            let result: ExportResult
            switch error {
            case .invalidConfig: result = .configError
            case .networkError: result = .networkError
            case .authError: result = .authError
            case .encodingError: result = .encodingError
            }
            status = ExportStatus(
                lastExportDate: Date(),
                lastResult: result,
                exportCount: status.exportCount
            )
            Log.data.error("Export failed: \(error)")
            return result
        } catch {
            status = ExportStatus(
                lastExportDate: Date(),
                lastResult: .networkError,
                exportCount: status.exportCount
            )
            return .networkError
        }
    }

    /// Check if enough time has passed since last trigger (debounce).
    public func shouldExport() -> Bool {
        guard let last = lastTriggerDate else { return true }
        return Date().timeIntervalSince(last) >= config.debounceSeconds
    }

    /// Record that an export was triggered (for debounce tracking).
    public func recordTrigger() {
        lastTriggerDate = Date()
    }

    /// Get current export status.
    public func currentStatus() -> ExportStatus {
        status
    }

    /// Update the export configuration.
    public func updateConfig(_ newConfig: ExportConfig) {
        config = newConfig
    }

    /// Get current config.
    public func currentConfig() -> ExportConfig {
        config
    }
}
