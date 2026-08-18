import SwiftUI
import UIKit

struct DocumentDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let documentID: UUID
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingEditor = false
    @State private var copiedText = false

    private var document: MedicalDocument? {
        store.documents.first { $0.id == documentID }
    }

    var body: some View {
        Group {
            if let document {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header(document)

                        sectionTitle("Оригинал")
                        DocumentPreview(document: document)

                        if document.status == .processing {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Распознаём документ…")
                                    .font(.subheadline.weight(.medium))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        if document.status == .failed {
                            failurePanel(document)
                        }

                        if document.status == .completed {
                            SafetyNotice()
                            extractedInformation(document.extractedInfo)
                            linkedRecords(document)
                            recognizedText(document.extractedText)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Документ")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if document.status == .completed {
                            Button {
                                isShowingEditor = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .accessibilityLabel("Исправить извлечённые данные")
                        }
                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("Удалить документ")
                    }
                }
                .sheet(isPresented: $isShowingEditor) {
                    DocumentEditView(document: document)
                        .environmentObject(store)
                }
                .confirmationDialog("Удалить документ?", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
                    Button("Удалить", role: .destructive) {
                        Task {
                            await store.deleteDocument(document)
                            dismiss()
                        }
                    }
                } message: {
                    Text("Будут удалены оригинальный файл и сохранённые извлечённые данные. Это действие нельзя отменить.")
                }
            } else {
                ContentUnavailableView("Документ не найден", systemImage: "doc.questionmark", description: Text("Возможно, он уже был удалён."))
            }
        }
    }

    @ViewBuilder
    private func header(_ document: MedicalDocument) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            if document.isSampleData {
                Label("Пример данных", systemImage: "eye")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            Text(document.title)
                .font(.title2.bold())
            HStack(spacing: 8) {
                Label(document.type.rawValue, systemImage: document.type.symbolName)
                Text("·")
                Text(document.recordDate.formatted(date: .long, time: .omitted))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ProcessingStatusBadge(status: document.status)
                if document.hasManualCorrections {
                    Label("Исправлено вручную", systemImage: "pencil.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func failurePanel(_ document: MedicalDocument) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Не удалось обработать документ", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)
            Text(document.errorMessage ?? "Причина ошибки не определена.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Повторить обработку", systemImage: "arrow.clockwise") {
                Task { await store.retryProcessing(documentID: document.id) }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func extractedInformation(_ information: ExtractedMedicalInfo) -> some View {
        sectionTitle("Извлечённая информация")
        if !information.hasContent {
            Text("Не определено")
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            VStack(spacing: 12) {
                if information.documentDateText != nil || information.doctor != nil || information.facility != nil {
                    InfoCard(title: "Сведения", symbol: "doc.text") {
                        KeyValueRows(rows: [
                            ("Дата", information.documentDateText ?? "Не определено"),
                            ("Врач", information.doctor ?? "Не определено"),
                            ("Учреждение", information.facility ?? "Не определено")
                        ])
                    }
                }

                if !information.labValues.isEmpty {
                    InfoCard(title: "Показатели", symbol: "testtube.2") {
                        VStack(spacing: 10) {
                            ForEach(information.labValues) { item in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(item.name)
                                        .font(.subheadline)
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text([item.value, item.unit].compactMap { $0 }.joined(separator: " "))
                                            .font(.subheadline.weight(.semibold))
                                        if let range = item.referenceRange {
                                            Text("Реф.: \(range)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                if item.id != information.labValues.last?.id { Divider() }
                            }
                        }
                    }
                }

                if !information.medicines.isEmpty {
                    InfoCard(title: "Лекарства", symbol: "pills") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(information.medicines) { medicine in
                                Text(medicine.name)
                                    .font(.subheadline.weight(.semibold))
                                if let dosage = medicine.dosage {
                                    Text(dosage)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !information.explicitClinicalMentions.isEmpty {
                    InfoCard(title: "Явно указано в документе", symbol: "quote.bubble") {
                        ForEach(information.explicitClinicalMentions, id: \.self) { mention in
                            Text(mention)
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func linkedRecords(_ document: MedicalDocument) -> some View {
        let conditions = store.profile.conditions.filter { document.linkedConditionIDsValue.contains($0.id) }
        let medications = store.profile.medications.filter { document.linkedMedicationIDsValue.contains($0.id) }
        if !conditions.isEmpty || !medications.isEmpty {
            InfoCard(title: "Связанные записи", symbol: "link") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(conditions) { condition in
                        Label("Заболевание: \(condition.name)", systemImage: "cross.case.fill")
                            .font(.subheadline)
                    }
                    ForEach(medications) { medication in
                        Label("Лекарство: \(medication.name)", systemImage: "pills.fill")
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recognizedText(_ text: String) -> some View {
        sectionTitle("Распознанный текст")
        VStack(alignment: .leading, spacing: 12) {
            Text(text.isEmpty ? "Не определено" : text)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                UIPasteboard.general.string = text
                copiedText = true
            } label: {
                Label(copiedText ? "Текст скопирован" : "Скопировать текст", systemImage: copiedText ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .disabled(text.isEmpty)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InfoCard<Content: View>: View {
    let title: String
    let symbol: String
    let content: Content

    init(title: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.headline)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct KeyValueRows: View {
    let rows: [(String, String)]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.0)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(row.1)
                        .multilineTextAlignment(.trailing)
                }
                .font(.subheadline)
            }
        }
    }
}
