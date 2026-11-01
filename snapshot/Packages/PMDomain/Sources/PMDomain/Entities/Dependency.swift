import Foundation

/// An advisory dependency between milestones or tasks.
/// Dependencies are warnings, not hard blocks — the user can proceed despite unmet dependencies.
public struct Dependency: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var sourceType: DependableType
    public var sourceId: UUID
    public var targetType: DependableType
    public var targetId: UUID

    public init(
        id: UUID = UUID(),
        sourceType: DependableType,
        sourceId: UUID,
        targetType: DependableType,
        targetId: UUID
    ) {
        self.id = id
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.targetType = targetType
        self.targetId = targetId
    }
}
