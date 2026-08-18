import SwiftUI

struct AnalysesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var searchText = ""

    private var groups: [AnalysisGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.analysisGroups.filter { query.isEmpty || $0.name.lowercased().contains(query) }
    }

    var body: some View {
        Group {
            if store.analysisGroups.isEmpty {
                EmptyState(
                    symbol: "testtube.2",
                    title: "Показателей пока нет",
                    message: "После обработки документа с анализами здесь появятся найденные показатели и их динамика."
                )
            } else if groups.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    Section {
                        Text("Показатели с одинаковым локальным ключом «название + единица измерения» автоматически объединяются между документами. При необходимости можно вручную исправить название, значение или единицу на экране документа.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Показатели") {
                        ForEach(groups) { group in
                            NavigationLink {
                                AnalysisTrendView(group: group)
                            } label: {
                                AnalysisGroupRow(group: group)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Анализы")
        .searchable(text: $searchText, prompt: "Поиск показателя")
    }
}

private struct AnalysisGroupRow: View {
    let group: AnalysisGroup

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: group.hasTrend ? "chart.xyaxis.line" : "testtube.2")
                .foregroundStyle(.teal)
                .frame(width: 30, height: 30)
                .background(.teal.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)
                if let latest = group.latestObservation {
                    Text("Последнее: \(latest.rawValue)\(latest.unit.map { " \($0)" } ?? "") · \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("\(group.observations.count) \(observationWord(for: group.observations.count))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }

    private func observationWord(for count: Int) -> String {
        let remainder = count % 10
        let teens = count % 100
        if teens >= 11 && teens <= 14 { return "измерений" }
        switch remainder {
        case 1: return "измерение"
        case 2...4: return "измерения"
        default: return "измерений"
        }
    }
}
