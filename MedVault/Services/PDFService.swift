import Foundation
import PDFKit
import UIKit

enum PDFServiceError: LocalizedError {
    case invalidPDF
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidPDF: return "Не удалось открыть PDF-файл."
        case .noTextFound: return "В PDF не найден доступный для извлечения текст."
        }
    }
}

struct PDFService {
    func extractText(from data: Data) throws -> String {
        guard let document = PDFDocument(data: data) else { throw PDFServiceError.invalidPDF }
        let text = document.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { throw PDFServiceError.noTextFound }
        return text
    }

    func thumbnail(from data: Data, maximumSize: CGSize = CGSize(width: 180, height: 240)) -> Data? {
        guard let document = PDFDocument(data: data), let page = document.page(at: 0) else { return nil }
        let image = page.thumbnail(of: maximumSize, for: .mediaBox)
        return image.jpegData(compressionQuality: 0.75)
    }
}
