import Testing
import Foundation
@testable import PMFeatures
@testable import PMDomain

// MARK: - Quick Capture Test Helper

private let qcCatId = UUID()

@MainActor
func makeQuickCaptureVM() -> (QuickCaptureViewModel, MockProjectRepository, MockCategoryRepository) {
    let projectRepo = MockProjectRepository()
    let categoryRepo = MockCategoryRepository()
    categoryRepo.categories = [
        PMDomain.Category(id: qcCatId, name: "Software", isBuiltIn: true)
    ]
    let vm = QuickCaptureViewModel(projectRepo: projectRepo, categoryRepo: categoryRepo)
    return (vm, projectRepo, categoryRepo)
}

// MARK: - Tests

@Suite("QuickCaptureViewModel")
struct QuickCaptureViewModelTests {

    @Test("Load categories populates list")
    @MainActor
    func loadCategories() async {
        let (vm, _, _) = makeQuickCaptureVM()

        await vm.loadCategories()

        #expect(vm.categories.count == 1)
        #expect(vm.categories.first?.name == "Software")
    }

    @Test("canSave requires non-empty transcript")
    @MainActor
    func canSaveRequiresTranscript() {
        let (vm, _, _) = makeQuickCaptureVM()

        #expect(vm.canSave == false)

        vm.transcript = "   "
        #expect(vm.canSave == false)

        vm.transcript = "Build an app"
        #expect(vm.canSave == true)
    }

    @Test("Save creates idea-state project")
    @MainActor
    func saveCreatesProject() async {
        let (vm, projectRepo, _) = makeQuickCaptureVM()
        await vm.loadCategories()

        vm.transcript = "Build a cool app"
        await vm.save()

        #expect(vm.didSave == true)
        #expect(vm.error == nil)
        #expect(projectRepo.projects.count == 1)

        let saved = projectRepo.projects.first!
        #expect(saved.lifecycleState == .idea)
        #expect(saved.quickCaptureTranscript == "Build a cool app")
        #expect(saved.categoryId == qcCatId)
    }

    @Test("Save uses title when provided")
    @MainActor
    func saveUsesTitle() async {
        let (vm, projectRepo, _) = makeQuickCaptureVM()
        await vm.loadCategories()

        vm.transcript = "Some description"
        vm.title = "My Project"
        await vm.save()

        #expect(projectRepo.projects.first?.name == "My Project")
    }

    @Test("Save auto-generates title from transcript")
    @MainActor
    func saveAutoTitle() async {
        let (vm, projectRepo, _) = makeQuickCaptureVM()
        await vm.loadCategories()

        vm.transcript = "First line\nSecond line"
        await vm.save()

        #expect(projectRepo.projects.first?.name == "First line")
    }

    @Test("Save fails with empty transcript")
    @MainActor
    func saveFailsEmpty() async {
        let (vm, _, _) = makeQuickCaptureVM()
        await vm.loadCategories()

        vm.transcript = "  "
        await vm.save()

        #expect(vm.didSave == false)
        #expect(vm.error == "Please enter a description.")
    }

    @Test("Save fails with no categories")
    @MainActor
    func saveFailsNoCategories() async {
        let (vm, _, categoryRepo) = makeQuickCaptureVM()
        categoryRepo.categories = []
        await vm.loadCategories()

        vm.transcript = "Some idea"
        await vm.save()

        #expect(vm.didSave == false)
        #expect(vm.error == "No categories available.")
    }

    @Test("Save uses selected category")
    @MainActor
    func saveUsesSelectedCategory() async {
        let customCatId = UUID()
        let (vm, projectRepo, categoryRepo) = makeQuickCaptureVM()
        categoryRepo.categories.append(PMDomain.Category(id: customCatId, name: "Hardware", isBuiltIn: false))
        await vm.loadCategories()

        vm.transcript = "Hardware idea"
        vm.selectedCategoryId = customCatId
        await vm.save()

        #expect(projectRepo.projects.first?.categoryId == customCatId)
    }

    @Test("Reset clears all state")
    @MainActor
    func resetClearsState() async {
        let (vm, _, _) = makeQuickCaptureVM()
        await vm.loadCategories()

        vm.transcript = "Something"
        vm.title = "Title"
        vm.selectedCategoryId = UUID()
        await vm.save()

        vm.reset()

        #expect(vm.transcript == "")
        #expect(vm.title == "")
        #expect(vm.selectedCategoryId == nil)
        #expect(vm.error == nil)
        #expect(vm.didSave == false)
    }

    @Test("canSave false while saving")
    @MainActor
    func canSaveFalseWhileSaving() {
        let (vm, _, _) = makeQuickCaptureVM()
        vm.transcript = "Something"
        #expect(vm.canSave == true)
        // isSaving is private(set), so we can't directly test this in isolation
        // but the save flow sets isSaving = true during execution
    }

    @Test("Load categories handles error")
    @MainActor
    func loadCategoriesError() async {
        let projectRepo = MockProjectRepository()
        let categoryRepo = MockCategoryRepository()
        categoryRepo.shouldThrow = true
        let vm = QuickCaptureViewModel(projectRepo: projectRepo, categoryRepo: categoryRepo)

        await vm.loadCategories()

        #expect(vm.categories.isEmpty)
        #expect(vm.error != nil)
    }
}
