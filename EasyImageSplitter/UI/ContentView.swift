import SwiftUI

struct ContentView: View {
    @State private var model = SplitterModel()
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 14) {
            if let photo = model.selected, let layout = model.layout {
                GridPreviewView(image: photo.info.preview, layout: layout)
                    .id(photo.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .padding(.horizontal, 12)
                    .padding(.top, 20)
                    .padding(.bottom, 6)
                    .overlay(alignment: .bottom) {
                        if let export = model.lastExport {
                            ExportToast(count: export.files.count, reveal: model.revealLastExport)
                                .padding(.bottom, 20)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }

                Group {
                    ThumbnailStrip(photos: model.photos, selection: $model.selectedID, remove: model.remove)
                    ControlBar(model: model)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                DropZoneView(isTargeted: isDropTargeted, isLoading: model.isLoading, choose: model.chooseImages)
                    .padding(.top, 12)
                    .transition(.opacity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if !model.photos.isEmpty && isDropTargeted {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(12)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .background(WindowBackground().ignoresSafeArea())
        .dropDestination(for: URL.self) { urls, _ in
            model.add(urls)
            return !urls.isEmpty
        } isTargeted: { isDropTargeted = $0 }
        .onDeleteCommand(perform: model.removeSelected)
        .animation(.smooth(duration: 0.35), value: model.selected?.id)
        .animation(.snappy, value: model.photos.map(\.id))
        .animation(.snappy, value: model.lastExport)
        .animation(.snappy(duration: 0.2), value: isDropTargeted)
        .alert(
            "Что-то пошло не так",
            isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }),
            presenting: model.errorMessage
        ) { _ in
            Button("OK") {}
        } message: { message in
            Text(message)
        }
        .frame(minWidth: 720, minHeight: 560)
    }
}

/// Полупрозрачный фон окна — системное «стекло», сквозь которое просвечивает рабочий стол.
private struct WindowBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private struct ExportToast: View {
    let count: Int
    let reveal: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Сохранено: \(count) PNG")
                .font(.callout.weight(.medium))
            Button("Показать в Finder", action: reveal)
                .buttonStyle(.link)
                .font(.callout)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }
}

#Preview {
    ContentView()
        .frame(width: 900, height: 640)
}
