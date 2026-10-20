import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Вырезает части из полноразмерного изображения и сохраняет их в PNG без пересжатия и масштабирования.
enum TileExporter {
    enum Error: LocalizedError {
        case cropFailed(Int)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .cropFailed(let number):
                "Не удалось вырезать часть №\(number)."
            case .writeFailed(let name):
                "Не удалось записать файл \(name). Проверьте, что в папку можно сохранять."
            }
        }
    }

    /// Имена частей: «IMG_1234_01.png», «IMG_1234_02.png»… — с ведущими нулями, чтобы сортировались по порядку.
    ///
    /// Если в папке занято хоть одно имя из набора, ко всему набору добавляется индекс
    /// («IMG_1234-2_01.png»…), чтобы части одного фото не смешались с прежними.
    static func fileURLs(
        baseName: String,
        count: Int,
        in folder: URL,
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> [URL] {
        let baseName = baseName.isEmpty ? "photo" : baseName
        let digits = max(2, String(count).count)
        var attempt = 1
        while true {
            let stem = attempt == 1 ? baseName : "\(baseName)-\(attempt)"
            let urls = (1...max(count, 1)).map { number in
                folder.appendingPathComponent("\(stem)_\(String(format: "%0\(digits)d", number)).png")
            }
            if !urls.contains(where: fileExists) {
                return urls
            }
            attempt += 1
        }
    }

    @discardableResult
    static func export(_ image: CGImage, layout: GridLayout, baseName: String, to folder: URL) throws -> [URL] {
        let urls = fileURLs(baseName: baseName, count: layout.tiles.count, in: folder)
        return try zip(layout.tiles, urls).map { tile, url in
            guard let part = image.cropping(to: tile.rect) else {
                throw Error.cropFailed(tile.number)
            }
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
                throw Error.writeFailed(url.lastPathComponent)
            }
            CGImageDestinationAddImage(destination, part, nil)
            guard CGImageDestinationFinalize(destination) else {
                throw Error.writeFailed(url.lastPathComponent)
            }
            return url
        }
    }
}
