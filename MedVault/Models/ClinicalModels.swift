import Foundation

// MARK: - Dates and clinical states

enum ConditionStatus: String, Codable, CaseIterable, Identifiable {
    case active = "Активное"
    case resolved = "Завершено"
    case inactive = "Неактивное"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .active: return "checkmark.seal.fill"
        case .resolved: return "checkmark.circle.fill"
        case .inactive: return "pause.circle.fill"
        }
    }
}

enum HistoryRangePreset: String, CaseIterable, Identifiable {
    case sevenDays = "7 дней"
    case month = "Месяц"
    case sixMonths = "6 месяцев"
    case year = "Год"
    case allTime = "Всё время"
    case custom = "Период"

    var id: String { rawValue }

    func dateInterval(relativeTo referenceDate: Date = .now, calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .sevenDays:
            return DateInterval(start: calendar.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate, end: referenceDate)
        case .month:
            return DateInterval(start: calendar.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate, end: referenceDate)
        case .sixMonths:
            return DateInterval(start: calendar.date(byAdding: .month, value: -6, to: referenceDate) ?? referenceDate, end: referenceDate)
        case .year:
            return DateInterval(start: calendar.date(byAdding: .year, value: -1, to: referenceDate) ?? referenceDate, end: referenceDate)
        case .allTime, .custom:
            return nil
        }
    }
}

struct MedicalHistoryFilter: Equatable {
    var preset: HistoryRangePreset = .allTime
    var customStart: Date = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    var customEnd: Date = .now
    var searchText: String = ""

    var dateInterval: DateInterval? {
        if preset == .custom {
            let start = min(customStart, customEnd)
            let inclusiveEnd = Calendar.current.date(byAdding: .day, value: 1, to: max(customStart, customEnd)) ?? customEnd
            return DateInterval(start: start, end: inclusiveEnd)
        }
        return preset.dateInterval()
    }
}

// MARK: - Timeline

enum MedicalTimelineEventKind: String, Codable {
    case document
    case condition
    case medicationStart
    case medicationEnd

    var title: String {
        switch self {
        case .document: return "Документ"
        case .condition: return "Заболевание"
        case .medicationStart: return "Начало лекарства"
        case .medicationEnd: return "Окончание лекарства"
        }
    }

    var symbolName: String {
        switch self {
        case .document: return "doc.text.fill"
        case .condition: return "cross.case.fill"
        case .medicationStart: return "pills.fill"
        case .medicationEnd: return "pills.circle"
        }
    }
}

struct MedicalTimelineEvent: Identifiable, Hashable {
    let id: String
    let date: Date
    let kind: MedicalTimelineEventKind
    let title: String
    let subtitle: String
    let documentID: UUID?
    let conditionID: UUID?
    let medicationID: UUID?

    init(
        id: String,
        date: Date,
        kind: MedicalTimelineEventKind,
        title: String,
        subtitle: String,
        documentID: UUID? = nil,
        conditionID: UUID? = nil,
        medicationID: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.documentID = documentID
        self.conditionID = conditionID
        self.medicationID = medicationID
    }
}

// MARK: - Longitudinal laboratory values

struct AnalysisObservation: Identifiable, Hashable {
    let id: UUID
    let groupKey: String
    let displayName: String
    let numericValue: Double?
    let rawValue: String
    let unit: String?
    let referenceRange: String?
    let date: Date
    let documentID: UUID
    let documentTitle: String
    let isManuallyEdited: Bool
}

struct AnalysisGroup: Identifiable, Hashable {
    let id: String
    let name: String
    let unit: String?
    let observations: [AnalysisObservation]

    var latestObservation: AnalysisObservation? {
        observations.max { $0.date < $1.date }
    }

    var numericObservations: [AnalysisObservation] {
        observations.filter { $0.numericValue != nil }.sorted { $0.date < $1.date }
    }

    var hasTrend: Bool { numericObservations.count >= 2 }
}

extension MedicalDocument {
    /// The date used in history and trends. A manually corrected clinical date takes precedence over import date.
    var recordDate: Date { clinicalDate ?? createdAt }

    var linkedConditionIDsValue: [UUID] { linkedConditionIDs ?? [] }
    var linkedMedicationIDsValue: [UUID] { linkedMedicationIDs ?? [] }
    var hasManualCorrections: Bool { manuallyEditedAt != nil }
}

extension MedicalCondition {
    var currentStatus: ConditionStatus { status ?? .active }
    var timelineDate: Date? { diagnosedAt }
    var linkedDocumentIDsValue: [UUID] { linkedDocumentIDs ?? [] }
}

extension Medication {
    var linkedDocumentIDsValue: [UUID] { linkedDocumentIDs ?? [] }
    var isActive: Bool { endedAt == nil || endedAt! > .now }
}

extension LabValue {
    var normalizedName: String {
        let lower = name.lowercased(with: Locale(identifier: "en_US_POSIX"))
        let aliases: [String: String] = [
            "hb": "hemoglobin",
            "hgb": "hemoglobin",
            "гемоглобин": "hemoglobin",
            "лейкоциты": "wbc",
            "тромбоциты": "platelets"
        ]
        let compact = String(lower.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
        return aliases[lower.trimmingCharacters(in: .whitespacesAndNewlines)] ?? compact
    }

    var normalizedUnit: String {
        (unit ?? "")
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "μ", with: "u")
            .replacingOccurrences(of: "µ", with: "u")
    }

    var analysisGroupKey: String {
        "\(normalizedName)|\(normalizedUnit)"
    }

    var numericValue: Double? {
        let normalized = value
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
        return Double(normalized)
    }

    var manualEditFlag: Bool { isManuallyEdited ?? false }
}
