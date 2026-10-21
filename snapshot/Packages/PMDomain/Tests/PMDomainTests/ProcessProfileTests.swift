import Testing
import Foundation
@testable import PMDomain

@Suite("ProcessProfile")
struct ProcessProfileTests {

    @Test("Codable round-trip with all fields")
    func codableRoundTrip() throws {
        let profile = ProcessProfile(
            projectId: UUID(),
            recommendedDeliverables: [
                .init(type: .visionStatement, status: .completed, rationale: "Always useful"),
                .init(type: .technicalBrief, status: .pending, rationale: "Software project")
            ],
            planningDepth: .fullRoadmap,
            suggestedModePath: ["exploration", "definition", "planning"],
            modificationHistory: [
                .init(description: "Initial recommendation", source: .exploration)
            ]
        )

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(ProcessProfile.self, from: data)

        #expect(decoded == profile)
        #expect(decoded.recommendedDeliverables.count == 2)
        #expect(decoded.planningDepth == .fullRoadmap)
        #expect(decoded.suggestedModePath == ["exploration", "definition", "planning"])
        #expect(decoded.modificationHistory.count == 1)
    }

    @Test("Default initializer produces empty arrays")
    func defaultsEmpty() {
        let profile = ProcessProfile(projectId: UUID())
        #expect(profile.recommendedDeliverables.isEmpty)
        #expect(profile.suggestedModePath.isEmpty)
        #expect(profile.modificationHistory.isEmpty)
        #expect(profile.planningDepth == .fullRoadmap)
    }

    @Test("RecommendedDeliverable default status is pending")
    func defaultDeliverableStatus() {
        let rec = ProcessProfile.RecommendedDeliverable(type: .visionStatement)
        #expect(rec.status == .pending)
        #expect(rec.rationale == nil)
    }

    @Test("All PlanningDepth cases round-trip")
    func planningDepthCases() throws {
        for depth in PlanningDepth.allCases {
            let profile = ProcessProfile(projectId: UUID(), planningDepth: depth)
            let data = try JSONEncoder().encode(profile)
            let decoded = try JSONDecoder().decode(ProcessProfile.self, from: data)
            #expect(decoded.planningDepth == depth)
        }
    }

    @Test("All ModificationSource cases round-trip")
    func modificationSourceCases() throws {
        for source in ProcessProfile.ModificationSource.allCases {
            let mod = ProcessProfile.ProfileModification(description: "Test", source: source)
            let data = try JSONEncoder().encode(mod)
            let decoded = try JSONDecoder().decode(ProcessProfile.ProfileModification.self, from: data)
            #expect(decoded.source == source)
        }
    }
}

@Suite("Deliverable")
struct DeliverableTests {

    @Test("Codable round-trip with version history")
    func codableRoundTrip() throws {
        let deliverable = Deliverable(
            projectId: UUID(),
            type: .technicalBrief,
            status: .completed,
            title: "Tech Brief",
            content: "Architecture details...",
            versionHistory: [
                .init(version: 1, content: "First draft", changeNote: "Initial", savedAt: Date(timeIntervalSince1970: 1000)),
                .init(version: 2, content: "Revised", changeNote: "Added data model", savedAt: Date(timeIntervalSince1970: 2000))
            ]
        )

        let data = try JSONEncoder().encode(deliverable)
        let decoded = try JSONDecoder().decode(Deliverable.self, from: data)

        #expect(decoded == deliverable)
        #expect(decoded.versionHistory.count == 2)
        #expect(decoded.versionHistory[0].version == 1)
        #expect(decoded.versionHistory[1].changeNote == "Added data model")
    }

    @Test("Default initializer")
    func defaults() {
        let d = Deliverable(projectId: UUID(), type: .visionStatement)
        #expect(d.status == .pending)
        #expect(d.title == "")
        #expect(d.content == "")
        #expect(d.versionHistory.isEmpty)
    }

    @Test("All DeliverableType cases")
    func allTypes() {
        #expect(DeliverableType.allCases.count == 5)
    }

    @Test("All DeliverableStatus cases")
    func allStatuses() {
        #expect(DeliverableStatus.allCases.count == 4)
    }

    @Test("Status transitions encode correctly")
    func statusCodable() throws {
        for status in DeliverableStatus.allCases {
            let d = Deliverable(projectId: UUID(), type: .creativeBrief, status: status)
            let data = try JSONEncoder().encode(d)
            let decoded = try JSONDecoder().decode(Deliverable.self, from: data)
            #expect(decoded.status == status)
        }
    }
}
