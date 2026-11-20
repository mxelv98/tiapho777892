import Foundation

/// PLCSIM-lite: a scan-cycle evaluator for the taught LAD subset.
/// One scan every 100 ms while RUN is on. Contacts read the current value
/// table; coils write it. Timers (TON/TOF/TP) and counters (CTU/CTD) keep
/// runtime state per instance; edge contacts keep the previous scan value.
/// Teaching simplification (documented): in a network where a CTU feeds a
/// TON, the counter is reset when the TON hold finishes (Q falls) — the
/// same batch behaviour as the SortingStation SCL twin.
final class Simulator: ObservableObject {
    @Published var values: [String: Bool] = [:]
    @Published var counts: [String: Int] = [:]
    @Published var powered = false
    @Published var running = false

    private var tonElapsed: [String: Double] = [:]
    private var timerQ: [String: Bool] = [:]
    private var timerLastIN: [String: Bool] = [:]
    private var tpActive: [String: Bool] = [:]
    private var ctuCV: [String: Int] = [:]
    private var ctuLastCU: [String: Bool] = [:]
    private var counterKind: [String: LadElementKind] = [:]
    private var counterPV: [String: Int] = [:]
    private var edgePrev: [String: Bool] = [:]
    private var timer: Timer?
    private var device: PlcDevice?

    func attach(_ device: PlcDevice) {
        self.device = device
        if values.isEmpty { reset() }
    }

    func reset() {
        values = [:]; counts = [:]
        tonElapsed = [:]; timerQ = [:]; timerLastIN = [:]; tpActive = [:]
        ctuCV = [:]; ctuLastCU = [:]; counterKind = [:]; counterPV = [:]; edgePrev = [:]
        if let d = device { for t in d.tags { values[t.name] = false } }
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

    func setInput(_ tag: String, _ v: Bool) { values[tag] = v }

    func counterPV(_ instance: String) -> Int { counterPV[instance] ?? 0 }

    private func isTimer(_ k: LadElementKind) -> Bool { k == .ton || k == .tof || k == .tp }

    private func scan() {
        guard let d = device, let main = d.blocks.first(where: { $0.type == "OB" }) else { return }
        let dt = 0.1
        for net in main.networks {
            var power = true
            for el in net.series {
                if el.kind == .notOp { power = !power; continue }
                if el.kind == .ctu || el.kind == .ctd { applyCounter(el, cuPower: power) }
                if isTimer(el.kind) { advanceTimer(el, power: power, net: net, dt: dt) }
                power = power && elementValue(el)
            }
            if !net.parallel.isEmpty {
                var branch = true
                for el in net.parallel {
                    if el.kind == .notOp { branch = !branch; continue }
                    if el.kind == .ctu || el.kind == .ctd { applyCounter(el, cuPower: branch) }
                    branch = branch && elementValue(el)
                }
                power = power || branch
            }
            applyOutput(net.output, power: power, net: net, dt: dt)
        }
        counts = ctuCV
    }

    private func elementValue(_ el: LadElement) -> Bool {
        switch el.kind {
        case .contactNO: return values[el.tag] ?? false
        case .contactNC: return !(values[el.tag] ?? false)
        case .pTrig:
            let cur = values[el.tag] ?? false
            let prev = edgePrev[el.id.uuidString] ?? false
            edgePrev[el.id.uuidString] = cur
            return cur && !prev
        case .nTrig:
            let cur = values[el.tag] ?? false
            let prev = edgePrev[el.id.uuidString] ?? false
            edgePrev[el.id.uuidString] = cur
            return !cur && prev
        case .ton, .tof, .tp: return timerQ[el.instance] ?? false
        case .ctu: return (ctuCV[el.instance] ?? 0) >= el.presetValue
        case .ctd: return (ctuCV[el.instance] ?? el.presetValue) <= 0
        default: return values[el.tag] ?? false
        }
    }

    private func advanceTimer(_ el: LadElement, power: Bool, net: LadNetwork, dt: Double) {
        let wasQ = timerQ[el.instance] ?? false
        var q = wasQ
        switch el.kind {
        case .ton:
            if power { tonElapsed[el.instance] = (tonElapsed[el.instance] ?? 0) + dt }
            else { tonElapsed[el.instance] = 0 }
            q = power && (tonElapsed[el.instance] ?? 0) >= el.presetSeconds
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
        case .ton, .tof, .tp: advanceTimer(el, power: power, net: net, dt: dt)
        case .ctu, .ctd: applyCounter(el, cuPower: power)
        default: break
        }
    }

    /// CU/CD comes from the counter's input tag (rising edge) when one is
    /// set, otherwise from the rung power flowing into the counter.
    private func applyCounter(_ el: LadElement, cuPower: Bool) {
        counterKind[el.instance] = el.kind
        counterPV[el.instance] = el.presetValue
        if el.kind == .ctd && ctuCV[el.instance] == nil { ctuCV[el.instance] = el.presetValue }
        let cu = el.inputTag.isEmpty ? cuPower : (values[el.inputTag] ?? false)
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
