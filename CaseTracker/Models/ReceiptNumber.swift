import Foundation

/// Helpers for USCIS receipt numbers: three letters (the service center) followed by ten digits.
enum ReceiptNumber {
    /// Uppercases and strips spaces, dashes, and other separators people paste in.
    static func normalize(_ raw: String) -> String {
        raw.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    static func isValid(_ raw: String) -> Bool {
        let value = normalize(raw)
        guard value.count == 13 else { return false }
        return value.prefix(3).allSatisfy(\.isLetter) && value.dropFirst(3).allSatisfy(\.isNumber)
    }

    static func serviceCenter(for raw: String) -> String? {
        switch String(normalize(raw).prefix(3)) {
        case "EAC", "VSC": "Vermont Service Center"
        case "WAC", "CSC": "California Service Center"
        case "LIN", "NSC": "Nebraska Service Center"
        case "SRC", "TSC": "Texas Service Center"
        case "MSC", "NBC": "National Benefits Center"
        case "YSC": "Potomac Service Center"
        case "IOE": "USCIS Online (ELIS)"
        default: nil
        }
    }
}
