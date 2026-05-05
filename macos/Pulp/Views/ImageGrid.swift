import SwiftUI

struct ImageGrid: View {
    @EnvironmentObject private var state: AppState

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 16)]

    var body: some View {
        VStack(spacing: 16) {
            header

            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(state.documents) { doc in
                        ImageCard(doc: doc)
                    }
                    AddTile()
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(state.documents.count == 1 ? "1 image" : "\(state.documents.count) images")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            Button("Clear") { state.clear() }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)

            if state.documents.count >= 2 {
                Button {
                    state.requestSaveAll()
                } label: {
                    Label("Save all", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }
        }
    }
}

private struct AddTile: View {
    @EnvironmentObject private var state: AppState
    @State private var hovering = false

    var body: some View {
        Button(action: { state.showOpenPanel() }) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .light))
                Text("Add more")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(hovering ? 0.04 : 0))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    Color.secondary.opacity(hovering ? 0.6 : 0.3),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 3])
                )
        }
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}
