import Foundation

struct DatasetItem: Identifiable, Hashable {
    enum SaveState: Hashable {
        case clean
        case dirty
        case saving
        case failed(String)
    }

    let id: String
    let imageURL: URL
    let captionURL: URL
    let filename: String
    let hasExistingCaption: Bool
    var caption: String
    var originalCaption: String
    var saveState: SaveState

    var isMissingCaption: Bool {
        caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct DatasetScanResult: Equatable {
    let folderURL: URL
    let items: [DatasetItem]
    let orphanCaptionCount: Int
}
