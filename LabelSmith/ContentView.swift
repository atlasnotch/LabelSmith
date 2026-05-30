import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var dataset: DatasetViewModel
    @Environment(\.undoManager) private var undoManager
    @FocusState private var captionFocused: Bool
    @State private var isBatchToolsVisible = true

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .environmentObject(dataset)
                .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 420)
        } detail: {
            DetailView(isBatchToolsVisible: $isBatchToolsVisible, captionFocused: $captionFocused)
                .environmentObject(dataset)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    dataset.presentOpenPanel()
                } label: {
                    Label("Open Folder", systemImage: "folder")
                }
                .help("Open Folder")

                Button {
                    dataset.selectPrevious()
                } label: {
                    Label("Previous", systemImage: "chevron.up")
                }
                .help("Previous Image")

                Button {
                    dataset.selectNext()
                } label: {
                    Label("Next", systemImage: "chevron.down")
                }
                .help("Next Image")

                Button {
                    isBatchToolsVisible.toggle()
                } label: {
                    Label(isBatchToolsVisible ? "Hide Batch Tools" : "Show Batch Tools", systemImage: "sidebar.right")
                }
                .disabled(dataset.items.isEmpty)
                .help(isBatchToolsVisible ? "Hide Batch Caption Tools" : "Show Batch Caption Tools")
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dataset.isDropTargeted) { providers in
            handleDrop(providers)
        }
        .task {
            dataset.setUndoManager(undoManager)
            dataset.restoreLastOpenedFolderIfNeeded()
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = item as? URL
            }

            if let url {
                Task { @MainActor in
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                        dataset.loadFolder(url)
                    }
                }
            }
        }

        return true
    }
}
