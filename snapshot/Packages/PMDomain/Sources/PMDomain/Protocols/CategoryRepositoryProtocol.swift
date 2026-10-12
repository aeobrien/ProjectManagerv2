import Foundation

/// Repository for Category CRUD and queries.
public protocol CategoryRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Category]
    func fetch(id: UUID) async throws -> Category?
    func save(_ category: Category) async throws
    func delete(id: UUID) async throws
    func seedBuiltInCategories() async throws
}
