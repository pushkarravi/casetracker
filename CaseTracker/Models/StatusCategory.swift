import SwiftUI

/// A coarse bucket for USCIS status text, used for badge color and icon.
/// USCIS has dozens of status titles; this keyword matching keeps the UI readable without a full table.
enum StatusCategory: String, CaseIterable {
    case received
    case inProgress
    case actionNeeded
    case approved
    case completed
    case denied
    case unknown

    init(statusTitle: String?) {
        guard let title = statusTitle?.lowercased(), !title.isEmpty else {
            self = .unknown
            return
        }
        func has(_ words: String...) -> Bool { words.contains { title.contains($0) } }

        if has("response to") {
            // e.g. "Response To USCIS' Request For Evidence Was Received"
            self = .inProgress
        } else if has("denied", "rejected", "terminated", "revoked", "abandoned", "withdrawal acknowledg") {
            self = .denied
        } else if has("evidence was sent", "request for evidence", "request for additional evidence", "intent to deny", "intent to revoke") {
            self = .actionNeeded
        } else if has("card", "document", "green card", "travel")
                    && has("mailed", "delivered", "picked up") {
            self = .completed
        } else if has("approved", "approval", "being produced", "was produced", "oath ceremony was completed") {
            self = .approved
        } else if has("received") {
            self = .received
        } else {
            self = .inProgress
        }
    }

    var label: String {
        switch self {
        case .received: "Received"
        case .inProgress: "In Progress"
        case .actionNeeded: "Action Needed"
        case .approved: "Approved"
        case .completed: "Delivered"
        case .denied: "Denied"
        case .unknown: "No Status"
        }
    }

    var symbol: String {
        switch self {
        case .received: "tray.and.arrow.down.fill"
        case .inProgress: "hourglass"
        case .actionNeeded: "exclamationmark.triangle.fill"
        case .approved: "checkmark.seal.fill"
        case .completed: "shippingbox.fill"
        case .denied: "xmark.octagon.fill"
        case .unknown: "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .received: .blue
        case .inProgress: .indigo
        case .actionNeeded: .orange
        case .approved: .green
        case .completed: .teal
        case .denied: .red
        case .unknown: .gray
        }
    }
}
