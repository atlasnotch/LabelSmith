import Foundation
import SwiftUI

@MainActor
final class DatasetViewModel: ObservableObject {
    @Published private(set) var folderURL: URL?
    @Published private(set) var items: [DatasetItem] = []
    @Published var selectedID: DatasetItem.ID? {
        didSet { saveCurrentWorkspaceState() }
    }
    @Published var searchText = "" {
        didSet { saveCurrentWorkspaceState() }
    }
    @Published var showMissingOnly = false {
        didSet { saveCurrentWorkspaceState() }
    }
    @Published private(set) var orphanCaptionCount = 0
    @Published private(set) var statusMessage = "Drop an Ostris image folder to begin."
    @Published var isDropTargeted = false
    @Published private(set) var managedFolders: [ManagedFolder] = []

    private let scanner: DatasetScanner
    private let navigation = DatasetNavigationModel()
    private let captionEditing: CaptionEditingModel
    private var workspace: WorkspaceCoordinator
    private let folderOpening: FolderOpening
    private weak var undoManager: UndoManager?

    init(
        scanner: DatasetScanner = DatasetScanner(),
        captionStore: CaptionStore = CaptionStore(),
        workspaceStore: WorkspaceStore = WorkspaceStore(),
        folderOpening: FolderOpening = FolderOpening()
    ) {
        self.scanner = scanner
        self.captionEditing = CaptionEditingModel(captionStore: captionStore)
        self.workspace = WorkspaceCoordinator(workspaceStore: workspaceStore)
        self.folderOpening = folderOpening
        self.managedFolders = workspace.managedFolders
    }

    var selectedItem: DatasetItem? {
        navigation.selectedItem(in: items, selectedID: selectedID)
    }

    var filteredItems: [DatasetItem] {
        navigation.filteredItems(
            from: items,
            searchText: searchText,
            showMissingOnly: showMissingOnly
        )
    }

    var completionSummary: String {
        guard !items.isEmpty else { return "No images loaded" }
        let missing = items.filter(\.isMissingCaption).count
        return "\(items.count) images, \(missing) missing captions"
    }

    var reviewSummary: String {
        guard !items.isEmpty else { return "No review progress" }
        return "\(reviewedCount) of \(items.count) reviewed"
    }

    var reviewProgress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(reviewedCount) / Double(items.count)
    }

    private var reviewedCount: Int {
        items.filter(\.isReviewed).count
    }

    func batchPreview(scope: BatchCaptionScope, operation: BatchCaptionOperation) -> BatchCaptionPreview {
        BatchCaptionEdit.preview(
            items: navigation.batchItems(scope: scope, items: items, filteredItems: filteredItems),
            operation: operation
        )
    }

    func setUndoManager(_ undoManager: UndoManager?) {
        self.undoManager = undoManager
    }

    func restoreLastOpenedFolderIfNeeded() {
        switch workspace.restoreLastOpenedFolderAction() {
        case .none:
            return
        case .load(let url):
            loadFolder(url)
        case .unavailable(let message):
            statusMessage = message
        }
    }

    func presentOpenPanel() {
        guard let url = folderOpening.chooseFolder() else { return }
        loadFolder(url)
    }

    func loadFolder(_ url: URL) {
        saveCurrentWorkspaceState()
        flushSelectedCaption()
        captionEditing.cancelAutosave()

        do {
            let result = try scanner.scan(folderURL: url)
            folderURL = result.folderURL
            items = result.items
            orphanCaptionCount = result.orphanCaptionCount
            applyWorkspaceState(for: result.folderURL.path)
            workspace.trackOpenedFolder(result.folderURL)
            managedFolders = workspace.managedFolders
            statusMessage = result.items.isEmpty
                ? "No .jpg, .jpeg, or .png images found in \(url.lastPathComponent)."
                : "Loaded \(result.items.count) images from \(url.lastPathComponent)."
        } catch {
            folderURL = nil
            items = []
            selectedID = nil
            orphanCaptionCount = 0
            statusMessage = "Could not load folder: \(error.localizedDescription)"
        }
    }

    func openManagedFolder(_ folder: ManagedFolder) {
        guard folder.isAvailable else {
            statusMessage = "Folder unavailable: \(folder.displayName)."
            return
        }

        loadFolder(folder.url)
    }

    func togglePinned(_ folder: ManagedFolder) {
        workspace.togglePinned(folder)
        managedFolders = workspace.managedFolders
    }

    func removeManagedFolder(_ folder: ManagedFolder) {
        workspace.removeManagedFolder(folder)
        managedFolders = workspace.managedFolders
    }

    func updateCaption(for itemID: DatasetItem.ID, caption: String) {
        setCaption(for: itemID, caption: caption, registersUndo: false)
    }

    func select(_ id: DatasetItem.ID?) {
        flushSelectedCaption()
        selectedID = id
    }

    func selectNext() {
        let result = navigation.select(offset: 1, selectedID: selectedID, visibleItems: filteredItems)
        guard result.shouldSelect else { return }
        select(result.selectedID)
    }

    func selectPrevious() {
        let result = navigation.select(offset: -1, selectedID: selectedID, visibleItems: filteredItems)
        guard result.shouldSelect else { return }
        select(result.selectedID)
    }

    func selectNextMissingCaption() {
        selectNextItem(matching: \.isMissingCaption, noneMessage: "No other missing captions.")
    }

    func selectNextUnreviewed() {
        selectNextItem(matching: { !$0.isReviewed }, noneMessage: "No other unreviewed images.")
    }

    func markSelectedReviewed(_ isReviewed: Bool = true) {
        guard let selectedID else { return }
        setReviewed(
            for: selectedID,
            isReviewed: isReviewed,
            actionName: isReviewed ? "Mark Reviewed" : "Mark Unreviewed"
        )
    }

    func toggleSelectedReviewed() {
        guard let selectedItem else { return }
        markSelectedReviewed(!selectedItem.isReviewed)
    }

    func copyPreviousCaptionToSelected() {
        var updatedItems = items
        guard let message = captionEditing.copyPreviousCaptionToSelected(
            selectedID: selectedID,
            filteredItems: filteredItems,
            items: &updatedItems,
            registerUndo: makeUndoRegistration(),
            saveCaption: makeCaptionSaveRequest()
        ) else {
            return
        }

        replaceItemsIfChanged(updatedItems)
        statusMessage = message
    }

    func clearSelectedCaption() {
        var updatedItems = items
        guard let message = captionEditing.clearSelectedCaption(
            selectedID: selectedID,
            items: &updatedItems,
            registerUndo: makeUndoRegistration(),
            saveCaption: makeCaptionSaveRequest()
        ) else {
            return
        }

        replaceItemsIfChanged(updatedItems)
        statusMessage = message
    }

    func flushSelectedCaption() {
        var updatedItems = items
        guard let message = captionEditing.flushCaption(for: selectedID, items: &updatedItems) else { return }
        replaceItemsIfChanged(updatedItems)
        statusMessage = message
    }

    func applyBatchCaptionChanges(_ changes: [BatchCaptionPreviewChange]) {
        var updatedItems = items
        guard let message = captionEditing.applyBatchCaptionChanges(
            changes,
            items: &updatedItems,
            registerUndo: makeUndoRegistration()
        ) else {
            return
        }

        replaceItemsIfChanged(updatedItems)
        statusMessage = message
    }

    func setCaption(
        for itemID: DatasetItem.ID,
        caption: String,
        registersUndo: Bool,
        actionName: String? = nil
    ) {
        var updatedItems = items
        captionEditing.setCaption(
            for: itemID,
            caption: caption,
            items: &updatedItems,
            registersUndo: registersUndo,
            actionName: actionName,
            registerUndo: makeUndoRegistration(),
            saveCaption: makeCaptionSaveRequest()
        )
        replaceItemsIfChanged(updatedItems)
    }

    func setReviewed(
        for itemID: DatasetItem.ID,
        isReviewed: Bool,
        registersUndo: Bool = true,
        actionName: String? = nil
    ) {
        var updatedItems = items
        guard let message = captionEditing.setReviewed(
            for: itemID,
            isReviewed: isReviewed,
            items: &updatedItems,
            registersUndo: registersUndo,
            actionName: actionName,
            registerUndo: makeUndoRegistration()
        ) else {
            return
        }

        replaceItemsIfChanged(updatedItems)
        saveCurrentWorkspaceState()
        statusMessage = message
    }

    func applyCaptionReplacements(
        _ replacements: [CaptionReplacement],
        savesImmediately: Bool,
        registersUndo: Bool,
        actionName: String
    ) {
        var updatedItems = items
        guard let message = captionEditing.applyCaptionReplacements(
            replacements,
            items: &updatedItems,
            savesImmediately: savesImmediately,
            registersUndo: registersUndo,
            actionName: actionName,
            registerUndo: makeUndoRegistration(),
            saveCaption: makeCaptionSaveRequest()
        ) else {
            return
        }

        replaceItemsIfChanged(updatedItems)
        statusMessage = message
    }

    private func saveCurrentWorkspaceState() {
        workspace.saveCurrentWorkspaceState(
            folderURL: folderURL,
            selectedID: selectedID,
            searchText: searchText,
            showMissingOnly: showMissingOnly,
            items: items
        )
        managedFolders = workspace.managedFolders
    }

    private func applyWorkspaceState(for folderPath: String) {
        let state = workspace.beginApplyingWorkspaceState(for: folderPath)
        defer { workspace.finishApplyingWorkspaceState() }

        searchText = state.searchText
        showMissingOnly = state.showMissingOnly

        for index in items.indices {
            items[index].isReviewed = state.reviewedItemIDs.contains(items[index].id)
        }

        if let selectedItemID = state.selectedItemID, items.contains(where: { $0.id == selectedItemID }) {
            selectedID = selectedItemID
        } else {
            selectedID = items.first?.id
        }
    }

    private func selectNextItem(
        matching predicate: (DatasetItem) -> Bool,
        noneMessage: String
    ) {
        let result = navigation.nextMatchingItem(
            selectedID: selectedID,
            items: items,
            matching: predicate,
            noneMessage: noneMessage
        )

        if result.shouldSelect {
            select(result.selectedID)
        }

        if let message = result.statusMessage {
            statusMessage = message
        }
    }

    private func saveCaption(for itemID: DatasetItem.ID) {
        var updatedItems = items
        guard let message = captionEditing.saveCaption(for: itemID, items: &updatedItems) else { return }
        replaceItemsIfChanged(updatedItems)
        statusMessage = message
    }

    private func registerUndo(
        actionName: String?,
        handler: @escaping @MainActor (DatasetViewModel) -> Void
    ) {
        undoManager?.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated {
                handler(target)
            }
        }

        if let actionName {
            undoManager?.setActionName(actionName)
        }
    }

    private func makeUndoRegistration() -> DatasetUndoRegistration {
        { [weak self] actionName, handler in
            self?.registerUndo(actionName: actionName, handler: handler)
        }
    }

    private func makeCaptionSaveRequest() -> DatasetCaptionSaveRequest {
        { [weak self] itemID in
            self?.saveCaption(for: itemID)
        }
    }

    private func replaceItemsIfChanged(_ updatedItems: [DatasetItem]) {
        if updatedItems != items {
            items = updatedItems
        }
    }
}
