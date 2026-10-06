import SwiftData
import SwiftUI

struct AddCaseView: View {
    let apiConfigured: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var existingCases: [TrackedCase]

    @State private var receipt = ""
    @State private var nickname = ""
    @State private var autoTrack = true
    @State private var initialStatus = ""

    private var normalized: String { ReceiptNumber.normalize(receipt) }
    private var isValid: Bool { ReceiptNumber.isValid(receipt) }
    private var isDuplicate: Bool { existingCases.contains { $0.receiptNumber == normalized } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. IOE0912345678", text: $receipt)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("Receipt Number")
                } footer: {
                    receiptFooter
                }

                Section("Nickname") {
                    TextField("e.g. My I-485", text: $nickname)
                }

                Section {
                    Toggle("Check automatically", isOn: $autoTrack)
                    if !autoTrack {
                        TextField("Current status (optional)", text: $initialStatus, axis: .vertical)
                    }
                } footer: {
                    Text(autoTrack
                         ? (apiConfigured
                            ? "The app checks USCIS and notifies you when the status changes."
                            : "Add your USCIS API credentials in Settings to turn on automatic checks.")
                         : "You'll record status updates yourself.")
                }
            }
            .navigationTitle("Add Case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: save)
                        .disabled(!isValid || isDuplicate)
                }
            }
        }
    }

    @ViewBuilder
    private var receiptFooter: some View {
        if receipt.isEmpty {
            Text("13 characters: 3 letters followed by 10 digits. Find it on your I-797 notice.")
        } else if isDuplicate {
            Text("You're already tracking this case.").foregroundStyle(.orange)
        } else if !isValid {
            Text("\(normalized.count)/13 characters: 3 letters followed by 10 digits.").foregroundStyle(.orange)
        } else if let center = ReceiptNumber.serviceCenter(for: normalized) {
            Label(center, systemImage: "building.columns")
        }
    }

    private func save() {
        let trackedCase = TrackedCase(
            receiptNumber: normalized,
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            isAutoTracked: autoTrack
        )
        context.insert(trackedCase)

        let status = initialStatus.trimmingCharacters(in: .whitespacesAndNewlines)
        if !autoTrack, !status.isEmpty {
            trackedCase.record(title: status, detail: nil, date: .now, source: .manual)
        }
        try? context.save()
        dismiss()

        guard autoTrack else { return }
        Task { @MainActor in
            await NotificationManager.requestAuthorization()
            if apiConfigured {
                _ = await CaseRefresher.refresh([trackedCase], in: context)
            }
        }
    }
}
