import SwiftUI

struct ImageCard: View {
    @ObservedObject var doc: ImageDocument
    @EnvironmentObject private var state: AppState
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            preview
            footer
        }
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
        .onHover { hovering = $0 }
    }

    private var preview: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let nsImage = doc.thumbnail {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.black.opacity(0.3)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .clipped()
            .blur(radius: doc.isEncoding ? 6 : 0)

            if doc.isEncoding {
                ZStack {
                    Color.black.opacity(0.25)
                    ProgressView()
                        .controlSize(.regular)
                        .tint(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .transition(.opacity)
            }

            if hovering && !doc.isEncoding {
                HStack(spacing: 6) {
                    cardButton(systemImage: "crop") {
                        state.requestCrop(doc)
                    }
                    cardButton(systemImage: "square.and.arrow.down") {
                        state.save(doc)
                    }
                    cardButton(systemImage: "xmark") {
                        state.remove(doc)
                    }
                }
                .padding(8)
                .transition(.opacity)
            }
        }
        .clipShape(.rect(topLeadingRadius: 12, topTrailingRadius: 12))
        .animation(.easeInOut(duration: 0.16), value: doc.isEncoding)
        .animation(.easeInOut(duration: 0.12), value: hovering)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(doc.displayName)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 6) {
                Text(formatBytes(doc.sourceByteCount))
                    .foregroundStyle(.secondary)

                if let encoded = doc.encoded {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(formatBytes(encoded.byteCount))
                    if let delta = savingsLabel(from: doc.sourceByteCount, to: encoded.byteCount) {
                        Text(delta)
                            .foregroundStyle(.green)
                    }
                }
            }
            .font(.system(size: 11))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(.thinMaterial, in: .circle)
        }
        .buttonStyle(.plain)
    }

    private func formatBytes(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }

    private func savingsLabel(from original: Int, to encoded: Int) -> String? {
        guard original > 0 else { return nil }
        let ratio = 1.0 - Double(encoded) / Double(original)
        guard ratio > 0.005 else { return nil }
        return "−\(Int(ratio * 100))%"
    }
}
