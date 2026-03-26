import os

extension Logger {
    private static let subsystem = "com.molinesdesigns.kuma-notify"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let network = Logger(subsystem: subsystem, category: "network")
}
