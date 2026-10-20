import SwiftUI

/// Плавающая стеклянная панель: имя файла, сетка и кнопка «Сохранить».
struct ControlBar: View {
    @Bindable var model: SplitterModel

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.selected?.fileName ?? "")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(model.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GridStepper(title: "Столбцы", value: $model.columns, range: 1...model.maxColumns)
            GridStepper(title: "Строки", value: $model.rows, range: 1...model.maxRows)

            Button(action: model.chooseImages) {
                if model.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "photo.badge.plus")
                }
            }
            .help("Добавить фото (⌘O)")
            .keyboardShortcut("o")

            Button(action: model.save) {
                if model.isSaving {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        if model.photos.count > 1 {
                            Text("\(model.savedCount) из \(model.photos.count)")
                                .monospacedDigit()
                        }
                    }
                } else {
                    Label(model.photos.count > 1 ? "Сохранить все" : "Сохранить", systemImage: "square.and.arrow.down")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("s")
            .disabled(model.isSaving || model.isLoading)
        }
        .controlSize(.large)
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: 820)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.18), radius: 22, y: 8)
    }
}

private struct GridStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.leading, 10)

            step(by: -1, systemImage: "minus")
            Text("\(value)")
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 22)
                .contentTransition(.numericText(value: Double(value)))
            step(by: 1, systemImage: "plus")
        }
        .padding(4)
        .background(.quaternary.opacity(0.6), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: change(by: 1)
            case .decrement: change(by: -1)
            @unknown default: break
            }
        }
    }

    private func step(by delta: Int, systemImage: String) -> some View {
        Button {
            change(by: delta)
        } label: {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .frame(width: 26, height: 26)
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .disabled(!range.contains(value + delta))
    }

    private func change(by delta: Int) {
        guard range.contains(value + delta) else { return }
        withAnimation(.snappy) { value += delta }
    }
}
