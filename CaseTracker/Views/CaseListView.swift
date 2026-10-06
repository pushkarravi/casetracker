import SwiftData
import SwiftUI

struct CaseListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \TrackedCase.createdAt, order: .reverse) private var cases: [TrackedCase]

    @State private var showingAdd = false
    @State private var showingSettings = false
    @State private var apiConfigured = USCISCredentials.isConfigured
    @State private var isRefreshing = false

    private var needsAPISetup: Bool {
        !apiConfigured && cases.contains(where: \.isAutoTracked)
    }

    var body: some View {
        NavigationStack {
            Group {
                if cases.isEmpty {
                    emptyState
                } else {
                    caseList
                }
            }
            .navigationTitle("Cases")
            .navigationDestination(for: TrackedCase.self) { CaseDetailView(trackedCase: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Case", systemImage: "plus") { showingAdd = true }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddCaseView(apiConfigured: apiConfigured)
            }
            .sheet(isPresented: $showingSettings, onDismiss: {
                apiConfigured = USCISCredentials.isConfigured
                Task { await refresh(force: false) }
            }) {
                SettingsView()
            }
        }
        .task { await refresh(force: false) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh(force: false) } }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Cases Yet", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("Add a USCIS receipt number to track its status and get notified when it changes.")
        } actions: {
            Button("Add Case") { showingAdd = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var caseList: some View {
        List {
            if needsAPISetup {
                Section {
                    Button {
                        showingSettings = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Connect the USCIS API").font(.subheadline.weight(.semibold))
                                Text("Automatic status checks need your developer.uscis.gov credentials.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "key.fill").foregroundStyle(.orange)
                        }
                    }
                }
            }

            Section {
                ForEach(cases) { trackedCase in
                    NavigationLink(value: trackedCase) {
                        CaseRow(trackedCase: trackedCase)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .refreshable { await refresh(force: true) }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(cases[index]) }
        try? context.save()
    }

    private func refresh(force: Bool) async {
        apiConfigured = USCISCredentials.isConfigured
        guard apiConfigured, !isRefreshing else { return }
        let targets = cases.filter { trackedCase in
            guard trackedCase.isAutoTracked else { return false }
            guard !force, let checked = trackedCase.lastCheckedAt else { return true }
            return Date.now.timeIntervalSince(checked) > CaseRefresher.staleInterval
        }
        guard !targets.isEmpty else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let changes = await CaseRefresher.refresh(targets, in: context)
        await NotificationManager.notify(changes)
    }
}

struct CaseRow: View {
    let trackedCase: TrackedCase

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(trackedCase.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if let form = trackedCase.formType {
                    Text(form)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if !trackedCase.nickname.isEmpty {
                Text(trackedCase.receiptNumber)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Text(trackedCase.statusTitle ?? (trackedCase.isAutoTracked ? "Waiting for first check…" : "No status recorded"))
                .font(.subheadline)
                .foregroundStyle(trackedCase.statusTitle == nil ? .secondary : .primary)
                .lineLimit(2)

            HStack {
                StatusBadge(category: trackedCase.category)
                Spacer()
                if trackedCase.lastError != nil {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Last check failed")
                }
                if let date = trackedCase.statusDate {
                    Text(date, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !trackedCase.isAutoTracked {
                    Image(systemName: "hand.raised")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Manually tracked")
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CaseListView()
        .modelContainer(for: [TrackedCase.self, StatusEvent.self], inMemory: true)
}
