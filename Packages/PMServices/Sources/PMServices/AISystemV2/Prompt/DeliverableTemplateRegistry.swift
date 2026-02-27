import Foundation
import PMDomain

/// A deliverable template containing information requirements and document structure.
public struct DeliverableTemplate: Sendable {
    public let type: DeliverableType
    public let purpose: String
    public let whenUseful: String
    public let informationRequirements: [String]
    public let documentStructure: [DocumentSection]

    public struct DocumentSection: Sendable {
        public let heading: String
        public let description: String

        public init(heading: String, description: String) {
            self.heading = heading
            self.description = description
        }
    }

    public init(
        type: DeliverableType,
        purpose: String,
        whenUseful: String,
        informationRequirements: [String],
        documentStructure: [DocumentSection]
    ) {
        self.type = type
        self.purpose = purpose
        self.whenUseful = whenUseful
        self.informationRequirements = informationRequirements
        self.documentStructure = documentStructure
    }

    /// Formats the information requirements as prompt text.
    public func formattedRequirements() -> String {
        informationRequirements.enumerated().map { index, req in
            "\(index + 1). \(req)"
        }.joined(separator: "\n")
    }

    /// Formats the document structure as prompt text.
    public func formattedStructure() -> String {
        documentStructure.map { section in
            "**\(section.heading)** — \(section.description)"
        }.joined(separator: "\n\n")
    }
}

/// Static registry of deliverable templates from the deliverable catalogue.
public enum DeliverableTemplateRegistry {

    /// Returns the template for a specific deliverable type.
    public static func template(for type: DeliverableType) -> DeliverableTemplate {
        switch type {
        case .visionStatement: return visionStatement
        case .technicalBrief: return technicalBrief
        case .setupSpecification: return setupSpecification
        case .researchPlan: return researchPlan
        case .creativeBrief: return creativeBrief
        }
    }

    /// Returns all available templates.
    public static var allTemplates: [DeliverableTemplate] {
        DeliverableType.allCases.map { template(for: $0) }
    }

    /// Returns a brief catalogue summary for use in Exploration prompts.
    public static func catalogueSummary() -> String {
        DeliverableType.allCases.map { type in
            let t = template(for: type)
            return "- **\(type.rawValue)**: \(t.purpose) Useful when: \(t.whenUseful)"
        }.joined(separator: "\n")
    }

    // MARK: - Templates

    private static let visionStatement = DeliverableTemplate(
        type: .visionStatement,
        purpose: "Articulates what a project is — its intent, principles, boundaries, and definition of done.",
        whenUseful: "Almost always. Any project that isn't immediately obvious in scope and intent.",
        informationRequirements: [
            "Core intent — what is this project, in the user's own words?",
            "Motivation and personal significance — why does this matter?",
            "Target audience or beneficiary — who is this for?",
            "Scope boundaries — what's explicitly in and what's explicitly out?",
            "Design principles — values and priorities that guide decisions.",
            "Definition of done — what does finished look like, concretely?",
            "Mental model or key metaphor (optional) — how the user thinks about the project.",
            "Ethical considerations or constraints (if applicable)."
        ],
        documentStructure: [
            .init(heading: "Intent", description: "Clear, concise statement of what this project is and aims to achieve. Two to three paragraphs maximum."),
            .init(heading: "Motivation", description: "Why this project exists. What need it addresses, why the user cares."),
            .init(heading: "Audience", description: "Who this is for and what their needs or expectations are."),
            .init(heading: "Scope", description: "What's included and what's explicitly excluded."),
            .init(heading: "Design Principles", description: "Guiding values for decision-making, each with a brief explanation."),
            .init(heading: "Definition of Done", description: "Concrete, verifiable criteria for completion."),
            .init(heading: "Mental Model", description: "(If applicable) The metaphor or frame the user uses to think about this project."),
            .init(heading: "Ethical Considerations", description: "(If applicable) Commitments or constraints around how the project operates.")
        ]
    )

    private static let technicalBrief = DeliverableTemplate(
        type: .technicalBrief,
        purpose: "Documents the technical architecture, technology choices, and implementation approach.",
        whenUseful: "Software projects almost always. Hardware projects often. Any project where technology choices have cascading consequences.",
        informationRequirements: [
            "Technology stack — languages, frameworks, platforms, tools, and rationale for each.",
            "Architecture overview — high-level system structure and component relationships.",
            "Data model — what data exists, how it's structured, how it's persisted.",
            "Key technical decisions — significant choices and their reasoning.",
            "Integration points — external systems, APIs, services the project connects to.",
            "Technical constraints — platform limitations, performance requirements, accessibility standards.",
            "Implementation order — what should be built first and dependency chain.",
            "Known risks and uncertainties — areas needing prototyping or validation."
        ],
        documentStructure: [
            .init(heading: "Technology Stack", description: "Each technology choice with rationale."),
            .init(heading: "Architecture", description: "High-level system structure. How components relate."),
            .init(heading: "Data Model", description: "What data exists, how it's structured, how it's stored."),
            .init(heading: "Key Decisions", description: "Significant technical choices and their reasoning."),
            .init(heading: "Integration Points", description: "External connections and dependencies."),
            .init(heading: "Constraints", description: "Technical limitations and requirements."),
            .init(heading: "Implementation Order", description: "What gets built first and the dependency chain."),
            .init(heading: "Risks and Uncertainties", description: "Known unknowns and areas requiring validation.")
        ]
    )

    private static let setupSpecification = DeliverableTemplate(
        type: .setupSpecification,
        purpose: "Documents physical, equipment, or environmental requirements for tangible projects.",
        whenUseful: "Event planning, hardware projects, music production, any project involving physical resources.",
        informationRequirements: [
            "Equipment and materials — what physical things are needed, specific items or categories.",
            "Configuration and connections — how pieces fit together (signal chain, wiring, layout).",
            "Venue or environment requirements — power, acoustics, capacity, accessibility.",
            "Sourcing and procurement — where materials come from, budget implications.",
            "Setup and teardown process — sequence for assembly and disassembly.",
            "Contingencies — backup options, minimum viable setup."
        ],
        documentStructure: [
            .init(heading: "Equipment and Materials", description: "Everything needed, with specifics where known."),
            .init(heading: "Configuration", description: "How everything connects and relates physically."),
            .init(heading: "Environment Requirements", description: "What the venue or space must provide."),
            .init(heading: "Procurement", description: "What needs to be acquired, from where, at what cost."),
            .init(heading: "Setup Process", description: "Step-by-step sequence for getting everything operational."),
            .init(heading: "Contingencies", description: "Backup plans and minimum viable configuration.")
        ]
    )

    private static let researchPlan = DeliverableTemplate(
        type: .researchPlan,
        purpose: "Structures an inquiry-driven project around clear questions, sources, and methodology.",
        whenUseful: "Learning projects, investigation projects, decision-making projects where the output is knowledge or a decision.",
        informationRequirements: [
            "Central question or objective — what is the user trying to learn, understand, or decide?",
            "Sub-questions — component questions that build toward the central inquiry.",
            "Sources and methods — where and how the user will investigate.",
            "Existing knowledge — what the user already knows, to establish the starting point.",
            "Success criteria — how to know when the research is 'done enough'.",
            "Output or application — what the user will do with what they learn."
        ],
        documentStructure: [
            .init(heading: "Central Question", description: "The core inquiry, stated clearly."),
            .init(heading: "Sub-Questions", description: "Component questions building toward the central one."),
            .init(heading: "Existing Knowledge", description: "What the user already knows."),
            .init(heading: "Sources and Methods", description: "Where and how to investigate."),
            .init(heading: "Success Criteria", description: "How to know when enough has been learned."),
            .init(heading: "Application", description: "What the knowledge will be used for.")
        ]
    )

    private static let creativeBrief = DeliverableTemplate(
        type: .creativeBrief,
        purpose: "Captures artistic or creative intent, guiding the work without over-constraining it.",
        whenUseful: "Music, visual art, writing, any project where the output is a creative work involving intuition and discovery.",
        informationRequirements: [
            "Artistic intent — what is the user trying to express or evoke? Emotional and experiential terms.",
            "Aesthetic references — existing works, styles, or artists in conversation with this project.",
            "Medium and materials — instruments, tools, software, physical materials.",
            "Context and setting — where and how the work will be experienced.",
            "Constraints and parameters — duration, format, budget, timeline, technical limitations.",
            "Open questions — what the user deliberately doesn't know yet and hopes to discover."
        ],
        documentStructure: [
            .init(heading: "Intent", description: "What the work aims to express or evoke."),
            .init(heading: "References", description: "Works, styles, and artists that inform this project."),
            .init(heading: "Medium and Materials", description: "Tools, instruments, software, physical materials."),
            .init(heading: "Context", description: "Where and how the work will be experienced."),
            .init(heading: "Constraints", description: "Duration, format, budget, timeline, technical parameters."),
            .init(heading: "Open Questions", description: "What the user wants to discover through the creative process.")
        ]
    )
}
