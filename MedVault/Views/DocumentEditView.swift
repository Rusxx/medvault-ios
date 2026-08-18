import SwiftUI

struct DocumentEditView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let sourceDocument: MedicalDocument

    @State private var title: String
    @State private var documentType: MedicalDocumentType
    @State private var useClinicalDate: Bool
    @State private var clinicalDate: Date
    @State private var doctor: String
    @State private var facility: String
    @State private var recognizedText: String
    @State private var labValues: [LabValue]
    @State private var selectedConditionIDs: Set<UUID>
    @State private var selectedMedicationIDs: Set<UUID>

    init(document: MedicalDocument) {
        sourceDocument = document
        _title = State(initialValue: document.title)
        _documentType = State(initialValue: document.type)
        _useClinicalDate = State(initialValue: document.clinicalDate != nil)
        _clinicalDate = State(initialValue: document.recordDate)
        _doctor = State(initialValue: document.extractedInfo.doctor ?? "")
        _facility = State(initialValue: document.extractedInfo.facility ?? "")
        _recognizedText = State(initialValue: document.extractedText)
        _labValues = State(initialValue: document.extractedInfo.labValues)
        _selectedConditionIDs = State(initialValue: Set(document.linkedConditionIDsValue))
        _selectedMedicationIDs = State(initialValue: Set(document.linkedMedicationIDsValue))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Основная информация") {
                    TextField("Название", text: $title)
                    Picker("Тип", selection: $documentType) {
                        ForEach(MedicalDocumentType.allCases) { type in
                            Label(type.rawValue, systemImage: type.symbolName).tag(type)
                        }
                    }
                    Toggle("Указать дату документа", isOn: $useClinicalDate)
                    if useClinicalDate {
                        DatePicker("Дата", selection: $clinicalDate, displayedComponents: .date)
                    }
                    TextField("Врач", text: $doctor)
                    TextField("Учреждение", text: $facility)
                }

                Section {
                    if labValues.isEmpty {
                        Text("Нет извлечённых показателей. Добавьте нужные значения вручную.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach($labValues) { $value in
                        LabValueEditor(value: $value)
                    }
                    .onDelete { labValues.remove(atOffsets: $0) }
                    Button("Добавить показатель", systemImage: "plus") {
                        labValues.append(LabValue(name: "", value: "", unit: nil, referenceRange: nil, isManuallyEdited: true))
                    }
                } header: {
                    Text("Показатели анализов")
                } footer: {
                    Text("Изменённые показатели помечаются как исправленные вручную. MedVault хранит введённый текст и не интерпретирует результаты.")
                }

                if !store.profile.conditions.isEmpty {
                    Section("Связать с заболеваниями") {
                        ForEach(store.profile.conditions) { condition in
                            Toggle(condition.name, isOn: selectionBinding(for: condition.id, in: $selectedConditionIDs))
                        }
                    }
                }

                if !store.profile.medications.isEmpty {
                    Section("Связать с лекарствами") {
                        ForEach(store.profile.medications) { medication in
                            Toggle(medication.name, isOn: selectionBinding(for: medication.id, in: $selectedMedicationIDs))
                        }
                    }
                }

                Section {
                    TextEditor(text: $recognizedText)
                        .font(.footnote.monospaced())
                        .frame(minHeight: 180)
                } header: {
                    Text("Распознанный текст")
                } footer: {
                    Text("Редактирование сохраняется только в локальном хранилище приложения и не изменяет оригинальный файл.")
                }
            }
            .navigationTitle("Исправить данные")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveChanges()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func selectionBinding(for id: UUID, in set: Binding<Set<UUID>>) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(id) },
            set: { isSelected in
                if isSelected {
                    set.wrappedValue.insert(id)
                } else {
                    set.wrappedValue.remove(id)
                }
            }
        )
    }

    private func saveChanges() {
        var document = sourceDocument
        var information = document.extractedInfo
        information.documentTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        information.documentDateText = useClinicalDate ? clinicalDate.formatted(date: .numeric, time: .omitted) : nil
        information.doctor = optionalText(doctor)
        information.facility = optionalText(facility)
        information.labValues = labValues.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        document.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        document.type = documentType
        document.clinicalDate = useClinicalDate ? clinicalDate : nil
        document.extractedText = recognizedText
        document.extractedInfo = information
        document.linkedConditionIDs = Array(selectedConditionIDs).sorted { $0.uuidString < $1.uuidString }
        document.linkedMedicationIDs = Array(selectedMedicationIDs).sorted { $0.uuidString < $1.uuidString }

        Task {
            await store.saveEditedDocument(document)
            dismiss()
        }
    }

    private func optionalText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct LabValueEditor: View {
    @Binding var value: LabValue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Название", text: $value.name)
            HStack {
                TextField("Значение", text: $value.value)
                    .keyboardType(.decimalPad)
                TextField("Единица", text: optionalBinding($value.unit))
            }
            TextField("Референсный диапазон", text: optionalBinding($value.referenceRange))
            Toggle("Исправлено вручную", isOn: Binding(
                get: { value.isManuallyEdited ?? false },
                set: { value.isManuallyEdited = $0 }
            ))
            .font(.footnote)
        }
        .padding(.vertical, 6)
    }

    private func optionalBinding(_ value: Binding<String?>) -> Binding<String> {
        Binding(
            get: { value.wrappedValue ?? "" },
            set: { value.wrappedValue = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }
}
