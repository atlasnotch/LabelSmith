import AppKit
import Foundation

struct FolderOpening {
    @MainActor
    func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.prompt = "Open"
        panel.message = "Choose an Ostris image folder"

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
