import Foundation
import SwiftData

@Model
final class TrackedCase {
    @Attribute(.unique) var receiptNumber: String
    var nickname: String
    var formType: String?
    var statusTitle: String?
    var statusDetail: String?
    var submittedDate: Date?
    /// The date USCIS reports for the current status.
    var statusDate: Date?
    var lastCheckedAt: Date?
    var lastError: String?
    /// When true, the app fetches status from the USCIS API. When false, the user records updates by hand.
    var isAutoTracked: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \StatusEvent.trackedCase)
    var events: [StatusEvent] = []

    init(receiptNumber: String, nickname: String = "", isAutoTracked: Bool, createdAt: Date = .now) {
        self.receiptNumber = ReceiptNumber.normalize(receiptNumber)
        self.nickname = nickname
        self.isAutoTracked = isAutoTracked
        self.createdAt = createdAt
    }

    var displayName: String { nickname.isEmpty ? receiptNumber : nickname }
    var category: StatusCategory { StatusCategory(statusTitle: statusTitle) }
    var serviceCenter: String? { ReceiptNumber.serviceCenter(for: receiptNumber) }
    var sortedEvents: [StatusEvent] { events.sorted { $0.date > $1.date } }

    /// Adds a timeline entry. It becomes the current status unless an existing entry is newer.
    @discardableResult
    func record(title: String, detail: String?, date: Date, source: StatusEvent.Source) -> StatusEvent {
        let isNewest = events.allSatisfy { $0.date <= date }
        let event = StatusEvent(date: date, title: title, detail: detail, source: source)
        events.append(event)
        if isNewest {
            statusTitle = title
            statusDetail = detail
            statusDate = date
        }
        return event
    }

    /// Resets the current status to the newest remaining timeline entry, e.g. after one is deleted.
    func syncStatusWithTimeline() {
        let latest = sortedEvents.first
        statusTitle = latest?.title
        statusDetail = latest?.detail
        statusDate = latest?.date
    }
}
