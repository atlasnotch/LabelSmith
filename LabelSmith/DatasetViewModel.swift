import AppKit
import Foundation
import SwiftUI

@MainActor
final class DatasetViewModel: ObservableObject {
    @Published private(set) var folderURL: URL?
    @Published private(set) var items: [DatasetItem] = []
    @Published var selectedID: DatasetItem.ID?
    @Published var searchText = ""
    @Published var showMissingOnly = false
    @Published private(set) var orphanCaptionCount = 0
    @Published private(set) var statusMessage = "Drop an Ostris image folder to begin."
    @Published var isDropTargeted = false

    private let scanner: DatasetScanner
    private let captionStore: CaptionStore
    private var autosaveTask: Task<Void, Never>?

    init(scanner: DatasetScanner = DatasetScanner(), captionStore: CaptionStore = CaptionStore()) {
        self.scanner = scanner
        self.captionStore = captionStore
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
        flushSelectedCaption()
        autosaveTask?.cancel()

        do {
            let result = try scanner.scan(folderURL: url)
            folderURL = result.folderURL
            items = result.items
            orphanCaptionCount = result.orphanCaptionCount
            selectedID = result.items.first?.id
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

    func flushSelectedCaption() {
        guard let selectedID else { return }
        saveCaption(for: selectedID)
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
}
