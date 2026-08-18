import SwiftUI

struct TimelineView: View {
    @EnvironmentObject private var store: AppStore
    @State private var filter = MedicalHistoryFilter()
    @State private var exportURL: URL?
    @State private var isShowingShareSheet = false
    @State private var exportError: String?

    private var events: [MedicalTimelineEvent] {
        store.timelineEvents(using: filter)
    }

    private var groupedEvents: [TimelineDaySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { calendar.startOfDay(for: $0.date) }
        return grouped.map { date, values in
            TimelineDaySection(date: date, events: values.sorted { $0.date > $1.date })
        }
        .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                Picker("Период", selection: $filter.preset) {
                    ForEach(HistoryRangePreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)

                if filter.preset == .custom {
                    DatePicker("С", selection: $filter.customStart, displayedComponents: .date)
                    DatePicker("По", selection: $filter.customEnd, in: filter.customStart..., displayedComponents: .date)
                }

                NavigationLink {
                    DocumentLibraryView()
                } label: {
                    Label("Библиотека документов", systemImage: "folder")
                }
            } header: {
                Text("Фильтр истории")
            } footer: {
                Text("В историю входят сохранённые документы, даты заболеваний и начало или окончание приёма лекарств.")
            }

            if groupedEvents.isEmpty {
                Section {
                    EmptyState(
                        symbol: "calendar.badge.magnifyingglass",
                        title: "Записей не найдено",
                        message: "Измените период или поисковый запрос либо добавьте документ и медицинские записи."
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .listRowBackground(Color.clear)
                }
            } else {
                ForEach(groupedEvents) { group in
                    Section(group.date.formatted(date: .complete, time: .omitted)) {
                        ForEach(group.events) { event in
                            TimelineEventRow(event: event)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("История")
        .searchable(text: $filter.searchText, prompt: "Поиск по истории")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    exportHistory()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(events.isEmpty)
                .accessibilityLabel("Экспортировать историю в PDF")
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let exportURL {
                ActivityShareSheet(items: [exportURL])
            }
        }
        .alert("Не удалось экспортировать историю", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    private func exportHistory() {
        do {
            exportURL = try HistoryPDFExportService().export(events: events, filter: filter, profile: store.profile)
            isShowingShareSheet = true
        } catch {
            exportError = error.localizedDescription
        }
    }
}

private struct TimelineDaySection: Identifiable {
    let date: Date
    let events: [MedicalTimelineEvent]
    var id: Date { date }
}

private struct TimelineEventRow: View {
    let event: MedicalTimelineEvent

    var body: some View {
        Group {
            if let documentID = event.documentID {
                NavigationLink {
                    DocumentDetailView(documentID: documentID)
                } label: {
                    rowContent
                }
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.kind.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(event.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(event.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }

    private var tint: Color {
        switch event.kind {
        case .document: return .teal
        case .condition: return .red
        case .medicationStart: return .blue
        case .medicationEnd: return .secondary
        }
    }
}
