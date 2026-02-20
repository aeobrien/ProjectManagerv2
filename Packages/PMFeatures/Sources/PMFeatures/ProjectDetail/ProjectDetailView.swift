import SwiftUI
import PMDomain
import PMDesignSystem

/// Tabbed view showing a project's full detail: overview, roadmap, documents, history.
public struct ProjectDetailView: View {
    @Bindable var viewModel: ProjectDetailViewModel
    var roadmapViewModel: ProjectRoadmapViewModel?
    @State private var selectedTab: DetailTab = .roadmap

    public init(viewModel: ProjectDetailViewModel, roadmapViewModel: ProjectRoadmapViewModel? = nil) {
        self.viewModel = viewModel
        self.roadmapViewModel = roadmapViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            projectHeader
            Divider()
            tabContent
        }
        .navigationTitle(viewModel.project.name)
        .task { await viewModel.load() }
    }

    // MARK: - Header

    private var projectHeader: some View {
        HStack(spacing: 12) {
            if let slot = viewModel.project.focusSlotIndex {
                Circle()
                    .fill(SlotColour.forIndex(slot))
                    .frame(width: 12, height: 12)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.project.name)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 8) {
                    Label(viewModel.project.lifecycleState.rawValue.capitalized,
                          systemImage: viewModel.project.lifecycleState.iconName)
                        .foregroundStyle(viewModel.project.lifecycleState.color)
                        .font(.caption)

                    if let dod = viewModel.project.definitionOfDone, !dod.isEmpty {
                        Text("·").foregroundStyle(.quaternary)
                        Text(dod)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Phase progress summary
            let totalPhases = viewModel.phases.count
            let completedPhases = viewModel.phases.filter { $0.status == .completed }.count
            if totalPhases > 0 {
                PMProgressLabel(
                    progress: Double(completedPhases) / Double(totalPhases),
                    style: .fraction(total: totalPhases)
                )
            }
        }
        .padding()
    }

    // MARK: - Tabs

    private var tabContent: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch selectedTab {
            case .roadmap:
                RoadmapView(viewModel: viewModel)
            case .timeline:
                if let roadmapVM = roadmapViewModel {
                    ProjectRoadmapView(viewModel: roadmapVM)
                } else {
                    PMEmptyState(icon: "map", title: "Timeline", message: "Timeline view not available.")
                }
            case .overview:
                OverviewTabView(viewModel: viewModel)
            }
        }
    }
}

enum DetailTab: String, CaseIterable {
    case roadmap = "Roadmap"
    case timeline = "Timeline"
    case overview = "Overview"
}

// MARK: - Overview Tab

struct OverviewTabView: View {
    let viewModel: ProjectDetailViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let dod = viewModel.project.definitionOfDone, !dod.isEmpty {
                    PMSectionHeader("Definition of Done")
                    Text(dod)
                        .font(.body)
                        .padding(.horizontal)
                }

                if let notes = viewModel.project.notes, !notes.isEmpty {
                    PMSectionHeader("Notes")
                    Text(notes)
                        .font(.body)
                        .padding(.horizontal)
                }

                PMSectionHeader("Phases", subtitle: "\(viewModel.phases.count) phases")
                ForEach(viewModel.phases) { phase in
                    HStack {
                        Text(phase.name)
                        Spacer()
                        Text(phase.status.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                if viewModel.phases.isEmpty {
                    PMEmptyState(icon: "list.bullet", title: "No Phases", message: "Add phases in the Roadmap tab.")
                        .frame(height: 200)
                }
            }
            .padding(.vertical)
        }
    }
}
