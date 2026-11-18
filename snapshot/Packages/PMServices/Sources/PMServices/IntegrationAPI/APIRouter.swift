import Foundation

/// HTTP methods supported by the integration API.
public enum HTTPMethod: String, Sendable {
    case GET
    case POST
    case PATCH
    case DELETE
}

/// A parsed API request.
public struct APIRequest: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let pathComponents: [String]
    public let queryParameters: [String: String]
    public let body: Data?
    public let headers: [String: String]

    public init(
        method: HTTPMethod,
        path: String,
        pathComponents: [String]? = nil,
        queryParameters: [String: String] = [:],
        body: Data? = nil,
        headers: [String: String] = [:]
    ) {
        self.method = method
        self.path = path
        self.pathComponents = pathComponents ?? path.split(separator: "/").map(String.init)
        self.queryParameters = queryParameters
        self.body = body
        self.headers = headers
    }
}

/// An API response.
public struct APIResponse: Sendable {
    public let statusCode: Int
    public let body: Data?
    public let contentType: String

    public init(statusCode: Int, body: Data? = nil, contentType: String = "application/json") {
        self.statusCode = statusCode
        self.body = body
        self.contentType = contentType
    }

    /// Create a JSON success response.
    public static func json<T: Encodable>(_ value: T, status: Int = 200) -> APIResponse {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try? encoder.encode(value)
        return APIResponse(statusCode: status, body: data)
    }

    /// Create an error response.
    public static func error(_ message: String, status: Int) -> APIResponse {
        let body = try? JSONEncoder().encode(["error": message])
        return APIResponse(statusCode: status, body: body)
    }

    /// 200 OK with no body.
    public static let ok = APIResponse(statusCode: 200)

    /// 201 Created with no body.
    public static let created = APIResponse(statusCode: 201)

    /// 404 Not Found.
    public static let notFound = APIResponse.error("Not found", status: 404)

    /// 401 Unauthorized.
    public static let unauthorized = APIResponse.error("Unauthorized", status: 401)

    /// 400 Bad Request.
    public static func badRequest(_ message: String) -> APIResponse {
        .error(message, status: 400)
    }
}

/// Matched route with extracted path parameters.
public struct RouteMatch: Sendable {
    public let handler: String  // Handler identifier
    public let pathParams: [String: String]
}

/// Routes API requests to handlers.
public struct APIRouter: Sendable {
    /// A registered route pattern.
    struct Route: Sendable {
        let method: HTTPMethod
        let pattern: [String]  // e.g., ["api", "v1", "projects", ":id"]
        let handler: String
    }

    private let routes: [Route]

    public init() {
        var routes: [Route] = []

        // Projects
        routes.append(Route(method: .GET, pattern: ["api", "v1", "projects"], handler: "listProjects"))
        routes.append(Route(method: .GET, pattern: ["api", "v1", "projects", ":projectId"], handler: "getProject"))

        // Tasks
        routes.append(Route(method: .GET, pattern: ["api", "v1", "projects", ":projectId", "tasks"], handler: "listTasks"))
        routes.append(Route(method: .PATCH, pattern: ["api", "v1", "tasks", ":taskId"], handler: "updateTask"))
        routes.append(Route(method: .POST, pattern: ["api", "v1", "tasks", ":taskId", "complete"], handler: "completeTask"))
        routes.append(Route(method: .POST, pattern: ["api", "v1", "tasks", ":taskId", "notes"], handler: "addTaskNotes"))
        routes.append(Route(method: .POST, pattern: ["api", "v1", "projects", ":projectId", "tasks"], handler: "createTask"))

        // Issues
        routes.append(Route(method: .POST, pattern: ["api", "v1", "projects", ":projectId", "issues"], handler: "reportIssue"))

        // Documents
        routes.append(Route(method: .GET, pattern: ["api", "v1", "projects", ":projectId", "documents"], handler: "listDocuments"))
        routes.append(Route(method: .PATCH, pattern: ["api", "v1", "documents", ":documentId"], handler: "updateDocument"))

        self.routes = routes
    }

    /// Match a request to a route.
    public func match(_ request: APIRequest) -> RouteMatch? {
        let components = request.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
            .map(String.init)

        for route in routes {
            guard route.method == request.method else { continue }
            guard route.pattern.count == components.count else { continue }

            var params: [String: String] = [:]
            var matched = true

            for (pattern, component) in zip(route.pattern, components) {
                if pattern.hasPrefix(":") {
                    let key = String(pattern.dropFirst())
                    params[key] = component
                } else if pattern != component {
                    matched = false
                    break
                }
            }

            if matched {
                return RouteMatch(handler: route.handler, pathParams: params)
            }
        }

        return nil
    }
}
