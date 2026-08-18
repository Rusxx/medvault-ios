import Foundation

// MARK: - Documents

enum MedicalDocumentType: String, Codable, CaseIterable, Identifiable {
    case labResult = "Анализ"
    case clinicalReport = "Заключение"
    case prescription = "Рецепт"
    case discharge = "Выписка"
    case imaging = "Снимок"
    case other = "Другое"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .labResult: return "testtube.2"
        case .clinicalReport: return "doc.text"
        case .prescription: return "pills"
        case .discharge: return "cross.case"
        case .imaging: return "viewfinder.rectangular"
        case .other: return "doc"
        }
    }
}

enum DocumentFileKind: String, Codable {
    case image
    case pdf

    var displayName: String {
        self == .image ? "Изображение" : "PDF"
    }
}

enum DocumentProcessingStatus: String, Codable {
    case pending = "Не обработан"
    case processing = "Обрабатывается"
    case completed = "Обработан"
    case failed = "Ошибка"

    var symbolName: String {
        switch self {
        case .pending: return "clock"
        case .processing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}

struct MedicalDocument: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var createdAt: Date
    var type: MedicalDocumentType
    var fileKind: DocumentFileKind
    var relativeFilePath: String
    var thumbnailData: Data?
    var extractedText: String
    var extractedInfo: ExtractedMedicalInfo
    var status: DocumentProcessingStatus
    var errorMessage: String?
    var isSampleData: Bool
    /// Optional clinical date manually corrected by the user; absent in records created before this version.
    var clinicalDate: Date?
    /// Local links from this document to medical-card entities.
    var linkedConditionIDs: [UUID]?
    var linkedMedicationIDs: [UUID]?
    /// Set only after a user saves manual corrections to extracted fields.
    var manuallyEditedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        type: MedicalDocumentType = .other,
        fileKind: DocumentFileKind,
        relativeFilePath: String,
        thumbnailData: Data? = nil,
        extractedText: String = "",
        extractedInfo: ExtractedMedicalInfo = .empty,
        status: DocumentProcessingStatus = .pending,
        errorMessage: String? = nil,
        isSampleData: Bool = false,
        clinicalDate: Date? = nil,
        linkedConditionIDs: [UUID]? = nil,
        linkedMedicationIDs: [UUID]? = nil,
        manuallyEditedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.type = type
        self.fileKind = fileKind
        self.relativeFilePath = relativeFilePath
        self.thumbnailData = thumbnailData
        self.extractedText = extractedText
        self.extractedInfo = extractedInfo
        self.status = status
        self.errorMessage = errorMessage
        self.isSampleData = isSampleData
        self.clinicalDate = clinicalDate
        self.linkedConditionIDs = linkedConditionIDs
        self.linkedMedicationIDs = linkedMedicationIDs
        self.manuallyEditedAt = manuallyEditedAt
    }
}

struct ExtractedMedicalInfo: Codable, Equatable {
    var documentTitle: String?
    var documentDateText: String?
    var doctor: String?
    var facility: String?
    var labValues: [LabValue]
    var medicines: [ExtractedMedication]
    var explicitClinicalMentions: [String]

    static let empty = ExtractedMedicalInfo(
        documentTitle: nil,
        documentDateText: nil,
        doctor: nil,
        facility: nil,
        labValues: [],
        medicines: [],
        explicitClinicalMentions: []
    )

    var hasContent: Bool {
        documentTitle != nil || documentDateText != nil || doctor != nil || facility != nil ||
        !labValues.isEmpty || !medicines.isEmpty || !explicitClinicalMentions.isEmpty
    }
}

struct LabValue: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var value: String
    var unit: String?
    var referenceRange: String?
    /// Optional for backward-compatible storage; records extracted before manual editing decode as false.
    var isManuallyEdited: Bool?

    init(id: UUID = UUID(), name: String, value: String, unit: String? = nil, referenceRange: String? = nil, isManuallyEdited: Bool? = nil) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.referenceRange = referenceRange
        self.isManuallyEdited = isManuallyEdited
    }
}

struct ExtractedMedication: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var dosage: String?

    init(id: UUID = UUID(), name: String, dosage: String? = nil) {
        self.id = id
        self.name = name
        self.dosage = dosage
    }
}

// MARK: - Medical card

struct MedicalProfile: Codable, Equatable {
    var personalInfo: PersonalInfo
    var allergies: [Allergy]
    var conditions: [MedicalCondition]
    var medications: [Medication]
    var procedures: [MedicalProcedure]

    static let empty = MedicalProfile(
        personalInfo: .empty,
        allergies: [],
        conditions: [],
        medications: [],
        procedures: []
    )
}

struct PersonalInfo: Codable, Equatable {
    var name: String
    var dateOfBirth: String
    var bloodType: String

    static let empty = PersonalInfo(name: "", dateOfBirth: "", bloodType: "")
}

struct Allergy: Codable, Identifiable, Equatable {
    let id: UUID
    var allergen: String
    var reaction: String
    var note: String

    init(id: UUID = UUID(), allergen: String, reaction: String = "", note: String = "") {
        self.id = id
        self.allergen = allergen
        self.reaction = reaction
        self.note = note
    }
}

struct MedicalCondition: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var year: String
    var note: String
    var diagnosedAt: Date?
    var resolvedAt: Date?
    var status: ConditionStatus?
    var linkedDocumentIDs: [UUID]?

    init(id: UUID = UUID(), name: String, year: String = "", note: String = "", diagnosedAt: Date? = nil, resolvedAt: Date? = nil, status: ConditionStatus? = nil, linkedDocumentIDs: [UUID]? = nil) {
        self.id = id
        self.name = name
        self.year = year
        self.note = note
        self.diagnosedAt = diagnosedAt
        self.resolvedAt = resolvedAt
        self.status = status
        self.linkedDocumentIDs = linkedDocumentIDs
    }
}

struct Medication: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var dosage: String
    var frequency: String
    var note: String
    var startedAt: Date?
    var endedAt: Date?
    var linkedDocumentIDs: [UUID]?

    init(id: UUID = UUID(), name: String, dosage: String = "", frequency: String = "", note: String = "", startedAt: Date? = nil, endedAt: Date? = nil, linkedDocumentIDs: [UUID]? = nil) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.note = note
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.linkedDocumentIDs = linkedDocumentIDs
    }
}

struct MedicalProcedure: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var year: String
    var comment: String

    init(id: UUID = UUID(), name: String, year: String = "", comment: String = "") {
        self.id = id
        self.name = name
        self.year = year
        self.comment = comment
    }
}

extension MedicalDocument {
    static let sampleData = MedicalDocument(
        title: "Пример данных: общий анализ крови",
        createdAt: .now,
        type: .labResult,
        fileKind: .pdf,
        relativeFilePath: "",
        extractedText: "Пример данных. Hemoglobin 132 g/L\nWBC 6.4 ×10⁹/L\nPlatelets 245 ×10⁹/L",
        extractedInfo: ExtractedMedicalInfo(
            documentTitle: "Пример данных: общий анализ крови",
            documentDateText: "01.01.2026",
            doctor: nil,
            facility: "Пример клиники",
            labValues: [
                LabValue(name: "Hemoglobin", value: "132", unit: "g/L"),
                LabValue(name: "WBC", value: "6.4", unit: "×10⁹/L"),
                LabValue(name: "Platelets", value: "245", unit: "×10⁹/L")
            ],
            medicines: [],
            explicitClinicalMentions: []
        ),
        status: .completed,
        isSampleData: true
    )
}
