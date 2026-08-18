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
            } footer: {
                Text("Укажите аллерген, реакцию и заметку, если они известны.")
            }

            Section {
                ForEach(store.profile.conditions) { condition in
                    Button { edit(condition) } label: {
                        MedicalListRow(title: condition.name, details: [condition.year.isEmpty ? nil : "Год: \(condition.year)", condition.note])
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
            }

            Section {
                ForEach(store.profile.medications) { medication in
                    Button { edit(medication) } label: {
                        MedicalListRow(title: medication.name, details: [medication.dosage, medication.frequency, medication.note])
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
                Text("MedVault хранит записи; он не напоминает о приёме и не даёт рекомендаций по лекарствам.")
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
            .toolbar { saveButton }
        }
    }

    @ToolbarContentBuilder private var saveButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Сохранить") { onSave(item); dismiss() }.disabled(item.allergen.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
    }
}

private struct ConditionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: MedicalCondition
    let onSave: (MedicalCondition) -> Void

    init(initial: MedicalCondition, onSave: @escaping (MedicalCondition) -> Void) {
        _item = State(initialValue: initial)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Название", text: $item.name)
                TextField("Год", text: $item.year).keyboardType(.numberPad)
                TextField("Заметка", text: $item.note, axis: .vertical)
            }
            .navigationTitle("Заболевание")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { onSave(item); dismiss() }.disabled(item.name.trimmingCharacters(in: .whitespaces).isEmpty) }
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            }
        }
    }
}

private struct MedicationEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: Medication
    let onSave: (Medication) -> Void

    init(initial: Medication, onSave: @escaping (Medication) -> Void) {
        _item = State(initialValue: initial)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Название", text: $item.name)
                TextField("Дозировка", text: $item.dosage)
                TextField("Частота", text: $item.frequency)
                TextField("Заметка", text: $item.note, axis: .vertical)
            }
            .navigationTitle("Лекарство")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { onSave(item); dismiss() }.disabled(item.name.trimmingCharacters(in: .whitespaces).isEmpty) }
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
