import SwiftData
import SwiftUI

struct CaseDetailView: View {
    @Bindable var trackedCase: TrackedCase

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showingUpdate = false
    @State private var confirmingDelete = false
    @State private var isRefreshing = false

    var body: some View {
        List {
            statusSection
            detailsSection
            timelineSection

            Section {
                Button("Stop Tracking Case", role: .destructive) { confirmingDelete = true }
            }
        }
        .navigationTitle(trackedCase.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { if trackedCase.isAutoTracked { await refresh() } }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if trackedCase.isAutoTracked {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Button("Check Now", systemImage: "arrow.clockwise") { Task { await refresh() } }
                    }
                }
                Button("Add Update", systemImage: "square.and.pencil") { showingUpdate = true }
            }
        }
        .sheet(isPresented: $showingUpdate) {
            ManualUpdateView(trackedCase: trackedCase)
        }
        .confirmationDialog("Stop tracking this case?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Case and History", role: .destructive) {
                context.delete(trackedCase)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("This removes the case and its timeline from this device. It doesn't affect your case with USCIS.")
        }
    }

    private var statusSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                StatusBadge(category: trackedCase.category)
                Text(trackedCase.statusTitle ?? "No status yet")
                    .font(.title3.weight(.semibold))
                if let date = trackedCase.statusDate {
                    Text(date, format: .dateTime.month(.wide).day().year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let detail = trackedCase.statusDetail {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(.vertical, 4)

            if let error = trackedCase.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            LabeledContent("Receipt") {
                Text(trackedCase.receiptNumber)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
            }
            TextField("Nickname", text: $trackedCase.nickname)
            if let form = trackedCase.formType {
                LabeledContent("Form", value: form)
            }
            if let center = trackedCase.serviceCenter {
                LabeledContent("Service center", value: center)
            }
            if let submitted = trackedCase.submittedDate {
                LabeledContent("Filed", value: submitted.formatted(date: .abbreviated, time: .omitted))
            }
            Toggle("Check automatically", isOn: $trackedCase.isAutoTracked)
            if trackedCase.isAutoTracked {
                LabeledContent("Last checked") {
                    if let checked = trackedCase.lastCheckedAt {
                        Text(checked, format: .relative(presentation: .named))
                    } else {
                        Text("Never")
                    }
                }
            }
        }
    }

    private var timelineSection: some View {
        Section("Timeline") {
            let events = trackedCase.sortedEvents
            if events.isEmpty {
                Text("Status changes will appear here.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    TimelineRow(event: event, isLatest: index == 0, isLast: index == events.count - 1)
                }
                .onDelete { offsets in
                    let removed = offsets.map { events[$0] }
                    trackedCase.events.removeAll { removed.contains($0) }
                    removed.forEach(context.delete)
                    trackedCase.syncStatusWithTimeline()
                    try? context.save()
                }
            }
        }
    }

    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let changes = await CaseRefresher.refresh([trackedCase], in: context)
        await NotificationManager.notify(changes)
    }
}

private struct TimelineRow: View {
    let event: StatusEvent
    let isLatest: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(isLatest ? StatusCategory(statusTitle: event.title).color : Color.secondary.opacity(0.4))
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.subheadline.weight(isLatest ? .semibold : .regular))
                HStack(spacing: 6) {
                    Text(event.date, format: .dateTime.month(.abbreviated).day().year())
                    Text("·")
                    Text(event.source.label)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let detail = event.detail, !isLatest || event.source == .manual {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
        }
    }
}
