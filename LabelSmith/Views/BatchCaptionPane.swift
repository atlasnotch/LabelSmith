import SwiftUI

struct BatchCaptionPane: View {
    @EnvironmentObject private var dataset: DatasetViewModel
    @State private var scope: BatchCaptionScope = .filtered
    @State private var operation = BatchCaptionOperation()

    private var preview: BatchCaptionPreview {
        dataset.batchPreview(scope: scope, operation: operation)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Batch Tools", systemImage: "slider.horizontal.3")
                    .font(.headline)

                Text("Preview edits before applying them to captions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scope")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker("Scope", selection: $scope) {
                            ForEach(BatchCaptionScope.allCases) { scope in
                                Text(scope.label).tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tool")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker("Tool", selection: $operation.kind) {
                            ForEach(BatchCaptionOperationKind.allCases) { kind in
                                Text(kind.label).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    BatchCaptionOperationControls(operation: $operation)

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Preview")
                                .font(.headline)

                            Spacer()

                            Text(operation.isReady ? "Ready" : "Needs input")
                                .font(.caption)
                                .foregroundStyle(operation.isReady ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
                        }

                        if preview.changes.isEmpty {
                            ContentUnavailableView(
                                "No Caption Changes",
                                systemImage: "checkmark.circle"
                            )
                            .frame(maxWidth: .infinity, minHeight: 180)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(preview.changes) { change in
                                    BatchCaptionPreviewRow(change: change)

                                    if change.id != preview.changes.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(14)
            }

            Divider()

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(preview.changedCount) of \(preview.targetCount)")
                        .font(.caption)
                        .foregroundStyle(.primary)

                    Text("captions will change")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Apply") {
                    dataset.applyBatchCaptionChanges(preview.changes)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(preview.changes.isEmpty)
            }
            .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .leading) {
            Divider()
        }
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
                    Toggle("Trim whitespace", isOn: $operation.trimsTagWhitespace)

                    Toggle("Remove duplicates", isOn: $operation.removesDuplicateTags)

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
                .font(.callout.weight(.semibold))
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 8) {
                CaptionPreviewText(title: "Before", text: change.originalCaption)
                CaptionPreviewText(title: "After", text: change.newCaption)
            }
        }
        .padding(.vertical, 10)
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
