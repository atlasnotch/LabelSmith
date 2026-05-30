import SwiftUI

struct DetailView: View {
    @EnvironmentObject private var dataset: DatasetViewModel
    @Binding var isBatchToolsVisible: Bool
    var captionFocused: FocusState<Bool>.Binding

    var body: some View {
        ZStack {
            if let item = dataset.selectedItem {
                HSplitView {
                    VStack(spacing: 0) {
                        ImagePreview(url: item.imageURL)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(nsColor: .windowBackgroundColor))

                        Divider()

                        CaptionEditor(item: item, captionFocused: captionFocused)
                            .environmentObject(dataset)
                            .frame(height: 170)
                    }
                    .frame(minWidth: 460)

                    if isBatchToolsVisible {
                        BatchCaptionPane()
                            .environmentObject(dataset)
                            .frame(minWidth: 340, idealWidth: 380, maxWidth: 460, maxHeight: .infinity)
                    }
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
    @State private var isClearConfirmationPresented = false
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
                        isClearConfirmationPresented = true
                    } label: {
                        Label("Clear Caption", systemImage: "xmark.circle")
                            .labelStyle(.iconOnly)
                    }
                    .help("Clear Caption")
                    .confirmationDialog(
                        "Clear caption?",
                        isPresented: $isClearConfirmationPresented,
                        titleVisibility: .visible
                    ) {
                        Button("Clear Caption", role: .destructive) {
                            dataset.clearSelectedCaption()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will clear the caption for \(item.filename).")
                    }

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
