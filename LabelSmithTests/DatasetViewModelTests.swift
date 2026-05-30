import XCTest
@testable import LabelSmith

@MainActor
final class DatasetViewModelTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testMarkReviewedAndSelectNextUnreviewed() throws {
        try writeImage("a.jpg", caption: "first")
        try writeImage("b.jpg", caption: "second")
        try writeImage("c.jpg", caption: "third")

        let dataset = DatasetViewModel()
        dataset.loadFolder(tempDirectory)

        XCTAssertEqual(dataset.reviewSummary, "0 of 3 reviewed")

        dataset.markSelectedReviewed()
        dataset.selectNextUnreviewed()

        XCTAssertEqual(dataset.selectedItem?.filename, "b.jpg")

        dataset.markSelectedReviewed()

        XCTAssertEqual(dataset.reviewSummary, "2 of 3 reviewed")
    }

    func testSelectNextMissingCaptionSkipsReviewedState() throws {
        try writeImage("a.jpg", caption: "first")
        try writeImage("b.jpg", caption: "")
        try writeImage("c.jpg", caption: "")

        let dataset = DatasetViewModel()
        dataset.loadFolder(tempDirectory)
        dataset.markSelectedReviewed()
        dataset.selectNextMissingCaption()

        XCTAssertEqual(dataset.selectedItem?.filename, "b.jpg")
    }

    func testCopyPreviousVisibleCaptionAndClearSelectedCaption() throws {
        try writeImage("a.jpg", caption: "first")
        try writeImage("b.jpg", caption: "second")

        let dataset = DatasetViewModel()
        dataset.loadFolder(tempDirectory)
        dataset.select(dataset.items[1].id)

        dataset.copyPreviousCaptionToSelected()

        XCTAssertEqual(dataset.selectedItem?.caption, "first")
        XCTAssertEqual(dataset.selectedItem?.saveState, .dirty)

        dataset.clearSelectedCaption()

        XCTAssertEqual(dataset.selectedItem?.caption, "")
    }

    private func writeImage(_ name: String, caption: String) throws {
        let imageURL = tempDirectory.appendingPathComponent(name)
        try Data().write(to: imageURL)
        try caption.write(
            to: imageURL.deletingPathExtension().appendingPathExtension("txt"),
            atomically: true,
            encoding: .utf8
        )
    }
}
