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

/// v4.0 tests — the extended instruction set and engine: numeric
/// operands, comparators, math/MOVE, SR/RS, CTUD, TONR, PID on the
/// built-in process model, SCL blocks, data-block operands, the force
/// table, jumps and multiple parallel branches.
final class TiaPhoneV4Tests: XCTestCase {

    private func el(_ k: LadElementKind, _ t: String) -> LadElement { LadElement(kind: k, tag: t) }

    private func device(tags: [PlcTag], networks: [LadNetwork], dbs: [PlcDataBlock] = []) -> PlcDevice {
        var d = PlcDevice()
        d.tags = tags
        d.blocks = [PlcBlock(name: "Main", number: 1, type: "OB", networks: networks)]
        if !dbs.isEmpty { d.dataBlocks = dbs }
        return d
    }

    func testMathAndMoveWriteNumericOperands() {
        var add = LadElement(kind: .math, tag: "A")
        add.op = "ADD"; add.inputTag = "B"; add.outTag = "C"
        let mv = LadElement(kind: .move, tag: "C", outTag: "D")
        var mvEl = mv; mvEl.outTag = "D"
        let d = device(tags: [
            PlcTag(name: "En", dataType: "Bool", address: "%I0.0"),
            PlcTag(name: "A", dataType: "Real", address: "%MD0"),
            PlcTag(name: "B", dataType: "Real", address: "%MD4"),
            PlcTag(name: "C", dataType: "Real", address: "%MD8"),
            PlcTag(name: "D", dataType: "Real", address: "%MD12"),
            PlcTag(name: "Done", dataType: "Bool", address: "%Q0.0")
        ], networks: [
            LadNetwork(title: "add", series: [el(.contactNO, "En"), add], output: el(.coil, "Done")),
            LadNetwork(title: "move", series: [el(.contactNO, "En"), mvEl], output: el(.coil, "Done"))
        ])
        let sim = Simulator(); sim.attach(d)
        sim.setOperandNum("A", 7); sim.setOperandNum("B", 5)
        sim.setInput("En", true)
        sim.scanOnce()
        XCTAssertEqual(sim.num("C"), 12)
        XCTAssertEqual(sim.num("D"), 12)
    }

    func testComparatorGatesRung() {
        var cmp = LadElement(kind: .cmp, tag: "Level")
        cmp.op = "GT"; cmp.useConst = true; cmp.constValue = 10
        let d = device(tags: [
            PlcTag(name: "Level", dataType: "Real", address: "%MD0"),
            PlcTag(name: "Big", dataType: "Bool", address: "%Q0.0")
        ], networks: [
            LadNetwork(title: "cmp", series: [cmp], output: el(.coil, "Big"))
        ])
        let sim = Simulator(); sim.attach(d)
        sim.setOperandNum("Level", 12); sim.scanOnce()
        XCTAssertEqual(sim.values["Big"], true)
        sim.setOperandNum("Level", 3); sim.scanOnce()
        XCTAssertEqual(sim.values["Big"], false)
    }

    func testSRResetDominantRSSetDominant() {
        var sr = LadElement(kind: .sr, tag: "Qsr", instance: "SR_1"); sr.inputTag = "Rst"
        var rs = LadElement(kind: .rs, tag: "Qrs", instance: "RS_1"); rs.inputTag = "Rst"
        let d = device(tags: [
            PlcTag(name: "Set", dataType: "Bool", address: "%I0.0"),
            PlcTag(name: "Rst", dataType: "Bool", address: "%I0.1"),
            PlcTag(name: "Qsr", dataType: "Bool", address: "%Q0.0"),
            PlcTag(name: "Qrs", dataType: "Bool", address: "%Q0.1")
        ], networks: [
            LadNetwork(title: "sr", series: [el(.contactNO, "Set"), sr], output: el(.coil, "Qsr")),
            LadNetwork(title: "rs", series: [el(.contactNO, "Set"), rs], output: el(.coil, "Qrs"))
        ])
        let sim = Simulator(); sim.attach(d)
        sim.setInput("Set", true); sim.scanOnce()
        XCTAssertEqual(sim.values["Qsr"], true)
        XCTAssertEqual(sim.values["Qrs"], true)
        sim.setInput("Rst", true); sim.scanOnce()   // both S and R true
        XCTAssertEqual(sim.values["Qsr"], false)    // SR: reset wins
        XCTAssertEqual(sim.values["Qrs"], true)     // RS: set wins
        sim.setInput("Set", false); sim.scanOnce()  // R alone
        XCTAssertEqual(sim.values["Qrs"], false)
    }

    func testCTUDCountsUpAndDown() {
        var ctud = LadElement(kind: .ctud, tag: "Full", instance: "C_1")
        ctud.presetValue = 3; ctud.preset = "3"; ctud.inputTag = "Down"
        let d = device(tags: [
            PlcTag(name: "Up", dataType: "Bool", address: "%I0.0"),
            PlcTag(name: "Down", dataType: "Bool", address: "%I0.1"),
            PlcTag(name: "Full", dataType: "Bool", address: "%Q0.0")
        ], networks: [
            LadNetwork(title: "ctud", series: [el(.contactNO, "Up"), ctud], output: el(.coil, "Full"))
        ])
        let sim = Simulator(); sim.attach(d)
        for _ in 0..<3 {
            sim.setInput("Up", true); sim.scanOnce()
            sim.setInput("Up", false); sim.scanOnce()
        }
        XCTAssertEqual(sim.counts["C_1"], 3)
        XCTAssertEqual(sim.values["Full"], true)
        sim.setInput("Down", true); sim.scanOnce()
        sim.setInput("Down", false); sim.scanOnce()
        XCTAssertEqual(sim.counts["C_1"], 2)
        XCTAssertEqual(sim.values["Full"], false)
    }

    func testTONRAccumulatesAcrossGaps() {
        var tonr = LadElement(kind: .tonr, tag: "Done", instance: "T_1")
        tonr.presetSeconds = 1.0; tonr.preset = "T#1s"; tonr.inputTag = "Rst"
        let d = device(tags: [
            PlcTag(name: "Run", dataType: "Bool", address: "%I0.0"),
            PlcTag(name: "Rst", dataType: "Bool", address: "%I0.1"),
            PlcTag(name: "Done", dataType: "Bool", address: "%Q0.0")
        ], networks: [
            LadNetwork(title: "tonr", series: [el(.contactNO, "Run"), tonr], output: el(.coil, "Done"))
        ])
        let sim = Simulator(); sim.attach(d)
        sim.setInput("Run", true)
        for _ in 0..<6 { sim.scanOnce() }            // 0.6 s accumulated
        XCTAssertEqual(sim.values["Done"], false)
        sim.setInput("Run", false)
        for _ in 0..<10 { sim.scanOnce() }           // gap: TONR holds its ET
        sim.setInput("Run", true)
        for _ in 0..<5 { sim.scanOnce() }            // 1.1 s total
        XCTAssertEqual(sim.values["Done"], true)
        sim.setInput("Rst", true); sim.scanOnce()    // reset clears the accumulator
        XCTAssertEqual(sim.values["Done"], false)
        XCTAssertEqual(sim.timerET["T_1"] ?? -1, 0)
    }

    func testPIDConvergesOnTankProcess() {
        let sim = Simulator()
        sim.attach(TiaProject.pidProject().devices[0])
        for _ in 0..<1200 { sim.scanOnce() }         // 120 simulated seconds
        let pv = sim.num("TankTemp")
        XCTAssertGreaterThan(pv, 52, "PID should heat the tank toward the 60 °C setpoint, got \(pv)")
        XCTAssertLessThan(pv, 68, "PID overshoot should stay bounded, got \(pv)")
        let out = sim.num("HeaterPower")
        XCTAssertGreaterThanOrEqual(out, 0)
        XCTAssertLessThanOrEqual(out, 100)
        XCTAssertGreaterThan(sim.history["TankTemp"]?.count ?? 0, 100)
    }

    func testSCLAssignmentAndIf() {
        var d = PlcDevice()
        d.tags = [
            PlcTag(name: "BtnOn", dataType: "Bool", address: "%I0.0"),
            PlcTag(name: "Motor", dataType: "Bool", address: "%Q0.0"),
            PlcTag(name: "Level", dataType: "Real", address: "%MD0"),
            PlcTag(name: "Alarm", dataType: "Bool", address: "%Q0.1")
        ]
        var main = PlcBlock(name: "Main", number: 1, type: "OB")
        main.language = "SCL"
        main.sclSource = """
        IF "BtnOn" THEN
            "Motor" := TRUE;
        END_IF;
        "Level" := 40.0 + 2.0 * 3.0;
        IF "Level" > 45.0 THEN
            "Alarm" := TRUE;
        END_IF;
        """
        d.blocks = [main]
        let sim = Simulator(); sim.attach(d)
        sim.setInput("BtnOn", true)
        sim.scanOnce()
        XCTAssertEqual(sim.values["Motor"], true)
        XCTAssertEqual(sim.num("Level"), 46)
        XCTAssertEqual(sim.values["Alarm"], true)
    }

    func testDataBlockOperandsWorkInLadder() {
        let mv = LadElement(kind: .move, tag: "Data.Level", outTag: "Copy")
        let d = device(tags: [
            PlcTag(name: "Lamp", dataType: "Bool", address: "%Q0.0"),
            PlcTag(name: "Copy", dataType: "Real", address: "%MD0")
        ], networks: [
            LadNetwork(title: "db flag", series: [el(.contactNO, "Data.Flag")], output: el(.coil, "Lamp")),
            LadNetwork(title: "db move", series: [mv], output: el(.coil, "Lamp"))
        ], dbs: [
            PlcDataBlock(name: "Data", number: 1, rows: [
                DbRow(name: "Flag", dataType: "Bool", startValue: "true"),
                DbRow(name: "Level", dataType: "Real", startValue: "25")
            ])
        ])
        let sim = Simulator(); sim.attach(d)
        sim.scanOnce()
        XCTAssertEqual(sim.values["Lamp"], true)
        XCTAssertEqual(sim.num("Copy"), 25)
    }

    func testForceOverridesPhysicalInput() {
        let sim = Simulator()
        sim.attach(TiaProject.motorProject().devices[0])
        sim.setForceBool("BtnOn", true)
        XCTAssertTrue(sim.isForced("BtnOn"))
        sim.scanOnce()
        XCTAssertEqual(sim.values["Motor"], true)
    }

    func testJumpSkipsNetworksUntilLabel() {
        let jmp = LadElement(kind: .jmp, tag: "LBL1")
        let lbl = LadElement(kind: .label, tag: "LBL1")
        let d = device(tags: [
            PlcTag(name: "Go", dataType: "Bool", address: "%I0.0"),
            PlcTag(name: "Skipped", dataType: "Bool", address: "%Q0.0"),
            PlcTag(name: "Reached", dataType: "Bool", address: "%Q0.1")
        ], networks: [
            LadNetwork(title: "jump", series: [el(.contactNO, "Go")], output: jmp),
            LadNetwork(title: "skipped", series: [], output: el(.coil, "Skipped")),
            LadNetwork(title: "label", series: [], output: lbl),
            LadNetwork(title: "after", series: [], output: el(.coil, "Reached"))
        ])
        let sim = Simulator(); sim.attach(d)
        sim.setInput("Go", true); sim.scanOnce()
        XCTAssertEqual(sim.values["Skipped"], false)
        XCTAssertEqual(sim.values["Reached"], true)
        sim.setInput("Go", false); sim.scanOnce()
        XCTAssertEqual(sim.values["Skipped"], true)
    }

    func testTwoParallelBranchesOrIntoOutput() {
        var net = LadNetwork(title: "branches", series: [el(.contactNO, "A")], output: el(.coil, "Out"))
        net.branches = [[el(.contactNO, "B")], [el(.contactNO, "C")]]
        net.syncParallel()
        let d = device(tags: [
            PlcTag(name: "A", dataType: "Bool", address: "%I0.0"),
            PlcTag(name: "B", dataType: "Bool", address: "%I0.1"),
            PlcTag(name: "C", dataType: "Bool", address: "%I0.2"),
            PlcTag(name: "Out", dataType: "Bool", address: "%Q0.0")
        ], networks: [net])
        let sim = Simulator(); sim.attach(d)
        sim.scanOnce()
        XCTAssertEqual(sim.values["Out"], false)
        sim.setInput("C", true); sim.scanOnce()
        XCTAssertEqual(sim.values["Out"], true)
        sim.setInput("C", false)
        sim.setInput("B", true); sim.scanOnce()
        XCTAssertEqual(sim.values["Out"], true)
    }
}
