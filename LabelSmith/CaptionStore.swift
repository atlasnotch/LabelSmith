import Foundation

struct CaptionStore {
    func save(_ caption: String, for item: DatasetItem) throws {
        try caption.write(to: item.captionURL, atomically: true, encoding: .utf8)
    }
}
