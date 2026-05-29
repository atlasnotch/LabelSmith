import Foundation

struct DatasetScanner {
    static let acceptedImageExtensions: Set<String> = ["jpg", "jpeg", "png"]

    var fileManager: FileManager = .default

    func scan(folderURL: URL) throws -> DatasetScanResult {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .isHiddenKey]
        let children = try fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsPackageDescendants]
        )

        let visibleFiles = children.filter { url in
            guard let values = try? url.resourceValues(forKeys: resourceKeys) else { return false }
            return values.isRegularFile == true && values.isHidden != true && !url.lastPathComponent.hasPrefix(".")
        }

        let imageURLs = visibleFiles
            .filter { Self.acceptedImageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { lhs, rhs in
                lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
            }

        let imageBaseNames = Set(imageURLs.map { $0.deletingPathExtension().lastPathComponent.lowercased() })
        let orphanCaptionCount = visibleFiles.filter { url in
            url.pathExtension.lowercased() == "txt"
                && !imageBaseNames.contains(url.deletingPathExtension().lastPathComponent.lowercased())
        }.count

        let items = imageURLs.map { imageURL in
            let captionURL = imageURL.deletingPathExtension().appendingPathExtension("txt")
            let caption = (try? String(contentsOf: captionURL, encoding: .utf8)) ?? ""
            let exists = fileManager.fileExists(atPath: captionURL.path)

            return DatasetItem(
                id: imageURL.path,
                imageURL: imageURL,
                captionURL: captionURL,
                filename: imageURL.lastPathComponent,
                hasExistingCaption: exists,
                caption: caption,
                originalCaption: caption,
                saveState: .clean
            )
        }

        return DatasetScanResult(folderURL: folderURL, items: items, orphanCaptionCount: orphanCaptionCount)
    }
}
