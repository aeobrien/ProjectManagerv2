# Phase 23: External Integration API — Manual Test Brief

## Automated Tests
- **28 tests** in 6 suites, passing via `cd Packages/PMServices && swift test`
- All **167 tests** pass in PMServices (no regressions).

### Suites
1. **APIRouterTests** (9 tests) — Pattern matching for all 10 routes, :param extraction, method matching, query string handling, 404 for unknown routes.
2. **APIResponseTests** (4 tests) — JSON response encoding, error responses, bad request, static response codes.
3. **IntegrationAPIHandlerTests** (12 tests) — Auth enforcement, auth success, no-auth passthrough, listProjects, getProject, getProject 404, auditLog, updateTask, createTask, reportIssue, updateDocument, unknown route 404.
4. **APIServerConfigTests** (2 tests) — Default config values, equality.
5. **AuditLogEntryTests** (1 test) — Entry creation with method/path/handler/success.
6. **APIKeyProviderTests** — API key rotation support tests.

## Manual Verification Checklist

### Server Lifecycle
- [ ] Integration API server starts on app launch when `integrationAPIEnabled` is true
- [ ] Server listens on the configured port (default 8420)
- [ ] Server does NOT start when `integrationAPIEnabled` is false
- [ ] Server is wired in both macOS ContentView and iOS iOSContentView

### Authentication
- [ ] Requests without `Authorization` header return 401 when API key is configured
- [ ] Requests with `Authorization: Bearer <key>` succeed when key matches
- [ ] All requests succeed when no API key is configured (open access)

### Endpoints — curl Examples
All examples assume server on localhost:8420 with no API key.

```bash
# List all projects
curl http://localhost:8420/api/v1/projects

# Get project by ID
curl http://localhost:8420/api/v1/projects/<project-id>

# List tasks for project (traverses phases → milestones → tasks)
curl http://localhost:8420/api/v1/projects/<project-id>/tasks

# Complete a task
curl -X POST http://localhost:8420/api/v1/tasks/<task-id>/complete

# Update a task (PATCH)
curl -X PATCH http://localhost:8420/api/v1/tasks/<task-id> \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated Name", "status": "inProgress"}'

# Add notes to a task
curl -X POST http://localhost:8420/api/v1/tasks/<task-id>/notes \
  -H "Content-Type: application/json" \
  -d '{"notes": "Some notes to append"}'

# Create a task
curl -X POST http://localhost:8420/api/v1/projects/<project-id>/tasks \
  -H "Content-Type: application/json" \
  -d '{"milestoneId": "<milestone-id>", "name": "New Task"}'

# Report an issue
curl -X POST http://localhost:8420/api/v1/projects/<project-id>/issues \
  -H "Content-Type: application/json" \
  -d '{"description": "Something broke"}'

# List documents for project
curl http://localhost:8420/api/v1/projects/<project-id>/documents

# Update a document (PATCH)
curl -X PATCH http://localhost:8420/api/v1/documents/<doc-id> \
  -H "Content-Type: application/json" \
  -d '{"title": "New Title", "content": "Updated content"}'

# With API key authentication
curl -H "Authorization: Bearer your-api-key" http://localhost:8420/api/v1/projects
```

### Handler Verification
- [ ] `GET /api/v1/projects` — returns all projects as JSON array
- [ ] `GET /api/v1/projects/:id` — returns single project, 404 if not found
- [ ] `GET /api/v1/projects/:id/tasks` — traverses phases→milestones→tasks for project
- [ ] `POST /api/v1/tasks/:id/complete` — marks task completed, sets completedAt
- [ ] `PATCH /api/v1/tasks/:id` — partial update (name, status, priority, definitionOfDone, notes)
- [ ] `POST /api/v1/tasks/:id/notes` — appends notes to existing task notes
- [ ] `POST /api/v1/projects/:id/tasks` — creates new task with milestoneId and name
- [ ] `POST /api/v1/projects/:id/issues` — appends `[Issue]` entry to project notes
- [ ] `GET /api/v1/projects/:id/documents` — returns documents for project
- [ ] `PATCH /api/v1/documents/:id` — updates document title/content, increments version

### Audit Log
- [ ] Write operations (POST, PATCH) are recorded in audit log
- [ ] GET operations are NOT recorded in audit log
- [ ] Audit entries include method, path, handler name, and success status

### Settings Integration
- [ ] Settings shows "Integration API" section with enable toggle
- [ ] When enabled, shows port stepper and API key field
- [ ] Port defaults to 8420
- [ ] API key field is a SecureField

### HTTP Server
- [ ] Server parses HTTP request line (method, path, HTTP version)
- [ ] Server parses headers correctly
- [ ] Server parses request body for POST/PATCH
- [ ] Server returns proper HTTP response with status line, headers, body
- [ ] Server includes CORS header `Access-Control-Allow-Origin: *`
- [ ] Server closes connection after response (`Connection: close`)

## Files Created/Modified

### New Files (Phase 23)
- `Packages/PMServices/Sources/PMServices/IntegrationAPI/APIRouter.swift` — Pattern-matching router with :param extraction, 10 routes
- `Packages/PMServices/Sources/PMServices/IntegrationAPI/IntegrationAPIServer.swift` — Handler with auth, audit logging, all 10 endpoint handlers, request payload structs
- `Packages/PMServices/Sources/PMServices/IntegrationAPI/HTTPServer.swift` — NWListener-based TCP server with HTTP parsing and response formatting

### Modified Files (This Audit)
- `Packages/PMServices/Sources/PMServices/IntegrationAPI/IntegrationAPIServer.swift` — Added phaseRepo/milestoneRepo, 4 missing handlers (updateTask, createTask, reportIssue, updateDocument), fixed listTasks to traverse phases→milestones→tasks, added payload structs
- `Packages/PMServices/Sources/PMServices/IntegrationAPI/HTTPServer.swift` — Fixed Log.data → Log.api
- `Packages/PMServices/Tests/PMServicesTests/IntegrationAPITests.swift` — Added mock PhaseRepo/MilestoneRepo, 4 new handler tests, updated all handler instantiations
- `Packages/PMData/Sources/PMData/Settings/SettingsManager.swift` — Added integrationAPIKey property
- `Packages/PMFeatures/Sources/PMFeatures/Settings/SettingsView.swift` — Added API key SecureField to integration section
- `ProjectManager/Sources/ContentView.swift` — Wire HTTPServer creation/start when integrationAPIEnabled
- `ProjectManageriOS/Sources/iOSContentView.swift` — Same wiring as macOS
