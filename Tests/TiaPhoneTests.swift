import XCTest
@testable import TiaPhone

/// Part 1 regression tests — the HMI-buttons-do-nothing failure, ported to
/// the real engine. Written against the pre-fix engine first: the lost-tap,
/// frozen-input and address-binding tests are expected to FAIL there and
/// pass after the Part 1 fix (separate PLCSIM/HMI input layers merged into
/// a frozen input image, pulse-stretched HMI writes, address resolution).
final class TiaPhoneTests: XCTestCase {

    private func makeSim() -> (Simulator, PlcDevice) {
        let sim = Simulator()
        let device = TiaProject.motorProject().devices[0]
        sim.attach(device)
        return (sim, device)
    }

    func testHMIOnLatchesMotorAndStaysAfterRelease() {
        let (sim, _) = makeSim()
        sim.setHMIInput("BtnOn", true)
        sim.scanOnce()
        XCTAssertEqual(sim.values["Motor"], true)
        sim.setHMIInput("BtnOn", false)
        for _ in 0..<5 { sim.scanOnce() }
        XCTAssertEqual(sim.values["Motor"], true)
    }

    func testHMIOffUnlatchesMotor() {
        let (sim, _) = makeSim()
        sim.setHMIInput("BtnOn", true); sim.scanOnce()
        sim.setHMIInput("BtnOn", false); sim.scanOnce()
        XCTAssertEqual(sim.values["Motor"], true)
        sim.setHMIInput("BtnOff", true); sim.scanOnce()
        XCTAssertEqual(sim.values["Motor"], false)
    }

    func testPLCSIMOffNeverOverwritesHMIOn() {
        let (sim, _) = makeSim()
        sim.setInput("BtnOn", false)          // PLCSIM switch sits at OFF
        sim.setHMIInput("BtnOn", true)        // HMI says ON
        sim.scanOnce()
        XCTAssertEqual(sim.values["Motor"], true)
    }

    func testPLCSIMSwitchesAloneDriveLatch() {
        let (sim, _) = makeSim()
        sim.setInput("BtnOn", true); sim.scanOnce()
        sim.setInput("BtnOn", false); sim.scanOnce()
        XCTAssertEqual(sim.values["Motor"], true)
        sim.setInput("BtnOff", true); sim.scanOnce()
        XCTAssertEqual(sim.values["Motor"], false)
    }

    func testSubScanTapIsNeverLost() {
        let (sim, _) = makeSim()
        sim.setHMIInput("BtnOn", true)
        sim.setHMIInput("BtnOn", false)       // pressed and released between scans
        sim.scanOnce()
        XCTAssertEqual(sim.values["Motor"], true)
    }

    func testInputsFrozenDuringScan() {
        // Network 1 writes coil "BtnOff"; network 2 reads BtnOff as an input.
        // With frozen inputs, network 2 still sees the value from scan start.
        let sim = Simulator()
        var device = PlcDevice()
        device.tags = [
            PlcTag(name: "BtnOn", dataType: "Bool", address: "%I0.0"),
            PlcTag(name: "BtnOff", dataType: "Bool", address: "%I0.1"),
            PlcTag(name: "Motor", dataType: "Bool", address: "%Q0.0")
        ]
        func el(_ k: LadElementKind, _ t: String) -> LadElement { LadElement(kind: k, tag: t) }
        device.blocks = [PlcBlock(name: "Main", number: 1, type: "OB", networks: [
            LadNetwork(title: "writer", series: [el(.contactNO, "BtnOn")], output: el(.coil, "BtnOff")),
            LadNetwork(title: "reader", series: [el(.contactNC, "BtnOff")], output: el(.coil, "Motor"))
        ])]
        sim.attach(device)
        sim.setInput("BtnOn", true)
        sim.scanOnce()
        XCTAssertEqual(sim.values["Motor"], true)
    }

    func testHMIBindsByAddress() {
        let (sim, _) = makeSim()
        sim.setHMIInput("%I0.0", true)        // bound by address, not by name
        sim.scanOnce()
        XCTAssertEqual(sim.values["Motor"], true)
    }
}
