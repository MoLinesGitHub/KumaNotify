import OSLog

extension Logger {
    static let app = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.molinesdesigns.kuma-notify",
        category: "app"
    )
}
