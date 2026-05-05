import SwiftUI

@main
struct PulpApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 760, minHeight: 540)
                .containerBackground(.regularMaterial, for: .window)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") { state.showOpenPanel() }
                    .keyboardShortcut("o")
            }
            CommandGroup(after: .saveItem) {
                Button("Save All…") { state.requestSaveAll() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(state.documents.count < 2)
            }
        }
    }
}
