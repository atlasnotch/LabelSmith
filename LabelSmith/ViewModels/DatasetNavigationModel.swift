import Foundation

struct DatasetSelectionResult {
    let selectedID: DatasetItem.ID?
    let shouldSelect: Bool
}

struct DatasetNavigationResult {
    let selectedID: DatasetItem.ID?
    let statusMessage: String?
    let shouldSelect: Bool
}

struct DatasetNavigationModel {
    func selectedItem(in items: [DatasetItem], selectedID: DatasetItem.ID?) -> DatasetItem? {
        guard let selectedID else { return nil }
        return items.first { $0.id == selectedID }
    }

    func filteredItems(
        from items: [DatasetItem],
        searchText: String,
        showMissingOnly: Bool
    ) -> [DatasetItem] {
        items.filter { item in
            let matchesSearch = searchText.isEmpty
                || item.filename.localizedCaseInsensitiveContains(searchText)
                || item.caption.localizedCaseInsensitiveContains(searchText)
            let matchesMissing = !showMissingOnly || item.isMissingCaption
            return matchesSearch && matchesMissing
        }
    }

    func select(
        offset: Int,
        selectedID: DatasetItem.ID?,
        visibleItems: [DatasetItem]
    ) -> DatasetSelectionResult {
        guard !visibleItems.isEmpty else {
            return DatasetSelectionResult(selectedID: selectedID, shouldSelect: false)
        }

        if let selectedID, let currentIndex = visibleItems.firstIndex(where: { $0.id == selectedID }) {
            let nextIndex = min(max(currentIndex + offset, 0), visibleItems.count - 1)
            return DatasetSelectionResult(selectedID: visibleItems[nextIndex].id, shouldSelect: true)
        }

        return DatasetSelectionResult(selectedID: visibleItems.first?.id, shouldSelect: true)
    }

    func nextMatchingItem(
        selectedID: DatasetItem.ID?,
        items: [DatasetItem],
        matching predicate: (DatasetItem) -> Bool,
        noneMessage: String
    ) -> DatasetNavigationResult {
        guard !items.isEmpty else {
            return DatasetNavigationResult(selectedID: selectedID, statusMessage: nil, shouldSelect: false)
        }

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
            return DatasetNavigationResult(
                selectedID: items[index].id,
                statusMessage: "Selected \(items[index].filename).",
                shouldSelect: true
            )
        }

        return DatasetNavigationResult(
            selectedID: selectedID,
            statusMessage: noneMessage,
            shouldSelect: false
        )
    }

    func batchItems(
        scope: BatchCaptionScope,
        items: [DatasetItem],
        filteredItems: [DatasetItem]
    ) -> [DatasetItem] {
        switch scope {
        case .filtered:
            filteredItems
        case .all:
            items
        }
    }
}
