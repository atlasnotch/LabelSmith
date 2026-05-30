import XCTest
@testable import LabelSmith

final class BatchCaptionEditTests: XCTestCase {
    func testFindReplaceUpdatesMatchingCaptionsOnly() {
        var operation = BatchCaptionOperation()
        operation.kind = .findReplace
        operation.findText = "dog"
        operation.replacementText = "cat"

        let preview = BatchCaptionEdit.preview(items: [
            item(filename: "one.jpg", caption: "a small dog"),
            item(filename: "two.jpg", caption: "a small bird")
        ], operation: operation)

        XCTAssertEqual(preview.targetCount, 2)
        XCTAssertEqual(preview.changes.map(\.filename), ["one.jpg"])
        XCTAssertEqual(preview.changes[0].newCaption, "a small cat")
    }

    func testAddPrefixSuffixAndTriggerWordsWithoutDuplicatingTags() {
        var operation = BatchCaptionOperation()
        operation.kind = .addRemove
        operation.affixMode = .add
        operation.prefix = "score_9, "
        operation.suffix = ", detailed"
        operation.triggerWords = "best quality, dog"

        let preview = BatchCaptionEdit.preview(items: [
            item(filename: "sample.jpg", caption: "dog, portrait")
        ], operation: operation)

        XCTAssertEqual(preview.changes[0].newCaption, "best quality, score_9, dog, portrait, detailed")
    }

    func testRemovePrefixSuffixAndTriggerWords() {
        var operation = BatchCaptionOperation()
        operation.kind = .addRemove
        operation.affixMode = .remove
        operation.prefix = "score_9, "
        operation.suffix = ", detailed"
        operation.triggerWords = "best quality"

        let preview = BatchCaptionEdit.preview(items: [
            item(filename: "sample.jpg", caption: "score_9, best quality, portrait, detailed")
        ], operation: operation)

        XCTAssertEqual(preview.changes[0].newCaption, "portrait")
    }

    func testNormalizeTagsTrimsAndDeduplicatesWhilePreservingOrder() {
        var operation = BatchCaptionOperation()
        operation.kind = .normalizeTags

        let preview = BatchCaptionEdit.preview(items: [
            item(filename: "sample.jpg", caption: " dog, cat, dog,  bird , CAT ")
        ], operation: operation)

        XCTAssertEqual(preview.changes[0].newCaption, "dog, cat, bird")
    }

    func testNormalizeTagsCanSortTags() {
        var operation = BatchCaptionOperation()
        operation.kind = .normalizeTags
        operation.sortsTags = true

        let preview = BatchCaptionEdit.preview(items: [
            item(filename: "sample.jpg", caption: "zebra, apple, Cat")
        ], operation: operation)

        XCTAssertEqual(preview.changes[0].newCaption, "apple, Cat, zebra")
    }

    func testNormalizeTagsCanKeepDuplicates() {
        var operation = BatchCaptionOperation()
        operation.kind = .normalizeTags
        operation.removesDuplicateTags = false

        let preview = BatchCaptionEdit.preview(items: [
            item(filename: "sample.jpg", caption: "dog, cat, DOG")
        ], operation: operation)

        XCTAssertEqual(preview.changes, [])
    }

    func testNormalizeTagsCanPreserveWhitespace() {
        var operation = BatchCaptionOperation()
        operation.kind = .normalizeTags
        operation.trimsTagWhitespace = false

        let preview = BatchCaptionEdit.preview(items: [
            item(filename: "sample.jpg", caption: " dog,cat ")
        ], operation: operation)

        XCTAssertEqual(preview.changes[0].newCaption, " dog, cat ")
    }

    func testNormalizeTagsIsNotReadyWhenEveryOptionIsDisabled() {
        var operation = BatchCaptionOperation()
        operation.kind = .normalizeTags
        operation.trimsTagWhitespace = false
        operation.removesDuplicateTags = false
        operation.sortsTags = false

        let preview = BatchCaptionEdit.preview(items: [
            item(filename: "sample.jpg", caption: " dog, dog")
        ], operation: operation)

        XCTAssertFalse(operation.isReady)
        XCTAssertEqual(preview.changes, [])
    }

    private func item(filename: String, caption: String) -> DatasetItem {
        let imageURL = URL(fileURLWithPath: "/tmp/\(filename)")
        return DatasetItem(
            id: imageURL.path,
            imageURL: imageURL,
            captionURL: imageURL.deletingPathExtension().appendingPathExtension("txt"),
            filename: filename,
            hasExistingCaption: true,
            caption: caption,
            originalCaption: caption,
            saveState: .clean
        )
    }
}
