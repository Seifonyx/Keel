import XCTest
@testable import KeelCore

final class KeelErrorExplainerTests: XCTestCase {
    func testSignInADIErrorOffersServerFix() {
        let e = KeelErrorExplainer.explain(domain: "AnisetteKit", code: -45063,
            text: "ADI native error (-45063): ADIProvisioningStart failed (Pending ADI session (-45063)): -45063")
        XCTAssertEqual(e.fix, .signInServer)
        XCTAssertEqual(e.title, "Apple didn't accept the sign-in")
        XCTAssertTrue(e.technical.contains("-45063"))
    }

    func testAppleSignIn503OffersServerFix() {
        let e = KeelErrorExplainer.explain(domain: "SideSign", code: 503, text: "Apple ID sign-in failed: HTTP 503 from GSA")
        XCTAssertEqual(e.fix, .signInServer)
    }

    func testVPNOff() {
        let e = KeelErrorExplainer.explain(domain: "Minimuxer", code: 2, text: "noVPN: LocalDevVPN is not connected")
        XCTAssertEqual(e.fix, .turnOnVPN)
    }

    func testPairing() {
        XCTAssertEqual(KeelErrorExplainer.explain(domain: "x", code: 1, text: "Invalid pairing file").fix, .replacePairingFile)
    }

    func testOffline() {
        let e = KeelErrorExplainer.explain(NSError(domain: "NSURLErrorDomain", code: -1009,
            userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]))
        XCTAssertEqual(e.title, "You're offline")
    }

    func testUnknownKeepsOriginalText() {
        let e = KeelErrorExplainer.explain(domain: "x", code: 9, text: "Weird thing happened")
        XCTAssertEqual(e.title, "Something went wrong")
        XCTAssertEqual(e.message, "Weird thing happened")
        XCTAssertNil(e.fix)
    }
}
