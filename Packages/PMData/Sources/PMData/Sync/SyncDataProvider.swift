import Foundation
import PMDomain
import PMUtilities
import os

/// Protocol for serializing and deserializing entity data during sync.
public protocol SyncDataProviderProtocol: Sendable {
    /// Serialize an entity to JSON data for pushing to remote.
    func serialize(entityType: SyncEntityType, entityId: UUID) async throws -> Data?

    /// Apply incoming entity data from remote (deserialize and save locally).
    func apply(entityType: SyncEntityType, entityId: UUID, data: Data) async throws

    /// Delete an entity locally (triggered by remote delete).
    func deleteEntity(entityType: SyncEntityType, entityId: UUID) async throws
}

/// Concrete implementation that uses repository protocols for entity serialization.
public final class RepositorySyncDataProvider: SyncDataProviderProtocol, @unchecked Sendable {
    private let projectRepo: ProjectRepositoryProtocol
    private let phaseRepo: PhaseRepositoryProtocol
    private let milestoneRepo: MilestoneRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol
    private let subtaskRepo: SubtaskRepositoryProtocol
    private let checkInRepo: CheckInRepositoryProtocol
    private let documentRepo: DocumentRepositoryProtocol
    private let categoryRepo: CategoryRepositoryProtocol
    private let conversationRepo: ConversationRepositoryProtocol
    private let dependencyRepo: DependencyRepositoryProtocol

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        projectRepo: ProjectRepositoryProtocol,
        phaseRepo: PhaseRepositoryProtocol,
        milestoneRepo: MilestoneRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
        subtaskRepo: SubtaskRepositoryProtocol,
        checkInRepo: CheckInRepositoryProtocol,
        documentRepo: DocumentRepositoryProtocol,
        categoryRepo: CategoryRepositoryProtocol,
        conversationRepo: ConversationRepositoryProtocol,
        dependencyRepo: DependencyRepositoryProtocol
    ) {
        self.projectRepo = projectRepo
        self.phaseRepo = phaseRepo
        self.milestoneRepo = milestoneRepo
        self.taskRepo = taskRepo
        self.subtaskRepo = subtaskRepo
        self.checkInRepo = checkInRepo
        self.documentRepo = documentRepo
        self.categoryRepo = categoryRepo
        self.conversationRepo = conversationRepo
        self.dependencyRepo = dependencyRepo

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: - Serialize

    public func serialize(entityType: SyncEntityType, entityId: UUID) async throws -> Data? {
        switch entityType {
        case .project:
            guard let entity = try await projectRepo.fetch(id: entityId) else { return nil }
            return try encoder.encode(entity)
        case .phase:
            guard let entity = try await phaseRepo.fetch(id: entityId) else { return nil }
            return try encoder.encode(entity)
        case .milestone:
            guard let entity = try await milestoneRepo.fetch(id: entityId) else { return nil }
            return try encoder.encode(entity)
        case .task:
            guard let entity = try await taskRepo.fetch(id: entityId) else { return nil }
            return try encoder.encode(entity)
        case .subtask:
            guard let entity = try await subtaskRepo.fetch(id: entityId) else { return nil }
            return try encoder.encode(entity)
        case .checkIn:
            guard let entity = try await checkInRepo.fetch(id: entityId) else { return nil }
            return try encoder.encode(entity)
        case .document:
            guard let entity = try await documentRepo.fetch(id: entityId) else { return nil }
            return try encoder.encode(entity)
        case .category:
            guard let entity = try await categoryRepo.fetch(id: entityId) else { return nil }
            return try encoder.encode(entity)
        case .conversation:
            guard let entity = try await conversationRepo.fetch(id: entityId) else { return nil }
            return try encoder.encode(entity)
        case .dependency:
            guard let entity = try await dependencyRepo.fetch(id: entityId) else { return nil }
            return try encoder.encode(entity)
        }
    }

    // MARK: - Apply

    public func apply(entityType: SyncEntityType, entityId: UUID, data: Data) async throws {
        switch entityType {
        case .project:
            let entity = try decoder.decode(Project.self, from: data)
            try await projectRepo.save(entity)
        case .phase:
            let entity = try decoder.decode(Phase.self, from: data)
            try await phaseRepo.save(entity)
        case .milestone:
            let entity = try decoder.decode(Milestone.self, from: data)
            try await milestoneRepo.save(entity)
        case .task:
            let entity = try decoder.decode(PMTask.self, from: data)
            try await taskRepo.save(entity)
        case .subtask:
            let entity = try decoder.decode(Subtask.self, from: data)
            try await subtaskRepo.save(entity)
        case .checkIn:
            let entity = try decoder.decode(CheckInRecord.self, from: data)
            try await checkInRepo.save(entity)
        case .document:
            let entity = try decoder.decode(Document.self, from: data)
            try await documentRepo.save(entity)
        case .category:
            let entity = try decoder.decode(Category.self, from: data)
            try await categoryRepo.save(entity)
        case .conversation:
            let entity = try decoder.decode(Conversation.self, from: data)
            try await conversationRepo.save(entity)
        case .dependency:
            let entity = try decoder.decode(Dependency.self, from: data)
            try await dependencyRepo.save(entity)
        }
        Log.data.info("Applied remote \(entityType.rawValue) \(entityId)")
    }

    // MARK: - Delete

    public func deleteEntity(entityType: SyncEntityType, entityId: UUID) async throws {
        switch entityType {
        case .project:    try await projectRepo.delete(id: entityId)
        case .phase:      try await phaseRepo.delete(id: entityId)
        case .milestone:  try await milestoneRepo.delete(id: entityId)
        case .task:       try await taskRepo.delete(id: entityId)
        case .subtask:    try await subtaskRepo.delete(id: entityId)
        case .checkIn:    try await checkInRepo.delete(id: entityId)
        case .document:   try await documentRepo.delete(id: entityId)
        case .category:   try await categoryRepo.delete(id: entityId)
        case .conversation: try await conversationRepo.delete(id: entityId)
        case .dependency: try await dependencyRepo.delete(id: entityId)
        }
        Log.data.info("Deleted remote \(entityType.rawValue) \(entityId)")
    }
}
