import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct RootTabView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection = 0
    @State private var isShowingFileImporter = false
    @State private var isShowingCamera = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isShowingImportMenu = false

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeView(
                    onAddRequested: { isShowingImportMenu = true },
                    onCameraRequested: presentCamera,
                    onFileRequested: { isShowingFileImporter = true }
                )
            }
            .tabItem { Label("Главная", systemImage: "house.fill") }
            .tag(0)

            NavigationStack {
                DocumentLibraryView()
            }
            .tabItem { Label("Документы", systemImage: "folder.fill") }
            .tag(1)

            NavigationStack {
                MedicalCardView()
            }
            .tabItem { Label("Медкарта", systemImage: "cross.case.fill") }
            .tag(2)

            NavigationStack {
                PrivacyView()
            }
            .tabItem { Label("Приватность", systemImage: "lock.fill") }
            .tag(3)
        }
        .tint(.teal)
        .confirmationDialog("Добавить медицинский документ", isPresented: $isShowingImportMenu, titleVisibility: .visible) {
            Button("Камера", systemImage: "camera", action: presentCamera)
            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                Label("Фото", systemImage: "photo.on.rectangle")
            }
            Button("PDF / Файл", systemImage: "doc", action: { isShowingFileImporter = true })
            Button("Отмена", role: .cancel) {}
        }
        .fileImporter(isPresented: $isShowingFileImporter, allowedContentTypes: [.image, .pdf], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await store.importDocument(from: url) }
            } else if case .failure(let error) = result {
                store.importMessage = "Не удалось выбрать файл: \(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker { image in
                guard let data = image.jpegData(compressionQuality: 0.92) else {
                    store.importMessage = "Не удалось подготовить фотографию."
                    return
                }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("medvault-camera-\(UUID().uuidString).jpg")
                do {
                    try data.write(to: url, options: .atomic)
                    Task { await store.importDocument(from: url) }
                } catch {
                    store.importMessage = "Не удалось сохранить фотографию: \(error.localizedDescription)"
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self) else {
                        store.importMessage = "Не удалось открыть выбранную фотографию."
                        return
                    }
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("medvault-photo-\(UUID().uuidString).jpg")
                    try data.write(to: url, options: .atomic)
                    await store.importDocument(from: url)
                } catch {
                    store.importMessage = "Не удалось импортировать фотографию: \(error.localizedDescription)"
                }
                selectedPhoto = nil
            }
        }
        .overlay {
            if store.isImporting {
                ZStack {
                    Color.black.opacity(0.16).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Распознаём документ…")
                            .font(.headline)
                        Text("Обработка выполняется локально на устройстве.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .transition(.opacity)
            }
        }
        .alert("MedVault", isPresented: Binding(
            get: { store.importMessage != nil },
            set: { if !$0 { store.clearImportMessage() } }
        )) {
            Button("OK", role: .cancel) { store.clearImportMessage() }
        } message: {
            Text(store.importMessage ?? "")
        }
    }

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            store.importMessage = "Камера недоступна на этом устройстве. Выберите фото или файл."
            return
        }
        isShowingCamera = true
    }
}
