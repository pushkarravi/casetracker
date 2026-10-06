import SwiftData
import SwiftUI

struct ManualUpdateView: View {
    let trackedCase: TrackedCase

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selection = Self.commonStatuses[0]
    @State private var customTitle = ""
    @State private var date = Date.now
    @State private var note = ""

    private static let custom = "Custom…"
    static let commonStatuses = [
        "Case Was Received",
        "Fingerprint Fee Was Received",
        "Case Was Updated To Show Fingerprints Were Taken",
        "Interview Was Scheduled",
        "Request for Additional Evidence Was Sent",
        "Response To USCIS' Request For Evidence Was Received",
        "Case Is Being Actively Reviewed By USCIS",
        "Case Was Transferred To Another Office",
        "Case Was Approved",
        "New Card Is Being Produced",
        "Card Was Mailed To Me",
        "Card Was Delivered To Me By The Post Office",
        "Case Was Denied",
    ]

    private var title: String {
        (selection == Self.custom ? customTitle : selection).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    Picker("Status", selection: $selection) {
                        ForEach(Self.commonStatuses + [Self.custom], id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.navigationLink)
                    if selection == Self.custom {
                        TextField("Status title", text: $customTitle)
                    }
                    DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                }
                Section("Note") {
                    TextField("Optional details", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let detail = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        trackedCase.record(title: title, detail: detail.isEmpty ? nil : detail, date: date, source: .manual)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
