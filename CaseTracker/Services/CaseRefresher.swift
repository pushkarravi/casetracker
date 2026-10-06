import Foundation
import SwiftData

/// Checks auto-tracked cases against USCIS and records status changes.
@MainActor
enum CaseRefresher {
    struct Change: Equatable {
        let receiptNumber: String
        let caseName: String
        let newStatus: String
    }

    /// Cases not checked within this window are refreshed when the app comes to the foreground.
    static let staleInterval: TimeInterval = 30 * 60

    static func refreshAll(in context: ModelContext) async -> [Change] {
        let descriptor = FetchDescriptor<TrackedCase>(predicate: #Predicate { $0.isAutoTracked })
        let cases = (try? context.fetch(descriptor)) ?? []
        return await refresh(cases, in: context)
    }

    static func refresh(_ cases: [TrackedCase], in context: ModelContext, client: USCISClient = .shared) async -> [Change] {
        var changes: [Change] = []
        for (index, trackedCase) in cases.filter(\.isAutoTracked).enumerated() {
            // Stay well under the API's 5 requests/second limit.
            if index > 0 { try? await Task.sleep(for: .milliseconds(300)) }
            do {
                let result = try await client.fetchStatus(receiptNumber: trackedCase.receiptNumber)
                if let change = apply(result, to: trackedCase) { changes.append(change) }
                trackedCase.lastError = nil
                trackedCase.lastCheckedAt = .now
            } catch let error as USCISError {
                trackedCase.lastError = error.localizedDescription
                // Credential problems affect every case; don't hammer the API.
                if error == .notConfigured || error == .invalidCredentials || error == .rateLimited { break }
            } catch {
                trackedCase.lastError = error.localizedDescription
            }
        }
        try? context.save()
        return changes
    }

    /// Merges an API result into a case. Returns a change when the status differs from what we had,
    /// except on the very first fetch (nothing to compare against, so no notification).
    @discardableResult
    static func apply(_ result: CaseStatusResult, to trackedCase: TrackedCase, now: Date = .now) -> Change? {
        trackedCase.formType = result.formType ?? trackedCase.formType
        trackedCase.submittedDate = result.submittedDate ?? trackedCase.submittedDate

        let previousStatus = trackedCase.statusTitle
        let isFirstFetch = previousStatus == nil

        if trackedCase.events.isEmpty {
            for entry in result.history where entry.title != result.statusTitle {
                trackedCase.record(title: entry.title, detail: nil, date: entry.date, source: .uscisHistory)
            }
        }

        guard result.statusTitle != previousStatus else {
            trackedCase.statusDetail = result.statusDetail ?? trackedCase.statusDetail
            return nil
        }

        let statusDate = result.modifiedDate ?? now
        trackedCase.record(title: result.statusTitle, detail: result.statusDetail, date: statusDate, source: .uscis)
        // The live API status is authoritative even if a manual entry carries a later date.
        trackedCase.statusTitle = result.statusTitle
        trackedCase.statusDetail = result.statusDetail
        trackedCase.statusDate = statusDate

        guard !isFirstFetch else { return nil }
        return Change(receiptNumber: trackedCase.receiptNumber, caseName: trackedCase.displayName, newStatus: result.statusTitle)
    }
}
