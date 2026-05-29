import SwiftUI

@main
struct LabelSmithApp: App {
    @StateObject private var dataset = DatasetViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataset)
                .frame(minWidth: 980, minHeight: 620)
        }
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

                Button("Save Caption") {
                    dataset.flushSelectedCaption()
                }
                .keyboardShortcut("s")
            }
        }
    }
}
