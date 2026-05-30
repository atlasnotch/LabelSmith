import SwiftUI

@main
struct LabelSmithApp: App {
    @StateObject private var dataset = DatasetViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataset)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder...") {
                    dataset.presentOpenPanel()
                }
                .keyboardShortcut("o")
            }

            CommandMenu("Dataset") {
                Button("Previous Image") {
                    dataset.selectPrevious()
                }
                .keyboardShortcut(.upArrow, modifiers: [])

                Button("Next Image") {
                    dataset.selectNext()
                }
                .keyboardShortcut(.downArrow, modifiers: [])

                Divider()

                Button("Next Missing Caption") {
                    dataset.selectNextMissingCaption()
                }
                .keyboardShortcut("m", modifiers: [.command, .option])

                Button("Next Unreviewed Image") {
                    dataset.selectNextUnreviewed()
                }
                .keyboardShortcut("u", modifiers: [.command, .option])

                Button("Mark Reviewed") {
                    dataset.markSelectedReviewed()
                }
                .keyboardShortcut("r", modifiers: [.command, .option])

                Button("Mark Unreviewed") {
                    dataset.markSelectedReviewed(false)
                }

                Divider()

                Button("Copy Previous Caption") {
                    dataset.copyPreviousCaptionToSelected()
                }
                .keyboardShortcut("c", modifiers: [.command, .option])

                Button("Clear Caption") {
                    dataset.clearSelectedCaption()
                }
                .keyboardShortcut(.delete, modifiers: [.command, .option])

                Divider()

                Button("Save Caption") {
                    dataset.flushSelectedCaption()
                }
                .keyboardShortcut("s")
            }
        }
    }
}
