import Foundation
import GRDB
import PMDomain

extension Deliverable: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "deliverable"

    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private static let jsonDecoder = JSONDecoder()

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["projectId"] = projectId
        container["type"] = type.rawValue
        container["status"] = status.rawValue
        container["title"] = title
        container["content"] = content
        container["versionHistory"] = try? String(
            data: Self.jsonEncoder.encode(versionHistory), encoding: .utf8
        )
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
    }

    public init(row: Row) throws {
        let typeString: String = row["type"]
        let statusString: String = row["status"]
        let historyJSON: String = row["versionHistory"]

        let history = (try? Self.jsonDecoder.decode(
            [DeliverableVersion].self, from: Data(historyJSON.utf8)
        )) ?? []

        self.init(
            id: row["id"],
            projectId: row["projectId"],
            type: DeliverableType(rawValue: typeString) ?? .visionStatement,
            status: DeliverableStatus(rawValue: statusString) ?? .pending,
            title: row["title"],
            content: row["content"],
            versionHistory: history,
            createdAt: row["createdAt"],
            updatedAt: row["updatedAt"]
        )
    }
}
