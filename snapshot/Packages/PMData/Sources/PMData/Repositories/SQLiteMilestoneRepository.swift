import Foundation
import GRDB
import PMDomain

public final class SQLiteMilestoneRepository: MilestoneRepositoryProtocol, Sendable {
    private let db: DatabaseQueue

    public init(db: DatabaseQueue) { self.db = db }

    public func fetchAll(forPhase phaseId: UUID) async throws -> [Milestone] {
        try await db.read { db in
            try Milestone.filter(Column("phaseId") == phaseId)
                .order(Column("sortOrder"))
                .fetchAll(db)
        }
    }

    public func fetch(id: UUID) async throws -> Milestone? {
        try await db.read { db in
            try Milestone.fetchOne(db, key: id)
        }
    }

    public func save(_ milestone: Milestone) async throws {
        try await db.write { db in
            try milestone.save(db)
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await db.write { db in
            try Milestone.deleteOne(db, key: id)
        }
    }

    public func reorder(milestones: [Milestone]) async throws {
        try await db.write { db in
            for milestone in milestones {
                try milestone.update(db)
            }
        }
    }
}
