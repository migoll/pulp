import SwiftUI

struct ImageGrid: View {
    @EnvironmentObject private var state: AppState

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 16)]

    var body: some View {
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

private struct AddTile: View {
    @EnvironmentObject private var state: AppState

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
        }
        .buttonStyle(.plain)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 3])
                )
        }
    }
}
