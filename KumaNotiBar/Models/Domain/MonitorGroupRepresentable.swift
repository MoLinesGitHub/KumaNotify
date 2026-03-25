protocol MonitorGroupRepresentable: Identifiable, Sendable {
    associatedtype Monitor: MonitorRepresentable
    var id: String { get }
    var name: String { get }
    var weight: Int { get }
    var monitors: [Monitor] { get }
}
