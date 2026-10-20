import CoreGraphics
import Foundation

/// Одна часть сетки. Координаты — в пикселях исходного изображения, начало в левом верхнем углу.
struct Tile: Identifiable, Equatable {
    /// Номер в карусели TikTok, начиная с 1: слева направо, сверху вниз.
    let number: Int
    let row: Int
    let column: Int
    let rect: CGRect

    var id: Int { number }
}

struct GridLayout: Equatable {
    let columns: Int
    let rows: Int
    /// Размер исходного изображения в пикселях.
    let imageSize: CGSize
    /// Часть изображения, которая попадает в нарезку; всё снаружи обрезается.
    let cropRect: CGRect
    let tileSize: CGSize
    let tiles: [Tile]
}

/// Делит изображение на равные части без масштабирования.
///
/// Если размер не делится на число столбцов (строк) нацело, остаток пикселей
/// обрезается поровну с двух сторон; нечётный пиксель уходит с правого (нижнего) края.
enum GridSplitter {
    static let allowedRange = 1...10

    enum Error: LocalizedError, Equatable {
        case invalidGrid
        case imageTooSmall

        var errorDescription: String? {
            switch self {
            case .invalidGrid: "Можно задать от 1 до 10 столбцов и строк."
            case .imageTooSmall: "Фото слишком маленькое для такой сетки."
            }
        }
    }

    static func layout(width: Int, height: Int, columns: Int, rows: Int) throws -> GridLayout {
        guard allowedRange.contains(columns), allowedRange.contains(rows) else {
            throw Error.invalidGrid
        }
        guard width >= columns, height >= rows else {
            throw Error.imageTooSmall
        }

        let tileWidth = width / columns
        let tileHeight = height / rows
        let originX = (width - tileWidth * columns) / 2
        let originY = (height - tileHeight * rows) / 2

        var tiles: [Tile] = []
        tiles.reserveCapacity(columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let rect = CGRect(
                    x: originX + column * tileWidth,
                    y: originY + row * tileHeight,
                    width: tileWidth,
                    height: tileHeight
                )
                tiles.append(Tile(number: tiles.count + 1, row: row, column: column, rect: rect))
            }
        }

        return GridLayout(
            columns: columns,
            rows: rows,
            imageSize: CGSize(width: width, height: height),
            cropRect: CGRect(x: originX, y: originY, width: tileWidth * columns, height: tileHeight * rows),
            tileSize: CGSize(width: tileWidth, height: tileHeight),
            tiles: tiles
        )
    }
}
