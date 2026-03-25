import XCTest
@testable import KumaNotiBar

final class KumaNotiBarTests: XCTestCase {
    func testMonitorStatusColors() {
        XCTAssertEqual(MonitorStatus.up.label, "Up")
        XCTAssertEqual(MonitorStatus.down.label, "Down")
    }
}
