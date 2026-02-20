import os

/// Centralised logging for the Project Manager application.
///
/// Usage: `Log.data.info("Loaded \(count) projects")`
///
/// Categories are organised by module area. All logging uses Apple's
/// unified logging system (`os.Logger`) for structured, performant output.
public enum Log {
    private static let subsystem = "com.projectmanager.app"

    /// Database operations, CRUD, queries
    public static let data = Logger(subsystem: subsystem, category: "data")

    /// Focus Board logic, slot management, diversity checks
    public static let focus = Logger(subsystem: subsystem, category: "focus")

    /// LLM API calls, context assembly, response parsing
    public static let ai = Logger(subsystem: subsystem, category: "ai")

    /// Audio recording, Whisper transcription
    public static let voice = Logger(subsystem: subsystem, category: "voice")

    /// CloudKit sync, Life Planner export
    public static let sync = Logger(subsystem: subsystem, category: "sync")

    /// View lifecycle events, navigation, user actions
    public static let ui = Logger(subsystem: subsystem, category: "ui")

    /// Integration API requests/responses
    public static let api = Logger(subsystem: subsystem, category: "api")

    /// Data export/import operations
    public static let export = Logger(subsystem: subsystem, category: "export")
}
