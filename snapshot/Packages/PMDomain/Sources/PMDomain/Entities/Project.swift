import Foundation

/// A meaningful endeavour with intent, identity, and a desired outcome.
public struct Project: Identifiable, Equatable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var categoryId: UUID
    public var lifecycleState: LifecycleState
    public var focusSlotIndex: Int?
    public var pauseReason: String?
    public var abandonmentReflection: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var lastWorkedOn: Date?
    public var definitionOfDone: String?
    public var notes: String?
    public var quickCaptureTranscript: String?
    public var repositoryURL: String?

    public init(
        id: UUID = UUID(),
        name: String,
        categoryId: UUID,
        lifecycleState: LifecycleState = .idea,
        focusSlotIndex: Int? = nil,
        pauseReason: String? = nil,
        abandonmentReflection: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastWorkedOn: Date? = nil,
        definitionOfDone: String? = nil,
        notes: String? = nil,
        quickCaptureTranscript: String? = nil,
        repositoryURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.categoryId = categoryId
        self.lifecycleState = lifecycleState
        self.focusSlotIndex = focusSlotIndex
        self.pauseReason = pauseReason
        self.abandonmentReflection = abandonmentReflection
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastWorkedOn = lastWorkedOn
        self.definitionOfDone = definitionOfDone
        self.notes = notes
        self.quickCaptureTranscript = quickCaptureTranscript
        self.repositoryURL = repositoryURL
    }
}
