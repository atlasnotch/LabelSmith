import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum LayoutMetrics {
    static let sidebarMinWidth: CGFloat = 220
    static let sidebarIdealWidth: CGFloat = 300
    static let sidebarMaxWidth: CGFloat = 380
    static let detailMinWidth: CGFloat = 360
    static let batchToolsMinWidth: CGFloat = 280
    static let batchToolsIdealWidth: CGFloat = 340
    static let batchToolsMaxWidth: CGFloat = 420
    static let splitViewDividerWidth: CGFloat = 6
    static let minimumContentHeight: CGFloat = 620

    static func minimumContentWidth(includesBatchTools: Bool) -> CGFloat {
        sidebarMinWidth
            + detailMinWidth
            + (includesBatchTools ? batchToolsMinWidth : 0)
            + (includesBatchTools ? splitViewDividerWidth * 2 : splitViewDividerWidth)
    }
}

struct ContentView: View {
    @EnvironmentObject private var dataset: DatasetViewModel
    @Environment(\.undoManager) private var undoManager
    @FocusState private var captionFocused: Bool
    @State private var isBatchToolsVisible = true

    private var showsBatchToolsPane: Bool {
        isBatchToolsVisible && dataset.selectedItem != nil
    }

    var body: some View {
        ZStack {
            HSplitView {
                SidebarView()
                    .environmentObject(dataset)
                    .frame(
                        minWidth: LayoutMetrics.sidebarMinWidth,
                        idealWidth: LayoutMetrics.sidebarIdealWidth,
                        maxWidth: LayoutMetrics.sidebarMaxWidth
                    )

                DetailView(captionFocused: $captionFocused)
                    .environmentObject(dataset)
                    .frame(minWidth: LayoutMetrics.detailMinWidth)

                if showsBatchToolsPane {
                    BatchCaptionPane()
                        .environmentObject(dataset)
                        .frame(
                            minWidth: LayoutMetrics.batchToolsMinWidth,
                            idealWidth: LayoutMetrics.batchToolsIdealWidth,
                            maxWidth: LayoutMetrics.batchToolsMaxWidth,
                            maxHeight: .infinity
                        )
                }
            }

            if dataset.isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, dash: [10, 8]))
                    .padding(18)
                    .allowsHitTesting(false)
            }
        }
        .frame(
            minWidth: LayoutMetrics.minimumContentWidth(includesBatchTools: showsBatchToolsPane),
            minHeight: LayoutMetrics.minimumContentHeight
        )
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
