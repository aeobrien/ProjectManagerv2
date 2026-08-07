import Foundation
import PMDomain

/// Composite payload for syncing a session with its messages and summary.
/// Child records are serialized as part of the parent to ensure atomicity.
struct SessionSyncPayload: Codable {
    let session: Session
    let messages: [SessionMessage]
    let summary: SessionSummary?
}
