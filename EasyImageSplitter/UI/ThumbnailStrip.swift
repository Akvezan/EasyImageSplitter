import SwiftUI

/// Лента добавленных фото: клик выбирает фото для превью, крестик при наведении убирает его.
struct ThumbnailStrip: View {
    let photos: [SplitterModel.Photo]
    @Binding var selection: SplitterModel.Photo.ID?
    let remove: (SplitterModel.Photo) -> Void

    var body: some View {
        // Пока миниатюры помещаются — лента по центру, иначе прокручивается.
        ViewThatFits(in: .horizontal) {
            thumbnails
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    thumbnails
                }
                .onChange(of: selection) { _, id in
                    withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
        .frame(maxWidth: 820)
    }

    private var thumbnails: some View {
        HStack(spacing: 10) {
            ForEach(photos) { photo in
                Thumbnail(
                    photo: photo,
                    isSelected: photo.id == (selection ?? photos.first?.id),
                    select: { selection = photo.id },
                    remove: { remove(photo) }
                )
                .id(photo.id)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .padding(8)
    }
}

private struct Thumbnail: View {
    let photo: SplitterModel.Photo
    let isSelected: Bool
    let select: () -> Void
    let remove: () -> Void

    @State private var isHovered = false

    var body: some View {
        Image(decorative: photo.info.preview, scale: 1)
            .resizable()
            .interpolation(.medium)
            .aspectRatio(contentMode: .fill)
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.white.opacity(0.15), lineWidth: isSelected ? 2.5 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if isHovered {
                    Button(action: remove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 5, y: -5)
                    .transition(.opacity)
                    .help("Убрать фото")
                }
            }
            .scaleEffect(isSelected ? 1 : 0.94)
            .shadow(color: .black.opacity(isSelected ? 0.25 : 0.1), radius: isSelected ? 6 : 3, y: 2)
            .contentShape(Rectangle())
            .onTapGesture(perform: select)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
            }
            .animation(.snappy, value: isSelected)
            .help(photo.fileName)
            .accessibilityElement()
            .accessibilityLabel(photo.fileName)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction(named: "Убрать фото", remove)
    }
}
