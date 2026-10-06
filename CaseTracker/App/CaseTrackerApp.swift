import SwiftData
import SwiftUI
import UserNotifications

@main
struct CaseTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: TrackedCase.self, StatusEvent.self)
        } catch {
            fatalError("Could not open the case database: \(error)")
        }
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            CaseListView()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { BackgroundRefresh.schedule() }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskIdentifier)) { [container] in
            await BackgroundRefresh.run(container: container)
        }
    }
}
