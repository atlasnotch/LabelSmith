import AppKit
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
    private let captionStore: CaptionStore
    private let workspaceStore: WorkspaceStore
    private var autosaveTask: Task<Void, Never>?
    private var workspaceSnapshot: WorkspaceSnapshot
    private var didAttemptInitialRestore = false
    private var isApplyingWorkspaceState = false
    private static let maximumRecentFolderCount = 12

    init(
        scanner: DatasetScanner = DatasetScanner(),
        captionStore: CaptionStore = CaptionStore(),
        workspaceStore: WorkspaceStore = WorkspaceStore()
    ) {
        self.scanner = scanner
        self.captionStore = captionStore
        self.workspaceStore = workspaceStore
        let snapshot = workspaceStore.load()
        self.workspaceSnapshot = snapshot
        self.managedFolders = Self.sortedManagedFolders(snapshot.managedFolders)
    }

    var selectedItem: DatasetItem? {
        guard let selectedID else { return nil }
        return items.first { $0.id == selectedID }
    }

    var filteredItems: [DatasetItem] {
        items.filter { item in
            let matchesSearch = searchText.isEmpty
                || item.filename.localizedCaseInsensitiveContains(searchText)
                || item.caption.localizedCaseInsensitiveContains(searchText)
            let matchesMissing = !showMissingOnly || item.isMissingCaption
            return matchesSearch && matchesMissing
        }
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
        BatchCaptionEdit.preview(items: batchItems(for: scope), operation: operation)
    }

    func restoreLastOpenedFolderIfNeeded() {
        guard !didAttemptInitialRestore else { return }
        didAttemptInitialRestore = true

        guard let path = workspaceSnapshot.lastFolderPath else { return }
        let url = URL(fileURLWithPath: path, isDirectory: true)

        guard folderExists(at: url) else {
            statusMessage = "Last folder unavailable: \(url.lastPathComponent)."
            return
        }

        loadFolder(url)
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.prompt = "Open"
        panel.message = "Choose an Ostris image folder"

        if panel.runModal() == .OK, let url = panel.url {
            loadFolder(url)
        }
    }

    func loadFolder(_ url: URL) {
        saveCurrentWorkspaceState()
        flushSelectedCaption()
        autosaveTask?.cancel()

        do {
            let result = try scanner.scan(folderURL: url)
            folderURL = result.folderURL
            items = result.items
            orphanCaptionCount = result.orphanCaptionCount
            applyWorkspaceState(for: result.folderURL.path)
            trackOpenedFolder(result.folderURL)
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
        guard let index = workspaceSnapshot.managedFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        workspaceSnapshot.managedFolders[index].isPinned.toggle()
        persistWorkspaceSnapshot()
    }

    func removeManagedFolder(_ folder: ManagedFolder) {
        workspaceSnapshot.managedFolders.removeAll { $0.id == folder.id }
        workspaceSnapshot.folderStates.removeValue(forKey: folder.path)

        if workspaceSnapshot.lastFolderPath == folder.path {
            workspaceSnapshot.lastFolderPath = nil
        }

        persistWorkspaceSnapshot()
    }

    func updateCaption(for itemID: DatasetItem.ID, caption: String) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].caption = caption
        items[index].saveState = caption == items[index].originalCaption ? .clean : .dirty
        scheduleAutosave(for: itemID)
    }

    func select(_ id: DatasetItem.ID?) {
        flushSelectedCaption()
        selectedID = id
    }

    func selectNext() {
        select(offset: 1)
    }

    func selectPrevious() {
        select(offset: -1)
    }

    func selectNextMissingCaption() {
        selectNextItem(matching: \.isMissingCaption, noneMessage: "No other missing captions.")
    }

    func selectNextUnreviewed() {
        selectNextItem(matching: { !$0.isReviewed }, noneMessage: "No other unreviewed images.")
    }

    func markSelectedReviewed(_ isReviewed: Bool = true) {
        guard let selectedID, let index = items.firstIndex(where: { $0.id == selectedID }) else { return }
        items[index].isReviewed = isReviewed
        saveCurrentWorkspaceState()
        statusMessage = isReviewed
            ? "Marked \(items[index].filename) reviewed."
            : "Marked \(items[index].filename) unreviewed."
    }

    func toggleSelectedReviewed() {
        guard let selectedItem else { return }
        markSelectedReviewed(!selectedItem.isReviewed)
    }

    func copyPreviousCaptionToSelected() {
        guard let selectedID, let selectedIndex = items.firstIndex(where: { $0.id == selectedID }) else { return }
        let visible = filteredItems
        guard
            let visibleIndex = visible.firstIndex(where: { $0.id == selectedID }),
            visibleIndex > visible.startIndex
        else {
            statusMessage = "No previous visible caption to copy."
            return
        }

        let previousCaption = visible[visible.index(before: visibleIndex)].caption
        updateCaption(for: selectedID, caption: previousCaption)
        statusMessage = "Copied previous caption to \(items[selectedIndex].filename)."
    }

    func clearSelectedCaption() {
        guard let selectedID, let index = items.firstIndex(where: { $0.id == selectedID }) else { return }
        updateCaption(for: selectedID, caption: "")
        statusMessage = "Cleared caption for \(items[index].filename)."
    }

    func flushSelectedCaption() {
        guard let selectedID else { return }
        saveCaption(for: selectedID)
    }

    func applyBatchCaptionChanges(_ changes: [BatchCaptionPreviewChange]) {
        guard !changes.isEmpty else { return }

        autosaveTask?.cancel()
        var savedCount = 0
        var failedCount = 0

        for change in changes {
            guard let index = items.firstIndex(where: { $0.id == change.itemID }) else { continue }

            items[index].caption = change.newCaption
            items[index].saveState = .saving
            let item = items[index]

            do {
                try captionStore.save(item.caption, for: item)
                items[index].originalCaption = item.caption
                items[index].saveState = .clean
                savedCount += 1
            } catch {
                items[index].saveState = .failed(error.localizedDescription)
                failedCount += 1
            }
        }

        if failedCount > 0 {
            statusMessage = "Saved \(savedCount) captions. \(failedCount) failed."
        } else {
            statusMessage = "Saved \(savedCount) batch caption edits."
        }
    }

    private func saveCurrentWorkspaceState() {
        guard !isApplyingWorkspaceState else { return }
        guard let folderURL else { return }

        workspaceSnapshot.folderStates[folderURL.path] = FolderUIState(
            selectedItemID: selectedID,
            searchText: searchText,
            showMissingOnly: showMissingOnly,
            reviewedItemIDs: Set(items.filter(\.isReviewed).map(\.id))
        )
        persistWorkspaceSnapshot()
    }

    private func applyWorkspaceState(for folderPath: String) {
        isApplyingWorkspaceState = true
        defer { isApplyingWorkspaceState = false }

        let state = workspaceSnapshot.folderStates[folderPath] ?? .empty
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

    private func trackOpenedFolder(_ url: URL) {
        let path = url.path

        if let index = workspaceSnapshot.managedFolders.firstIndex(where: { $0.path == path }) {
            workspaceSnapshot.managedFolders[index].lastOpenedAt = Date()
        } else {
            workspaceSnapshot.managedFolders.append(ManagedFolder(
                path: path,
                isPinned: false,
                lastOpenedAt: Date()
            ))
        }

        workspaceSnapshot.lastFolderPath = path
        persistWorkspaceSnapshot()
    }

    private func persistWorkspaceSnapshot() {
        workspaceSnapshot.managedFolders = Self.sortedManagedFolders(workspaceSnapshot.managedFolders)
        managedFolders = workspaceSnapshot.managedFolders
        workspaceStore.save(workspaceSnapshot)
    }

    private func folderExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private func select(offset: Int) {
        let visible = filteredItems
        guard !visible.isEmpty else { return }

        if let selectedID, let currentIndex = visible.firstIndex(where: { $0.id == selectedID }) {
            let nextIndex = min(max(currentIndex + offset, 0), visible.count - 1)
            select(visible[nextIndex].id)
        } else {
            select(visible.first?.id)
        }
    }

    private func selectNextItem(
        matching predicate: (DatasetItem) -> Bool,
        noneMessage: String
    ) {
        guard !items.isEmpty else { return }

        let startIndex = selectedID.flatMap { selectedID in
            items.firstIndex { $0.id == selectedID }
        }
        let searchOffsets: Range<Int>

        if startIndex == nil {
            searchOffsets = 0..<items.count
        } else {
            searchOffsets = 1..<items.count
        }

        for offset in searchOffsets {
            let index = ((startIndex ?? 0) + offset) % items.count
            guard predicate(items[index]) else { continue }
            select(items[index].id)
            statusMessage = "Selected \(items[index].filename)."
            return
        }

        statusMessage = noneMessage
    }

    private func scheduleAutosave(for itemID: DatasetItem.ID) {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            self?.saveCaption(for: itemID)
        }
    }

    private func saveCaption(for itemID: DatasetItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        guard items[index].saveState == .dirty else { return }

        items[index].saveState = .saving
        let item = items[index]

        do {
            try captionStore.save(item.caption, for: item)
            items[index].originalCaption = item.caption
            items[index].saveState = .clean
            statusMessage = "Saved \(item.captionURL.lastPathComponent)."
        } catch {
            items[index].saveState = .failed(error.localizedDescription)
            statusMessage = "Could not save \(item.captionURL.lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func batchItems(for scope: BatchCaptionScope) -> [DatasetItem] {
        switch scope {
        case .filtered:
            filteredItems
        case .all:
            items
        }
    }

    private static func sortedManagedFolders(_ folders: [ManagedFolder]) -> [ManagedFolder] {
        let sorted = folders.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }

            return lhs.lastOpenedAt > rhs.lastOpenedAt
        }

        let pinned = sorted.filter(\.isPinned)
        let recent = sorted.filter { !$0.isPinned }.prefix(maximumRecentFolderCount)
        return pinned + recent
    }
}
