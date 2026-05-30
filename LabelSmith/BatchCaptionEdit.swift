import Foundation

enum BatchCaptionScope: String, CaseIterable, Identifiable {
    case filtered
    case all

    var id: Self { self }

    var label: String {
        switch self {
        case .filtered:
            "Filtered"
        case .all:
            "All"
        }
    }
}

enum BatchCaptionOperationKind: String, CaseIterable, Identifiable {
    case findReplace
    case addRemove
    case normalizeTags

    var id: Self { self }

    var label: String {
        switch self {
        case .findReplace:
            "Find/Replace"
        case .addRemove:
            "Add/Remove"
        case .normalizeTags:
            "Normalize Tags"
        }
    }
}

enum BatchCaptionAffixMode: String, CaseIterable, Identifiable {
    case add
    case remove

    var id: Self { self }

    var label: String {
        switch self {
        case .add:
            "Add"
        case .remove:
            "Remove"
        }
    }
}

struct BatchCaptionOperation: Equatable {
    var kind: BatchCaptionOperationKind = .findReplace
    var findText = ""
    var replacementText = ""
    var isCaseSensitive = false
    var affixMode: BatchCaptionAffixMode = .add
    var prefix = ""
    var suffix = ""
    var triggerWords = ""
    var trimsTagWhitespace = true
    var removesDuplicateTags = true
    var sortsTags = false

    var isReady: Bool {
        switch kind {
        case .findReplace:
            !findText.isEmpty
        case .addRemove:
            !prefix.isEmpty || !suffix.isEmpty || !parsedTriggerWords.isEmpty
        case .normalizeTags:
            trimsTagWhitespace || removesDuplicateTags || sortsTags
        }
    }

    var parsedTriggerWords: [String] {
        Self.parseTags(triggerWords)
    }

    func transformedCaption(_ caption: String) -> String {
        guard isReady else { return caption }

        switch kind {
        case .findReplace:
            return caption.replacingOccurrences(
                of: findText,
                with: replacementText,
                options: isCaseSensitive ? [] : [.caseInsensitive]
            )
        case .addRemove:
            return transformAffixes(caption)
        case .normalizeTags:
            return Self.normalizedTags(
                caption,
                trimsWhitespace: trimsTagWhitespace,
                removesDuplicates: removesDuplicateTags,
                sorted: sortsTags
            )
        }
    }

    private func transformAffixes(_ caption: String) -> String {
        var transformed = caption

        switch affixMode {
        case .add:
            if !prefix.isEmpty, !transformed.hasPrefix(prefix) {
                transformed = prefix + transformed
            }

            if !suffix.isEmpty, !transformed.hasSuffix(suffix) {
                transformed += suffix
            }

            let tagsToAdd = parsedTriggerWords
            if !tagsToAdd.isEmpty {
                transformed = Self.addTags(tagsToAdd, to: transformed)
            }
        case .remove:
            if !prefix.isEmpty, transformed.hasPrefix(prefix) {
                transformed.removeFirst(prefix.count)
            }

            if !suffix.isEmpty, transformed.hasSuffix(suffix) {
                transformed.removeLast(suffix.count)
            }

            let tagsToRemove = parsedTriggerWords
            if !tagsToRemove.isEmpty {
                transformed = Self.removeTags(tagsToRemove, from: transformed)
            }
        }

        return transformed
    }

    private static func addTags(_ tagsToAdd: [String], to caption: String) -> String {
        var existingTags = parseTags(caption)
        var seen = Set(existingTags.map { $0.lowercased() })

        for tag in tagsToAdd.reversed() where !seen.contains(tag.lowercased()) {
            existingTags.insert(tag, at: 0)
            seen.insert(tag.lowercased())
        }

        return existingTags.joined(separator: ", ")
    }

    private static func removeTags(_ tagsToRemove: [String], from caption: String) -> String {
        let removals = Set(tagsToRemove.map { $0.lowercased() })
        return parseTags(caption)
            .filter { !removals.contains($0.lowercased()) }
            .joined(separator: ", ")
    }

    private static func normalizedTags(
        _ caption: String,
        trimsWhitespace: Bool,
        removesDuplicates: Bool,
        sorted: Bool
    ) -> String {
        let tags = parseTags(caption, trimsWhitespace: trimsWhitespace)
        var normalized = [String]()

        if removesDuplicates {
            var seen = Set<String>()

            for tag in tags {
                let key = duplicateKey(for: tag)
                guard !seen.contains(key) else { continue }
                normalized.append(tag)
                seen.insert(key)
            }
        } else {
            normalized = tags
        }

        if sorted {
            normalized.sort {
                sortKey(for: $0).localizedCaseInsensitiveCompare(sortKey(for: $1)) == .orderedAscending
            }
        }

        return normalized.joined(separator: ", ")
    }

    private static func parseTags(_ text: String, trimsWhitespace: Bool = true) -> [String] {
        text.split(separator: ",", omittingEmptySubsequences: true)
            .map { tag in
                let rawTag = String(tag)
                return trimsWhitespace
                    ? rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
                    : rawTag
            }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func duplicateKey(for tag: String) -> String {
        tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func sortKey(for tag: String) -> String {
        tag.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct BatchCaptionPreviewChange: Identifiable, Equatable {
    let itemID: DatasetItem.ID
    let filename: String
    let originalCaption: String
    let newCaption: String

    var id: DatasetItem.ID { itemID }
}

struct BatchCaptionPreview {
    let targetCount: Int
    let changes: [BatchCaptionPreviewChange]

    var changedCount: Int {
        changes.count
    }
}

enum BatchCaptionEdit {
    static func preview(items: [DatasetItem], operation: BatchCaptionOperation) -> BatchCaptionPreview {
        let changes = items.compactMap { item -> BatchCaptionPreviewChange? in
            let newCaption = operation.transformedCaption(item.caption)
            guard newCaption != item.caption else { return nil }

            return BatchCaptionPreviewChange(
                itemID: item.id,
                filename: item.filename,
                originalCaption: item.caption,
                newCaption: newCaption
            )
        }

        return BatchCaptionPreview(targetCount: items.count, changes: changes)
    }
}
