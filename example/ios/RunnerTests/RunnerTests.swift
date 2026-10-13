import Testing
import UIKit

@testable import duo_display

struct ConversionTests {
  @Test func rectKeepsPointsUnchanged() {
    let rect = RectMessage(CGRect(x: 455.5, y: 0, width: 40, height: 669))
    #expect(rect == RectMessage(x: 455.5, y: 0, width: 40, height: 669))
  }

  @Test @available(iOS 27.1, *)
  func hingeStatusMapsOneToOne() {
    #expect(HingeStatusMessage(.closed) == .closed)
    #expect(HingeStatusMessage(.partiallyOpen) == .partiallyOpen)
    #expect(HingeStatusMessage(.fullyOpen) == .fullyOpen)
    #expect(HingeStatusMessage(.unknown) == .unknown)
  }

  @Test @available(iOS 27.1, *)
  func verticalBarEdgeMapsOneToOne() {
    #expect(VerticalBarEdgeMessage(.trailing) == .trailing)
    #expect(VerticalBarEdgeMessage(.leading) == .leading)
    #expect(VerticalBarEdgeMessage(.unspecified) == .unspecified)
  }
}
