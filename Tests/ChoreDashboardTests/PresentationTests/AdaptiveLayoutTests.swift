import Testing
import Foundation
@testable import ChoreDashboard

@Suite("LeftColumnAdaptiveLayout Split Mathematics")
struct AdaptiveLayoutTests {

    @Test("Standard split assigns natural bottom height when within bounds")
    func testStandardSplitWithinQuota() {
        let (top, bottom) = LeftColumnAdaptiveLayout.calculateSplit(
            boundsHeight: 1000,
            bottomNaturalHeight: 250,
            maxBottomRatio: 0.40
        )

        #expect(bottom == 250)
        #expect(top == 750)
    }

    @Test("Natural bottom height is clamped to maxBottomRatio threshold")
    func testBottomHeightClamping() {
        let (top, bottom) = LeftColumnAdaptiveLayout.calculateSplit(
            boundsHeight: 1000,
            bottomNaturalHeight: 600, // Exceeds 40% (400pt)
            maxBottomRatio: 0.40
        )

        #expect(bottom == 400)
        #expect(top == 600)
    }

    @Test("Zero bounds height produces non-negative zero-dimension layouts")
    func testZeroBoundsHandling() {
        let (top, bottom) = LeftColumnAdaptiveLayout.calculateSplit(
            boundsHeight: 0,
            bottomNaturalHeight: 300,
            maxBottomRatio: 0.40
        )

        #expect(bottom == 0)
        #expect(top == 0)
    }

    @Test("Negative natural size input is clamped to zero floor")
    func testNegativeNaturalSizeClamping() {
        let (top, bottom) = LeftColumnAdaptiveLayout.calculateSplit(
            boundsHeight: 800,
            bottomNaturalHeight: -50,
            maxBottomRatio: 0.40
        )

        #expect(bottom == 0)
        #expect(top == 800)
    }
}