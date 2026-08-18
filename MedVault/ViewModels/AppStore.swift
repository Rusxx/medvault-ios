import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var documents: [MedicalDocument] = []
    @Published var profile: MedicalProfile = .empty {
        didSet { scheduleProfileSave() }
    }
    @Published var isImporting = false
    @Published var importMessage: String?
    @Published var loadError: String?

    private let storage = StorageService.shared
    private let ocrService = OCRService()
    private let pdfService = PDFService()
    private let parser = MedicalTextParser()
    private var profileSaveTask: Task<Void, Never>?

    init() {
        Task { await loadPersistedData() }
    }

    var completedDocumentCount: Int {
        documents.filter { $0.status == .completed }.count
    }

    var latestDocument: MedicalDocument? {
        documents.sorted { $0.createdAt > $1.createdAt }.first
    }

    func loadPersistedData() async {
        do {
            documents = try await storage.loadDocuments().sorted { $0.createdAt > $1.createdAt }
            profile = try await storage.loadProfile()
        } catch {
            loadError = "Не удалось открыть локальные данные: \(error.localizedDescription)"
        }
    }

    func importDocument(from sourceURL: URL) async {
        guard let fileKind = sourceURL.inferredDocumentFileKind else {
            importMessage = "Поддерживаются изображения и PDF-файлы."
            return
        }

        isImporting = true
        defer { isImporting = false }
        let accessedSecurityScopedResource = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScopedResource { sourceURL.stopAccessingSecurityScopedResource() }
        }

        do {
            let saved = try await storage.saveImportedFile(from: sourceURL, fileKind: fileKind)
            let baseTitle = sourceURL.deletingPathExtension().lastPathComponent.isEmpty
                ? "Медицинский документ"
                : sourceURL.deletingPathExtension().lastPathComponent
            let thumbnail: Data?
            if fileKind == .image {
                thumbnail = UIImage(data: saved.data)?.preparingThumbnail(of: CGSize(width: 180, height: 240))?.jpegData(compressionQuality: 0.75)
            } else {
                thumbnail = pdfService.thumbnail(from: saved.data)
            }

            let document = MedicalDocument(
                title: baseTitle,
                type: inferType(from: baseTitle),
                fileKind: fileKind,
                relativeFilePath: saved.relativePath,
                thumbnailData: thumbnail,
                status: .processing
            )
            documents.insert(document, at: 0)
            await persistDocuments()
            await processDocument(id: document.id)
        } catch {
            importMessage = "Не удалось сохранить документ: \(error.localizedDescription)"
        }
    }

    func retryProcessing(documentID: UUID) async {
        await processDocument(id: documentID)
    }

    func deleteDocument(_ document: MedicalDocument) async {
        do {
            try await storage.deleteFile(at: document.relativeFilePath)
            documents.removeAll { $0.id == document.id }
            await persistDocuments()
        } catch {
            importMessage = "Не удалось удалить оригинал файла: \(error.localizedDescription)"
        }
    }

    func addClearlyLabeledSampleData() async {
        guard !documents.contains(where: { $0.isSampleData }) else { return }
        let sample = MedicalDocument.sampleData
        documents.insert(sample, at: 0)
        await persistDocuments()
    }

    func removeAllSampleData() async {
        documents.removeAll { $0.isSampleData }
        await persistDocuments()
    }

    func clearImportMessage() {
        importMessage = nil
    }

    private func processDocument(id: UUID) async {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[index].status = .processing
        documents[index].errorMessage = nil
        await persistDocuments()

        do {
            let document = documents[index]
            let fileURL = await storage.fileURL(for: document.relativeFilePath)
            let data = try Data(contentsOf: fileURL)
            let text: String
            switch document.fileKind {
            case .image:
                text = try await ocrService.recognizeText(in: data)
            case .pdf:
                text = try pdfService.extractText(from: data)
            }
            let information = parser.parse(text, fallbackTitle: document.title)
            guard let latestIndex = documents.firstIndex(where: { $0.id == id }) else { return }
            documents[latestIndex].extractedText = text
            documents[latestIndex].extractedInfo = information
            if let title = information.documentTitle, !title.isEmpty {
                documents[latestIndex].title = title
            }
            documents[latestIndex].type = inferType(from: text, fallback: documents[latestIndex].type)
            documents[latestIndex].status = .completed
            documents[latestIndex].errorMessage = nil
            await persistDocuments()
        } catch {
            guard let latestIndex = documents.firstIndex(where: { $0.id == id }) else { return }
            documents[latestIndex].status = .failed
            documents[latestIndex].errorMessage = error.localizedDescription
            await persistDocuments()
        }
    }

    private func persistDocuments() async {
        do {
            try await storage.saveDocuments(documents)
        } catch {
            loadError = "Не удалось сохранить изменения: \(error.localizedDescription)"
        }
    }

    private func scheduleProfileSave() {
        profileSaveTask?.cancel()
        let profileSnapshot = profile
        profileSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            do {
                try await storage.saveProfile(profileSnapshot)
            } catch {
                self.loadError = "Не удалось сохранить медкарту: \(error.localizedDescription)"
            }
        }
    }

    private func inferType(from text: String, fallback: MedicalDocumentType = .other) -> MedicalDocumentType {
        let lower = text.lowercased()
        if lower.contains("анализ") || lower.contains("blood") || lower.contains("hemoglobin") || lower.contains("гемоглобин") { return .labResult }
        if lower.contains("рецепт") || lower.contains("prescription") { return .prescription }
        if lower.contains("выпис") || lower.contains("discharge") { return .discharge }
        if lower.contains("рентген") || lower.contains("мрт") || lower.contains("кт") || lower.contains("ultrasound") { return .imaging }
        if lower.contains("заключение") || lower.contains("conclusion") || lower.contains("report") { return .clinicalReport }
        return fallback
    }
}
