import Foundation
import UIKit
import SwiftUI

/// Generates a shareable PDF in the app's temporary directory. It performs no network request.
struct HistoryPDFExportService {
    enum ExportError: LocalizedError {
        case emptyHistory

        var errorDescription: String? {
            switch self {
            case .emptyHistory: return "В выбранном периоде нет записей для экспорта."
            }
        }
    }

    func export(events: [MedicalTimelineEvent], filter: MedicalHistoryFilter, profile: MedicalProfile) throws -> URL {
        guard !events.isEmpty else { throw ExportError.emptyHistory }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MedVault-История-\(UUID().uuidString).pdf")
        let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 at 72 points per inch.
        let margins = UIEdgeInsets(top: 48, left: 44, bottom: 48, right: 44)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        try renderer.writePDF(to: outputURL) { context in
            var cursorY: CGFloat = 0
            var pageNumber = 0

            func beginPage() {
                context.beginPage()
                pageNumber += 1
                cursorY = margins.top
                let footer = "MedVault · локальный экспорт · стр. \(pageNumber)"
                footer.draw(
                    in: CGRect(x: margins.left, y: pageBounds.height - margins.bottom + 14, width: pageBounds.width - margins.left - margins.right, height: 16),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.secondaryLabel]
                )
            }

            func drawText(_ text: String, font: UIFont, color: UIColor = .label, spacingAfter: CGFloat = 8) {
                let rect = CGRect(x: margins.left, y: cursorY, width: pageBounds.width - margins.left - margins.right, height: 300)
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let height = (text as NSString).boundingRect(
                    with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                ).height.rounded(.up)
                if cursorY + height + spacingAfter > pageBounds.height - margins.bottom {
                    beginPage()
                }
                (text as NSString).draw(in: CGRect(x: margins.left, y: cursorY, width: rect.width, height: height + 4), withAttributes: attributes)
                cursorY += height + spacingAfter
            }

            beginPage()
            drawText("MedVault — медицинская история", font: .boldSystemFont(ofSize: 20), spacingAfter: 12)
            let patientName = profile.personalInfo.name.trimmingCharacters(in: .whitespacesAndNewlines)
            drawText("Пациент: \(patientName.isEmpty ? "Не указано" : patientName)", font: .systemFont(ofSize: 11), color: .secondaryLabel, spacingAfter: 3)
            drawText("Период: \(periodDescription(for: filter))", font: .systemFont(ofSize: 11), color: .secondaryLabel, spacingAfter: 14)
            drawText("В документ включены сохранённые события. Это не медицинское заключение и не диагностический отчёт.", font: .italicSystemFont(ofSize: 9), color: .secondaryLabel, spacingAfter: 16)

            for event in events.sorted(by: { $0.date > $1.date }) {
                drawText(event.date.formatted(date: .long, time: .omitted), font: .boldSystemFont(ofSize: 10), color: .systemTeal, spacingAfter: 2)
                drawText("\(event.kind.title): \(event.title)", font: .boldSystemFont(ofSize: 12), spacingAfter: 2)
                drawText(event.subtitle, font: .systemFont(ofSize: 10), color: .secondaryLabel, spacingAfter: 12)
            }
        }

        return outputURL
    }

    private func periodDescription(for filter: MedicalHistoryFilter) -> String {
        if filter.preset == .custom {
            return "\(filter.customStart.formatted(date: .numeric, time: .omitted)) — \(filter.customEnd.formatted(date: .numeric, time: .omitted))"
        }
        return filter.preset.rawValue
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
