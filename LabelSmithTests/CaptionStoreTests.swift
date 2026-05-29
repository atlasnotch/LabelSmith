import XCTest
@testable import LabelSmith

final class CaptionStoreTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testSaveCreatesSidecarCaptionFile() throws {
        let imageURL = tempDirectory.appendingPathComponent("sample.jpg")
        let captionURL = tempDirectory.appendingPathComponent("sample.txt")
        try Data().write(to: imageURL)
        let item = DatasetItem(
            id: imageURL.path,
            imageURL: imageURL,
            captionURL: captionURL,
            filename: imageURL.lastPathComponent,
            hasExistingCaption: false,
            caption: "fresh caption",
            originalCaption: "",
            saveState: .dirty
        )

        try CaptionStore().save(item.caption, for: item)

        XCTAssertEqual(try String(contentsOf: captionURL, encoding: .utf8), "fresh caption")
    }

    func testSavePreservesEmptyCaptionFile() throws {
        let imageURL = tempDirectory.appendingPathComponent("sample.png")
        let captionURL = tempDirectory.appendingPathComponent("sample.txt")
        try Data().write(to: imageURL)
        try "old caption".write(to: captionURL, atomically: true, encoding: .utf8)
        let item = DatasetItem(
            id: imageURL.path,
            imageURL: imageURL,
            captionURL: captionURL,
            filename: imageURL.lastPathComponent,
            hasExistingCaption: true,
            caption: "",
            originalCaption: "old caption",
            saveState: .dirty
        )

        try CaptionStore().save(item.caption, for: item)

        XCTAssertEqual(try String(contentsOf: captionURL, encoding: .utf8), "")
        XCTAssertTrue(FileManager.default.fileExists(atPath: captionURL.path))
    }
}
