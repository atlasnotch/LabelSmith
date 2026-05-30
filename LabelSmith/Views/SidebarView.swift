import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var dataset: DatasetViewModel

    var body: some View {
        VStack(spacing: 0) {
            ManagedFoldersView()
                .environmentObject(dataset)

            Divider()

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

private struct ManagedFoldersView: View {
    @EnvironmentObject private var dataset: DatasetViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Folders", systemImage: "folder")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    dataset.presentOpenPanel()
                } label: {
                    Label("Open Folder", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Open Folder")
            }

            if dataset.managedFolders.isEmpty {
                Text("No managed folders")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(dataset.managedFolders) { folder in
                            ManagedFolderRow(
                                folder: folder,
                                isCurrent: dataset.folderURL?.path == folder.path
                            )
                            .environmentObject(dataset)
                        }
                    }
                }
                .frame(maxHeight: 140)
            }
        }
        .padding(10)
    }
}

private struct ManagedFolderRow: View {
    @EnvironmentObject private var dataset: DatasetViewModel
    let folder: ManagedFolder
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 6) {
            Button {
                dataset.openManagedFolder(folder)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: folder.isAvailable ? "folder" : "exclamationmark.triangle")
                        .foregroundStyle(folder.isAvailable ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(folder.displayName)
                            .font(.caption)
                            .foregroundStyle(folder.isAvailable ? .primary : .secondary)
                            .lineLimit(1)

                        Text(folder.url.deletingLastPathComponent().path)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .disabled(!folder.isAvailable)
            .frame(minWidth: 0, maxWidth: .infinity)

            Button {
                dataset.togglePinned(folder)
            } label: {
                Label(folder.isPinned ? "Unpin Folder" : "Pin Folder", systemImage: folder.isPinned ? "pin.fill" : "pin")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help(folder.isPinned ? "Unpin Folder" : "Pin Folder")

            Button {
                dataset.removeManagedFolder(folder)
            } label: {
                Label("Remove Folder", systemImage: "xmark")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("Remove Folder")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(isCurrent ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
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
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                ReviewStateIcon(isReviewed: item.isReviewed)
                SaveStateIcon(state: item.saveState, isMissing: item.isMissingCaption)
            }
        }
        .padding(.vertical, 4)
    }
}
