import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var documents: [ImageDocument] = []
    @Published var settings: EncodeSettings = EncodeSettings()
    @Published var saveAllRequest: SaveAllRequest?
    @Published var cropTarget: ImageDocument?

    private var cancellables: Set<AnyCancellable> = []
    private static let supportedTypes: [UTType] = [
        .jpeg, .png, .webP, .tiff, .gif, .bmp, .heic,
        UTType("public.avif") ?? .image,
    ]

    init() {
        $settings
            .removeDuplicates()
            .dropFirst()
            .debounce(for: .milliseconds(180), scheduler: DispatchQueue.main)
            .sink { [weak self] newSettings in
                self?.reencodeAll(with: newSettings)
            }
            .store(in: &cancellables)
    }

    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = Self.supportedTypes
        if panel.runModal() == .OK {
            ingest(urls: panel.urls)
        }
    }

    func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            Task { [weak self] in
                guard let url = await provider.loadURL() else { return }
                self?.ingest(urls: [url])
            }
        }
    }

    func remove(_ doc: ImageDocument) {
        documents.removeAll { $0.id == doc.id }
    }

    func requestCrop(_ doc: ImageDocument) {
        cropTarget = doc
    }

    func cancelCrop() {
        cropTarget = nil
    }

    /// `pixelRect` is in original-image pixel coordinates (top-left origin).
    func applyCrop(pixelRect: CGRect) {
        guard let doc = cropTarget else { return }
        cropTarget = nil
        Task { await doc.applyCrop(pixelRect: pixelRect, settings: settings) }
    }

    func clear() {
        documents.removeAll()
    }

    func save(_ doc: ImageDocument) {
        guard let encoded = doc.encoded else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [settings.format.contentType]
        panel.nameFieldStringValue = "\(doc.displayName).\(settings.format.fileExtension)"
        if panel.runModal() == .OK, let url = panel.url {
            try? encoded.data.write(to: url)
        }
    }

    /// Show the confirmation sheet that asks about folder wrapping. The
    /// actual save runs from [`performSaveAll`] once the user confirms.
    func requestSaveAll() {
        guard documents.count >= 2 else { return }
        saveAllRequest = SaveAllRequest(count: documents.count)
    }

    func cancelSaveAll() {
        saveAllRequest = nil
    }

    /// Run the export. Pass `nil` for `folderName` to write straight into the
    /// chosen directory; pass a non-empty name to create a subfolder.
    func performSaveAll(folderName: String?) {
        saveAllRequest = nil
        guard !documents.isEmpty else { return }

        // Defer until the next runloop so SwiftUI gets a tick to dismiss the
        // confirmation sheet before NSOpenPanel takes over the main thread.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            self?.runSaveAll(folderName: folderName)
        }
    }

    private func runSaveAll(folderName: String?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Save"
        panel.message = "Choose where to save \(documents.count) images."

        guard panel.runModal() == .OK, let parent = panel.url else { return }

        let trimmed = folderName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination: URL
        if let trimmed, !trimmed.isEmpty {
            destination = uniqueFolder(in: parent, named: trimmed)
            try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        } else {
            destination = parent
        }

        for doc in documents {
            guard let encoded = doc.encoded else { continue }
            let filename = "\(doc.displayName).\(settings.format.fileExtension)"
            let url = destination.appendingPathComponent(filename)
            try? encoded.data.write(to: url)
        }

        NSWorkspace.shared.activateFileViewerSelecting([destination])
    }

    private func ingest(urls: [URL]) {
        for url in urls {
            Task { await loadAndAdd(url: url) }
        }
    }

    private func loadAndAdd(url: URL) async {
        let loaded = await Task.detached(priority: .userInitiated) { () -> (Data, PulpImage)? in
            guard let data = try? Data(contentsOf: url),
                  let image = PulpImage.decode(data) else { return nil }
            return (data, image)
        }.value

        guard let (data, image) = loaded else { return }
        let doc = ImageDocument(sourceURL: url, sourceBytes: data, image: image)
        documents.append(doc)
        await doc.encode(with: settings)
    }

    private func reencodeAll(with settings: EncodeSettings) {
        for doc in documents {
            Task { await doc.encode(with: settings) }
        }
    }

    private func uniqueFolder(in parent: URL, named base: String) -> URL {
        var candidate = parent.appendingPathComponent(base, isDirectory: true)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = parent.appendingPathComponent("\(base) \(counter)", isDirectory: true)
            counter += 1
        }
        return candidate
    }
}

struct SaveAllRequest: Identifiable, Equatable {
    let id = UUID()
    let count: Int
}

private extension NSItemProvider {
    func loadURL() async -> URL? {
        await withCheckedContinuation { continuation in
            _ = loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }
}
