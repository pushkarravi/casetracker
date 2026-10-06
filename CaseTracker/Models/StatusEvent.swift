import Foundation
import SwiftData

@Model
final class StatusEvent {
    var date: Date
    var title: String
    var detail: String?
    var sourceRaw: String
    var trackedCase: TrackedCase?

    enum Source: String {
        /// A change the app detected from a live API check.
        case uscis
        /// History USCIS returned for the case before we started tracking it.
        case uscisHistory
        /// Entered by hand.
        case manual

        var label: String {
            switch self {
            case .uscis: "USCIS"
            case .uscisHistory: "USCIS history"
            case .manual: "Manual"
            }
        }
    }

    init(date: Date, title: String, detail: String?, source: Source) {
        self.date = date
        self.title = title
        self.detail = detail
        self.sourceRaw = source.rawValue
    }

    var source: Source { Source(rawValue: sourceRaw) ?? .manual }
}
