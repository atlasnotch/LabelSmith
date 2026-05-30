import XCTest
@testable import LabelSmith

final class DatasetViewModelTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    @MainActor
    func testMarkReviewedAndSelectNextUnreviewed() throws {
        try writeImage("a.jpg", caption: "first")
        try writeImage("b.jpg", caption: "second")
        try writeImage("c.jpg", caption: "third")

        let dataset = DatasetViewModel(workspaceStore: testWorkspaceStore())
        dataset.loadFolder(tempDirectory)

        XCTAssertEqual(dataset.reviewSummary, "0 of 3 reviewed")

        dataset.markSelectedReviewed()
        dataset.selectNextUnreviewed()

        XCTAssertEqual(dataset.selectedItem?.filename, "b.jpg")

        dataset.markSelectedReviewed()

        XCTAssertEqual(dataset.reviewSummary, "2 of 3 reviewed")
    }

    @MainActor
    func testSelectNextMissingCaptionSkipsReviewedState() throws {
        try writeImage("a.jpg", caption: "first")
        try writeImage("b.jpg", caption: "")
        try writeImage("c.jpg", caption: "")

        let dataset = DatasetViewModel(workspaceStore: testWorkspaceStore())
        dataset.loadFolder(tempDirectory)
        dataset.markSelectedReviewed()
        dataset.selectNextMissingCaption()

        XCTAssertEqual(dataset.selectedItem?.filename, "b.jpg")
    }

    @MainActor
    func testCopyPreviousVisibleCaptionAndClearSelectedCaption() throws {
        try writeImage("a.jpg", caption: "first")
        try writeImage("b.jpg", caption: "second")

        let dataset = DatasetViewModel(workspaceStore: testWorkspaceStore())
        dataset.loadFolder(tempDirectory)
        dataset.select(dataset.items[1].id)

        dataset.copyPreviousCaptionToSelected()

        XCTAssertEqual(dataset.selectedItem?.caption, "first")
        XCTAssertEqual(dataset.selectedItem?.saveState, .dirty)

        dataset.clearSelectedCaption()

        XCTAssertEqual(dataset.selectedItem?.caption, "")
    }

    @MainActor
    func testRestoresLastFolderAndPerFolderState() throws {
        try writeImage("a.jpg", caption: "first")
        try writeImage("b.jpg", caption: "second")
        let workspaceStore = testWorkspaceStore()

        let firstSession = DatasetViewModel(workspaceStore: workspaceStore)
        firstSession.loadFolder(tempDirectory)
        firstSession.markSelectedReviewed()
        firstSession.select(firstSession.items[1].id)
        firstSession.searchText = "second"
        firstSession.showMissingOnly = true

        let restoredSession = DatasetViewModel(workspaceStore: workspaceStore)
        restoredSession.restoreLastOpenedFolderIfNeeded()

        XCTAssertEqual(restoredSession.folderURL?.path, tempDirectory.path)
        XCTAssertEqual(restoredSession.selectedItem?.filename, "b.jpg")
        XCTAssertEqual(restoredSession.searchText, "second")
        XCTAssertTrue(restoredSession.showMissingOnly)
        XCTAssertTrue(restoredSession.items[0].isReviewed)
        XCTAssertEqual(restoredSession.reviewSummary, "1 of 2 reviewed")
    }

    @MainActor
    func testUnavailableLastFolderIsKeptInManagedFoldersAndReported() {
        let missingURL = tempDirectory.appendingPathComponent("missing", isDirectory: true)
        let workspaceStore = testWorkspaceStore()
        workspaceStore.save(WorkspaceSnapshot(
            lastFolderPath: missingURL.path,
            managedFolders: [
                ManagedFolder(path: missingURL.path, isPinned: true, lastOpenedAt: Date())
            ],
            folderStates: [:]
        ))

        let dataset = DatasetViewModel(workspaceStore: workspaceStore)
        dataset.restoreLastOpenedFolderIfNeeded()

        XCTAssertTrue(dataset.items.isEmpty)
        XCTAssertEqual(dataset.managedFolders.first?.path, missingURL.path)
        XCTAssertTrue(dataset.statusMessage.contains("unavailable"))
    }

    @MainActor
    func testManagedFoldersSortPinnedBeforeRecent() throws {
        try writeImage("a.jpg", caption: "first")
        let secondDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: secondDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: secondDirectory) }
        try Data().write(to: secondDirectory.appendingPathComponent("c.jpg"))

        let workspaceStore = testWorkspaceStore()
        let dataset = DatasetViewModel(workspaceStore: workspaceStore)
        dataset.loadFolder(tempDirectory)
        let firstFolder = dataset.managedFolders[0]
        dataset.loadFolder(secondDirectory)

        dataset.togglePinned(firstFolder)

        XCTAssertEqual(dataset.managedFolders.first?.path, tempDirectory.path)
        XCTAssertTrue(dataset.managedFolders.first?.isPinned == true)
    }

    @MainActor
    func testUndoMarkReviewedRestoresReviewState() throws {
        try writeImage("a.jpg", caption: "first")
        let undoManager = UndoManager()
        let dataset = DatasetViewModel(workspaceStore: testWorkspaceStore())
        dataset.setUndoManager(undoManager)
        dataset.loadFolder(tempDirectory)

        dataset.markSelectedReviewed()

        XCTAssertTrue(dataset.selectedItem?.isReviewed == true)

        undoManager.undo()

        XCTAssertFalse(dataset.selectedItem?.isReviewed == true)

        undoManager.redo()

        XCTAssertTrue(dataset.selectedItem?.isReviewed == true)
    }

    @MainActor
    func testUndoClearAndCopyPreviousCaptionRestoresCaption() throws {
        try writeImage("a.jpg", caption: "first")
        try writeImage("b.jpg", caption: "second")
        let undoManager = UndoManager()
        let dataset = DatasetViewModel(workspaceStore: testWorkspaceStore())
        dataset.setUndoManager(undoManager)
        dataset.loadFolder(tempDirectory)
        dataset.select(dataset.items[1].id)

        dataset.clearSelectedCaption()

        XCTAssertEqual(dataset.selectedItem?.caption, "")

        undoManager.undo()

        XCTAssertEqual(dataset.selectedItem?.caption, "second")

        dataset.copyPreviousCaptionToSelected()

        XCTAssertEqual(dataset.selectedItem?.caption, "first")

        undoManager.undo()

        XCTAssertEqual(dataset.selectedItem?.caption, "second")
    }

    @MainActor
    func testUndoBatchCaptionChangesRestoresFiles() throws {
        try writeImage("a.jpg", caption: "first")
        try writeImage("b.jpg", caption: "second")
        let undoManager = UndoManager()
        let dataset = DatasetViewModel(workspaceStore: testWorkspaceStore())
        dataset.setUndoManager(undoManager)
        dataset.loadFolder(tempDirectory)

        dataset.applyBatchCaptionChanges([
            BatchCaptionPreviewChange(
                itemID: dataset.items[0].id,
                filename: dataset.items[0].filename,
                originalCaption: "first",
                newCaption: "updated first"
            ),
            BatchCaptionPreviewChange(
                itemID: dataset.items[1].id,
                filename: dataset.items[1].filename,
                originalCaption: "second",
                newCaption: "updated second"
            )
        ])

        XCTAssertEqual(dataset.items.map(\.caption), ["updated first", "updated second"])
        XCTAssertEqual(try readCaption("a"), "updated first")

        undoManager.undo()

        XCTAssertEqual(dataset.items.map(\.caption), ["first", "second"])
        XCTAssertEqual(try readCaption("a"), "first")
        XCTAssertEqual(try readCaption("b"), "second")
    }

    private func writeImage(_ name: String, caption: String) throws {
        let imageURL = tempDirectory.appendingPathComponent(name)
        try Data().write(to: imageURL)
        try caption.write(
            to: imageURL.deletingPathExtension().appendingPathExtension("txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func readCaption(_ basename: String) throws -> String {
        try String(contentsOf: tempDirectory.appendingPathComponent("\(basename).txt"), encoding: .utf8)
    }

    private func testWorkspaceStore() -> WorkspaceStore {
        let suiteName = "LabelSmithTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return WorkspaceStore(defaults: defaults)
    }
}
