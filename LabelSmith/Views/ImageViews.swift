import AppKit
import SwiftUI

extension View {
    func imageFileDragSource(_ url: URL) -> some View {
        contentShape(Rectangle())
            .onDrag {
                let provider = NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url as NSURL)
                provider.suggestedName = url.lastPathComponent
                return provider
            }
    }
}

struct ImagePreview: View {
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
        .imageFileDragSource(url)
    }
}

struct ThumbnailView: View {
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
