import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            SettingsBar(settings: $state.settings)

            Group {
                if state.documents.isEmpty {
                    DropZone()
                } else {
                    ImageGrid()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .contentShape(.rect)
        .onTapGesture { resignFocus() }
        .onAppear {
            // macOS auto-promotes the first text field to first responder when
            // the window opens. Push it back so we don't start with the quality
            // field selected.
            DispatchQueue.main.async { resignFocus() }
        }
        .onDrop(of: [.fileURL, .image], isTargeted: nil) { providers in
            state.handleDrop(providers: providers)
            return true
        }
        .sheet(item: $state.saveAllRequest) { request in
            SaveAllSheet(
                count: request.count,
                onContinue: { folderName in state.performSaveAll(folderName: folderName) },
                onCancel: { state.cancelSaveAll() }
            )
        }
    }

    private func resignFocus() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }
}
