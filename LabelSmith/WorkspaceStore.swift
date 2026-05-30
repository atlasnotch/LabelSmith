import Foundation

struct ManagedFolder: Codable, Equatable, Identifiable {
    let path: String
    var isPinned: Bool
    var lastOpenedAt: Date

    var id: String { path }

    var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    var displayName: String {
        url.lastPathComponent.isEmpty ? path : url.lastPathComponent
    }

    var isAvailable: Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}

struct FolderUIState: Codable, Equatable {
    var selectedItemID: DatasetItem.ID?
    var searchText: String
    var showMissingOnly: Bool
    var reviewedItemIDs: Set<DatasetItem.ID>

    static let empty = FolderUIState(
        selectedItemID: nil,
        searchText: "",
        showMissingOnly: false,
        reviewedItemIDs: []
    )
}

struct WorkspaceSnapshot: Codable, Equatable {
    var lastFolderPath: String?
    var managedFolders: [ManagedFolder]
    var folderStates: [String: FolderUIState]

    static let empty = WorkspaceSnapshot(
        lastFolderPath: nil,
        managedFolders: [],
        folderStates: [:]
    )
}

struct WorkspaceStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "workspaceSnapshot.v1") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> WorkspaceSnapshot {
        guard
            let data = defaults.data(forKey: key),
            let snapshot = try? JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
        else {
            return .empty
        }

        return snapshot
    }

    func save(_ snapshot: WorkspaceSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
