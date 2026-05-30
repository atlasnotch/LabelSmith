import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var dataset: DatasetViewModel
    @FocusState private var captionFocused: Bool
    @State private var isBatchEditorPresented = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .environmentObject(dataset)
                .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 420)
        } detail: {
            DetailView(captionFocused: $captionFocused)
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
                    isBatchEditorPresented = true
                } label: {
                    Label("Batch Tools", systemImage: "slider.horizontal.3")
                }
                .disabled(dataset.items.isEmpty)
                .help("Batch Caption Tools")
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dataset.isDropTargeted) { providers in
            handleDrop(providers)
        }
        .sheet(isPresented: $isBatchEditorPresented) {
            BatchCaptionSheet()
                .environmentObject(dataset)
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

private struct SidebarView: View {
    @EnvironmentObject private var dataset: DatasetViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search", text: $dataset.searchText)
                    .textFieldStyle(.plain)

                Toggle(isOn: $dataset.showMissingOnly) {
                    Image(systemName: "exclamationmark.circle")
                }
                .toggleStyle(.button)
                .help("Show Missing Captions")
            }
            .padding(10)

            List(selection: Binding(
                get: { dataset.selectedID },
                set: { dataset.select($0) }
            )) {
                ForEach(dataset.filteredItems) { item in
                    DatasetRow(item: item)
                        .tag(item.id)
                }
            }
            .listStyle(.sidebar)

            VStack(alignment: .leading, spacing: 4) {
                Text(dataset.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(dataset.completionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(dataset.reviewSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ProgressView(value: dataset.reviewProgress)
                    .controlSize(.small)

                if dataset.orphanCaptionCount > 0 {
                    Text("\(dataset.orphanCaptionCount) orphan captions ignored")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.bar)
        }
    }
}

private struct DatasetRow: View {
    let item: DatasetItem

    var body: some View {
        HStack(spacing: 10) {
            ThumbnailView(url: item.imageURL)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.filename)
                    .font(.body)
                    .lineLimit(1)

                Text(item.caption.isEmpty ? "No caption" : item.caption)
                    .font(.caption)
                    .foregroundStyle(item.caption.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                ReviewStateIcon(isReviewed: item.isReviewed)
                SaveStateIcon(state: item.saveState, isMissing: item.isMissingCaption)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DetailView: View {
    @EnvironmentObject private var dataset: DatasetViewModel
    var captionFocused: FocusState<Bool>.Binding

    var body: some View {
        ZStack {
            if let item = dataset.selectedItem {
                VStack(spacing: 0) {
                    ImagePreview(url: item.imageURL)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .windowBackgroundColor))

                    Divider()

                    CaptionEditor(item: item, captionFocused: captionFocused)
                        .environmentObject(dataset)
                        .frame(height: 170)
                }
            } else {
                DropPrompt()
            }

            if dataset.isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, dash: [10, 8]))
                    .padding(18)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct CaptionEditor: View {
    @EnvironmentObject private var dataset: DatasetViewModel
    let item: DatasetItem
    var captionFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.filename)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 6) {
                    Button {
                        dataset.copyPreviousCaptionToSelected()
                    } label: {
                        Label("Copy Previous Caption", systemImage: "doc.on.doc")
                            .labelStyle(.iconOnly)
                    }
                    .help("Copy Previous Caption")

                    Button {
                        dataset.clearSelectedCaption()
                    } label: {
                        Label("Clear Caption", systemImage: "xmark.circle")
                            .labelStyle(.iconOnly)
                    }
                    .help("Clear Caption")

                    Button {
                        dataset.toggleSelectedReviewed()
                    } label: {
                        Label(
                            item.isReviewed ? "Mark Unreviewed" : "Mark Reviewed",
                            systemImage: item.isReviewed ? "checkmark.seal.fill" : "checkmark.seal"
                        )
                        .labelStyle(.iconOnly)
                    }
                    .help(item.isReviewed ? "Mark Unreviewed" : "Mark Reviewed")
                }
                .buttonStyle(.borderless)

                SaveStateLabel(state: item.saveState)
            }

            TextEditor(text: Binding(
                get: { dataset.selectedItem?.caption ?? "" },
                set: { dataset.updateCaption(for: item.id, caption: $0) }
            ))
            .font(.system(.body, design: .monospaced))
            .focused(captionFocused)
            .scrollContentBackground(.hidden)
            .padding(6)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(12)
    }
}

private struct BatchCaptionSheet: View {
    @EnvironmentObject private var dataset: DatasetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var scope: BatchCaptionScope = .filtered
    @State private var operation = BatchCaptionOperation()

    private var preview: BatchCaptionPreview {
        dataset.batchPreview(scope: scope, operation: operation)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Label("Batch Caption Tools", systemImage: "slider.horizontal.3")
                        .font(.title3.weight(.semibold))

                    Spacer()

                    Text("\(preview.changedCount) of \(preview.targetCount) captions")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Picker("Scope", selection: $scope) {
                        ForEach(BatchCaptionScope.allCases) { scope in
                            Text(scope.label).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)

                    Picker("Tool", selection: $operation.kind) {
                        ForEach(BatchCaptionOperationKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity)
                }

                BatchCaptionOperationControls(operation: $operation)
            }
            .padding(18)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Preview")
                        .font(.headline)

                    Spacer()

                    Text(operation.isReady ? "Ready to apply" : "Waiting for input")
                        .font(.caption)
                        .foregroundStyle(operation.isReady ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
                }

                if preview.changes.isEmpty {
                    ContentUnavailableView(
                        "No Caption Changes",
                        systemImage: "checkmark.circle"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(preview.changes) { change in
                        BatchCaptionPreviewRow(change: change)
                    }
                    .listStyle(.inset)
                }
            }
            .padding(18)
            .frame(minHeight: 280)

            Divider()

            HStack {
                Label("Edits are written only when applied.", systemImage: "eye")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Apply") {
                    dataset.applyBatchCaptionChanges(preview.changes)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(preview.changes.isEmpty)
            }
            .padding(18)
        }
        .frame(width: 760, height: 620)
    }
}

private struct BatchCaptionOperationControls: View {
    @Binding var operation: BatchCaptionOperation

    var body: some View {
        Group {
            switch operation.kind {
            case .findReplace:
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        Text("Find")
                            .foregroundStyle(.secondary)
                        TextField("Text to find", text: $operation.findText)
                            .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        Text("Replace")
                            .foregroundStyle(.secondary)
                        TextField("Replacement text", text: $operation.replacementText)
                            .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        Text("")
                        Toggle("Case sensitive", isOn: $operation.isCaseSensitive)
                    }
                }
            case .addRemove:
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        Text("Mode")
                            .foregroundStyle(.secondary)
                        Picker("Mode", selection: $operation.affixMode) {
                            ForEach(BatchCaptionAffixMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    GridRow {
                        Text("Prefix")
                            .foregroundStyle(.secondary)
                        TextField("Text at the start", text: $operation.prefix)
                            .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        Text("Suffix")
                            .foregroundStyle(.secondary)
                        TextField("Text at the end", text: $operation.suffix)
                            .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        Text("Triggers")
                            .foregroundStyle(.secondary)
                        TextField("Comma-separated trigger words", text: $operation.triggerWords)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            case .normalizeTags:
                HStack(spacing: 12) {
                    Toggle("Trim whitespace", isOn: .constant(true))
                        .disabled(true)

                    Toggle("Remove duplicates", isOn: .constant(true))
                        .disabled(true)

                    Toggle("Sort alphabetically", isOn: $operation.sortsTags)

                    Spacer()
                }
            }
        }
        .font(.callout)
    }
}

private struct BatchCaptionPreviewRow: View {
    let change: BatchCaptionPreviewChange

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(change.filename)
                .font(.headline)
                .lineLimit(1)

            HStack(alignment: .top, spacing: 12) {
                CaptionPreviewText(title: "Before", text: change.originalCaption)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 22)
                CaptionPreviewText(title: "After", text: change.newCaption)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct CaptionPreviewText: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(text.isEmpty ? "Empty caption" : text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(text.isEmpty ? .secondary : .primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

private struct DropPrompt: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(.secondary)

            Text("Drop an Ostris image folder")
                .font(.title2)

            Text(".jpg, .jpeg, and .png images with matching .txt captions")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ImagePreview: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(14)
            } else {
                ProgressView()
            }
        }
        .task(id: url) {
            image = NSImage(contentsOf: url)
        }
    }
}

private struct ThumbnailView: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.25))

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: url) {
            image = NSImage(contentsOf: url)
        }
    }
}

private struct ReviewStateIcon: View {
    let isReviewed: Bool

    var body: some View {
        Image(systemName: isReviewed ? "checkmark.seal.fill" : "circle")
            .foregroundStyle(isReviewed ? AnyShapeStyle(.blue) : AnyShapeStyle(.tertiary))
            .frame(width: 18, height: 18)
            .help(isReviewed ? "Reviewed" : "Unreviewed")
    }
}

private struct SaveStateIcon: View {
    let state: DatasetItem.SaveState
    let isMissing: Bool

    var body: some View {
        Group {
            switch state {
            case .clean where isMissing:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
            case .clean:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .dirty:
                Image(systemName: "circle.fill")
                    .foregroundStyle(.blue)
            case .saving:
                ProgressView()
                    .controlSize(.small)
            case .failed:
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(.red)
            }
        }
        .frame(width: 18, height: 18)
    }
}

private struct SaveStateLabel: View {
    let state: DatasetItem.SaveState

    var body: some View {
        switch state {
        case .clean:
            Label("Saved", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
        case .dirty:
            Label("Unsaved", systemImage: "circle.fill")
                .foregroundStyle(.blue)
        case .saving:
            Label("Saving", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
        case .failed(let message):
            Label(message, systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
        }
    }
}
