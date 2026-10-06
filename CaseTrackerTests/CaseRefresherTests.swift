import Foundation
import SwiftData
import Testing
@testable import CaseTracker

@MainActor
struct CaseRefresherTests {
    let container = try! ModelContainer(
        for: TrackedCase.self, StatusEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    private func makeCase() -> TrackedCase {
        let trackedCase = TrackedCase(receiptNumber: "IOE0912345678", nickname: "Mine", isAutoTracked: true)
        container.mainContext.insert(trackedCase)
        return trackedCase
    }

    private func result(_ title: String, history: [CaseStatusResult.HistoryEntry] = []) -> CaseStatusResult {
        CaseStatusResult(
            receiptNumber: "IOE0912345678", formType: "I-485", submittedDate: nil,
            modifiedDate: Date(timeIntervalSince1970: 1_700_000_000), statusTitle: title,
            statusDetail: "Details", history: history
        )
    }

    @Test func firstFetchImportsHistoryWithoutNotifying() {
        let trackedCase = makeCase()
        let history = [CaseStatusResult.HistoryEntry(date: Date(timeIntervalSince1970: 1_600_000_000), title: "Case Was Received")]

        let change = CaseRefresher.apply(result("Case Was Approved", history: history), to: trackedCase)

        #expect(change == nil)
        #expect(trackedCase.statusTitle == "Case Was Approved")
        #expect(trackedCase.formType == "I-485")
        #expect(trackedCase.sortedEvents.map(\.title) == ["Case Was Approved", "Case Was Received"])
        #expect(trackedCase.sortedEvents.last?.source == .uscisHistory)
    }

    @Test func statusChangeIsReportedOnce() {
        let trackedCase = makeCase()
        CaseRefresher.apply(result("Case Was Received"), to: trackedCase)

        let change = CaseRefresher.apply(result("Case Was Approved"), to: trackedCase)
        #expect(change == .init(receiptNumber: "IOE0912345678", caseName: "Mine", newStatus: "Case Was Approved"))

        #expect(CaseRefresher.apply(result("Case Was Approved"), to: trackedCase) == nil)
        #expect(trackedCase.events.count == 2)
    }

    @Test func manualRecordOnlyBecomesCurrentWhenNewest() {
        let trackedCase = makeCase()
        trackedCase.record(title: "Interview Was Scheduled", detail: nil, date: .now, source: .manual)
        trackedCase.record(title: "Case Was Received", detail: nil, date: .now.addingTimeInterval(-86_400), source: .manual)
        #expect(trackedCase.statusTitle == "Interview Was Scheduled")

        trackedCase.events.removeAll { $0.title == "Interview Was Scheduled" }
        trackedCase.syncStatusWithTimeline()
        #expect(trackedCase.statusTitle == "Case Was Received")
    }
}
