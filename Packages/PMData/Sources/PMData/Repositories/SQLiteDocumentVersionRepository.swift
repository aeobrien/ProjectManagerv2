import Foundation
import GRDB
import PMDomain

public final class SQLiteDocumentVersionRepository: DocumentVersionRepositoryProtocol, Sendable {
    private let db: DatabaseQueue

    public init(db: DatabaseQueue) { self.db = db }

    public func fetchAll(forDocument documentId: UUID) async throws -> [DocumentVersion] {
        try await db.read { db in
            try DocumentVersion.filter(Column("documentId") == documentId)
                .order(Column("version").desc)
                .fetchAll(db)
        }
    }

    public func save(_ version: DocumentVersion) async throws {
        try await db.write { db in
            try version.save(db)
        }
    }

    public func deleteAll(forDocument documentId: UUID) async throws {
        _ = try await db.write { db in
            try DocumentVersion.filter(Column("documentId") == documentId).deleteAll(db)
        }
    }
}
