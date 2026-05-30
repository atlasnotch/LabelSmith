import SwiftUI

struct ReviewStateIcon: View {
    let isReviewed: Bool

    var body: some View {
        Image(systemName: isReviewed ? "checkmark.seal.fill" : "circle")
            .foregroundStyle(isReviewed ? AnyShapeStyle(.blue) : AnyShapeStyle(.tertiary))
            .frame(width: 18, height: 18)
            .help(isReviewed ? "Reviewed" : "Unreviewed")
    }
}

struct SaveStateIcon: View {
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

struct SaveStateLabel: View {
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
