import SwiftUI

struct DropZone: View {
    @EnvironmentObject private var state: AppState

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
        }
        .buttonStyle(.plain)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                )
        }
    }
}
