import SwiftUI

struct MedicalCardView: View {
    @EnvironmentObject private var store: AppStore
    @State private var activeEditor: EditorKind?
    @State private var allergyDraft = Allergy(allergen: "")
    @State private var conditionDraft = MedicalCondition(name: "")
    @State private var medicationDraft = Medication(name: "")
    @State private var procedureDraft = MedicalProcedure(name: "")

    var body: some View {
        Form {
            Section("Личные данные") {
                TextField("Имя", text: personalName)
                    .textContentType(.name)
                TextField("Дата рождения", text: dateOfBirth)
                    .textContentType(.birthday)
                TextField("Группа крови", text: bloodType)
            }

            Section {
                ForEach(store.profile.allergies) { allergy in
                    Button { edit(allergy) } label: {
                        MedicalListRow(title: allergy.allergen, details: [allergy.reaction, allergy.note])
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in store.profile.allergies.remove(atOffsets: offsets) }
                Button("Добавить аллергию", systemImage: "plus") {
                    allergyDraft = Allergy(allergen: "")
                    activeEditor = .allergy
                }
            } header: {
                Label("Аллергии", systemImage: "allergens")
            }

            Section {
                ForEach(store.profile.conditions) { condition in
                    Button { edit(condition) } label: {
                        ConditionRow(condition: condition, documentCount: store.linkedDocuments(for: condition).count)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in store.profile.conditions.remove(atOffsets: offsets) }
                Button("Добавить заболевание", systemImage: "plus") {
                    conditionDraft = MedicalCondition(name: "")
                    activeEditor = .condition
                }
            } header: {
                Label("Заболевания", systemImage: "heart.text.square")
            } footer: {
                Text("Для заболевания указываются дата, статус и заметка. Связанные документы выбираются на экране редактирования документа.")
            }

            Section {
                ForEach(store.profile.medications) { medication in
                    Button { edit(medication) } label: {
                        MedicationRow(medication: medication, documentCount: store.linkedDocuments(for: medication).count)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in store.profile.medications.remove(atOffsets: offsets) }
                Button("Добавить лекарство", systemImage: "plus") {
                    medicationDraft = Medication(name: "")
                    activeEditor = .medication
                }
            } header: {
                Label("Лекарства", systemImage: "pills")
            } footer: {
                Text("MedVault хранит записи о сроках приёма; он не напоминает о приёме и не даёт рекомендаций по лекарствам.")
            }

            Section {
                ForEach(store.profile.procedures) { procedure in
                    Button { edit(procedure) } label: {
                        MedicalListRow(title: procedure.name, details: [procedure.year.isEmpty ? nil : "Год: \(procedure.year)", procedure.comment])
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in store.profile.procedures.remove(atOffsets: offsets) }
                Button("Добавить операцию", systemImage: "plus") {
                    procedureDraft = MedicalProcedure(name: "")
                    activeEditor = .procedure
                }
            } header: {
                Label("Операции", systemImage: "cross.case")
            }
        }
        .navigationTitle("Медкарта")
        .sheet(item: $activeEditor) { editor in
            switch editor {
            case .allergy:
                AllergyEditor(initial: allergyDraft) { upsert($0) }
            case .condition:
                ConditionEditor(initial: conditionDraft) { upsert($0) }
            case .medication:
                MedicationEditor(initial: medicationDraft) { upsert($0) }
            case .procedure:
                ProcedureEditor(initial: procedureDraft) { upsert($0) }
            }
        }
    }

    private var personalName: Binding<String> {
        Binding(get: { store.profile.personalInfo.name }, set: { store.profile.personalInfo.name = $0 })
    }
    private var dateOfBirth: Binding<String> {
        Binding(get: { store.profile.personalInfo.dateOfBirth }, set: { store.profile.personalInfo.dateOfBirth = $0 })
    }
    private var bloodType: Binding<String> {
        Binding(get: { store.profile.personalInfo.bloodType }, set: { store.profile.personalInfo.bloodType = $0 })
    }

    private func edit(_ item: Allergy) { allergyDraft = item; activeEditor = .allergy }
    private func edit(_ item: MedicalCondition) { conditionDraft = item; activeEditor = .condition }
    private func edit(_ item: Medication) { medicationDraft = item; activeEditor = .medication }
    private func edit(_ item: MedicalProcedure) { procedureDraft = item; activeEditor = .procedure }

    private func upsert(_ item: Allergy) {
        if let index = store.profile.allergies.firstIndex(where: { $0.id == item.id }) { store.profile.allergies[index] = item }
        else { store.profile.allergies.append(item) }
    }
    private func upsert(_ item: MedicalCondition) {
        if let index = store.profile.conditions.firstIndex(where: { $0.id == item.id }) { store.profile.conditions[index] = item }
        else { store.profile.conditions.append(item) }
    }
    private func upsert(_ item: Medication) {
        if let index = store.profile.medications.firstIndex(where: { $0.id == item.id }) { store.profile.medications[index] = item }
        else { store.profile.medications.append(item) }
    }
    private func upsert(_ item: MedicalProcedure) {
        if let index = store.profile.procedures.firstIndex(where: { $0.id == item.id }) { store.profile.procedures[index] = item }
        else { store.profile.procedures.append(item) }
    }

    private enum EditorKind: String, Identifiable {
        case allergy, condition, medication, procedure
        var id: String { rawValue }
    }
}

private struct MedicalListRow: View {
    let title: String
    let details: [String?]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.isEmpty ? "Не определено" : title)
                .foregroundStyle(.primary)
            let visibleDetails = details.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if !visibleDetails.isEmpty {
                Text(visibleDetails.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct ConditionRow: View {
    let condition: MedicalCondition
    let documentCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(condition.name)
                    .foregroundStyle(.primary)
                Spacer()
                Label(condition.currentStatus.rawValue, systemImage: condition.currentStatus.symbolName)
                    .font(.caption)
                    .foregroundStyle(condition.currentStatus == .active ? .green : .secondary)
            }
            let dateText = condition.diagnosedAt?.formatted(date: .abbreviated, time: .omitted) ?? (condition.year.isEmpty ? nil : condition.year)
            let details = [dateText.map { "С: \($0)" }, documentCount > 0 ? "Документов: \(documentCount)" : nil, condition.note.isEmpty ? nil : condition.note]
            let visible = details.compactMap { $0 }
            if !visible.isEmpty {
                Text(visible.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct MedicationRow: View {
    let medication: Medication
    let documentCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(medication.name)
                    .foregroundStyle(.primary)
                Spacer()
                Text(medication.isActive ? "Активно" : "Завершено")
                    .font(.caption)
                    .foregroundStyle(medication.isActive ? .green : .secondary)
            }
            let dates = [
                medication.startedAt.map { "С: \($0.formatted(date: .abbreviated, time: .omitted))" },
                medication.endedAt.map { "По: \($0.formatted(date: .abbreviated, time: .omitted))" }
            ].compactMap { $0 }.joined(separator: " · ")
            let details = [medication.dosage, medication.frequency, dates.isEmpty ? nil : dates, documentCount > 0 ? "Документов: \(documentCount)" : nil]
            let visible = details.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if !visible.isEmpty {
                Text(visible.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct AllergyEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: Allergy
    let onSave: (Allergy) -> Void

    init(initial: Allergy, onSave: @escaping (Allergy) -> Void) {
        _item = State(initialValue: initial)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Аллерген", text: $item.allergen)
                TextField("Реакция", text: $item.reaction)
                TextField("Заметка", text: $item.note, axis: .vertical)
            }
            .navigationTitle("Аллергия")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { onSave(item); dismiss() }.disabled(item.allergen.trimmingCharacters(in: .whitespaces).isEmpty) }
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            }
        }
    }
}

private struct ConditionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: MedicalCondition
    @State private var hasDiagnosedDate: Bool
    @State private var hasResolvedDate: Bool
    @State private var diagnosedDate: Date
    @State private var resolvedDate: Date

    let onSave: (MedicalCondition) -> Void

    init(initial: MedicalCondition, onSave: @escaping (MedicalCondition) -> Void) {
        _item = State(initialValue: initial)
        _hasDiagnosedDate = State(initialValue: initial.diagnosedAt != nil)
        _hasResolvedDate = State(initialValue: initial.resolvedAt != nil)
        _diagnosedDate = State(initialValue: initial.diagnosedAt ?? .now)
        _resolvedDate = State(initialValue: initial.resolvedAt ?? .now)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Название", text: $item.name)
                Picker("Статус", selection: $item.status) {
                    Text("Активное").tag(ConditionStatus?.some(.active))
                    Text("Завершено").tag(ConditionStatus?.some(.resolved))
                    Text("Неактивное").tag(ConditionStatus?.some(.inactive))
                }
                Toggle("Указать дату начала", isOn: $hasDiagnosedDate)
                if hasDiagnosedDate {
                    DatePicker("Дата начала", selection: $diagnosedDate, displayedComponents: .date)
                }
                Toggle("Указать дату завершения", isOn: $hasResolvedDate)
                if hasResolvedDate {
                    DatePicker("Дата завершения", selection: $resolvedDate, in: hasDiagnosedDate ? diagnosedDate... : Date.distantPast..., displayedComponents: .date)
                }
                TextField("Заметка", text: $item.note, axis: .vertical)
            }
            .navigationTitle("Заболевание")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        item.diagnosedAt = hasDiagnosedDate ? diagnosedDate : nil
                        item.resolvedAt = hasResolvedDate ? resolvedDate : nil
                        item.year = hasDiagnosedDate ? diagnosedDate.formatted(.dateTime.year()) : item.year
                        onSave(item)
                        dismiss()
                    }
                    .disabled(item.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            }
        }
    }
}

private struct MedicationEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: Medication
    @State private var hasStartDate: Bool
    @State private var hasEndDate: Bool
    @State private var startDate: Date
    @State private var endDate: Date

    let onSave: (Medication) -> Void

    init(initial: Medication, onSave: @escaping (Medication) -> Void) {
        _item = State(initialValue: initial)
        _hasStartDate = State(initialValue: initial.startedAt != nil)
        _hasEndDate = State(initialValue: initial.endedAt != nil)
        _startDate = State(initialValue: initial.startedAt ?? .now)
        _endDate = State(initialValue: initial.endedAt ?? .now)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Название", text: $item.name)
                TextField("Дозировка", text: $item.dosage)
                TextField("Частота", text: $item.frequency)
                Toggle("Указать дату начала", isOn: $hasStartDate)
                if hasStartDate {
                    DatePicker("Дата начала", selection: $startDate, displayedComponents: .date)
                }
                Toggle("Указать дату окончания", isOn: $hasEndDate)
                if hasEndDate {
                    DatePicker("Дата окончания", selection: $endDate, in: hasStartDate ? startDate... : Date.distantPast..., displayedComponents: .date)
                }
                TextField("Заметка", text: $item.note, axis: .vertical)
            }
            .navigationTitle("Лекарство")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        item.startedAt = hasStartDate ? startDate : nil
                        item.endedAt = hasEndDate ? endDate : nil
                        onSave(item)
                        dismiss()
                    }
                    .disabled(item.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            }
        }
    }
}

private struct ProcedureEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: MedicalProcedure
    let onSave: (MedicalProcedure) -> Void

    init(initial: MedicalProcedure, onSave: @escaping (MedicalProcedure) -> Void) {
        _item = State(initialValue: initial)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Название", text: $item.name)
                TextField("Год", text: $item.year).keyboardType(.numberPad)
                TextField("Комментарий", text: $item.comment, axis: .vertical)
            }
            .navigationTitle("Операция")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { onSave(item); dismiss() }.disabled(item.name.trimmingCharacters(in: .whitespaces).isEmpty) }
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            }
        }
    }
}
