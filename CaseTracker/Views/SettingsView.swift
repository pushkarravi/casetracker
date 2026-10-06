import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @AppStorage(USCISEnvironment.storageKey) private var environment: USCISEnvironment = .sandbox
    @AppStorage(NotificationManager.enabledKey) private var notifyOnChange = true

    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var connectionMessage: (text: String, isError: Bool)?
    @State private var isTesting = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private var hasUnsavedCredentials: Bool {
        USCISCredentials(clientId: clientId, clientSecret: clientSecret) != USCISCredentials.load()
    }

    var body: some View {
        NavigationStack {
            Form {
                apiSection
                notificationsSection

                Section("Testing") {
                    Text("In Sandbox, try receipt number **EAC9999103402**. Sandbox data is fake and limited to 1,000 requests a day.")
                        .font(.footnote)
                }

                Section {
                    Text("Case Tracker isn't affiliated with USCIS. It reads your case status through the official USCIS Case Status API. Your credentials stay in this device's Keychain.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                let saved = USCISCredentials.load()
                clientId = saved?.clientId ?? ""
                clientSecret = saved?.clientSecret ?? ""
                notificationStatus = await NotificationManager.authorizationStatus()
            }
            .onChange(of: environment) {
                connectionMessage = nil
                Task { await USCISClient.shared.clearToken() }
            }
        }
    }

    private var apiSection: some View {
        Section {
            Picker("Environment", selection: $environment) {
                ForEach(USCISEnvironment.allCases) { Text($0.label).tag($0) }
            }
            TextField("Client ID", text: $clientId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Client Secret", text: $clientSecret)

            Button("Save and Test Connection") {
                Task { await saveAndTest() }
            }
            .disabled(clientId.isEmpty || clientSecret.isEmpty || isTesting)

            if isTesting {
                ProgressView()
            } else if let connectionMessage {
                Label(connectionMessage.text, systemImage: connectionMessage.isError ? "xmark.circle" : "checkmark.circle")
                    .foregroundStyle(connectionMessage.isError ? .red : .green)
                    .font(.footnote)
            }

            if USCISCredentials.isConfigured {
                Button("Remove Credentials", role: .destructive) {
                    USCISCredentials.clear()
                    clientId = ""
                    clientSecret = ""
                    connectionMessage = nil
                    Task { await USCISClient.shared.clearToken() }
                }
            }
        } header: {
            Text("USCIS API")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Automatic checks use the official USCIS Case Status API. Register an app at developer.uscis.gov to get a client ID and secret. Sandbox keys work right away; production keys need USCIS approval.")
                Link("Open developer.uscis.gov", destination: URL(string: "https://developer.uscis.gov")!)
            }
        }
    }

    private var notificationsSection: some View {
        Section {
            Toggle("Notify on status change", isOn: $notifyOnChange)
            switch notificationStatus {
            case .denied:
                Button("Allow Notifications in iOS Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
            case .notDetermined:
                Button("Allow Notifications") {
                    Task {
                        await NotificationManager.requestAuthorization()
                        notificationStatus = await NotificationManager.authorizationStatus()
                    }
                }
            default:
                EmptyView()
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("The app checks in the background every few hours. iOS decides exactly when, based on how often you use the app. Opening the app or pulling to refresh always checks right away.")
        }
    }

    private func saveAndTest() async {
        let credentials = USCISCredentials(
            clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines),
            clientSecret: clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        credentials.save()
        isTesting = true
        defer { isTesting = false }
        do {
            try await USCISClient.shared.testConnection()
            connectionMessage = ("Connected to USCIS \(environment.label).", false)
        } catch {
            connectionMessage = (error.localizedDescription, true)
        }
    }
}
