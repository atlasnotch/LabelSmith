import Foundation

typealias DatasetUndoRegistration = (
    _ actionName: String?,
    _ handler: @escaping @MainActor (DatasetViewModel) -> Void
) -> Void

typealias DatasetCaptionSaveRequest = @MainActor (_ itemID: DatasetItem.ID) -> Void

struct CaptionReplacement {
    let itemID: DatasetItem.ID
    let caption: String
}

@MainActor
final class CaptionEditingModel {
    private let captionStore: CaptionStore
    private var autosaveTask: Task<Void, Never>?

    init(captionStore: CaptionStore) {
        self.captionStore = captionStore
    }

    func cancelAutosave() {
        autosaveTask?.cancel()
        autosaveTask = nil
    }

    func setCaption(
        for itemID: DatasetItem.ID,
        caption: String,
        items: inout [DatasetItem],
        registersUndo: Bool,
        actionName: String? = nil,
        registerUndo: DatasetUndoRegistration,
        saveCaption: @escaping DatasetCaptionSaveRequest
    ) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        let oldCaption = items[index].caption
        guard oldCaption != caption else { return }

        if registersUndo {
            registerUndo(actionName) { target in
                target.setCaption(
                    for: itemID,
                    caption: oldCaption,
                    registersUndo: true,
                    actionName: actionName
                )
            }
        }

        items[index].caption = caption
        items[index].saveState = caption == items[index].originalCaption ? .clean : .dirty
        scheduleAutosave(for: itemID, saveCaption: saveCaption)
    }

    func setReviewed(
        for itemID: DatasetItem.ID,
        isReviewed: Bool,
        items: inout [DatasetItem],
        registersUndo: Bool,
        actionName: String? = nil,
        registerUndo: DatasetUndoRegistration
    ) -> String? {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return nil }
        let oldReviewed = items[index].isReviewed
        guard oldReviewed != isReviewed else { return nil }

        if registersUndo {
            registerUndo(actionName) { target in
                target.setReviewed(
                    for: itemID,
                    isReviewed: oldReviewed,
                    registersUndo: true,
                    actionName: actionName
                )
            }
        }

        items[index].isReviewed = isReviewed
        return isReviewed
            ? "Marked \(items[index].filename) reviewed."
            : "Marked \(items[index].filename) unreviewed."
    }

    func copyPreviousCaptionToSelected(
        selectedID: DatasetItem.ID?,
        filteredItems: [DatasetItem],
        items: inout [DatasetItem],
        registerUndo: DatasetUndoRegistration,
        saveCaption: @escaping DatasetCaptionSaveRequest
    ) -> String? {
        guard let selectedID, let selectedIndex = items.firstIndex(where: { $0.id == selectedID }) else { return nil }
        guard
            let visibleIndex = filteredItems.firstIndex(where: { $0.id == selectedID }),
            visibleIndex > filteredItems.startIndex
        else {
            return "No previous visible caption to copy."
        }

        let previousCaption = filteredItems[filteredItems.index(before: visibleIndex)].caption
        setCaption(
            for: selectedID,
            caption: previousCaption,
            items: &items,
            registersUndo: true,
            actionName: "Copy Previous Caption",
            registerUndo: registerUndo,
            saveCaption: saveCaption
        )
        return "Copied previous caption to \(items[selectedIndex].filename)."
    }

    func clearSelectedCaption(
        selectedID: DatasetItem.ID?,
        items: inout [DatasetItem],
        registerUndo: DatasetUndoRegistration,
        saveCaption: @escaping DatasetCaptionSaveRequest
    ) -> String? {
        guard let selectedID, let index = items.firstIndex(where: { $0.id == selectedID }) else { return nil }
        setCaption(
            for: selectedID,
            caption: "",
            items: &items,
            registersUndo: true,
            actionName: "Clear Caption",
            registerUndo: registerUndo,
            saveCaption: saveCaption
        )
        return "Cleared caption for \(items[index].filename)."
    }

    func flushCaption(for selectedID: DatasetItem.ID?, items: inout [DatasetItem]) -> String? {
        guard let selectedID else { return nil }
        return saveCaption(for: selectedID, items: &items)
    }

    func applyBatchCaptionChanges(
        _ changes: [BatchCaptionPreviewChange],
        items: inout [DatasetItem],
        registerUndo: DatasetUndoRegistration
    ) -> String? {
        guard !changes.isEmpty else { return nil }

        cancelAutosave()
        let replacements = changes.map {
            CaptionReplacement(itemID: $0.itemID, caption: $0.newCaption)
        }
        return applyCaptionReplacements(
            replacements,
            items: &items,
            savesImmediately: true,
            registersUndo: true,
            actionName: "Batch Caption Edits",
            registerUndo: registerUndo,
            saveCaption: { _ in }
        )
    }

    func applyCaptionReplacements(
        _ replacements: [CaptionReplacement],
        items: inout [DatasetItem],
        savesImmediately: Bool,
        registersUndo: Bool,
        actionName: String,
        registerUndo: DatasetUndoRegistration,
        saveCaption: @escaping DatasetCaptionSaveRequest
    ) -> String? {
        let validReplacements = replacements.compactMap { replacement -> CaptionReplacement? in
            guard
                let index = items.firstIndex(where: { $0.id == replacement.itemID }),
                items[index].caption != replacement.caption
            else {
                return nil
            }

            return replacement
        }
        guard !validReplacements.isEmpty else { return nil }

        if registersUndo {
            let inverseReplacements = validReplacements.compactMap { replacement -> CaptionReplacement? in
                guard let index = items.firstIndex(where: { $0.id == replacement.itemID }) else { return nil }
                return CaptionReplacement(itemID: replacement.itemID, caption: items[index].caption)
            }

            registerUndo(actionName) { target in
                target.applyCaptionReplacements(
                    inverseReplacements,
                    savesImmediately: savesImmediately,
                    registersUndo: true,
                    actionName: actionName
                )
            }
        }

        var savedCount = 0
        var changedCount = 0
        var failedCount = 0

        for replacement in validReplacements {
            guard let index = items.firstIndex(where: { $0.id == replacement.itemID }) else { continue }

            items[index].caption = replacement.caption
            items[index].saveState = replacement.caption == items[index].originalCaption ? .clean : .dirty
            changedCount += 1

            if savesImmediately {
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
            } else {
                scheduleAutosave(for: replacement.itemID, saveCaption: saveCaption)
            }
        }

        if savesImmediately {
            return failedCount > 0
                ? "Saved \(savedCount) captions. \(failedCount) failed."
                : "Saved \(savedCount) batch caption edits."
        } else {
            return "Changed \(changedCount) captions."
        }
    }

    func saveCaption(for itemID: DatasetItem.ID, items: inout [DatasetItem]) -> String? {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return nil }
        guard items[index].saveState == .dirty else { return nil }

        items[index].saveState = .saving
        let item = items[index]

        do {
            try captionStore.save(item.caption, for: item)
            items[index].originalCaption = item.caption
            items[index].saveState = .clean
            return "Saved \(item.captionURL.lastPathComponent)."
        } catch {
            items[index].saveState = .failed(error.localizedDescription)
            return "Could not save \(item.captionURL.lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func scheduleAutosave(
        for itemID: DatasetItem.ID,
        saveCaption: @escaping DatasetCaptionSaveRequest
    ) {
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            saveCaption(itemID)
            self?.autosaveTask = nil
        }
    }
}
