import Foundation

/// PLCSIM-lite: a scan-cycle evaluator for the taught LAD subset.
/// One scan every 100 ms while RUN is on. Contacts read the current value
/// table; coils write it. Timers (TON/TOF/TP/TONR) and counters
/// (CTU/CTD/CTUD) keep runtime state per instance; edge contacts keep
/// the previous scan value.
/// v4.0: numeric operands (Int/Real tags, data-block rows, counter CVs)
/// live in `nums`; comparators, math, MOVE, SR/RS, PID, JMP/LABEL/RET,
/// SCL blocks, a force table, value history (trends) and a small process
/// model (tank temperature / level) complete the teaching engine.
/// Teaching simplification (documented): in a network where a CTU feeds a
/// TON, the counter is reset when the TON hold finishes (Q falls) — the
/// same batch behaviour as the SortingStation SCL twin.
final class Simulator: ObservableObject {
    @Published var values: [String: Bool] = [:]
    @Published var nums: [String: Double] = [:]
    @Published var counts: [String: Int] = [:]
    @Published var timerET: [String: Double] = [:]   // elapsed time per timer instance (Part 3 live values)
    @Published var history: [String: [Double]] = [:] // numeric history per operand (HMI trends)
    @Published var powered = false
    @Published var running = false

    private var tonElapsed: [String: Double] = [:]
    private var timerQ: [String: Bool] = [:]
    private var timerLastIN: [String: Bool] = [:]
    private var tpActive: [String: Bool] = [:]
    private var ctuCV: [String: Int] = [:]
    private var ctuLastCU: [String: Bool] = [:]
    private var ctudLastCD: [String: Bool] = [:]
    private var counterKind: [String: LadElementKind] = [:]
    private var counterPV: [String: Int] = [:]
    private var edgePrev: [String: Bool] = [:]
    private var srState: [String: Bool] = [:]
    private var pidI: [String: Double] = [:]
    private var pidPrevPV: [String: Double] = [:]
    // Part 1 fix: separate input layers. The scan freezes an input image =
    // PLCSIM switch OR HMI write; HMI "true" writes are pulse-stretched so
    // a tap shorter than one scan is never lost.
    private var physBits: [String: Bool] = [:]
    private var hmiBits: [String: Bool] = [:]
    private var physNums: [String: Double] = [:]
    private var hmiPulse: Set<String> = []
    private var hmiSeen: Set<String> = []
    private(set) var inputImage: [String: Bool] = [:]
    private(set) var forcedBools: [String: Bool] = [:]
    private(set) var forcedNums: [String: Double] = [:]
    private var timer: Timer?
    private var device: PlcDevice?

    func attach(_ device: PlcDevice) {
        self.device = device
        if values.isEmpty { reset() }
    }

    func reset() {
        values = [:]; nums = [:]; counts = [:]; timerET = [:]; history = [:]
        tonElapsed = [:]; timerQ = [:]; timerLastIN = [:]; tpActive = [:]
        ctuCV = [:]; ctuLastCU = [:]; ctudLastCD = [:]; counterKind = [:]; counterPV = [:]; edgePrev = [:]
        srState = [:]; pidI = [:]; pidPrevPV = [:]
        physBits = [:]; hmiBits = [:]; physNums = [:]; hmiPulse = []; hmiSeen = []; inputImage = [:]
        forcedBools = [:]; forcedNums = [:]
        if let d = device {
            for t in d.tags {
                values[t.name] = false
                if t.dataType != "Bool" { nums[t.name] = Double(t.startValue ?? "") ?? 0 }
            }
            for db in d.dataBlocks ?? [] {
                for row in db.rows {
                    let key = "\(db.name).\(row.name)"
                    if row.dataType == "Bool" { values[key] = (row.startValue.lowercased() == "true") }
                    else { nums[key] = Double(row.startValue) ?? 0 }
                }
            }
        }
    }

    func power(_ on: Bool) {
        powered = on
        if !on { running = false; stopTimer() }
    }

    func run(_ on: Bool) {
        guard powered else { return }
        running = on
        if on { startTimer() } else { stopTimer() }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.scan() }
    }
    private func stopTimer() { timer?.invalidate(); timer = nil }

    /// Resolve a tag name OR an address (%I0.0) to the tag's name.
    private func resolve(_ tagOrAddress: String) -> String {
        guard let d = device else { return tagOrAddress }
        if d.tags.contains(where: { $0.name == tagOrAddress }) { return tagOrAddress }
        return d.tags.first { $0.address == tagOrAddress }?.name ?? tagOrAddress
    }

    private func publishMerged(_ name: String) {
        values[name] = (physBits[name] ?? false) || (hmiBits[name] ?? false)
    }

    /// PLCSIM switch / SIM-table write (level-held).
    func setInput(_ tag: String, _ v: Bool) {
        let name = resolve(tag)
        physBits[name] = v
        publishMerged(name)
    }

    /// HMI write (momentary buttons, I/O fields). A true write released
    /// before any scan has frozen it is held for exactly one more scan.
    func setHMIInput(_ tag: String, _ v: Bool) {
        let name = resolve(tag)
        if v { hmiSeen.remove(name) }
        else if (hmiBits[name] ?? false) && !hmiSeen.contains(name) { hmiPulse.insert(name) }
        if !v { hmiSeen.remove(name) }
        hmiBits[name] = v
        publishMerged(name)
    }

    /// One synchronous scan, for tests and single-stepping.
    func scanOnce() { scan() }

    func counterPV(_ instance: String) -> Int { counterPV[instance] ?? 0 }

    /// HMI slider write: set a counter's current value directly.
    func setCounterValue(_ instance: String, _ v: Int) {
        let val = max(0, v)
        ctuCV[instance] = val
        counts[instance] = val
    }

    // MARK: - Numeric operands (v4.0)

    /// Read a numeric operand: a literal, a numeric tag, a data-block row
    /// ("DB.Row"), or a counter instance (its CV).
    func num(_ operand: String) -> Double {
        if operand.isEmpty { return 0 }
        if let v = Double(operand) { return v }
        let name = resolve(operand)
        if let v = nums[name] { return v }
        if let v = nums[operand] { return v }
        if let cv = ctuCV[operand] { return Double(cv) }
        return 0
    }

    /// Program write to a numeric operand.
    func setNum(_ operand: String, _ v: Double) {
        guard !operand.isEmpty else { return }
        nums[resolve(operand)] = v
        if nums[operand] == nil { nums[operand] = v }
    }

    /// External (HMI / watch / recipe) write to a numeric operand. Input
    /// operands are written at the physical layer so the scan's frozen
    /// image picks them up instead of overwriting them.
    func setOperandNum(_ operand: String, _ v: Double) {
        let name = resolve(operand)
        if let d = device, let t = d.tags.first(where: { $0.name == name }), t.address.hasPrefix("%I") {
            physNums[name] = v
        }
        nums[name] = v
        if name != operand { nums[operand] = v }
    }

    /// SIM-table numeric modify (level-held physical value).
    func setNumInput(_ operand: String, _ v: Double) {
        let name = resolve(operand)
        physNums[name] = v
        nums[name] = v
    }

    // MARK: - Force table (v4.0)

    func setForceBool(_ operand: String, _ v: Bool?) {
        let name = resolve(operand)
        if let v { forcedBools[name] = v; values[name] = v } else { forcedBools[name] = nil }
    }

    func setForceNum(_ operand: String, _ v: Double?) {
        let name = resolve(operand)
        if let v { forcedNums[name] = v; nums[name] = v } else { forcedNums[name] = nil }
    }

    func isForced(_ operand: String) -> Bool {
        forcedBools[resolve(operand)] != nil || forcedNums[resolve(operand)] != nil
    }

    // MARK: - SCL accessors

    func sclValue(_ name: String) -> SclValue {
        if isBoolOperand(name) { return .bool(bit(name)) }
        return .num(num(name))
    }

    func sclSet(_ name: String, _ v: SclValue) {
        switch v {
        case .bool(let b):
            values[resolve(name)] = b
            if values[name] == nil { values[name] = b }
        case .num(let n):
            setNum(name, n)
        }
    }

    private func isBoolOperand(_ name: String) -> Bool {
        guard let d = device else { return nums[name] == nil }
        if let t = d.tags.first(where: { $0.name == name }) { return t.dataType == "Bool" }
        if name.contains(".") {
            let parts = name.split(separator: ".", maxSplits: 1)
            if parts.count == 2,
               let db = (d.dataBlocks ?? []).first(where: { $0.name == String(parts[0]) }),
               let row = db.rows.first(where: { $0.name == String(parts[1]) }) {
                return row.dataType == "Bool"
            }
        }
        return nums[name] == nil
    }

    // MARK: - Scan

    private func isTimer(_ k: LadElementKind) -> Bool { k == .ton || k == .tof || k == .tp || k == .tonr }

    private func scan() {
        guard let d = device, !d.blocks.isEmpty else { return }
        // Freeze the input image for the whole scan: PLCSIM switch OR HMI
        // write (plus a pulse-stretched HMI true not yet seen by any scan).
        for t in d.tags where t.address.hasPrefix("%I") {
            if t.dataType == "Bool" {
                var img = (physBits[t.name] ?? false) || (hmiBits[t.name] ?? false) || hmiPulse.contains(t.name)
                if let f = forcedBools[t.name] { img = f }
                inputImage[t.name] = img
                values[t.name] = img
                if hmiBits[t.name] ?? false { hmiSeen.insert(t.name) }
                hmiPulse.remove(t.name)
            } else if let pv = physNums[t.name] {
                nums[t.name] = forcedNums[t.name] ?? pv
            }
        }
        let dt = 0.1
        // OBs first, then FB/FC blocks in tree order (teaching model:
        // every block runs each scan, like a Main that calls them all).
        let ordered = d.blocks.filter { $0.type == "OB" } + d.blocks.filter { $0.type != "OB" }
        for block in ordered {
            if block.language == "SCL" {
                SclEngine.run(source: block.sclSource ?? "", sim: self)
            } else {
                runLadBlock(block, dt: dt)
            }
        }
        applyProcess()
        // Force wins over the program for this scan.
        for (k, v) in forcedBools { values[k] = v }
        for (k, v) in forcedNums { nums[k] = v }
        counts = ctuCV
        for (k, v) in nums {
            var h = history[k] ?? []
            h.append(v)
            if h.count > 200 { h.removeFirst(h.count - 200) }
            history[k] = h
        }
    }

    private func runLadBlock(_ block: PlcBlock, dt: Double) {
        var labels: [String: Int] = [:]
        for (i, net) in block.networks.enumerated() where net.output.kind == .label {
            labels[net.output.tag] = i
        }
        var idx = 0
        var guardSteps = 0
        while idx < block.networks.count && guardSteps < 10000 {
            guardSteps += 1
            let net = block.networks[idx]
            var power = evalRung(net.series, advanceTimers: true, net: net, dt: dt)
            for branch in net.branches {
                let bp = evalRung(branch, advanceTimers: false, net: net, dt: dt)
                power = power || bp
            }
            switch net.output.kind {
            case .jmp:
                if power, let target = labels[net.output.tag] { idx = target; continue }
            case .label:
                break
            case .ret:
                if power { return }
            default:
                applyOutput(net.output, power: power, net: net, dt: dt)
            }
            idx += 1
        }
    }

    /// Evaluate one rung (series or one parallel branch) and return the
    /// power leaving it. Side effects (counters, math, PID…) happen in
    /// element order, exactly like the scan reads the rung.
    private func evalRung(_ elements: [LadElement], advanceTimers: Bool, net: LadNetwork, dt: Double) -> Bool {
        var power = true
        for el in elements {
            if el.kind == .notOp { power = !power; continue }
            switch el.kind {
            case .ctu, .ctd, .ctud:
                applyCounter(el, cuPower: power)
            case .ton, .tof, .tp, .tonr:
                if advanceTimers { advanceTimer(el, power: power, net: net, dt: dt) }
            case .sr, .rs:
                applySR(el, sPower: power)
            case .math, .move:
                if power { execMath(el) }
            case .pid:
                if power { applyPID(el, dt: dt) }
            default:
                break
            }
            power = power && elementValue(el)
        }
        return power
    }

    /// Read a bit the way the running scan sees it: inputs come from the
    /// frozen input image, everything else from the value table.
    private func bit(_ tag: String) -> Bool {
        if let img = inputImage[tag] { return img }
        return values[tag] ?? false
    }

    private func elementValue(_ el: LadElement) -> Bool {
        switch el.kind {
        case .contactNO: return bit(el.tag)
        case .contactNC: return !bit(el.tag)
        case .pTrig:
            let cur = bit(el.tag)
            let prev = edgePrev[el.id.uuidString] ?? false
            edgePrev[el.id.uuidString] = cur
            return cur && !prev
        case .nTrig:
            let cur = bit(el.tag)
            let prev = edgePrev[el.id.uuidString] ?? false
            edgePrev[el.id.uuidString] = cur
            return !cur && prev
        case .ton, .tof, .tp, .tonr: return timerQ[el.instance] ?? false
        case .ctu: return (ctuCV[el.instance] ?? 0) >= el.presetValue
        case .ctd: return (ctuCV[el.instance] ?? el.presetValue) <= 0
        case .ctud: return (ctuCV[el.instance] ?? 0) >= el.presetValue
        case .sr, .rs: return srState[el.instance] ?? false
        case .cmp: return cmpResult(el)
        default: return values[el.tag] ?? false
        }
    }

    // MARK: - Instructions (v4.0)

    private func cmpResult(_ el: LadElement) -> Bool {
        let a = num(el.tag)
        let b = el.useConst ? el.constValue : num(el.inputTag)
        switch el.op {
        case "EQ": return abs(a - b) < 0.0001
        case "NE": return abs(a - b) >= 0.0001
        case "GT": return a > b
        case "GE": return a >= b
        case "LT": return a < b
        case "LE": return a <= b
        default: return a > b
        }
    }

    private func execMath(_ el: LadElement) {
        let a = num(el.tag)
        let b = el.useConst ? el.constValue : num(el.inputTag)
        let r: Double
        if el.kind == .move {
            r = a
        } else {
            switch el.op {
            case "SUB": r = a - b
            case "MUL": r = a * b
            case "DIV": r = b == 0 ? 0 : a / b
            case "SHL": r = Double(Int(a) << max(0, min(31, Int(b))))
            case "SHR": r = Double(Int(a) >> max(0, min(31, Int(b))))
            default: r = a + b   // ADD
            }
        }
        setNum(el.outTag, r)
    }

    private func applySR(_ el: LadElement, sPower: Bool) {
        let r = el.inputTag.isEmpty ? false : bit(el.inputTag)
        var state = srState[el.instance] ?? false
        if el.kind == .sr {          // reset dominant
            if r { state = false } else if sPower { state = true }
        } else {                     // rs: set dominant
            if sPower { state = true } else if r { state = false }
        }
        srState[el.instance] = state
        if !el.tag.isEmpty { values[el.tag] = state }
    }

    private func applyPID(_ el: LadElement, dt: Double) {
        let sp = num(el.tag)
        let pv = num(el.inputTag)
        let e = sp - pv
        var iNew = pidI[el.instance] ?? 0
        if el.ti > 0 { iNew += (el.kp / el.ti) * e * dt }
        let prevPV = pidPrevPV[el.instance] ?? pv
        let dTerm = el.td > 0 ? -el.kp * el.td * (pv - prevPV) / dt : 0
        var out = el.kp * e + iNew + dTerm
        // Conditional-integration anti-windup, then clamp to 0…100 %.
        if (out > 100 && e > 0) || (out < 0 && e < 0) {
            out = el.kp * e + (pidI[el.instance] ?? 0) + dTerm
        } else {
            pidI[el.instance] = iNew
        }
        out = max(0, min(100, out))
        pidPrevPV[el.instance] = pv
        setNum(el.outTag, out)
    }

    // MARK: - Process model (v4.0)

    /// A tiny plant the students can close a loop around: a heated tank.
    /// Runs only when the project actually has these operands.
    private func applyProcess() {
        if nums["TankTemp"] != nil && nums["HeaterPower"] != nil {
            var t = nums["TankTemp"] ?? 20
            t += (nums["HeaterPower"] ?? 0) / 100.0 * 0.09 - (t - 20) * 0.0008
            nums["TankTemp"] = max(20, min(98, t))
        }
        if nums["TankLevel"] != nil {
            let fill = (bit("FillCmd") || bit("Pump")) ? 0.09 : (nums["PumpPower"] ?? 0) * 0.0009
            let drain = (bit("DrainCmd") || bit("Valve")) ? 0.11 : (nums["ValvePower"] ?? 0) * 0.0011
            let l = (nums["TankLevel"] ?? 0) + fill - drain
            nums["TankLevel"] = max(0, min(100, l))
        }
    }

    // MARK: - Timers / counters / outputs

    private func advanceTimer(_ el: LadElement, power: Bool, net: LadNetwork, dt: Double) {
        let wasQ = timerQ[el.instance] ?? false
        var q = wasQ
        switch el.kind {
        case .ton:
            if power { tonElapsed[el.instance] = (tonElapsed[el.instance] ?? 0) + dt }
            else { tonElapsed[el.instance] = 0 }
            q = power && (tonElapsed[el.instance] ?? 0) >= el.presetSeconds
        case .tonr:
            // Accumulates across IN gaps; only the R operand resets it.
            if !el.inputTag.isEmpty && bit(el.inputTag) { tonElapsed[el.instance] = 0 }
            else if power { tonElapsed[el.instance] = (tonElapsed[el.instance] ?? 0) + dt }
            q = (tonElapsed[el.instance] ?? 0) >= el.presetSeconds
        case .tof:
            if power { tonElapsed[el.instance] = 0; q = true }
            else {
                tonElapsed[el.instance] = (tonElapsed[el.instance] ?? 0) + dt
                q = (tonElapsed[el.instance] ?? 0) < el.presetSeconds
            }
        case .tp:
            let last = timerLastIN[el.instance] ?? false
            if power && !last { tpActive[el.instance] = true; tonElapsed[el.instance] = 0 }
            timerLastIN[el.instance] = power
            if tpActive[el.instance] ?? false {
                tonElapsed[el.instance] = (tonElapsed[el.instance] ?? 0) + dt
                q = (tonElapsed[el.instance] ?? 0) < el.presetSeconds
                if !q { tpActive[el.instance] = false }
            } else { q = false }
        default: break
        }
        timerQ[el.instance] = q
        timerET[el.instance] = tonElapsed[el.instance] ?? 0
        if !el.tag.isEmpty { values[el.tag] = q }
        if el.kind == .ton && wasQ && !q {
            for s in net.series where s.kind == .ctu { ctuCV[s.instance] = 0 }
        }
    }

    private func applyOutput(_ el: LadElement, power: Bool, net: LadNetwork, dt: Double) {
        switch el.kind {
        case .coil: values[el.tag] = power
        case .coilSet: if power { values[el.tag] = true }
        case .coilReset:
            if power {
                if let kind = counterKind[el.tag] {
                    ctuCV[el.tag] = (kind == .ctd) ? (counterPV[el.tag] ?? 0) : 0
                } else { values[el.tag] = false }
            }
        case .ton, .tof, .tp, .tonr: advanceTimer(el, power: power, net: net, dt: dt)
        case .ctu, .ctd, .ctud: applyCounter(el, cuPower: power)
        case .sr, .rs: applySR(el, sPower: power)
        case .cmp:
            if !el.outTag.isEmpty { values[el.outTag] = power && cmpResult(el) }
        case .math, .move:
            if power { execMath(el) }
        case .pid:
            if power { applyPID(el, dt: dt) } else { pidPrevPV[el.instance] = num(el.inputTag) }
        default: break
        }
    }

    /// CU/CD comes from the counter's input tag (rising edge) when one is
    /// set, otherwise from the rung power flowing into the counter.
    /// CTUD: CU is the rung power / input flow, CD is the input tag.
    private func applyCounter(_ el: LadElement, cuPower: Bool) {
        counterKind[el.instance] = el.kind
        counterPV[el.instance] = el.presetValue
        if el.kind == .ctd && ctuCV[el.instance] == nil { ctuCV[el.instance] = el.presetValue }
        if el.kind == .ctud {
            let lastU = ctuLastCU[el.instance] ?? false
            if cuPower && !lastU { ctuCV[el.instance] = (ctuCV[el.instance] ?? 0) + 1 }
            ctuLastCU[el.instance] = cuPower
            let cd = el.inputTag.isEmpty ? false : bit(el.inputTag)
            let lastD = ctudLastCD[el.instance] ?? false
            if cd && !lastD { ctuCV[el.instance] = (ctuCV[el.instance] ?? 0) - 1 }
            ctudLastCD[el.instance] = cd
            if !el.tag.isEmpty { values[el.tag] = (ctuCV[el.instance] ?? 0) >= el.presetValue }
            return
        }
        let cu = el.inputTag.isEmpty ? cuPower : bit(el.inputTag)
        let last = ctuLastCU[el.instance] ?? false
        if cu && !last {
            if el.kind == .ctd { ctuCV[el.instance] = (ctuCV[el.instance] ?? el.presetValue) - 1 }
            else { ctuCV[el.instance] = (ctuCV[el.instance] ?? 0) + 1 }
        }
        ctuLastCU[el.instance] = cu
        if !el.tag.isEmpty {
            values[el.tag] = el.kind == .ctd
                ? (ctuCV[el.instance] ?? el.presetValue) <= 0
                : (ctuCV[el.instance] ?? 0) >= el.presetValue
        }
    }
}
