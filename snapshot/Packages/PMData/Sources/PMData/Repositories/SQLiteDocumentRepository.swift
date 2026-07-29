import Foundation
import GRDB
import PMDomain

public final class SQLiteDocumentRepository: DocumentRepositoryProtocol, Sendable {
    private let db: DatabaseQueue

    public init(db: DatabaseQueue) { self.db = db }

    public func fetchAll(forProject projectId: UUID) async throws -> [Document] {
        try await db.read { db in
            try Document.filter(Column("projectId") == projectId)
                .order(Column("updatedAt").desc)
                .fetchAll(db)
        }
    }

    public func fetch(id: UUID) async throws -> Document? {
        try await db.read { db in
            try Document.fetchOne(db, key: id)
        }
    }

    public func fetchByType(_ type: DocumentType, projectId: UUID) async throws -> [Document] {
        try await db.read { db in
            try Document.filter(Column("type") == type.rawValue && Column("projectId") == projectId)
                .order(Column("updatedAt").desc)
                .fetchAll(db)
        }
    }

    public func save(_ document: Document) async throws {
        try await db.write { db in
            try document.save(db)
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await db.write { db in
            try Document.deleteOne(db, key: id)
        }
    }

    public func search(query: String) async throws -> [Document] {
        try await db.read { db in
            let pattern = FTS5Pattern(matchingAnyTokenIn: query)
            guard let pattern else { return [] }
            let sql = """
                SELECT document.*
                FROM document
                JOIN searchIndex ON searchIndex.rowid = document.rowid
                WHERE searchIndex MATCH ?
                ORDER BY rank
                """
            return try Document.fetchAll(db, sql: sql, arguments: [pattern])
        }
    }
}
