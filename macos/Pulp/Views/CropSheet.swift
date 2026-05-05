import AppKit
import ImageIO
import SwiftUI

struct CropSheet: View {
    @ObservedObject var doc: ImageDocument
    let onApply: (CGRect) -> Void
    let onCancel: () -> Void

    /// Crop rectangle in normalized image coordinates (0...1, top-left origin).
    @State private var crop = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var aspect: CropAspect = .free
    @State private var fullImage: CGImage?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            cropArea
        }
        .frame(minWidth: 800, idealWidth: 1100, minHeight: 600, idealHeight: 760)
        .task { loadFullImage() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Crop").font(.headline)

            Spacer()

            Menu {
                ForEach(CropAspect.allCases) { option in
                    Button(option.label) { selectAspect(option) }
                }
            } label: {
                Label(aspect.label, systemImage: "aspectratio")
            }
            .menuStyle(.button)
            .controlSize(.small)
            .fixedSize()

            Button("Cancel", role: .cancel, action: onCancel)
                .keyboardShortcut(.cancelAction)

            Button("Apply") {
                onApply(pixelRect(crop))
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var cropArea: some View {
        GeometryReader { geo in
            let imageFrame = computeImageFrame(in: geo.size)

            ZStack {
                Color.black.opacity(0.85)

                if let cg = fullImage {
                    Image(decorative: cg, scale: 1.0, orientation: .up)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: imageFrame.width, height: imageFrame.height)
                        .position(x: imageFrame.midX, y: imageFrame.midY)
                }

                CropOverlay(
                    crop: $crop,
                    aspect: aspect,
                    imageFrame: imageFrame,
                    imagePixelSize: imagePixelSize
                )
            }
        }
    }

    private var imagePixelSize: CGSize {
        if let cg = fullImage {
            return CGSize(width: cg.width, height: cg.height)
        }
        return CGSize(width: doc.image.width, height: doc.image.height)
    }

    private func loadFullImage() {
        guard
            let source = CGImageSourceCreateWithData(doc.sourceBytes as CFData, nil),
            let cg = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return }
        fullImage = cg
    }

    private func selectAspect(_ option: CropAspect) {
        aspect = option
        guard let ratio = option.ratio else { return }
        crop = recenterCropForRatio(crop, ratio: ratio)
    }

    private func recenterCropForRatio(_ rect: CGRect, ratio: CGFloat) -> CGRect {
        let imageRatio = imagePixelSize.width / imagePixelSize.height
        let normalizedRatio = ratio / imageRatio
        let centerX = rect.midX
        let centerY = rect.midY

        var width = rect.width
        var height = width / normalizedRatio
        if height > 1 {
            height = 1
            width = height * normalizedRatio
        }

        return CGRect(
            x: max(0, min(1 - width, centerX - width / 2)),
            y: max(0, min(1 - height, centerY - height / 2)),
            width: width,
            height: height
        )
    }

    private func pixelRect(_ normalized: CGRect) -> CGRect {
        CGRect(
            x: normalized.minX * imagePixelSize.width,
            y: normalized.minY * imagePixelSize.height,
            width: normalized.width * imagePixelSize.width,
            height: normalized.height * imagePixelSize.height
        )
    }

    private func computeImageFrame(in size: CGSize) -> CGRect {
        let inset: CGFloat = 48
        let available = CGSize(
            width: max(0, size.width - inset * 2),
            height: max(0, size.height - inset * 2)
        )
        let imageAspect = imagePixelSize.width / imagePixelSize.height
        let containerAspect = available.width / available.height

        if imageAspect > containerAspect {
            let h = available.width / imageAspect
            return CGRect(x: inset, y: (size.height - h) / 2, width: available.width, height: h)
        } else {
            let w = available.height * imageAspect
            return CGRect(x: (size.width - w) / 2, y: inset, width: w, height: available.height)
        }
    }
}

enum CropAspect: String, CaseIterable, Identifiable {
    case free
    case square
    case landscape16x9
    case portrait9x16
    case landscape4x3
    case portrait3x4
    case landscape3x2
    case portrait2x3

    var id: String { rawValue }

    var label: String {
        switch self {
        case .free:           return "Free"
        case .square:         return "1:1"
        case .landscape16x9:  return "16:9"
        case .portrait9x16:   return "9:16"
        case .landscape4x3:   return "4:3"
        case .portrait3x4:    return "3:4"
        case .landscape3x2:   return "3:2"
        case .portrait2x3:    return "2:3"
        }
    }

    /// Ratio in pixel space: `width / height`. `nil` means no constraint.
    var ratio: CGFloat? {
        switch self {
        case .free:           return nil
        case .square:         return 1
        case .landscape16x9:  return 16.0 / 9.0
        case .portrait9x16:   return 9.0 / 16.0
        case .landscape4x3:   return 4.0 / 3.0
        case .portrait3x4:    return 3.0 / 4.0
        case .landscape3x2:   return 3.0 / 2.0
        case .portrait2x3:    return 2.0 / 3.0
        }
    }
}

// MARK: - Overlay

private struct CropOverlay: View {
    @Binding var crop: CGRect
    let aspect: CropAspect
    let imageFrame: CGRect
    let imagePixelSize: CGSize

    @State private var dragStart: (rect: CGRect, point: CGPoint)?

    var body: some View {
        let displayed = displayRect(crop)

        ZStack(alignment: .topLeading) {
            DimMask(crop: displayed, container: imageFrame)
                .allowsHitTesting(false)

            // Border
            Rectangle()
                .strokeBorder(Color.white.opacity(0.95), lineWidth: 1.5)
                .frame(width: displayed.width, height: displayed.height)
                .position(x: displayed.midX, y: displayed.midY)
                .allowsHitTesting(false)

            // Translation hit area (centered crop body)
            Color.clear
                .contentShape(.rect)
                .frame(width: displayed.width, height: displayed.height)
                .position(x: displayed.midX, y: displayed.midY)
                .gesture(translateGesture)

            // Eight handles
            ForEach(CropHandle.allCases) { handle in
                handleView(handle, displayed: displayed)
            }
        }
    }

    private func handleView(_ handle: CropHandle, displayed: CGRect) -> some View {
        let center = handle.position(in: displayed)
        return Circle()
            .fill(.white)
            .overlay(Circle().stroke(.black.opacity(0.25), lineWidth: 0.5))
            .frame(width: 12, height: 12)
            .position(x: center.x, y: center.y)
            .gesture(handleGesture(handle))
    }

    private var translateGesture: some Gesture {
        DragGesture(coordinateSpace: .local)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = (rect: crop, point: value.startLocation)
                }
                guard let start = dragStart, imageFrame.width > 0, imageFrame.height > 0 else { return }
                let dx = (value.location.x - start.point.x) / imageFrame.width
                let dy = (value.location.y - start.point.y) / imageFrame.height

                var r = start.rect
                r.origin.x = max(0, min(1 - r.width, r.minX + dx))
                r.origin.y = max(0, min(1 - r.height, r.minY + dy))
                crop = r
            }
            .onEnded { _ in dragStart = nil }
    }

    private func handleGesture(_ handle: CropHandle) -> some Gesture {
        DragGesture(coordinateSpace: .local)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = (rect: crop, point: value.startLocation)
                }
                guard let start = dragStart, imageFrame.width > 0, imageFrame.height > 0 else { return }
                let dx = (value.location.x - start.point.x) / imageFrame.width
                let dy = (value.location.y - start.point.y) / imageFrame.height

                var r = start.rect
                handle.apply(dx: dx, dy: dy, to: &r)

                if let ratio = aspect.ratio {
                    r = enforceAspect(r, ratio: ratio, anchor: handle, original: start.rect)
                }
                crop = clamp(r)
            }
            .onEnded { _ in dragStart = nil }
    }

    private func displayRect(_ normalized: CGRect) -> CGRect {
        CGRect(
            x: imageFrame.minX + normalized.minX * imageFrame.width,
            y: imageFrame.minY + normalized.minY * imageFrame.height,
            width: normalized.width * imageFrame.width,
            height: normalized.height * imageFrame.height
        )
    }

    private func clamp(_ rect: CGRect) -> CGRect {
        var r = rect
        r.size.width = max(0.05, min(1, r.size.width))
        r.size.height = max(0.05, min(1, r.size.height))
        r.origin.x = max(0, min(1 - r.size.width, r.origin.x))
        r.origin.y = max(0, min(1 - r.size.height, r.origin.y))
        return r
    }

    private func enforceAspect(
        _ rect: CGRect,
        ratio: CGFloat,
        anchor: CropHandle,
        original: CGRect
    ) -> CGRect {
        let imageRatio = imagePixelSize.width / imagePixelSize.height
        let normalizedRatio = ratio / imageRatio
        var r = rect

        switch anchor {
        case .topCenter, .bottomCenter:
            r.size.width = r.size.height * normalizedRatio
            r.origin.x = original.midX - r.size.width / 2
        default:
            r.size.height = r.size.width / normalizedRatio
        }

        let anchorPoint = anchor.fixedPoint(of: original)
        switch anchor {
        case .topLeft:
            r.origin.x = anchorPoint.x - r.size.width
            r.origin.y = anchorPoint.y - r.size.height
        case .topRight:
            r.origin.x = anchorPoint.x
            r.origin.y = anchorPoint.y - r.size.height
        case .bottomLeft:
            r.origin.x = anchorPoint.x - r.size.width
            r.origin.y = anchorPoint.y
        case .bottomRight:
            r.origin.x = anchorPoint.x
            r.origin.y = anchorPoint.y
        case .topCenter:
            r.origin.y = anchorPoint.y - r.size.height
        case .bottomCenter:
            r.origin.y = anchorPoint.y
        case .leftCenter:
            r.origin.x = anchorPoint.x - r.size.width
            r.origin.y = anchorPoint.y - r.size.height / 2
        case .rightCenter:
            r.origin.x = anchorPoint.x
            r.origin.y = anchorPoint.y - r.size.height / 2
        }
        return r
    }
}

private struct DimMask: View {
    let crop: CGRect
    let container: CGRect

    var body: some View {
        Path { path in
            path.addRect(container)
            path.addRect(crop)
        }
        .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
    }
}

private enum CropHandle: CaseIterable, Identifiable {
    case topLeft, topRight, bottomLeft, bottomRight
    case topCenter, bottomCenter, leftCenter, rightCenter

    var id: Self { self }

    func position(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft:      return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight:     return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft:   return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight:  return CGPoint(x: rect.maxX, y: rect.maxY)
        case .topCenter:    return CGPoint(x: rect.midX, y: rect.minY)
        case .bottomCenter: return CGPoint(x: rect.midX, y: rect.maxY)
        case .leftCenter:   return CGPoint(x: rect.minX, y: rect.midY)
        case .rightCenter:  return CGPoint(x: rect.maxX, y: rect.midY)
        }
    }

    /// The point on the rectangle that should stay fixed while this handle is
    /// dragged.
    func fixedPoint(of rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft:      return CGPoint(x: rect.maxX, y: rect.maxY)
        case .topRight:     return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomLeft:   return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomRight:  return CGPoint(x: rect.minX, y: rect.minY)
        case .topCenter:    return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomCenter: return CGPoint(x: rect.midX, y: rect.minY)
        case .leftCenter:   return CGPoint(x: rect.maxX, y: rect.midY)
        case .rightCenter:  return CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    func apply(dx: CGFloat, dy: CGFloat, to rect: inout CGRect) {
        switch self {
        case .topLeft:
            rect.origin.x += dx
            rect.origin.y += dy
            rect.size.width -= dx
            rect.size.height -= dy
        case .topRight:
            rect.origin.y += dy
            rect.size.width += dx
            rect.size.height -= dy
        case .bottomLeft:
            rect.origin.x += dx
            rect.size.width -= dx
            rect.size.height += dy
        case .bottomRight:
            rect.size.width += dx
            rect.size.height += dy
        case .topCenter:
            rect.origin.y += dy
            rect.size.height -= dy
        case .bottomCenter:
            rect.size.height += dy
        case .leftCenter:
            rect.origin.x += dx
            rect.size.width -= dx
        case .rightCenter:
            rect.size.width += dx
        }
    }
}
