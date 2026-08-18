import Foundation

/// Pure local transformations for history, analysis grouping, and the compact clinician-facing summary.
struct ClinicalAggregationService {
    func timelineEvents(documents: [MedicalDocument], profile: MedicalProfile) -> [MedicalTimelineEvent] {
        var events: [MedicalTimelineEvent] = documents.map { document in
            MedicalTimelineEvent(
                id: "document-\(document.id.uuidString)",
                date: document.recordDate,
                kind: .document,
                title: document.title,
                subtitle: "\(document.type.rawValue) · \(document.status.rawValue)",
                documentID: document.id
            )
        }

        for condition in profile.conditions {
            if let diagnosedAt = condition.diagnosedAt {
                events.append(MedicalTimelineEvent(
                    id: "condition-\(condition.id.uuidString)",
                    date: diagnosedAt,
                    kind: .condition,
                    title: condition.name,
                    subtitle: "Заболевание · \(condition.currentStatus.rawValue)",
                    conditionID: condition.id
                ))
            }
        }

        for medication in profile.medications {
            if let startedAt = medication.startedAt {
                events.append(MedicalTimelineEvent(
                    id: "medication-start-\(medication.id.uuidString)",
                    date: startedAt,
                    kind: .medicationStart,
                    title: medication.name,
                    subtitle: "Начало приёма\(medication.dosage.isEmpty ? "" : " · \(medication.dosage)")",
                    medicationID: medication.id
                ))
            }
            if let endedAt = medication.endedAt {
                events.append(MedicalTimelineEvent(
                    id: "medication-end-\(medication.id.uuidString)",
                    date: endedAt,
                    kind: .medicationEnd,
                    title: medication.name,
                    subtitle: "Окончание приёма",
                    medicationID: medication.id
                ))
            }
        }

        return events.sorted { $0.date > $1.date }
    }

    func analysisGroups(from documents: [MedicalDocument]) -> [AnalysisGroup] {
        var byKey: [String: [AnalysisObservation]] = [:]
        for document in documents where document.status == .completed {
            for value in document.extractedInfo.labValues {
                let observation = AnalysisObservation(
                    id: value.id,
                    groupKey: value.analysisGroupKey,
                    displayName: value.name,
                    numericValue: value.numericValue,
                    rawValue: value.value,
                    unit: value.unit,
                    referenceRange: value.referenceRange,
                    date: document.recordDate,
                    documentID: document.id,
                    documentTitle: document.title,
                    isManuallyEdited: value.manualEditFlag
                )
                byKey[observation.groupKey, default: []].append(observation)
            }
        }

        return byKey.compactMap { key, observations in
            guard let representative = observations.sorted(by: { $0.date > $1.date }).first else { return nil }
            return AnalysisGroup(
                id: key,
                name: representative.displayName,
                unit: representative.unit,
                observations: observations.sorted { $0.date < $1.date }
            )
        }
        .sorted { left, right in
            (left.latestObservation?.date ?? .distantPast) > (right.latestObservation?.date ?? .distantPast)
        }
    }

    func filtered(events: [MedicalTimelineEvent], using filter: MedicalHistoryFilter) -> [MedicalTimelineEvent] {
        let query = filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return events.filter { event in
            let isWithinDateRange = filter.dateInterval.map { $0.contains(event.date) } ?? true
            let haystack = "\(event.title) \(event.subtitle) \(event.kind.title)".lowercased()
            let matchesSearch = query.isEmpty || haystack.contains(query)
            return isWithinDateRange && matchesSearch
        }
    }
}
