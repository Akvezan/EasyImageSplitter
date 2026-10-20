import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class SplitterModel {
    struct Photo: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let info: ImageInfo

        var fileName: String { url.lastPathComponent }
        var baseName: String { url.deletingPathExtension().lastPathComponent }

        static func == (lhs: Photo, rhs: Photo) -> Bool { lhs.id == rhs.id }
    }

    struct ExportResult: Equatable {
        let id = UUID()
        let files: [URL]
    }

    private(set) var photos: [Photo] = []
    var selectedID: Photo.ID?
    private(set) var isLoading = false
    private(set) var isSaving = false
    /// Сколько фото уже сохранено в текущем экспорте.
    private(set) var savedCount = 0
    private(set) var lastExport: ExportResult?
    var errorMessage: String?

    /// Сетка общая для всех фото.
    var columns = 3
    var rows = 1

    var selected: Photo? {
        photos.first { $0.id == selectedID } ?? photos.first
    }

    var layout: GridLayout? {
        guard let selected else { return nil }
        return try? GridSplitter.layout(
            width: selected.info.pixelWidth,
            height: selected.info.pixelHeight,
            columns: columns,
            rows: rows
        )
    }

    var maxColumns: Int { min(GridSplitter.allowedRange.upperBound, photos.map(\.info.pixelWidth).min() ?? .max) }
    var maxRows: Int { min(GridSplitter.allowedRange.upperBound, photos.map(\.info.pixelHeight).min() ?? .max) }

    var summary: String {
        guard let selected, let layout else { return "" }
        let count = layout.tiles.count.russianPlural("часть", "части", "частей")
        let tile = "\(Int(layout.tileSize.width)) × \(Int(layout.tileSize.height))"
        let size = "\(selected.info.pixelWidth) × \(selected.info.pixelHeight) px  ·  \(count) по \(tile)"
        guard photos.count > 1, let index = photos.firstIndex(of: selected) else { return size }
        return "Фото \(index + 1) из \(photos.count)  ·  \(size)"
    }

    func chooseImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.message = "Выберите одно или несколько фото"
        present(panel) { [weak self] panel in self?.add(panel.urls) }
    }

    func add(_ urls: [URL]) {
        let newURLs = urls.filter { url in !photos.contains { $0.url == url } }
        guard !newURLs.isEmpty else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            var failed: [String] = []
            var firstAdded: Photo.ID?
            for url in newURLs {
                do {
                    let info = try await Task.detached(priority: .userInitiated) {
                        try ImageLoader.inspect(url)
                    }.value
                    let photo = Photo(url: url, info: info)
                    photos.append(photo)
                    firstAdded = firstAdded ?? photo.id
                } catch {
                    failed.append(url.lastPathComponent)
                }
            }
            if let firstAdded {
                selectedID = firstAdded
                lastExport = nil
            }
            columns = min(columns, maxColumns)
            rows = min(rows, maxRows)
            if !failed.isEmpty {
                errorMessage = "Не удалось открыть как изображение: \(failed.joined(separator: ", "))."
            }
        }
    }

    func remove(_ photo: Photo) {
        guard let index = photos.firstIndex(of: photo) else { return }
        photos.remove(at: index)
        if selectedID == photo.id {
            selectedID = photos.indices.contains(index) ? photos[index].id : photos.last?.id
        }
    }

    func removeSelected() {
        if let selected { remove(selected) }
    }

    func save() {
        guard !photos.isEmpty, layout != nil else { return }
        let parts = (photos.count * columns * rows).russianPlural("часть", "части", "частей")
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Сохранить"
        panel.message = photos.count > 1
            ? "Куда сохранить \(parts) из \(photos.count) фото?"
            : "Куда сохранить \(parts)?"

        let photos = photos, columns = columns, rows = rows
        present(panel) { [weak self] panel in
            guard let folder = panel.url else { return }
            self?.export(photos, columns: columns, rows: rows, to: folder)
        }
    }

    func revealLastExport() {
        guard let lastExport else { return }
        NSWorkspace.shared.activateFileViewerSelecting(lastExport.files)
    }

    private func export(_ photos: [Photo], columns: Int, rows: Int, to folder: URL) {
        isSaving = true
        savedCount = 0
        Task {
            defer { isSaving = false }
            var files: [URL] = []
            var failures: [String] = []
            for photo in photos {
                let url = photo.url, baseName = photo.baseName
                do {
                    let written = try await Task.detached(priority: .userInitiated) {
                        let image = try ImageLoader.loadFull(url)
                        let layout = try GridSplitter.layout(width: image.width, height: image.height, columns: columns, rows: rows)
                        return try TileExporter.export(image, layout: layout, baseName: baseName, to: folder)
                    }.value
                    files += written
                } catch {
                    failures.append("\(photo.fileName): \(error.localizedDescription)")
                }
                savedCount += 1
            }

            if !failures.isEmpty {
                errorMessage = "Не всё удалось сохранить.\n" + failures.joined(separator: "\n")
            }
            guard !files.isEmpty else { return }
            let result = ExportResult(files: files)
            lastExport = result
            try? await Task.sleep(for: .seconds(5))
            if lastExport == result { lastExport = nil }
        }
    }

    private func present(_ panel: NSOpenPanel, completion: @escaping (NSOpenPanel) -> Void) {
        let handle: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK else { return }
            completion(panel)
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }
}

private extension Int {
    func russianPlural(_ one: String, _ few: String, _ many: String) -> String {
        let mod10 = self % 10
        let mod100 = self % 100
        let word: String
        if mod10 == 1 && mod100 != 11 {
            word = one
        } else if (2...4).contains(mod10) && !(12...14).contains(mod100) {
            word = few
        } else {
            word = many
        }
        return "\(self) \(word)"
    }
}
