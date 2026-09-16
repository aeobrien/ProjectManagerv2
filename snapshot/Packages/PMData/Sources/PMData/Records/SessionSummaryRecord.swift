import Foundation
import GRDB
import PMDomain

// Custom FetchableRecord/PersistableRecord for SessionSummary.
// Scalar metadata columns are stored directly; section structs are JSON-encoded to text columns.

extension SessionSummary: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "sessionSummary"

    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private static let jsonDecoder = JSONDecoder()

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["sessionId"] = sessionId
        container["mode"] = mode.rawValue
        container["subMode"] = subMode?.rawValue
        container["completionStatus"] = completionStatus.rawValue
        container["deliverableType"] = deliverableType

        // JSON-encode section structs
        container["contentEstablished"] = try? String(
            data: Self.jsonEncoder.encode(contentEstablished), encoding: .utf8
        )
        container["contentObserved"] = try? String(
            data: Self.jsonEncoder.encode(contentObserved), encoding: .utf8
        )
        container["whatComesNext"] = try? String(
            data: Self.jsonEncoder.encode(whatComesNext), encoding: .utf8
        )
        if let modeSpecific {
            container["modeSpecific"] = try? String(
                data: Self.jsonEncoder.encode(modeSpecific), encoding: .utf8
            )
        } else {
            container["modeSpecific"] = String?.none
        }

        container["startedAt"] = startedAt
        container["endedAt"] = endedAt
        container["duration"] = duration
        container["messageCount"] = messageCount
        container["inputTokens"] = inputTokens
        container["outputTokens"] = outputTokens
    }

    public init(row: Row) throws {
        let modeString: String = row["mode"]
        let subModeString: String? = row["subMode"]
        let completionStatusString: String = row["completionStatus"]

        let contentEstablishedJSON: String = row["contentEstablished"]
        let contentObservedJSON: String = row["contentObserved"]
        let whatComesNextJSON: String = row["whatComesNext"]
        let modeSpecificJSON: String? = row["modeSpecific"]

        let contentEstablished = (try? Self.jsonDecoder.decode(
            ContentEstablished.self, from: Data(contentEstablishedJSON.utf8)
        )) ?? ContentEstablished()

        let contentObserved = (try? Self.jsonDecoder.decode(
            ContentObserved.self, from: Data(contentObservedJSON.utf8)
        )) ?? ContentObserved()

        let whatComesNext = (try? Self.jsonDecoder.decode(
            WhatComesNext.self, from: Data(whatComesNextJSON.utf8)
        )) ?? WhatComesNext()

        let modeSpecific: ModeSpecificData? = modeSpecificJSON.flatMap { json in
            try? Self.jsonDecoder.decode(ModeSpecificData.self, from: Data(json.utf8))
        }

        self.init(
            id: row["id"],
            sessionId: row["sessionId"],
            mode: SessionMode(rawValue: modeString) ?? .exploration,
            subMode: subModeString.flatMap { SessionSubMode(rawValue: $0) },
            completionStatus: SessionCompletionStatus(rawValue: completionStatusString) ?? .completed,
            deliverableType: row["deliverableType"],
            contentEstablished: contentEstablished,
            contentObserved: contentObserved,
            whatComesNext: whatComesNext,
            modeSpecific: modeSpecific,
            startedAt: row["startedAt"],
            endedAt: row["endedAt"],
            duration: row["duration"],
            messageCount: row["messageCount"],
            inputTokens: row["inputTokens"],
            outputTokens: row["outputTokens"]
        )
    }
}
