import SwiftUI

/// Фото с наложенной сеткой: обрезаемые края затемнены, части подписаны номерами в порядке карусели.
struct GridPreviewView: View {
    let image: CGImage
    let layout: GridLayout

    var body: some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    // Превью уменьшено, а координаты сетки — в пикселях полного изображения.
                    gridOverlay(scale: proxy.size.width / layout.imageSize.width)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func gridOverlay(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            CropShade(crop: layout.cropRect.scaled(by: scale))
                .fill(.black.opacity(0.5), style: FillStyle(eoFill: true))

            ZStack(alignment: .topLeading) {
                ForEach(layout.tiles) { tile in
                    let rect = tile.rect.scaled(by: scale)
                    Rectangle()
                        .stroke(.white, lineWidth: 1.5)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
            .compositingGroup()
            .opacity(0.9)
            .shadow(color: .black.opacity(0.35), radius: 1.5)

            ForEach(layout.tiles) { tile in
                let rect = tile.rect.scaled(by: scale)
                NumberBadge(number: tile.number, tileSize: rect.size)
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
        }
    }
}

private struct NumberBadge: View {
    let number: Int
    let tileSize: CGSize

    var body: some View {
        let diameter = min(max(min(tileSize.width, tileSize.height) * 0.2, 20), 46)
        Text("\(number)")
            .font(.system(size: diameter * 0.48, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, number > 9 ? diameter * 0.18 : 0)
            .frame(minWidth: diameter, minHeight: diameter)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
            .environment(\.colorScheme, .dark)
            .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
    }
}

/// Всё изображение минус область нарезки — заливается с правилом even-odd.
private struct CropShade: Shape {
    var crop: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRect(crop)
        return path
    }
}

private extension CGRect {
    func scaled(by scale: CGFloat) -> CGRect {
        CGRect(x: minX * scale, y: minY * scale, width: width * scale, height: height * scale)
    }
}
