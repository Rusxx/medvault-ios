import Foundation

/// A deliberately conservative parser. It identifies text patterns that are visibly present;
/// it does not infer diagnoses, calculate results, or make clinical recommendations.
struct MedicalTextParser {
    func parse(_ text: String, fallbackTitle: String) -> ExtractedMedicalInfo {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        var info = ExtractedMedicalInfo.empty
        info.documentTitle = firstMeaningfulTitle(in: lines) ?? fallbackTitle
        info.documentDateText = matchFirst(in: normalized, pattern: #"\b(?:0[1-9]|[12][0-9]|3[01])[.\-/](?:0[1-9]|1[0-2])[.\-/](?:19|20)\d{2}\b"#)
        info.doctor = findLabelValue(in: lines, labels: ["врач", "doctor", "доктор"])
        info.facility = findLabelValue(in: lines, labels: ["учреждение", "клиника", "больница", "hospital", "clinic"])
        info.labValues = parseLabValues(lines)
        info.medicines = parseMedications(lines)
        info.explicitClinicalMentions = parseExplicitClinicalMentions(lines)
        return info
    }

    private func firstMeaningfulTitle(in lines: [String]) -> String? {
        lines.first { line in
            let lower = line.lowercased()
            return line.count > 4 && line.count < 110 &&
                !lower.contains("дата") && !lower.contains("date") &&
                !lower.contains("пациент") && !lower.contains("patient")
        }
    }

    private func findLabelValue(in lines: [String], labels: [String]) -> String? {
        for line in lines {
            let lower = line.lowercased()
            for label in labels where lower.hasPrefix(label) {
                let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty { return value }
                }
            }
        }
        return nil
    }

    private func parseLabValues(_ lines: [String]) -> [LabValue] {
        // Example: Hemoglobin 132 g/L (120–160)
        let pattern = #"^([A-Za-zА-Яа-яЁё][A-Za-zА-Яа-яЁё0-9 .()/%+\-]{1,48}?)\s*[:=]?\s*([<>]?[0-9]+(?:[.,][0-9]+)?)\s*([A-Za-zА-Яа-яµμ×/^0-9⁰¹²³⁴⁵⁶⁷⁸⁹\-]+)?\s*(?:\(?([0-9.,\-–— ]{3,30})\)?)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var values: [LabValue] = []
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range), match.numberOfRanges >= 5 else { continue }
            guard let name = capture(1, in: line, match: match),
                  let value = capture(2, in: line, match: match) else { continue }
            let excluded = ["дата", "возраст", "год", "page", "стр"]
            guard !excluded.contains(where: { name.lowercased().contains($0) }) else { continue }
            values.append(LabValue(name: name, value: value, unit: capture(3, in: line, match: match), referenceRange: capture(4, in: line, match: match)))
        }
        return Array(values.prefix(30))
    }

    private func parseMedications(_ lines: [String]) -> [ExtractedMedication] {
        let dosagePattern = #"(?i)([A-Za-zА-Яа-яЁё][A-Za-zА-Яа-яЁё\-]{2,40})\s+(\d+(?:[.,]\d+)?\s*(?:мг|мкг|mg|mcg|мл|ml|таб\.?|капс\.?))"#
        guard let regex = try? NSRegularExpression(pattern: dosagePattern) else { return [] }
        var medicines: [ExtractedMedication] = []
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range),
                  let name = capture(1, in: line, match: match),
                  let dosage = capture(2, in: line, match: match) else { continue }
            medicines.append(ExtractedMedication(name: name, dosage: dosage))
        }
        return Array(medicines.prefix(20))
    }

    private func parseExplicitClinicalMentions(_ lines: [String]) -> [String] {
        let labels = ["диагноз", "заключение", "diagnosis", "impression"]
        return lines.compactMap { line in
            let lower = line.lowercased()
            guard labels.contains(where: { lower.hasPrefix($0) }) else { return nil }
            let components = line.split(separator: ":", maxSplits: 1).map(String.init)
            return components.count == 2 ? components[1].trimmingCharacters(in: .whitespaces) : line
        }.filter { !$0.isEmpty }
    }

    private func matchFirst(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), let swiftRange = Range(match.range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    private func capture(_ index: Int, in text: String, match: NSTextCheckingResult) -> String? {
        guard match.range(at: index).location != NSNotFound,
              let range = Range(match.range(at: index), in: text) else { return nil }
        let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
