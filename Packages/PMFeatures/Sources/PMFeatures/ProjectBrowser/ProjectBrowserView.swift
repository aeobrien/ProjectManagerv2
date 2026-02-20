import SwiftUI
import PMDomain
import PMDesignSystem

/// The main project browser view with filtering, search, and list display.
public struct ProjectBrowserView: View {
    @Bindable var viewModel: ProjectBrowserViewModel
    var onSelectProject: ((Project) -> Void)?

    public init(viewModel: ProjectBrowserViewModel, onSelectProject: ((Project) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onSelectProject = onSelectProject
    }

    public var body: some View {
        VStack(spacing: 0) {
            filterBar
            projectList
        }
        .searchable(text: $viewModel.searchText, prompt: "Search projects...")
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.isShowingCreateSheet = true
                } label: {
                    Label("New Project", systemImage: "plus")
                }
            }

            ToolbarItem {
                sortMenu
            }
        }
        .sheet(isPresented: $viewModel.isShowingCreateSheet) {
            ProjectCreateSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingEditSheet) {
            if let project = viewModel.editingProject {
                ProjectEditSheet(viewModel: viewModel, project: project)
            }
        }
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Lifecycle filters
                FilterChip(
                    label: "All",
                    isSelected: viewModel.selectedLifecycleFilter == .all
                ) {
                    viewModel.selectedLifecycleFilter = .all
                }

                ForEach(LifecycleState.allCases, id: \.self) { state in
                    FilterChip(
                        label: state.rawValue.capitalized,
                        isSelected: viewModel.selectedLifecycleFilter == .state(state),
                        tint: state.color
                    ) {
                        viewModel.selectedLifecycleFilter = .state(state)
                    }
                }

                Divider().frame(height: 20)

                // Category filter
                Menu {
                    Button("All Categories") {
                        viewModel.selectedCategoryId = nil
                    }
                    Divider()
                    ForEach(viewModel.categories) { category in
                        Button(category.name) {
                            viewModel.selectedCategoryId = category.id
                        }
                    }
                } label: {
                    Label(selectedCategoryLabel, systemImage: "folder")
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var selectedCategoryLabel: String {
        if let id = viewModel.selectedCategoryId {
            return viewModel.categories.first { $0.id == id }?.name ?? "Category"
        }
        return "All Categories"
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(SortOrder.allCases, id: \.self) { order in
                Button {
                    viewModel.sortOrder = order
                } label: {
                    if viewModel.sortOrder == order {
                        Label(order.rawValue, systemImage: "checkmark")
                    } else {
                        Text(order.rawValue)
                    }
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    // MARK: - Project List

    private var projectList: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredProjects.isEmpty {
                PMEmptyState(
                    icon: "folder",
                    title: emptyTitle,
                    message: emptyMessage,
                    actionLabel: viewModel.searchText.isEmpty ? "New Project" : nil
                ) {
                    viewModel.isShowingCreateSheet = true
                }
            } else {
                List(viewModel.filteredProjects) { project in
                    ProjectRowView(
                        project: project,
                        categoryName: viewModel.categoryName(for: project)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectProject?(project)
                    }
                    .contextMenu {
                        projectContextMenu(for: project)
                    }
                }
            }
        }
    }

    private var emptyTitle: String {
        viewModel.searchText.isEmpty ? "No Projects" : "No Results"
    }

    private var emptyMessage: String {
        if !viewModel.searchText.isEmpty {
            return "No projects match \"\(viewModel.searchText)\"."
        }
        switch viewModel.selectedLifecycleFilter {
        case .all:
            return "Create your first project to get started."
        case .state(let state):
            return "No \(state.rawValue) projects."
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func projectContextMenu(for project: Project) -> some View {
        Button("Edit...") {
            viewModel.editingProject = project
            viewModel.isShowingEditSheet = true
        }

        Menu("Change State") {
            ForEach(Array(viewModel.validTransitions(for: project)), id: \.self) { state in
                Button(state.rawValue.capitalized) {
                    if state == .paused || state == .abandoned {
                        viewModel.editingProject = project
                        viewModel.transitionTarget = state
                        viewModel.isShowingStateTransition = true
                    } else {
                        Task { await viewModel.transitionProject(project, to: state) }
                    }
                }
            }
        }

        Divider()

        Button("Delete", role: .destructive) {
            viewModel.editingProject = project
            viewModel.isShowingDeleteConfirmation = true
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? tint.opacity(0.15) : Color.clear, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? tint : .secondary.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Project Row

struct ProjectRowView: View {
    let project: Project
    let categoryName: String

    var body: some View {
        HStack(spacing: 12) {
            // Focus slot indicator
            if let slotIndex = project.focusSlotIndex {
                Circle()
                    .fill(SlotColour.forIndex(slotIndex))
                    .frame(width: 10, height: 10)
            } else {
                Circle()
                    .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(project.name)
                        .font(.headline)

                    Image(systemName: project.lifecycleState.iconName)
                        .font(.caption)
                        .foregroundStyle(project.lifecycleState.color)
                }

                HStack(spacing: 8) {
                    Text(categoryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.quaternary)

                    Text(project.lifecycleState.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(project.lifecycleState.color)

                    if let updatedAgo = relativeDate(project.updatedAt) {
                        Text("·")
                            .foregroundStyle(.quaternary)
                        Text(updatedAgo)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func relativeDate(_ date: Date) -> String? {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview("Project Browser") {
    Text("Project Browser requires live dependencies")
        .frame(width: 600, height: 400)
}
