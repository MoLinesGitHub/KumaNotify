import SwiftUI

struct OnboardingView: View {
    @Bindable var settingsStore: SettingsStore
    var onComplete: () -> Void

    @State private var step = 0
    @State private var serverURL = ""
    @State private var slug = ""
    @State private var serverName = "My Kuma Server"
    @State private var isTesting = false
    @State private var testResult: TestResult?

    enum TestResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i <= step ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)

            TabView(selection: $step) {
                welcomeStep.tag(0)
                serverStep.tag(1)
                completionStep.tag(2)
            }
            .tabViewStyle(.automatic)
        }
        .frame(width: 440, height: 360)
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse)

            Text("Welcome to Kuma Notify")
                .font(.title.bold())

            Text("Monitor your services directly from the menu bar.\nGet instant notifications when something goes down.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Spacer()

            Button("Get Started") {
                withAnimation { step = 1 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Step 2: Server Setup

    private var serverStep: some View {
        VStack(spacing: 16) {
            Text("Connect Your Server")
                .font(.title2.bold())
                .padding(.top, 20)

            Form {
                TextField("Server URL", text: $serverURL, prompt: Text("http://192.168.1.100:3001"))
                    .textFieldStyle(.roundedBorder)
                TextField("Status Page Slug", text: $slug, prompt: Text("e.g. cortes"))
                    .textFieldStyle(.roundedBorder)
                TextField("Display Name", text: $serverName)
                    .textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            if let result = testResult {
                switch result {
                case .success(let title):
                    Label(String(format: String(localized: "Connected: %@"), title), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                case .failure(let error):
                    Label(error, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            HStack {
                Button("Back") {
                    withAnimation { step = 0 }
                }

                Spacer()

                Button("Test Connection") {
                    Task { await testConnection() }
                }
                .disabled(serverURL.isEmpty || slug.isEmpty || isTesting)

                Button("Next") {
                    saveAndContinue()
                }
                .buttonStyle(.borderedProminent)
                .disabled(serverURL.isEmpty || slug.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Step 3: Done

    private var completionStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.title.bold())

            Text("Kuma Notify is now monitoring your services.\nLook for the icon in your menu bar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Start Monitoring") {
                settingsStore.hasCompletedOnboarding = true
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Actions

    private func testConnection() async {
        guard let url = URL(string: serverURL) else {
            testResult = .failure("Invalid URL")
            return
        }

        isTesting = true
        defer { isTesting = false }

        let connection = ServerConnection(
            name: serverName,
            baseURL: url,
            statusPageSlug: slug
        )

        let service = UptimeKumaService()
        do {
            let result = try await service.fetchStatusPage(connection: connection)
            testResult = .success(result.title)
        } catch {
            testResult = .failure(error.localizedDescription)
        }
    }

    private func saveAndContinue() {
        guard let url = URL(string: serverURL) else { return }
        settingsStore.serverConnection = ServerConnection(
            name: serverName,
            baseURL: url,
            statusPageSlug: slug
        )
        withAnimation { step = 2 }
    }
}
