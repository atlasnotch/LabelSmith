import Foundation

enum WorkspaceRestoreAction {
    case none
    case load(URL)
    case unavailable(String)
}

struct WorkspaceCoordinator {
    private let workspaceStore: WorkspaceStore
    private var workspaceSnapshot: WorkspaceSnapshot
    private(set) var managedFolders: [ManagedFolder]
    private(set) var isApplyingWorkspaceState = false
    private var didAttemptInitialRestore = false
    private static let maximumRecentFolderCount = 12

    init(workspaceStore: WorkspaceStore) {
        self.workspaceStore = workspaceStore
        let snapshot = workspaceStore.load()
        self.workspaceSnapshot = snapshot
        self.managedFolders = Self.sortedManagedFolders(snapshot.managedFolders)
    }

    mutating func restoreLastOpenedFolderAction() -> WorkspaceRestoreAction {
        guard !didAttemptInitialRestore else { return .none }
        didAttemptInitialRestore = true

        guard let path = workspaceSnapshot.lastFolderPath else { return .none }
        let url = URL(fileURLWithPath: path, isDirectory: true)

        guard folderExists(at: url) else {
            return .unavailable("Last folder unavailable: \(url.lastPathComponent).")
        }

        return .load(url)
    }

    mutating func saveCurrentWorkspaceState(
        folderURL: URL?,
        selectedID: DatasetItem.ID?,
        searchText: String,
        showMissingOnly: Bool,
        items: [DatasetItem]
    ) {
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

    mutating func beginApplyingWorkspaceState(for folderPath: String) -> FolderUIState {
        isApplyingWorkspaceState = true
        return workspaceSnapshot.folderStates[folderPath] ?? .empty
    }

    mutating func finishApplyingWorkspaceState() {
        isApplyingWorkspaceState = false
    }

    mutating func trackOpenedFolder(_ url: URL) {
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

    mutating func togglePinned(_ folder: ManagedFolder) {
        guard let index = workspaceSnapshot.managedFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        workspaceSnapshot.managedFolders[index].isPinned.toggle()
        persistWorkspaceSnapshot()
    }

    mutating func removeManagedFolder(_ folder: ManagedFolder) {
        workspaceSnapshot.managedFolders.removeAll { $0.id == folder.id }
        workspaceSnapshot.folderStates.removeValue(forKey: folder.path)

        if workspaceSnapshot.lastFolderPath == folder.path {
            workspaceSnapshot.lastFolderPath = nil
        }

        persistWorkspaceSnapshot()
    }

    private mutating func persistWorkspaceSnapshot() {
        workspaceSnapshot.managedFolders = Self.sortedManagedFolders(workspaceSnapshot.managedFolders)
        managedFolders = workspaceSnapshot.managedFolders
        workspaceStore.save(workspaceSnapshot)
    }

    private func folderExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
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
