import Foundation
import GRDB
import PMDomain

extension ProcessProfile: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "processProfile"

    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private static let jsonDecoder = JSONDecoder()

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["projectId"] = projectId
        container["planningDepth"] = planningDepth.rawValue
        container["recommendedDeliverables"] = try? String(
            data: Self.jsonEncoder.encode(recommendedDeliverables), encoding: .utf8
        )
        container["suggestedModePath"] = try? String(
            data: Self.jsonEncoder.encode(suggestedModePath), encoding: .utf8
        )
        container["modificationHistory"] = try? String(
            data: Self.jsonEncoder.encode(modificationHistory), encoding: .utf8
        )
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
    }

    public init(row: Row) throws {
        let planningDepthString: String = row["planningDepth"]
        let deliverablesJSON: String = row["recommendedDeliverables"]
        let modePathJSON: String = row["suggestedModePath"]
        let historyJSON: String = row["modificationHistory"]

        let deliverables = (try? Self.jsonDecoder.decode(
            [RecommendedDeliverable].self, from: Data(deliverablesJSON.utf8)
        )) ?? []

        let modePath = (try? Self.jsonDecoder.decode(
            [String].self, from: Data(modePathJSON.utf8)
        )) ?? []

        let history = (try? Self.jsonDecoder.decode(
            [ProfileModification].self, from: Data(historyJSON.utf8)
        )) ?? []

        self.init(
            id: row["id"],
            projectId: row["projectId"],
            recommendedDeliverables: deliverables,
            planningDepth: PlanningDepth(rawValue: planningDepthString) ?? .fullRoadmap,
            suggestedModePath: modePath,
            modificationHistory: history,
            createdAt: row["createdAt"],
            updatedAt: row["updatedAt"]
        )
    }
}
