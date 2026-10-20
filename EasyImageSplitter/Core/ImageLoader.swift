import CoreGraphics
import Foundation
import ImageIO

struct ImageInfo {
    /// Размер полного изображения в пикселях — уже с учётом поворота по EXIF.
    let pixelWidth: Int
    let pixelHeight: Int
    /// Уменьшенная копия для превью, чтобы не держать в памяти десятки мегапикселей на каждое фото.
    let preview: CGImage
}

/// Читает любые форматы, которые понимает ImageIO: JPG, PNG, HEIC, WEBP, TIFF и т. д.
enum ImageLoader {
    static let previewMaxPixelSize = 2400

    enum Error: LocalizedError {
        case unreadable

        var errorDescription: String? {
            "Не удалось открыть файл как изображение. Подойдут JPG, PNG, HEIC, WEBP и другие форматы фото."
        }
    }

    /// Быстрый разбор: размеры и превью, без декодирования полного изображения.
    static func inspect(_ url: URL) throws -> ImageInfo {
        try withAccess(to: url) {
            let source = try makeSource(url)
            guard let preview = orientedImage(from: source, maxPixelSize: previewMaxPixelSize) else {
                throw Error.unreadable
            }

            let metadata = Metadata(source)
            var width = metadata.width
            var height = metadata.height
            if width == 0 || height == 0 {
                let full = try decodeFull(source)
                (width, height) = (full.width, full.height)
            } else if metadata.isRotated {
                swap(&width, &height)
            }
            return ImageInfo(pixelWidth: width, pixelHeight: height, preview: preview)
        }
    }

    /// Полноразмерное изображение для экспорта, повёрнутое по EXIF.
    static func loadFull(_ url: URL) throws -> CGImage {
        try withAccess(to: url) {
            try decodeFull(makeSource(url))
        }
    }

    private struct Metadata {
        let orientation: UInt32
        let width: Int
        let height: Int

        /// EXIF-ориентации 5–8 меняют ширину и высоту местами.
        var isRotated: Bool { (5...8).contains(orientation) }

        init(_ source: CGImageSource) {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
            orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
            width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
            height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        }
    }

    private static func makeSource(_ url: URL) throws -> CGImageSource {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0 else {
            throw Error.unreadable
        }
        return source
    }

    private static func decodeFull(_ source: CGImageSource) throws -> CGImage {
        let metadata = Metadata(source)
        let image: CGImage?
        if metadata.orientation == 1 || metadata.width == 0 || metadata.height == 0 {
            image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        } else {
            // Фото с камеры часто хранятся «лёжа» с EXIF-ориентацией: разворачиваем при декодировании, не меняя размер.
            image = orientedImage(from: source, maxPixelSize: max(metadata.width, metadata.height))
        }
        guard let image else { throw Error.unreadable }
        return image
    }

    private static func orientedImage(from source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func withAccess<T>(to url: URL, _ body: () throws -> T) rethrows -> T {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        return try body()
    }
}
