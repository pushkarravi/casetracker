import BackgroundTasks
import Foundation
import SwiftData

/// Periodic status checks while the app isn't running. iOS decides the actual timing;
/// `earliestBeginDate` is only a lower bound.
enum BackgroundRefresh {
    /// Must match `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
    static let taskIdentifier = "com.pushkarravi.CaseTracker.refresh"
    static let interval: TimeInterval = 4 * 60 * 60

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        try? BGTaskScheduler.shared.submit(request)
    }

    @MainActor
    static func run(container: ModelContainer) async {
        schedule()
        guard USCISCredentials.isConfigured else { return }
        let changes = await CaseRefresher.refreshAll(in: container.mainContext)
        await NotificationManager.notify(changes)
    }
}
