import SwiftUI

enum OnboardingViewLogic {
    static func normalizedSlug(from rawValue: String) -> String {
        ServerConnection.normalizedStatusPageSlug(from: rawValue)
    }

    static func normalizedServerName(from rawValue: String) -> String {
        ServerConnection.normalizedDisplayName(from: rawValue)
    }

    static func validatedServerURL(from rawValue: String) -> URL? {
        ServerConnection.validatedBaseURL(from: rawValue)
    }

    static func canContinue(serverURL: String, slug: String) -> Bool {
        validatedServerURL(from: serverURL) != nil
            && ServerConnection.validatedStatusPageSlug(from: slug) != nil
    }

    static func draftConnection(
        serverURL: String,
        slug: String,
        serverName: String
    ) -> ServerConnection? {
        guard let url = validatedServerURL(from: serverURL),
              let validatedSlug = ServerConnection.validatedStatusPageSlug(from: slug)
        else {
            return nil
        }

        return ServerConnection(
            name: normalizedServerName(from: serverName),
            baseURL: url,
            statusPageSlug: validatedSlug
        )
    }
}

struct OnboardingView: View {
    @Bindable var settingsStore: SettingsStore
    var onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var serverURL = ""
    @State private var slug = ""
    @State private var serverName = String(localized: "My Kuma Server")
    @State private var isTesting = false
    @State private var testResult: TestResult?

    private var normalizedSlug: String {
        OnboardingViewLogic.normalizedSlug(from: slug)
    }

    private var normalizedServerName: String {
        OnboardingViewLogic.normalizedServerName(from: serverName)
    }

    private var validatedServerURL: URL? {
        OnboardingViewLogic.validatedServerURL(from: serverURL)
    }

    private var canContinue: Bool {
        OnboardingViewLogic.canContinue(serverURL: serverURL, slug: slug)
    }

    enum TestResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: welcomeStep
                case 1: serverStep
                default: completionStep
                }
            }

            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i <= step ? Color(red: 0.722, green: 0.922, blue: 0.792) : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 20)
        }
        .frame(width: 440, height: 360)
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 56))
                .foregroundStyle(Color(red: 0.722, green: 0.922, blue: 0.792))
                .symbolEffect(.pulse)

            Text("Welcome to Kuma Control")
                .font(.title.bold())
                .accessibilityIdentifier("onboarding.welcomeTitle")

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
            .accessibilityIdentifier("onboarding.getStartedButton")
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
                    .accessibilityIdentifier("onboarding.serverURLField")
                TextField("Status Page Slug", text: $slug, prompt: Text("e.g. cortes"))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("onboarding.statusPageSlugField")
                TextField("Display Name", text: $serverName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("onboarding.displayNameField")
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
                .accessibilityIdentifier("onboarding.backButton")

                Spacer()

                Button("Test Connection") {
                    Task { await testConnection() }
                }
                .disabled(!canContinue || isTesting)
                .accessibilityIdentifier("onboarding.testConnectionButton")

                Button("Next") {
                    saveAndContinue()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canContinue)
                .accessibilityIdentifier("onboarding.nextButton")
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

            Text("Kuma Control is now monitoring your services.\nLook for the icon in your menu bar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Start Monitoring") {
                settingsStore.hasCompletedOnboarding = true
                onComplete()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("onboarding.startMonitoringButton")
            .padding(.bottom, 30)
        }
    }

    // MARK: - Actions

    private func testConnection() async {
        guard let url = validatedServerURL else {
            testResult = .failure(String(localized: "Invalid URL"))
            return
        }
        guard let validatedSlug = ServerConnection.validatedStatusPageSlug(from: slug) else {
            testResult = .failure(String(localized: "Invalid status page slug"))
            return
        }

        isTesting = true
        defer { isTesting = false }

        let connection = ServerConnection(
            name: normalizedServerName,
            baseURL: url,
            statusPageSlug: validatedSlug
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
        guard let connection = OnboardingViewLogic.draftConnection(
            serverURL: serverURL,
            slug: slug,
            serverName: serverName
        ) else { return }
        settingsStore.serverConnection = connection
        withAnimation { step = 2 }
    }
}
