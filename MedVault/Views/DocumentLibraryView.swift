import SwiftUI

struct DocumentLibraryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedType: MedicalDocumentType?

    private var filteredDocuments: [MedicalDocument] {
        guard let selectedType else { return store.documents }
        return store.documents.filter { $0.type == selectedType }
    }

    var body: some View {
        Group {
            if store.documents.isEmpty {
                EmptyState(
                    symbol: "folder.badge.plus",
                    title: "Библиотека пуста",
                    message: "Импортируйте медицинский документ с главного экрана."
                )
            } else {
                List {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(title: "Все", isSelected: selectedType == nil) { selectedType = nil }
                                ForEach(MedicalDocumentType.allCases) { type in
                                    FilterChip(title: type.rawValue, isSelected: selectedType == type) { selectedType = type }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 0))

                    Section("Все документы") {
                        ForEach(filteredDocuments) { document in
                            NavigationLink {
                                DocumentDetailView(documentID: document.id)
                            } label: {
                                DocumentRow(document: document)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Документы")
        .overlay(alignment: .bottom) {
            if let error = store.loadError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 8)
            }
        }
    }
}

private struct DocumentRow: View {
    let document: MedicalDocument

    var body: some View {
        HStack(spacing: 12) {
            DocumentThumbnail(document: document)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(document.title)
                        .font(.headline)
                        .lineLimit(1)
                    if document.isSampleData {
                        Text("Пример данных")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.12), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
                Text("\(document.type.rawValue) · \(document.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProcessingStatusBadge(status: document.status)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(isSelected ? Color.teal : Color(uiColor: .tertiarySystemFill), in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
