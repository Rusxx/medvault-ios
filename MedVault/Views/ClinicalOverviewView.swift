import SwiftUI

struct ClinicalOverviewView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                patientHeader
                overviewWarning
                activeConditionsSection
                activeMedicationsSection
                latestAnalysesSection
                historySection
            }
            .padding()
        }
        .navigationTitle("Врачебный обзор")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var patientHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Пациент", systemImage: "person.text.rectangle")
                .font(.headline)
                .foregroundStyle(.teal)
            Text(store.profile.personalInfo.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Не указано" : store.profile.personalInfo.name)
                .font(.title.bold())
            HStack(spacing: 12) {
                overviewMetadata("Дата рождения", store.profile.personalInfo.dateOfBirth)
                overviewMetadata("Группа крови", store.profile.personalInfo.bloodType)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var overviewWarning: some View {
        Label("Это компактное представление сохранённых записей. Оно не содержит диагностики, оценки рисков или медицинских рекомендаций.", systemImage: "exclamationmark.shield.fill")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(12)
            .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var activeConditionsSection: some View {
        overviewTitle("Активные заболевания", symbol: "cross.case.fill", count: store.activeConditions.count)
        if store.activeConditions.isEmpty {
            overviewEmpty("Активные заболевания не указаны.")
        } else {
            OverviewCard {
                ForEach(store.activeConditions) { condition in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(condition.name).font(.headline)
                            Text(condition.diagnosedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Дата не указана")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !condition.linkedDocumentIDsValue.isEmpty {
                            Label("\(condition.linkedDocumentIDsValue.count)", systemImage: "doc.text")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if condition.id != store.activeConditions.last?.id { Divider() }
                }
            }
        }
    }

    @ViewBuilder
    private var activeMedicationsSection: some View {
        overviewTitle("Текущие лекарства", symbol: "pills.fill", count: store.activeMedications.count)
        if store.activeMedications.isEmpty {
            overviewEmpty("Активные лекарства не указаны.")
        } else {
            OverviewCard {
                ForEach(store.activeMedications) { medication in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(medication.name).font(.headline)
                            Text([medication.dosage, medication.frequency].filter { !$0.isEmpty }.joined(separator: " · ").isEmpty ? "Детали не указаны" : [medication.dosage, medication.frequency].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let start = medication.startedAt {
                            Text("с \(start.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if medication.id != store.activeMedications.last?.id { Divider() }
                }
            }
        }
    }

    @ViewBuilder
    private var latestAnalysesSection: some View {
        overviewTitle("Последние анализы", symbol: "testtube.2", count: store.analysisGroups.count)
        if store.recentAnalysisGroups.isEmpty {
            overviewEmpty("Обработанные показатели пока отсутствуют.")
        } else {
            OverviewCard {
                ForEach(store.recentAnalysisGroups) { group in
                    NavigationLink {
                        AnalysisTrendView(group: group)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(group.name).font(.headline).foregroundStyle(.primary)
                                Text("\(group.observations.count) знач. · \(group.hasTrend ? "есть динамика" : "одно значение")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let latest = group.latestObservation {
                                Text("\(latest.rawValue)\(latest.unit.map { " \($0)" } ?? "")")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    if group.id != store.recentAnalysisGroups.last?.id { Divider() }
                }
            }
        }
    }

    private var historySection: some View {
        NavigationLink {
            TimelineView()
        } label: {
            Label("Открыть полную историю", systemImage: "calendar")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
    }

    private func overviewTitle(_ title: String, symbol: String, count: Int) -> some View {
        HStack {
            Label(title, systemImage: symbol)
                .font(.title3.bold())
            Spacer()
            Text("\(count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func overviewEmpty(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func overviewMetadata(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Не указано" : value).font(.subheadline.weight(.medium))
        }
    }
}

private struct OverviewCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
