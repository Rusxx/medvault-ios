import SwiftUI
import Charts

struct AnalysisTrendView: View {
    let group: AnalysisGroup
    @State private var selectedRange: HistoryRangePreset = .allTime

    private var observations: [AnalysisObservation] {
        guard let interval = selectedRange.dateInterval() else { return group.observations }
        return group.observations.filter { interval.contains($0.date) }
    }

    private var numericObservations: [AnalysisObservation] {
        observations.filter { $0.numericValue != nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name)
                        .font(.largeTitle.bold())
                    if let unit = group.unit, !unit.isEmpty {
                        Text(unit)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Text("График отображает только числовые значения, явно сохранённые в документах. Он не интерпретирует результат и не даёт рекомендаций.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Picker("Период", selection: $selectedRange) {
                    ForEach([HistoryRangePreset.month, .sixMonths, .year, .allTime]) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)

                if numericObservations.count >= 2 {
                    Chart(numericObservations) { observation in
                        if let value = observation.numericValue {
                            LineMark(
                                x: .value("Дата", observation.date),
                                y: .value("Значение", value)
                            )
                            .foregroundStyle(.teal)
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Дата", observation.date),
                                y: .value("Значение", value)
                            )
                            .foregroundStyle(.teal)
                            .symbolSize(38)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: min(5, numericObservations.count)))
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 250)
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    ContentUnavailableView(
                        "Недостаточно данных для графика",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Для динамики нужны как минимум два числовых значения одного показателя в разные даты."))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }

                Text("Значения по датам")
                    .font(.title2.bold())

                VStack(spacing: 0) {
                    ForEach(observations.sorted { $0.date > $1.date }) { observation in
                        NavigationLink {
                            DocumentDetailView(documentID: observation.documentID)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(observation.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(observation.documentTitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("\(observation.rawValue)\(observation.unit.map { " \($0)" } ?? "")")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    if let reference = observation.referenceRange, !reference.isEmpty {
                                        Text("Реф.: \(reference)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if observation.isManuallyEdited {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .accessibilityLabel("Исправлено вручную")
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        if observation.id != observations.last?.id { Divider() }
                    }
                }
                .padding(.horizontal)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding()
        }
        .navigationTitle("Динамика")
        .navigationBarTitleDisplayMode(.inline)
    }
}
