import SwiftUI
import PDFKit
import UIKit

struct ProcessingStatusBadge: View {
    let status: DocumentProcessingStatus

    private var tint: Color {
        switch status {
        case .pending: return .secondary
        case .processing: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }

    var body: some View {
        Label(status.rawValue, systemImage: status.symbolName)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct SafetyNotice: View {
    var body: some View {
        Label {
            Text("Информация извлечена автоматически и может содержать ошибки. Проверяйте данные по оригиналу документа. Приложение не является медицинским диагностическим инструментом.")
                .font(.footnote)
        } icon: {
            Image(systemName: "exclamationmark.shield.fill")
        }
        .foregroundStyle(.secondary)
        .padding(12)
        .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct MetricCard: View {
    let count: Int
    let title: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
            Text("\(count)")
                .font(.title.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct DocumentThumbnail: View {
    let document: MedicalDocument

    var body: some View {
        Group {
            if let data = document.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: document.fileKind == .pdf ? "doc.richtext" : "photo")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.tint.opacity(0.12))
            }
        }
        .frame(width: 54, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.quaternary))
    }
}

struct DocumentPreview: View {
    let document: MedicalDocument
    @State private var localURL: URL?

    var body: some View {
        Group {
            if document.isSampleData {
                ContentUnavailableView("Пример данных", systemImage: "doc.text.magnifyingglass", description: Text("У демонстрационной записи нет оригинального файла."))
            } else if let localURL {
                switch document.fileKind {
                case .image:
                    if let image = UIImage(contentsOfFile: localURL.path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        unavailablePreview
                    }
                case .pdf:
                    PDFKitPreview(url: localURL)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 230)
            }
        }
        .frame(minHeight: document.fileKind == .pdf ? 360 : 230)
        .task(id: document.id) {
            guard !document.isSampleData else { return }
            localURL = await StorageService.shared.fileURL(for: document.relativeFilePath)
        }
    }

    private var unavailablePreview: some View {
        ContentUnavailableView("Файл недоступен", systemImage: "exclamationmark.triangle", description: Text("Оригинал документа не найден в локальном хранилище."))
    }
}

struct PDFKitPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(parent: CameraPicker) { self.parent = parent }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }
    }
}
