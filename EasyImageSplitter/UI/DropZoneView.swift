import SwiftUI

struct DropZoneView: View {
    let isTargeted: Bool
    let isLoading: Bool
    let choose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                .symbolEffect(.bounce, value: isTargeted)

            VStack(spacing: 6) {
                Text("Перетащите фото сюда")
                    .font(.title2.weight(.semibold))
                Text("Можно сразу несколько · JPG, PNG, HEIC, WEBP")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(height: 32)
            } else {
                Button("Выбрать фото", action: choose)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut("o")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.03))
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: [8, 6])
                )
        }
        .scaleEffect(isTargeted ? 1.01 : 1)
    }
}
