import Foundation
import UniformTypeIdentifiers

/// Persists app metadata and original files only inside the app's Application Support container.
actor StorageService {
    static let shared = StorageService()

    private let fileManager = FileManager.default
    private let metadataFileName = "documents.json"
    private let profileFileName = "medical_profile.json"

    private var baseDirectory: URL {
        let appSupport = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport.appendingPathComponent("MedVault", isDirectory: true)
    }

    private var documentsDirectory: URL {
        baseDirectory.appendingPathComponent("Documents", isDirectory: true)
    }

    private var metadataURL: URL { baseDirectory.appendingPathComponent(metadataFileName) }
    private var profileURL: URL { baseDirectory.appendingPathComponent(profileFileName) }

    func prepareStorage() throws {
        try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
    }

    func saveImportedFile(from sourceURL: URL, fileKind: DocumentFileKind) throws -> (relativePath: String, data: Data) {
        try prepareStorage()
        let sourceData = try Data(contentsOf: sourceURL)
        let ext: String
        switch fileKind {
        case .image:
            ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        case .pdf:
            ext = "pdf"
        }
        let filename = "\(UUID().uuidString).\(ext)"
        let destination = documentsDirectory.appendingPathComponent(filename)
        try sourceData.write(to: destination, options: .atomic)
        return ("Documents/\(filename)", sourceData)
    }

    func fileURL(for relativePath: String) -> URL {
        baseDirectory.appendingPathComponent(relativePath)
    }

    func deleteFile(at relativePath: String) throws {
        guard !relativePath.isEmpty else { return }
        let url = fileURL(for: relativePath)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func loadDocuments() throws -> [MedicalDocument] {
        try prepareStorage()
        guard fileManager.fileExists(atPath: metadataURL.path) else { return [] }
        let data = try Data(contentsOf: metadataURL)
        return try JSONDecoder.medVault.decode([MedicalDocument].self, from: data)
    }

    func saveDocuments(_ documents: [MedicalDocument]) throws {
        try prepareStorage()
        let data = try JSONEncoder.medVault.encode(documents)
        try data.write(to: metadataURL, options: .atomic)
    }

    func loadProfile() throws -> MedicalProfile {
        try prepareStorage()
        guard fileManager.fileExists(atPath: profileURL.path) else { return .empty }
        return try JSONDecoder.medVault.decode(MedicalProfile.self, from: Data(contentsOf: profileURL))
    }

    func saveProfile(_ profile: MedicalProfile) throws {
        try prepareStorage()
        let data = try JSONEncoder.medVault.encode(profile)
        try data.write(to: profileURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static var medVault: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var medVault: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension URL {
    var inferredDocumentFileKind: DocumentFileKind? {
        if pathExtension.lowercased() == "pdf" { return .pdf }
        if let type = UTType(filenameExtension: pathExtension), type.conforms(to: .image) { return .image }
        return nil
    }
}
