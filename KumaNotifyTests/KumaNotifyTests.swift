import XCTest
@testable import KumaNotify

final class KumaNotifyTests: XCTestCase {
    func testMonitorStatusRawValues() {
        XCTAssertEqual(MonitorStatus.up.rawValue, 1)
        XCTAssertEqual(MonitorStatus.down.rawValue, 0)
        XCTAssertEqual(MonitorStatus.pending.rawValue, 2)
        XCTAssertEqual(MonitorStatus.maintenance.rawValue, 3)
    }

    func testMonitorStatusLabelsNotEmpty() {
        for status in MonitorStatus.allCases {
            XCTAssertFalse(status.label.isEmpty)
        }
    }

    func testOverallStatusLabels() {
        XCTAssertFalse(OverallStatus.allUp.label.isEmpty)
        XCTAssertFalse(OverallStatus.unreachable.label.isEmpty)
        XCTAssertFalse(OverallStatus.someDown(count: 2, total: 5).label.isEmpty)
    }

    func testIncidentTransitionType() {
        XCTAssertEqual(IncidentTransitionType.wentDown.rawValue, "went_down")
        XCTAssertEqual(IncidentTransitionType.recovered.rawValue, "recovered")
        XCTAssertFalse(IncidentTransitionType.wentDown.label.isEmpty)
        XCTAssertFalse(IncidentTransitionType.recovered.label.isEmpty)
    }
}
