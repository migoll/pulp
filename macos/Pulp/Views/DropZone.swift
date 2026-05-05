import SwiftUI

struct DropZone: View {
    @EnvironmentObject private var state: AppState
    @State private var hovering = false

    var body: some View {
        Button(action: { state.showOpenPanel() }) {
            VStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Drag & drop images here, or click to select")
                    .font(.system(size: 15))
                    .foregroundStyle(.primary.opacity(0.85))
                Text("Supports JPEG, PNG, WebP, AVIF, TIFF, GIF, BMP, HEIC")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(hovering ? 0.04 : 0))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    Color.secondary.opacity(hovering ? 0.7 : 0.4),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                )
        }
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}
