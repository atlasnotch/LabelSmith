import XCTest
@testable import LabelSmith

final class DatasetScannerTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testScanLoadsStrictTopLevelOstrisImagesAndCaptions() throws {
        try writeFile("image10.jpg", data: Data())
        try writeFile("image2.PNG", data: Data())
        try writeFile("image2.txt", text: "a small label")
        try writeFile("notes.md", text: "ignore me")
        try writeFile("orphan.txt", text: "no image")
        try writeFile(".hidden.jpg", data: Data())

        let nested = tempDirectory.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data().write(to: nested.appendingPathComponent("nested.jpg"))

        let result = try DatasetScanner().scan(folderURL: tempDirectory)

        XCTAssertEqual(result.items.map(\.filename), ["image2.PNG", "image10.jpg"])
        XCTAssertEqual(result.items[0].caption, "a small label")
        XCTAssertTrue(result.items[0].hasExistingCaption)
        XCTAssertEqual(result.items[1].caption, "")
        XCTAssertFalse(result.items[1].hasExistingCaption)
        XCTAssertEqual(result.orphanCaptionCount, 1)
    }

    func testScanRejectsNonOstrisImageExtensions() throws {
        try writeFile("photo.webp", data: Data())
        try writeFile("photo.gif", data: Data())
        try writeFile("photo.tiff", data: Data())

        let result = try DatasetScanner().scan(folderURL: tempDirectory)

        XCTAssertTrue(result.items.isEmpty)
    }

    func testEmptyCaptionFileCountsAsMissingCaption() throws {
        try writeFile("empty.jpg", data: Data())
        try writeFile("empty.txt", text: "")

        let result = try DatasetScanner().scan(folderURL: tempDirectory)

        XCTAssertEqual(result.items.count, 1)
        XCTAssertTrue(result.items[0].hasExistingCaption)
        XCTAssertTrue(result.items[0].isMissingCaption)
    }

    private func writeFile(_ name: String, text: String) throws {
        try text.write(to: tempDirectory.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private func writeFile(_ name: String, data: Data) throws {
        try data.write(to: tempDirectory.appendingPathComponent(name))
    }
}
