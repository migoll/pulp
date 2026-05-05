import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var documents: [ImageDocument] = []
    @Published var settings: EncodeSettings = EncodeSettings()

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

    func saveAll() {
        guard !documents.isEmpty else { return }
        let folderName = "Pulp Export"

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export"
        panel.message = "Choose where to save \(documents.count) images. A new folder \"\(folderName)\" will be created."

        guard panel.runModal() == .OK, let parent = panel.url else { return }

        let destination = uniqueFolder(in: parent, named: folderName)
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

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

private extension NSItemProvider {
    func loadURL() async -> URL? {
        await withCheckedContinuation { continuation in
            _ = loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }
}
