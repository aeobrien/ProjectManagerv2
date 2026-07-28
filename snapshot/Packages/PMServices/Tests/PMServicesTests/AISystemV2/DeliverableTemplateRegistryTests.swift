import Testing
import Foundation
@testable import PMServices
import PMDomain

@Suite("DeliverableTemplateRegistry")
struct DeliverableTemplateRegistryTests {

    @Test("Template exists for every DeliverableType")
    func allTypesHaveTemplates() {
        for type in DeliverableType.allCases {
            let template = DeliverableTemplateRegistry.template(for: type)
            #expect(template.type == type)
            #expect(!template.purpose.isEmpty)
            #expect(!template.whenUseful.isEmpty)
            #expect(!template.informationRequirements.isEmpty)
            #expect(!template.documentStructure.isEmpty)
        }
    }

    @Test("allTemplates returns all five templates")
    func allTemplatesCount() {
        let templates = DeliverableTemplateRegistry.allTemplates
        #expect(templates.count == 5)
    }

    @Test("Vision statement template has correct requirements")
    func visionStatementRequirements() {
        let template = DeliverableTemplateRegistry.template(for: .visionStatement)
        #expect(template.informationRequirements.count == 8)
        #expect(template.documentStructure.count == 8)
        #expect(template.informationRequirements[0].contains("Core intent"))
    }

    @Test("Technical brief template has correct requirements")
    func technicalBriefRequirements() {
        let template = DeliverableTemplateRegistry.template(for: .technicalBrief)
        #expect(template.informationRequirements.count == 8)
        #expect(template.documentStructure.count == 8)
        #expect(template.informationRequirements[0].contains("Technology stack"))
    }

    @Test("Setup specification template")
    func setupSpecRequirements() {
        let template = DeliverableTemplateRegistry.template(for: .setupSpecification)
        #expect(template.informationRequirements.count == 6)
        #expect(template.documentStructure.count == 6)
    }

    @Test("Research plan template")
    func researchPlanRequirements() {
        let template = DeliverableTemplateRegistry.template(for: .researchPlan)
        #expect(template.informationRequirements.count == 6)
        #expect(template.documentStructure.count == 6)
    }

    @Test("Creative brief template")
    func creativeBriefRequirements() {
        let template = DeliverableTemplateRegistry.template(for: .creativeBrief)
        #expect(template.informationRequirements.count == 6)
        #expect(template.documentStructure.count == 6)
    }

    @Test("formattedRequirements produces numbered list")
    func formattedRequirements() {
        let template = DeliverableTemplateRegistry.template(for: .visionStatement)
        let formatted = template.formattedRequirements()
        #expect(formatted.contains("1."))
        #expect(formatted.contains("2."))
        #expect(formatted.contains("Core intent"))
    }

    @Test("formattedStructure produces section headings")
    func formattedStructure() {
        let template = DeliverableTemplateRegistry.template(for: .technicalBrief)
        let formatted = template.formattedStructure()
        #expect(formatted.contains("**Technology Stack**"))
        #expect(formatted.contains("**Architecture**"))
    }

    @Test("catalogueSummary includes all types")
    func catalogueSummary() {
        let summary = DeliverableTemplateRegistry.catalogueSummary()
        for type in DeliverableType.allCases {
            #expect(summary.contains(type.rawValue))
        }
    }
}
