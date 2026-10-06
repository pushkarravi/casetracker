import Foundation

/// A parsed case-status response, independent of the wire format.
struct CaseStatusResult: Equatable {
    struct HistoryEntry: Equatable {
        var date: Date
        var title: String
    }

    var receiptNumber: String
    var formType: String?
    var submittedDate: Date?
    var modifiedDate: Date?
    var statusTitle: String
    var statusDetail: String?
    var history: [HistoryEntry]
}

/// Decodes `GET /case-status/{receiptNumber}` responses.
///
/// Shape (from developer.uscis.gov):
/// ```json
/// { "case_status": { "receiptNumber": "...", "formType": "I-130",
///     "submittedDate": "09-05-2023 14:28:46", "modifiedDate": "09-05-2023 14:28:46",
///     "current_case_status_text_en": "...", "current_case_status_desc_en": "...",
///     "hist_case_status": [ { "date": "...", "completed_text_en": "..." } ] },
///   "message": "Query was successful ..." }
/// ```
enum USCISResponseParser {
    private struct Envelope: Decodable {
        let caseStatus: Payload?
        let message: String?

        enum CodingKeys: String, CodingKey {
            case caseStatus = "case_status"
            case message
        }
    }

    private struct Payload: Decodable {
        let receiptNumber: String?
        let formType: String?
        let submittedDate: String?
        let modifiedDate: String?
        let statusTitle: String?
        let statusDetail: String?
        let history: [History]?

        enum CodingKeys: String, CodingKey {
            case receiptNumber, formType, submittedDate, modifiedDate
            case statusTitle = "current_case_status_text_en"
            case statusDetail = "current_case_status_desc_en"
            case history = "hist_case_status"
        }
    }

    private struct History: Decodable {
        let date: String?
        let completedText: String?

        enum CodingKeys: String, CodingKey {
            case date
            case completedText = "completed_text_en"
        }
    }

    static func parse(_ data: Data, receiptNumber: String) throws -> CaseStatusResult {
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw USCISError.invalidResponse
        }
        guard let payload = envelope.caseStatus,
              let title = payload.statusTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty
        else {
            throw USCISError.caseNotFound(envelope.message)
        }

        let history: [CaseStatusResult.HistoryEntry] = (payload.history ?? []).compactMap { entry in
            guard let text = entry.completedText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty,
                  let date = parseDate(entry.date)
            else { return nil }
            return .init(date: date, title: text)
        }

        return CaseStatusResult(
            receiptNumber: payload.receiptNumber ?? receiptNumber,
            formType: payload.formType?.nilIfBlank,
            submittedDate: parseDate(payload.submittedDate),
            modifiedDate: parseDate(payload.modifiedDate),
            statusTitle: title,
            statusDetail: payload.statusDetail?.nilIfBlank,
            history: history
        )
    }

    /// Extracts a human-readable message from an error body, if there is one.
    static func errorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let message = object["message"] as? String { return message }
        if let errors = object["errors"] as? [[String: Any]], let first = errors.first {
            return first["message"] as? String ?? first["detail"] as? String
        }
        if let fault = object["fault"] as? [String: Any] { return fault["faultstring"] as? String }
        return nil
    }

    private static let dateFormatters: [DateFormatter] = [
        "MM-dd-yyyy HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss",
        "MM-dd-yyyy",
        "MM/dd/yyyy",
        "yyyy-MM-dd",
        "MMMM d, yyyy",
    ].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // USCIS doesn't document a zone; their systems run on US Eastern time.
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = format
        return formatter
    }

    static func parseDate(_ string: String?) -> Date? {
        guard let string = string?.trimmingCharacters(in: .whitespaces), !string.isEmpty else { return nil }
        for formatter in dateFormatters {
            if let date = formatter.date(from: string) { return date }
        }
        return ISO8601DateFormatter().date(from: string)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
