import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    let onAddRequested: () -> Void
    let onCameraRequested: () -> Void
    let onFileRequested: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Здравствуйте\(greetingName)")
                        .font(.largeTitle.bold())
                    Text("Ваши медицинские документы хранятся только на этом устройстве.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button(action: onAddRequested) {
                    Label("Добавить медицинский документ", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)

                HStack(spacing: 12) {
                    Button(action: onCameraRequested) {
                        Label("Сфотографировать", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button(action: onFileRequested) {
                        Label("Выбрать файл", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .font(.subheadline.weight(.semibold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricCard(count: store.documents.count, title: "документов", symbol: "doc.text.fill", tint: .teal)
                    MetricCard(count: store.profile.medications.count, title: "лекарств", symbol: "pills.fill", tint: .orange)
                    MetricCard(count: store.profile.allergies.count, title: "аллергий", symbol: "allergens", tint: .pink)
                    MetricCard(count: store.completedDocumentCount, title: "обработано", symbol: "checkmark.seal.fill", tint: .green)
                }

                NavigationLink {
                    ClinicalOverviewView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "stethoscope")
                            .font(.title3)
                            .foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Врачебный обзор")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Пациент, активные записи, последние анализы и динамика")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Последняя запись")
                        .font(.title2.bold())
                    if let document = store.latestDocument {
                        NavigationLink {
                            DocumentDetailView(documentID: document.id)
                        } label: {
                            LatestDocumentCard(document: document)
                        }
                        .buttonStyle(.plain)
                    } else {
                        EmptyState(
                            symbol: "doc.badge.plus",
                            title: "Документов пока нет",
                            message: "Добавьте изображение или PDF, чтобы сохранить и извлечь информацию локально.",
                            actionTitle: "Добавить документ",
                            action: onAddRequested
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                }

                SafetyNotice()
            }
            .padding()
        }
        .navigationTitle("MedVault")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Добавить пример данных", systemImage: "eye") {
                        Task { await store.addClearlyLabeledSampleData() }
                    }
                    if store.documents.contains(where: { $0.isSampleData }) {
                        Button("Удалить примеры данных", systemImage: "trash", role: .destructive) {
                            Task { await store.removeAllSampleData() }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private var greetingName: String {
        let name = store.profile.personalInfo.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "" : ", \(name)"
    }
}

private struct LatestDocumentCard: View {
    let document: MedicalDocument

    var body: some View {
        HStack(spacing: 14) {
            DocumentThumbnail(document: document)
            VStack(alignment: .leading, spacing: 5) {
                Text(document.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(document.recordDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProcessingStatusBadge(status: document.status)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
