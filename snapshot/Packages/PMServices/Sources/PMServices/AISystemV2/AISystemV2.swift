import Foundation

/// Namespace for the V2 AI system redesign.
///
/// The V2 AI system replaces the existing AI managers with a unified pipeline built around:
/// - **Sessions**: Lifecycle management for conversations
/// - **Prompts**: Layered prompt composition (system/mode/conversation)
/// - **Modes**: Configurable conversation modes (brain dump, check-in, planning, etc.)
/// - **Signals**: Structured parsing of AI responses (MODE_COMPLETE, DOCUMENT_DRAFT, etc.)
/// - **Context**: Mode-aware context assembly from project data
/// - **Pipeline**: The unified ConversationManager tying it all together
///
/// All V2 code lives in this namespace, separate from existing AI managers which continue
/// to function until the migration is complete.
public enum AISystemV2 {
    public static let version = "0.1.0"
}
