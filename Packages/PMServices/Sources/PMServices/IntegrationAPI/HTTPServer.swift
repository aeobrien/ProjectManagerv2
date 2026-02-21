import Foundation
import Network
import PMUtilities
import os

/// A lightweight HTTP server using NWListener for the integration API.
public actor HTTPServer {
    private let handler: APIHandlerProtocol
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private let config: APIServerConfig

    public private(set) var isRunning = false

    public init(handler: APIHandlerProtocol, config: APIServerConfig) {
        self.handler = handler
        self.config = config
    }

    /// Start listening for connections.
    public func start() throws {
        guard config.enabled, !isRunning else { return }

        let params = NWParameters.tcp
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: config.port)!)
        self.listener = listener

        let port = config.port

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                Log.data.info("Integration API server listening on port \(port)")
            case .failed(let error):
                Log.data.error("Integration API server failed: \(error)")
            default:
                break
            }
        }

        listener.newConnectionHandler = { connection in
            let connectionId = UUID()
            Task { [weak self] in
                await self?.handleConnection(connection, id: connectionId)
            }
        }

        listener.start(queue: .global(qos: .utility))
        isRunning = true
        Log.data.info("HTTP server starting on port \(port)")
    }

    /// Stop the server.
    public func stop() {
        listener?.cancel()
        listener = nil
        for connection in connections.values {
            connection.cancel()
        }
        connections.removeAll()
        isRunning = false
        Log.data.info("HTTP server stopped")
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection, id: UUID) {
        connections[id] = connection

        connection.start(queue: .global(qos: .utility))

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            Task { [weak self] in
                guard let self else { return }

                if let data {
                    let request = await self.parseHTTPRequest(data)
                    let apiResponse = await self.handler.handle(request)
                    let httpResponse = await self.formatHTTPResponse(apiResponse)
                    await self.sendResponse(httpResponse, on: connection, connectionId: id)
                } else if let error {
                    Log.data.error("Connection error: \(error)")
                    await self.removeConnection(id: id)
                }
            }
        }
    }

    private func removeConnection(id: UUID) {
        connections[id]?.cancel()
        connections.removeValue(forKey: id)
    }

    // MARK: - HTTP Parsing

    private func parseHTTPRequest(_ data: Data) -> APIRequest {
        guard let rawString = String(data: data, encoding: .utf8) else {
            return APIRequest(method: .GET, path: "/")
        }

        let lines = rawString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return APIRequest(method: .GET, path: "/")
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            return APIRequest(method: .GET, path: "/")
        }

        let methodStr = String(parts[0])
        let method = HTTPMethod(rawValue: methodStr) ?? .GET
        let fullPath = String(parts[1])

        // Split path and query
        let pathParts = fullPath.split(separator: "?", maxSplits: 1)
        let path = String(pathParts[0])
        var queryParams: [String: String] = [:]
        if pathParts.count > 1 {
            let queryString = String(pathParts[1])
            for pair in queryString.split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    queryParams[String(kv[0])] = String(kv[1])
                }
            }
        }

        // Parse headers
        var headers: [String: String] = [:]
        var bodyStartIndex: Int?
        for (i, line) in lines.dropFirst().enumerated() {
            if line.isEmpty {
                bodyStartIndex = i + 2 // index after blank line in original lines
                break
            }
            let headerParts = line.split(separator: ":", maxSplits: 1)
            if headerParts.count == 2 {
                headers[String(headerParts[0]).trimmingCharacters(in: .whitespaces)] =
                    String(headerParts[1]).trimmingCharacters(in: .whitespaces)
            }
        }

        // Extract body
        var body: Data?
        if let startIdx = bodyStartIndex, startIdx < lines.count {
            let bodyString = lines[startIdx...].joined(separator: "\r\n")
            if !bodyString.isEmpty {
                body = bodyString.data(using: .utf8)
            }
        }

        return APIRequest(
            method: method,
            path: path,
            queryParameters: queryParams,
            body: body,
            headers: headers
        )
    }

    // MARK: - HTTP Response Formatting

    private func formatHTTPResponse(_ response: APIResponse) -> Data {
        var httpResponse = "HTTP/1.1 \(response.statusCode) \(statusText(response.statusCode))\r\n"
        httpResponse += "Content-Type: \(response.contentType)\r\n"
        httpResponse += "Connection: close\r\n"
        httpResponse += "Access-Control-Allow-Origin: *\r\n"

        if let body = response.body {
            httpResponse += "Content-Length: \(body.count)\r\n"
            httpResponse += "\r\n"
            var data = httpResponse.data(using: .utf8)!
            data.append(body)
            return data
        } else {
            httpResponse += "Content-Length: 0\r\n"
            httpResponse += "\r\n"
            return httpResponse.data(using: .utf8)!
        }
    }

    private func sendResponse(_ data: Data, on connection: NWConnection, connectionId: UUID) {
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error {
                Log.data.error("Failed to send response: \(error)")
            }
            Task { [weak self] in
                await self?.removeConnection(id: connectionId)
            }
        })
    }

    private func statusText(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 201: return "Created"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}
