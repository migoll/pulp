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
        .onDrop(of: [.fileURL, .image], isTargeted: nil) { providers in
            state.handleDrop(providers: providers)
            return true
        }
    }
}
