import Foundation

/// A classification of a project's domain.
/// Categories are user-extensible and used to enforce diversity on the Focus Board.
public struct Category: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var isBuiltIn: Bool
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        name: String,
        isBuiltIn: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.sortOrder = sortOrder
    }
}

extension Category {
    /// The built-in categories seeded on first launch.
    public static let builtInCategories: [Category] = [
        Category(name: "Software", isBuiltIn: true, sortOrder: 0),
        Category(name: "Music", isBuiltIn: true, sortOrder: 1),
        Category(name: "Hardware / Electronics", isBuiltIn: true, sortOrder: 2),
        Category(name: "Creative", isBuiltIn: true, sortOrder: 3),
        Category(name: "Life Admin", isBuiltIn: true, sortOrder: 4),
        Category(name: "Research / Learning", isBuiltIn: true, sortOrder: 5),
    ]
}
